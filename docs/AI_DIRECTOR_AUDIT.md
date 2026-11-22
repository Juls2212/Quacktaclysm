# Auditoría del Director de IA (Fase 16-0, solo lectura)

Fecha: 2026-11-21. Esta fase no cambia código: solo se creó este informe. No se leyó ni se imprimió `ai-service/.env` (está en `.gitignore`, línea 14) y no se ejecutó ninguna prueba.

## 1. Flujo actual de la IA

**Servicio (`ai-service/app/`, FastAPI + Responses API)**
- Dos endpoints: `GET /health` y `POST /v1/adaptive/profile`. `/health` expone solo `status`, `mode` (`mock` u `openai`) y `openai_configured` (booleano); nunca la clave ni el modelo.
- Esquema de petición (`schemas.py`, estricto, `extra="forbid"`): `released` y `kept` (0-10), `current_level` (1-3), `evaluation_point` (`after_decision`, `level_start`, `ending`), `local_profile` y hasta 10 `decisions` (`fragment_id` y `boss_id` con patrón `^[a-z0-9_]{1,64}$`, `level`, `choice`). No hay ningún texto libre del jugador.
- Respuesta: `profile` (3 valores), `narrative_variant` y `source` (`openai` o `mock`).
- Salida estructurada (`openai_client.py`): `text.format = json_schema` estricto con `profile` y `narrative_variant` (enums), `max_output_tokens = 400`, `store=False`, un reintento del SDK. El prompt de sistema declara que el mensaje de usuario son datos, no instrucciones.
- Modo mock: `rules.classify` (liberada +1, guardada −1; umbral 1,0) y variante por defecto del perfil. El modo `openai` sin clave o modelo degrada a mock con un único aviso sin material secreto. La configuración sale de `ai-service/.env` por `python-dotenv` (los valores del archivo ganan a variables de shell).
- Errores: 504 (timeout), 502 (error o respuesta inservible, nunca texto del SDK), 503 (sin configurar), 422 (petición inválida sin eco de la entrada), 413 (cuerpo > 16 KB). El log de acceso guarda método, ruta, estado y duración, nunca cuerpos ni cabeceras.
- Sin autenticación ni límite de tasa (lo dice una nota en `main.py`).

**Cliente (`game/backend/ai/`)**
- No hay autoload de IA: `AdaptiveRefiner` (nodo hijo de cada nivel, `level_base.tscn`) usa `AiClient` (HTTPRequest no bloqueante, una petición a la vez, estados `ok/disabled/invalid_url/connection_failed/timeout/http_error/invalid_json/cancelled`). `AiServiceConfig` no contiene claves; URL por defecto `http://127.0.0.1:8000`, anulable con la variable `QUACKTACLYSM_AI_URL`; tiempo de espera 10 s, respuesta máxima 4096 bytes.
- Cuándo se llama: solo tras una decisión de fragmento (`DecisionFlow`, punto `after_decision`, y `ending` en el nivel 3). La decisión se aplica primero con el clasificador local y la IA solo refina después, sin bloquear. `LevelBase` espera como mucho `refine_wait_timeout` = 3 s antes de avanzar de nivel.
- Qué hace el juego con cada campo (`AdaptiveResponseValidator`): `profile` debe estar a distancia ≤ `max_profile_distance` del perfil local; con el valor entregado (0) debe ser idéntico, así que la IA no cambia el perfil. `narrative_variant` solo se acepta si está en la lista del perfil. Todo lo demás (variante de encuentro, `ending_variant`, `boss_aggression` 0,9/1,0/1,15) sale de la tabla del perfil, no de la IA.
- Consumidores reales: `boss_aggression` (`LevelBase._apply_adaptive` → `boss.set_aggression`), `encounter_variant` (`variant_groups`: enemigos extra del nivel 3) y `narrative_variant` (solo la línea de introducción del nivel, `intro_lines`). `ending_variant` no lo lee nadie: los finales se eligen por almas liberadas (`EndingSelector`).
- Sin conexión: `refinement_skipped`, el estado local se mantiene y el jugador no ve errores (cubierto por `ai_down_phase14g_smoke_test`).
- Hallazgo: `adaptive_narrative_variant` vive solo en memoria (`GameState`), así que al continuar desde disco la variante remota se pierde y vuelve la del perfil.

## 2. Telemetría existente y faltante

| Dato | Dónde se registra | ¿Persistido? |
|---|---|---|
| Decisiones (id, jefe, nivel, elección) | `GameState.decisions` | Sí (clave `decisions`) |
| Almas liberadas / guardadas | `GameState.souls_released/kept` | Sí |
| Perfil adaptativo | `GameState.adaptive_profile` | Sí |
| Nivel y checkpoint | `GameState.current_level/checkpoint` | Sí |
| Variante narrativa remota | `GameState.adaptive_narrative_variant` | No (memoria) |
| Muertes, daño recibido por origen, uso de ligero/pesado/dash/onda/doble salto, curaciones, tiempo por nivel, bajas, precisión | En ningún sitio | Falta todo |

Las señales ya existen para recogerlo sin tocar la lógica: `Player` (`dash_started`, `attack_started`, `heavy_attack_started`, `dash_slash_started`, `wave_cast`, `double_jumped`, `focus_completed`, `died`, `respawned`), `HealthComponent.damaged(info)` con `DamageInfo.source/team/attack_kind` (desde la 15e-1) y `EnemyBase.died`. Falta un colector.

Recomendación: un `RunTelemetry` (RefCounted) en memoria, con campo en `GameState` (autoload existente, sin clave de guardado ni autoload nuevos), alimentado por un nodo observador en cada nivel. Lo que se envía son categorías (bajo/medio/alto), no recuentos, y un tema calculado en local.

## 3. Puntos de enganche y topes propuestos

El plan se aplica en `LevelBase._apply_adaptive` (que ya corre una vez al cargar), nunca durante una pelea y siempre mediante recursos, no en nodos visuales.

| Enganche | Qué se tocaría | Parámetros acotados |
|---|---|---|
| Enemigos y extras | `variant_groups` y huecos de aparición definidos en la escena del nivel | Entre 0 y 3 enemigos extra por encima de la base; solo en huecos ya definidos (≥ 150 px de los bordes de hueco, regla de la 15e-2); nunca más del 150 % de los enemigos base |
| Énfasis de patrones del jefe | `BossPattern.weight` desde `BossBase` | Multiplicador de peso entre 0,6 y 1,5 por patrón; nunca cero, ningún patrón fuera de su fase; los telegraphs mínimos no se tocan |
| Agresión del jefe | `boss.set_aggression` | Se mantiene 0,9/1,0/1,15 del perfil; el Director solo puede moverlo dentro de ±0,05 |
| Vida y daño | `BossStats`, hitboxes | Sin cambio posible: tope fijo, daño ≤ 1 corazón, vida del jefe intacta |
| Introducción del jefe e historia | `BossIntro` / textos | Solo elegir entre líneas ya escritas; la IA no escribe diálogo del jefe |
| Selección de final | `EndingSelector` (3/2/1/0 almas) | Los cuatro finales no cambian; el Director solo elige una variante de epílogo entre un máximo de tres ya escritas por final |
| Perfil de corrupción | — | Nunca: el plan no lleva campo de perfil |

## 4. Persistencia sin clave nueva

| Opción | Pros | Contras |
|---|---|---|
| A. Recalcular desde telemetría guardada | Estable | La telemetría no se guarda (haría falta una 8.ª clave) |
| B. Guardar dentro de `adaptive_profile` | Sin clave nueva | Esa cadena es un enumerado validado; mezclar un plan la rompe y arriesga que la IA toque el perfil |
| C. Recalculo local determinista | Cero claves, reproducible | Al continuar se pierde la parte "inteligente" de esa sesión |

Recomendación: C con caché. El plan validado se guarda en memoria por nivel, de modo que muertes y reintentos en la misma sesión lo conservan. Al continuar desde disco, el planificador local calcula el plan de forma determinista a partir de decisiones, nivel y perfil guardados (semilla derivada de ellos). La IA solo se consulta cuando hay telemetría fresca en memoria, o sea al avanzar de nivel en vivo.

## 5. Seguridad y robustez

- Superficie de inyección: hoy no hay texto del jugador en la petición (solo identificadores validados por expresión regular). Para el Director, enviar solo categorías y un tema (enumerado), nunca texto libre, y mantener la instrucción de que el mensaje de usuario son datos.
- Validación: esquema estricto de salida estructurada y validación local. Toda salida del modelo se trata como no fiable.
- Línea libre: 8-18 palabras y ≤ 110 caracteres, sin dígitos, sin saltos de línea, sin marcas ni direcciones, solo caracteres del español, sin palabras de reproche y sin nombrar personajes distintos de «nieto». Si falla, se usa la línea del banco local.
- Límites de tasa: hoy no hay. Añadir tope por IP y por día antes de alojarlo públicamente, además de HTTPS.
- Coste por partida completa: unas 3-4 peticiones (niveles 2 y 3, fin, quizá el nivel 1), cada una de unos 700 tokens de entrada y menos de 200 de salida; del orden de 4 000 tokens por partida, es decir, céntimos o menos con un modelo pequeño. El modelo concreto está en `.env` y no se leyó.
- Latencia: el cliente espera 10 s y el servicio 8 s con un reintento (el peor caso supera el tiempo del cliente). El Director necesita un presupuesto de unos 3 s con configuración propia, y se pide durante la transición de escena.
- Clave ausente o rotada: el servicio degrada a mock y el cliente nunca ve la clave. Una clave rotada produce 502 y el cliente cae al planificador local.
- Registros: ya no se guardan cuerpos; el Director no debe registrar telemetría ni líneas.

## 6. Plan de pruebas

Cubiertas hoy: `adaptive_phase9_smoke_test` (clasificador y validador), `ai_phase10_smoke_test` (cliente y refinador con transporte falso), `ai_phase10_integration_test` (servicio real en mock), `ai_down_phase14g_smoke_test` (sin conexión) y 22 pruebas pytest en `ai-service/tests/test_service.py` más las de `test_env_loading.py` (mock, 502/504/503, ausencia de fugas de clave).

Haría falta: pruebas unitarias del validador del plan (límites y rechazo), modo de plan fijo para reproducibilidad, caída al planificador local por tiempo de espera, topes nunca superados (por cálculo, con todos los extremos), línea validada con el banco de reserva, ninguna clave de guardado nueva (siguen 7), ningún autoload nuevo (siguen 3) y pytest del nuevo esquema.

## 7. Fases propuestas

| Fase | Contenido | Esfuerzo |
|---|---|---|
| 16a | Colector de telemetría en memoria y categorías | 1 día |
| 16b | Esquema del servicio, validador Python y modo mock del plan | 1-1,5 días |
| 16c | Plan local determinista, aplicación en el nivel, caché, tiempo de espera y respaldo | 2 días |
| 16d | Línea del abuelo, reflejo del cielo y epílogo | 1,5-2 días |
| 16e | Pruebas y documentación | 1 día |

Riesgos: el equilibrio de enemigos extra y pesos, que el reflejo choque con otros elementos del inicio de nivel y que el plan parezca arbitrario si no se explica.

Lo que no haría: cambiar el perfil con la IA, dejar que escriba diálogo del jefe o historia, actuar a mitad de pelea, enviar recuentos brutos o texto del jugador, guardar el plan en el archivo de guardado, ni tocar vida o daño.

## 8. Voz y reflejo del abuelo

**a) El abuelo en la historia.** Es un samurái que entrenó al pato; lo llama «nieto», habla corto y con ternura: «El filo no es rabia, nieto. Es respeto por aquello que cortas.», «no te juzgo», «Cuídala». Su aparición directa es la escena «El abuelo vuelve» del nivel 3 (cueva del prólogo, `ElderScene`), y en los capítulos 1 y 2 el pato lo recuerda y habla de su silencio. Un reflejo nítido con voz propia en los niveles 1 y 2 estropearía esa revelación y contradiría el silencio. Propuesta: en los niveles 1 y 2 el reflejo es una silueta borrosa, hecha de estrellas y sin cara, y la línea se presenta como un recuerdo («Recuerdas la voz de tu abuelo: …»); se afina en el nivel 2 y es nítida y con su voz directa en el 3.

**b) Dónde vive el reflejo.** Lo más limpio es un nodo propio (CanvasLayer detrás del campo de juego y encima del fondo) dibujado por código. `Backdrop` (cielo, capas y partículas) y `ProfilePresenter` (tinte por perfil y superposición con viñeta) ya existen, pero el reflejo no debe vivir dentro de ellos: así hereda el tinte de corrupción del cielo como cualquier otra capa sin lógica de juego en nodos visuales. Interacción: el rojo de posesión solo aparece en peleas, y el reflejo nunca se muestra en una pelea. Con «Efectos de corrupción» desactivado: sin brillo ni movimiento. En el nivel 3 hay que convivir con el clima de tormenta (`StormWeather`) y el cambio de bioma a mitad de nivel.

**c) Dónde se muestra la línea.** `LevelBase` ya muestra la tarjeta de título, la línea de introducción (`intro_lines`, 4 s) y la línea de consecuencia. Propuesta: encolar un paso `director_line` en `PresentationQueue` después de ellos; en el nivel 3, después de la escena del abuelo (que pausa el juego), nunca durante. `AbilityIntro` actúa tras decisiones del nivel anterior y `BossIntro` solo en el encuentro, así que no colisionan; con checkpoint de arena (continuar) no se muestra. En el nivel 1 hay poca telemetría (solo el tutorial); recomiendo que el Director arranque en el nivel 2.

**d) Temas y líneas de ejemplo (8-18 palabras, sin cifras ni reproche).**

| Tema | Línea 1 | Línea 2 |
|---|---|---|
| Calma | El agua turbia se aclara cuando dejas de agitarla, nieto. Respira primero. | Un filo tranquilo corta más limpio que uno temblando. Suelta los hombros, nieto. |
| Paciencia | El bambú no corre hacia el cielo, nieto. Crece un nudo cada vez. | Quien espera el momento justo no pierde el paso. Aguanta un poco más. |
| Distancia | Lo que muerde de cerca, calla de lejos. Mide el espacio, nieto. | Un buen guerrero elige dónde pisar antes de elegir dónde cortar. |
| Ritmo | Todo golpe tiene su respiración, nieto. Escucha el silencio antes del trueno. | La hoja llega cuando el viento se detiene. Aprende a esperar ese instante. |
| Recursos | Una brasa bien guardada calienta toda la noche. Cuida tus fuerzas, nieto. | El sabio no gasta todo su aliento en la primera colina. |
| Valor | El miedo también camina contigo, nieto. Que vaya detrás, no delante. | Dar un paso temblando sigue siendo dar un paso. Avanza. |
| Equilibrio | Soltar y cargar pesan distinto, nieto. Elige con el corazón despierto. | La luz no se gasta al compartirla. Recuérdalo cuando dudes. |

**Reglas del validador.** 8-18 palabras y ≤ 110 caracteres; una sola línea; ningún dígito; solo letras del español y puntuación simple; sin corchetes, direcciones ni emojis; sin palabras de reproche (murió, moriste, fallaste, fracaso, culpa, error, torpe, débil, inútil, perdiste, derrota); sin imperativos de instrucción (ignora, sistema); sin nombres de personajes distintos de «nieto»; sin alusiones a jefes o niveles. Si no pasa, se usa una línea del banco local determinista (semilla: tema, nivel y decisiones).
