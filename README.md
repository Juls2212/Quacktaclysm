# Quacktaclysm

Videojuego 2D de acción en vista lateral con combate con espada (cuerpo a cuerpo y una onda a distancia), enemigos y jefes, hecho con Godot 4 y GDScript para escritorio (prioridad Windows, compatible con macOS). El nombre oficial es Quacktaclysm (`config/name` en Project Settings). El jugador recorre un tutorial y tres niveles; tras cada jefe decide **Liberar** o **Conservar** un fragmento de alma, y esas decisiones cambian la dificultad de los jefes, los enemigos extra, la potencia de la onda y el final. Un servicio de IA opcional puede refinar ese perfil.

> **Estado:** todo el contenido jugable existe. Héroe, enemigos y jefes son patos dibujados y animados por código (`DuckRig`) que caen como ragdoll al morir; los niveles tienen cielo, parallax y pisos orgánicos por bioma, y el menú principal es una escena animada con letra propia ("Pato Tinta"). Los proyectiles y las puertas siguen con arte provisional (los proyectiles enemigos llevan un contorno de peligro dibujado); el HUD, la pausa, el Game Over y los menús ya tienen su aspecto definitivo de piedra. Nadie lo ha jugado con ventana todavía: ver `docs/KNOWN_ISSUES.md`.

## Requisitos

- **Godot 4.7.x** (desarrollado con 4.7.2 stable). Versiones detectadas en `docs/ENVIRONMENT.md`.
- **Python 3.11** solo para el servicio de IA (`ai-service/`) y el ejecutor de pruebas (`tools/run_all_tests.py`, solo biblioteca estándar).

## Estructura del repositorio

```
game/             Proyecto de Godot (raíz: game/project.godot)
  frontend/       Escenas, UI, niveles, animaciones, sprites y audio
  backend/        Lógica del juego (player, combat, enemies, bosses,
                  decisions, ai, persistence, progression)
ai-service/       Servicio de IA externo (FastAPI) y sus pruebas
docs/             Documentación (ver la lista al final)
tools/            Utilidades (ejecutor de pruebas)
builds/           Salida de la exportación (ignorada por Git)
```

- **frontend** = escenas, UI, arte, audio y niveles. **backend** = lógica del juego. **ai-service** = servicio de IA externo.

## Abrir y ejecutar el proyecto

1. Instala Godot 4.7.x.
2. En el gestor de proyectos importa `game/project.godot`.
3. Pulsa F5: se abre el menú principal (`game/frontend/ui/main_menu.tscn`).

## Controles

| Acción | Teclas por defecto (se pueden cambiar) |
| --- | --- |
| Mover | A / D o flechas izquierda / derecha |
| Saltar | Espacio o flecha arriba |
| Dash | Shift o K |
| Ataque de espada | J o clic izquierdo |
| Onda de espada (a distancia) | **U o clic derecho** |
| Golpe pesado | **I o clic central** |
| Curarse (mantener) | **E o Q** |
| Tajo de dash | pulsar **ataque durante el dash** (sin tecla propia) |
| Pausa | Esc o P |

**Cambiar los controles:** en **Opciones → Controles…** (desde el menú principal o desde la pausa). Cada acción tiene una asignación **principal** y una **alternativa**, de teclado o de ratón (clic izquierdo, derecho, central y botones laterales). Haz clic en una casilla, pulsa la tecla o el botón nuevo y ya está; la "×" quita la alternativa (la principal no se puede quitar). Si la tecla ya la usa otra acción, el juego pregunta si **intercambiar** o cancelar. **Esc cancela** la captura y está **reservada**: siempre pausa y no se puede asignar a otra acción. "Restaurar valores por defecto" lo deja todo como en la tabla. Los cambios se aplican al instante y se guardan en `user://controls.cfg` (en Windows, `%APPDATA%\Godot\app_userdata\Quacktaclysm\controls.cfg`), un archivo aparte de la partida; **para restaurar a mano, borra ese archivo con el juego cerrado**. Los textos del tutorial muestran siempre las asignaciones actuales. El mando (gamepad) no está soportado.

**Corrupción visible y audible (Fase 14c):** el perfil adaptativo (compasivo / neutral / corrupto) se nota en el mundo. Con el perfil **corrupto** el fondo se vuelve violeta frío y desaturado, aparece una viñeta oscura en los bordes, los enemigos y jefes brillan (ojo y aro de la cabeza), el pato tiene un aura tenue y la música suena más grave y apagada. Con el **compasivo** todo es más cálido y dorado y la música no se apaga. Con el **neutral** el aspecto es el de siempre. Al tomar una decisión que **cambia** el perfil, la placa de la corrupción y la pantalla dan un destello breve y los colores y la música cambian de forma gradual. Es solo presentación: ningún valor de juego cambia. En **Opciones** hay un interruptor **"Efectos de corrupción"** (activado por defecto): apagado, desaparecen los tintes, la viñeta, los destellos, el brillo y los efectos de música, pero la placa del HUD y la línea de consecuencias se quedan. Se guarda en `user://settings.cfg` junto al resto de opciones (nunca en la partida).

**Historia y dos finales (Fases 14d y 15h):** cada alma tiene nombre, un recuerdo (se ve en el panel de decisión) y una frase para liberarla y otra para conservarla; los tres guardianes hablan al empezar el combate (Enter salta las líneas) y una al caer; el abuelo vuelve al llegar al nivel 3 (escena corta de unos 20 s, Enter la salta) y revela el sentido de la profecía. El final depende **solo de cuántas almas liberaste**: 3 = *El cielo se abre*, 2 = *La cicatriz del cielo* (nombra el alma guardada), 1 = *El filo y la duda* (nombra la única liberada), 0 = *La nueva estrella caída*. Cada final es una secuencia de subtítulos de ~35-60 s sobre el sistema de planos del prólogo (**mantén Enter para saltarla**) y termina en una tarjeta de resumen con los contadores y los **nombres** de las almas liberadas y guardadas. Todo el guion está en `game/backend/story/default_story_texts.tres` y, para leerlo y revisarlo, en `docs/STORY.md`.

**Ataques legibles (Fase 14e):** cada ataque enemigo avisa con una forma dibujada en el suelo que **se llena durante la preparación**: el golpe cuerpo a cuerpo, un arco corto delante (naranja; rojo claro y más ancho en el enemigo robusto); el enemigo rápido, un carril estrecho que marca la embestida (amarillo); el que dispara, una línea fina hacia ti (rosa); y los jefes, un arco ancho (golpe), un carril largo (embestida) o varias líneas en abanico (descarga). Además hay un signo de exclamación sobre la cabeza de los enemigos, un sonido distinto por tipo, un destello blanco y un pequeño rebote al recibir un golpe (algo más fuerte en los jefes), un tinte apagado mientras se recuperan (la ventana para castigarlos) y una pequeña alma que sale al morir. **No cambia ningún tiempo ni valor del juego**, y los avisos se ven siempre, también con "Efectos de corrupción" desactivado. Todo se retoca en `game/frontend/fx/default_telegraphs.tres`.

**Más sonido y proyectiles legibles (Fase 14f):** pasos al correr (marcados por la distancia recorrida), impactos de los proyectiles (contra el escenario, el pato o un enemigo) y de la onda de espada, exorcismo, acorde de la presentación del jefe, título del nivel, portal, cambio de escena y Game Over. Cada jefe tiene su propia música (el jefe 1 y el 3 usan la misma pista a distinto tono) y la música baja un poco mientras alguien habla o dura la presentación. Los proyectiles enemigos llevan un **contorno de peligro** rojo-anaranjado con un halo que late, distinto de la onda de espada del pato (azul, cian o violeta). Todos los sonidos nuevos están en **una tabla editable**, `game/frontend/audio/default_audio_events.tres`, junto con la música de cada jefe. No hay audio ni arte nuevos (se reutilizan archivos con otro tono y volumen) y no cambia ningún valor de juego.

La pausa no se abre si otro sistema ya tiene el juego pausado (panel de decisión, Game Over), durante una transición o con el jugador muerto. "Menú principal" **no guarda**: se pierde el progreso posterior al último guardado automático. En un build de depuración además: `K` mata al jefe (¡coincide con el dash!, ver `docs/KNOWN_ISSUES.md`), `H` le quita el 10 %, `F2` te lleva al checkpoint de la arena y `F3` muestra datos de depuración; las escenas de pruebas (`boss_test`, etc.) tienen sus propias teclas.

## Flujo del juego

menú principal → **tutorial** (mover, saltar, esquivar, atacar, golpear al muñeco, lanzar la onda) → **Nivel 1** → **Nivel 2** → **Nivel 3** → **final** → menú principal.

En cada nivel: recorrer, llegar al checkpoint de la arena, derrotar al jefe (las puertas se cierran durante el combate), recoger el fragmento de alma y decidir. Tras la decisión el nivel avanza solo. Al completar el Nivel 3 se guarda `checkpoint = "ending"` y se abre el final.

- **Nueva partida:** reinicia el estado y abre el tutorial. Si ya hay partida guardada pide confirmación; el archivo no se borra, se reemplaza en el próximo guardado automático.
- **Continuar:** carga el archivo y abre el nivel guardado; si la partida está **completada** (`checkpoint = "ending"`) reabre el final. Si el archivo está dañado o es de una versión más nueva, muestra un mensaje y no cambia nada (la copia `.bak` se usa automáticamente si existe).
- **Opciones:** pantalla completa y volumen general; se guardan al instante en `user://settings.cfg` (aparte de la partida). **Créditos:** quién hizo el juego, recursos externos y agradecimientos. Esc cierra el panel abierto.
- **Game Over:** "Has caído" con Reintentar (reaparece en el último checkpoint) y Menú principal; el tutorial reaparece solo.

**Vida y daño por contacto:** el jugador tiene **8 corazones** (`max_health` en `PlayerStats`), más **1 por cada fragmento de alma liberado** (hasta 11; `health_per_released_soul` y `released_souls_cap`). Tocar a un enemigo vivo o a un jefe en combate hace daño (1 por defecto, con empuje y un intervalo de repetición); el dash, la invulnerabilidad tras un golpe y la de reaparecer protegen igual que contra un ataque. Un enemigo en estado de daño, muerto, un jefe sin activar, en la transición de fase o derrotado no hacen daño. Los valores están en `EnemyStats` / `BossStats` (grupo "Contact damage").

**Decisiones con consecuencias (Fase 14b):** liberar un fragmento da +1 corazón máximo; conservarlo mantiene la onda de espada más fuerte (fragmentos de los niveles 1 y 2). Cada decisión cambia el perfil del nivel siguiente (umbral 1,0): compasivo suaviza el nivel (jefe más lento, sin enemigos extra) y corrupto lo endurece (jefe más rápido, enemigos extra). El HUD muestra el perfil y su puntuación, y cada nivel empieza con una línea que explica las consecuencias. Teclas de depuración (solo builds de depuración): `F4` mata al jefe, `H` le quita el 10 %, `F2` salta a la arena y `F3` muestra datos.

**Medidor de alma y curación (Fase 15a, sustituye a los orbes de salud):** golpear a enemigos y jefes llena un **medidor de alma** (máx. 99): espada 11, golpe pesado 22, tajo de dash 16, onda de espada 8; al morir un enemigo suelta una alma pequeña que el pato absorbe (+11) y un jefe una grande (+33). **Mantén E (o Q) 0,9 s** para enfocar: el pato queda quieto y, al terminar, recupera **1 corazón** y gasta el coste; si te hieren, sueltas la tecla, esquivas o te caes, se interrumpe sin gastar nada. No hace nada con la vida llena ni con alma insuficiente. **Conservar fragmentos encarece curarse:** el coste es 33 + 5 × fragmentos conservados (33, 38, 43, 48). El HUD tiene una barra de alma con una marca en el coste (brilla cuando alcanza) y cada nivel lo dice en su línea de consecuencias. El medidor empieza en 0 en cada nivel y se vacía al reaparecer tras morir. Una tarjeta «Nueva habilidad» enseña la tecla (leída de tus controles) en el tutorial y al conservar un fragmento que mejora la onda. Todos los números están en `game/backend/player/default_soul_config.tres`.

**Movimientos de espada nuevos** (disponibles desde el inicio, sin desbloqueo ni guardado):
- **Golpe pesado** (I / clic central): preparación visible (el cuerpo se tiñe y se aplasta), golpe ancho de 3 de daño, recuperación larga en la que el jugador es vulnerable y recarga. No se puede cancelar con otras acciones (solo el daño o la muerte lo interrumpen; si te golpean en la preparación no hay golpe ni recarga).
**Ajustes del jefe 2 y de la onda (Fase 15d-bis):** el jefe 2 tiene ahora **50 PV** (antes 60); su embestida solo se elige si tiene un carril útil por delante (nunca se desperdicia en una plataforma: se mide el carril antes del telegrafiado y se dibuja el real) y el jefe **nunca se queda sin atacar**: si ningún patrón encaja usa, por orden, una descarga apuntada al pato, un salto hacia su plataforma o el suelo, o un pisotón (máximo 1,5 s sin atacar). Los **nenúfares** ya no están a ras de suelo: flotan a 56 px sobre un tallo curvo que se comprime como un muelle (no es sólido, se camina por debajo; hay que saltar y caer encima). La **onda de espada** tiene un color por nivel: azul-blanco (sin fragmentos conservados), esmeralda (uno) y violeta con núcleo oscuro (dos), con estela más larga y brillo más intenso; la tarjeta de la mejora y el destello del impacto usan el color del nivel.

**Posesión al cambiar de fase (Fase 15d):** cuando un jefe cruza la línea de su barra de vida empieza una secuencia de unos 3 s (configurable entre 2,5 y 4 s): el jefe, inactivo e invulnerable, se eleva y se endereza temblando con los ojos y el contorno rojos, el fondo y el cielo se tiñen de rojo con una viñeta que late, hay un temblor ligero de cámara y dos destellos rojos suaves. El pato queda quieto e invulnerable, los proyectiles enemigos en el aire desaparecen y los peligros del jefe se detienen. Después empieza la fase 2 como siempre (los pinchos del jefe 2 salen solo entonces) y el jefe conserva un brillo rojo y el fondo un tinte rojo sutil hasta que muere o se cancela el combate. La línea de la barra del jefe late al cruzarla y la barra queda teñida de rojo. Con «Efectos de corrupción» desactivado no hay tinte, destello, temblor ni viñeta: queda una pausa corta (1 s) con el cambio de pose del jefe y el sonido. Todos los números están en `game/frontend/presentation/default_possession_config.tres`. Además, el salto del jefe 2 es algo menos frecuente (peso 1,2 en la fase 2; recarga de 7 s y 8 s).

**Jefe 2 rediseñado y doble salto (Fase 15c):** la arena del pantano tiene dos pisos de plataformas (bajo, a ~90 px, alcanzable saltando; alto, a ~250 px, solo con un **nenúfar trampolín** o con el doble salto desde el piso bajo) y tres nenúfares que lanzan al pato ~300 px hacia arriba si cae sobre ellos (no si camina). La Cosa del Pantano **salta** entre plataformas (marcador de aterrizaje en el suelo, descarga hacia abajo desde arriba, aterrizaje con daño) y, en la fase 2, el **suelo se llena de pinchos** en ciclos de aviso 1,2 s / activos 3 s / descanso 4 s (daño normal de 1 corazón; el dash los esquiva; plataformas y nenúfares son seguros). Al decidir sobre el alma del jefe 2 (liberar o conservar) se desbloquea el **doble salto** (la misma tecla de salto, una vez por salto; se deduce de las decisiones guardadas, sin dato nuevo) y sale una tarjeta «Nueva habilidad». Todo se dibuja por código con textura opcional (`texture` del nenúfar, `spike_texture` de los pinchos). Números en `default_bounce_config.tres`, `default_floor_hazard_config.tres`, `PlayerStats` (grupo «Double jump») y los nodos `Leap` / `LeapLight` de `boss_two.tscn`.

**Esquive invulnerable y jefes (Fase 15b):** el dash es **invulnerable de principio a fin** (no protege de las zonas de muerte: caer fuera del mundo mata igual); la velocidad, duración y recarga no cambian. La **primera vez** que entras en la arena de un jefe se reproduce una introducción: presentación «VS», saludo del guardián y la historia del pato (6 líneas por jefe), con el jefe quieto y el pato bloqueado e invulnerable; Enter la salta y no se repite al reintentar ni al continuar desde el checkpoint de la arena. La tarjeta «Nueva habilidad» de conservar un fragmento espera ahora a que termine la animación de corrupción (cola de presentación, `PresentationQueue`). El suelo de las tres arenas es continuo hasta el muro derecho.

- **Tajo de dash**: pulsa atacar durante el dash. El dash sigue y lleva un golpe delantero de 2 de daño; una vez por dash, con la recarga del dash y una recuperación extra de 0,12 s en la que no se puede atacar.
- Todo se ajusta en los grupos "Heavy attack" y "Dash slash" de `PlayerStats` (`default_player_stats.tres`). Por diseño su daño sostenido por segundo está entre 1,0× y 1,5× el de la espada (la onda sigue por debajo).

**Onda de espada:** ataque a distancia disponible desde el inicio. Su potencia (nivel 0, 1 o 2) sale de las decisiones: por defecto cada fragmento de los niveles 1 y 2 que se **conserva** sube un nivel. Se ajusta en `game/backend/player/default_sword_wave_config.tres` (niveles, recargas, `upgrade_rules`). Por diseño su daño sostenido por segundo queda por debajo del de la espada. *Este ataque amplía el diseño original (que solo documenta la katana): ver `docs/CHANGES_FROM_DESIGN.md`.*

**Parámetros adaptativos:** solo se aplican al cargar un nivel (agresividad del jefe, enemigos extra de la variante "corrupted", texto de introducción) y en el final. Detalle en `docs/ADAPTIVE_CONTRACT.md`.

## Partida guardada

El juego guarda su progreso en un único archivo JSON con **exactamente siete claves**, `save_game.json`, dentro de la carpeta `user://` del proyecto (Godot la crea con el nombre del proyecto, `Quacktaclysm`). Junto a él puede haber `save_game.json.bak` (versión anterior) y `save_game.json.corrupt` (archivo ilegible puesto en cuarentena). Ubicación:

- Windows: `%APPDATA%\Godot\app_userdata\Quacktaclysm\`
- macOS: `~/Library/Application Support/Godot/app_userdata/Quacktaclysm/`
- Linux: `~/.local/share/godot/app_userdata/Quacktaclysm/`

Para borrar la partida basta con eliminar esos archivos con el juego cerrado (o usar la tecla 3 de la escena `boss_test`). Viven fuera del repositorio y nunca se suben a Git. Las pruebas usan archivos `test_save_*.json` y no tocan el real.

## Servicio de IA

**Para qué sirve:** un servicio local (FastAPI) que, tras cada decisión Liberar/Conservar, puede *refinar* el perfil adaptativo (`compassionate` / `neutral` / `corrupt`) y elegir una variante narrativa consultando a OpenAI. El resultado local (`LocalProfileClassifier`) se aplica siempre primero; el servicio es opcional. **El juego funciona igual sin él**: si no está disponible, se mantiene el resultado local y no se muestra ningún error al jugador. La IA nunca controla el combate.

**Preparar el entorno** (desde la raíz del repositorio; las dependencias se instalan SOLO dentro del venv):

```
cd ai-service
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements-dev.txt     # Windows
# macOS/Linux: .venv/bin/python -m pip install -r requirements-dev.txt
```

**Configuración (cada ingeniera, en su propio portátil):** copia `ai-service/.env.example` a `ai-service/.env` y rellénalo con TU clave y TU modelo (`OPENAI_API_KEY`, `OPENAI_MODEL`). El modelo solo se lee de ese archivo; no está en el código ni lo fijamos en el repositorio: elige uno de los que tu cuenta de OpenAI tenga disponibles (lista en el panel de tu cuenta de OpenAI). `AI_SERVICE_MODE` puede ser `mock` (reglas deterministas, sin red, para desarrollo y pruebas) o `openai`.
El servicio lee `ai-service/.env` por su ruta junto al código, así que funciona desde cualquier carpeta, y **el `.env` manda sobre las variables del terminal** (un `$env:AI_SERVICE_MODE` viejo no lo pisa). El cliente del juego nunca lee ni contiene ninguna clave. **Nunca compartas la clave por chat ni la subas a Git;** cada persona usa la suya.

**Arrancar el servicio** (escucha en `127.0.0.1:8000` por defecto):

```
cd ai-service
.venv\Scripts\python run_dev.py                          # usa AI_SERVICE_MODE del .env (mock por defecto)
set AI_SERVICE_MODE=openai && .venv\Scripts\python run_dev.py   # modo openai (PowerShell: $env:AI_SERVICE_MODE="openai")
```

Comprobación rápida: `http://127.0.0.1:8000/health` devuelve solo `{"status":"ok","mode":"...","openai_configured":true|false}`; nunca muestra nada de la clave (ni prefijo ni longitud). Si falta `.env`, o si `AI_SERVICE_MODE=openai` pero `OPENAI_API_KEY` u `OPENAI_MODEL` están vacíos, el servicio **no falla**: arranca en modo `mock` e imprime un único aviso (sin claves) para copiar `.env.example` a `.env` y rellenarlo. En ese caso `/health` dirá `"mode":"mock"` y `"openai_configured":false`: es la señal de que tu `.env` no se está leyendo bien.

**URL del servicio en el juego:** por defecto `http://127.0.0.1:8000` (recurso `game/backend/ai/default_ai_service_config.tres`). Para usar otra URL, define la variable de entorno `QUACKTACLYSM_AI_URL` antes de abrir Godot o del juego exportado, o edita el recurso. En la escena `boss_test`, la tecla `7` pide un refinamiento. **Sin el servicio** (por ejemplo, en el `.exe` exportado sin nada escuchando), el juego usa el clasificador local.

**Pruebas de Python** (sin red y sin clave real; solo hace falta ejecutarlas si se toca `ai-service/`):

```
cd ai-service
.venv\Scripts\python -m pytest -q
```

`python tools/run_all_tests.py` también ejecuta, al final, las pruebas de carga del `.env` (`ai-service/tests/test_env_loading.py`, con archivos temporales) si existe `ai-service/.venv`; si no existe, las salta con un aviso.

**Prueba de integración con Godot** (servicio en modo mock en el puerto 8765 + Godot headless; detiene el servicio al terminar):

```
ai-service\.venv\Scripts\python ai-service\scripts\integration_mock.py --godot <ejecutable de consola de Godot>
```

> **Advertencia:** nunca subas `.env` al repositorio ni pegues claves de API en issues, chats o capturas. Solo `.env.example` (con valores vacíos) está versionado. Las pruebas de Python apuntan el cargador a un archivo inexistente (`AI_SERVICE_ENV_FILE`, en `ai-service/tests/conftest.py`), así que nunca leen tu `.env` real.

**Antes de publicar el servicio en internet:** este servicio NO tiene autenticación ni límite de peticiones. Hace falta añadir autenticación, rate limiting, HTTPS (proxy inverso) y revisar los límites de coste en OpenAI.

## Ejecutar todas las pruebas

```
python tools/run_all_tests.py                 # todo el lote
python tools/run_all_tests.py --list          # lista las pruebas
python tools/run_all_tests.py --only boss     # solo las que contienen "boss"
python tools/run_all_tests.py --godot <ejecutable> --timeout 300
```

El ejecutor busca el ejecutable de Godot en `--godot`, luego en la variable de entorno `GODOT_BIN` y luego en `godot` / `godot4` del PATH. Descubre `*_smoke_test`, `*_e2e_test`, `*_playthrough_test`, `*_soak_test` y `*_leak_test` en `game/frontend/scenes/test/` (excluye `ai_phase10_integration_test`, que necesita un servicio real), cuenta líneas `PASS`/`FAIL`/`ERROR`, imprime una tabla y termina con código distinto de cero si algo falla. También comprueba que el `save_game.json` real no cambió durante el lote (si no puede resolver la carpeta de usuario de forma segura, omite esa comprobación y lo dice). **Ejecútalo antes de cada fusión.** El bot de resistencia y la prueba de fugas se ejecutan con `--fixed-fps 60` (el ejecutor lo añade solo); a mano: `godot --headless --fixed-fps 60 --path game res://frontend/scenes/test/bot_phase13_soak_test.tscn -- --seed=123` (opciones: `--seed=N`, `--frames=N`, `--only=level_1`).

## Exportar (Windows)

El preset "Windows Desktop" está en `game/export_presets.cfg` (un solo `.exe` con el PCK incrustado, 64 bits, sin credenciales ni certificados; excluye las escenas y scripts de prueba salvo `training_dummy`, que usa el tutorial). Requiere las **plantillas de exportación** de la misma versión de Godot:

1. En el editor: menú *Editor* → *Administrar plantillas de exportación* → descargar para la versión instalada.
2. *Proyecto* → *Exportar…* → "Windows Desktop" → *Exportar proyecto*, o por terminal desde la raíz del repositorio:

```
godot --headless --path game --export-release "Windows Desktop"
```

La salida queda en `game/builds/Quacktaclysm.exe` (la ruta del preset; `builds/` está ignorada por Git). La Fase 14g exportó y ejecutó así una build (≈ 120 MB). Una build de lanzamiento no incluye las ayudas de depuración (`OS.is_debug_build()` es falso). Para apuntar el juego exportado a otro servicio de IA, define `QUACKTACLYSM_AI_URL` antes de ejecutarlo; sin servicio usa el clasificador local.

## Convenciones de Git

- Mensajes de commit en inglés, en imperativo y descriptivos (por ejemplo, "Add boss aggression multiplier"). Un cambio coherente por commit.
- **Nunca** se sube `.env` ni claves de API (`.gitignore` ya lo cubre; solo se versiona `.env.example`).
- Etiqueta prevista para la primera versión jugable completa: `core-gameplay-v1` (aún no creada).
- Ejecutar `python tools/run_all_tests.py` antes de fusionar.

## Documentación

- `docs/HANDOFF.md` — **punto de entrada**: estado actual, cómo ejecutar, dónde está cada recurso editable, reglas (y la guía para sustituir arte y contenido).
- `docs/QA_CHECKLIST.md` — lista de pruebas manuales en ventana real, en orden de juego.
- `docs/BALANCE_REPORT.md` — medición de balance con bots y propuestas de ajuste (sin aplicar).
- `docs/STORY.md` — guion de la historia, las almas, los guardianes, el abuelo y los dos finales («Estrellas que suben» y «El acantilado»).
- `docs/ADAPTIVE_CONTRACT.md` — contrato del perfil adaptativo y del servicio de IA.
- `docs/CHANGES_FROM_DESIGN.md` — diferencias entre el diseño original y la implementación.
- `docs/KNOWN_ISSUES.md` — límites conocidos y todo lo que falta por verificar jugando.
- `docs/ENVIRONMENT.md` — versiones y entorno detectados.

## Jefe 3 (Fase 15e-1)

El jefe final es El Ojo de la Tormenta, en tres fases (ojo flotante, Kenzo con guardia, ojo con tormenta). Ver `docs/HANDOFF.md` sección 22. Prueba: `phase15e1_smoke_test`.

## Nivel 3 (Fase 15e-2)

Los huecos del nivel 3 exigen salto + doble salto + dash (485, 460 y 525 px). Ver `docs/HANDOFF.md` sección 23 y `phase15e2_smoke_test`.

## Director de IA local (Fase 16a)

El juego observa cómo juegas (en memoria, sin guardarlo) y ajusta con topes los enemigos extra y el peso de los patrones del jefe al cargar cada nivel (desde el 2). Sin red por ahora. Ver `docs/DIRECTOR_PLAN.md` y `docs/HANDOFF.md` sección 25.

## Director de IA remoto (Fase 16b)

El servicio de IA tiene un endpoint nuevo, `POST /v1/director/plan`, que propone el plan del SIGUIENTE nivel dentro de topes; el planificador local sigue siendo el respaldo. La opción «Adaptación con IA» (activada por defecto, en `settings.cfg`) la desactiva: apagada, no sale ninguna petición. **Antes de alojar el servicio de forma pública hacen falta autenticación y HTTPS** (para uso local no): ahora solo hay un límite de peticiones por IP (30 por minuto, configurable con `AI_SERVICE_RATE_LIMIT_PER_MINUTE`) y un límite de tamaño de cuerpo. La clave de OpenAI nunca llega al juego. Ver `docs/DIRECTOR_PLAN.md` y `docs/HANDOFF.md` sección 26.

## La voz del abuelo (Fase 16c)

Al empezar cada nivel el abuelo dice una frase breve (un recuerdo en los niveles 1 y 2, su voz en el 3) con su reflejo de estrellas en el cielo, y cada final tiene tres variantes de epílogo según cómo se jugó. La frase sale del servicio de IA si hay conexión y es válida; si no, de un banco local. Ver `docs/STORY.md` (sección 6) y `docs/HANDOFF.md` sección 27.

## La capa de Kenzo y las historias de los guardianes (Fase 15f)

La guardia de Kenzo (jefe 3, fase 2) es ahora una capa de armadura visible sobre su cuerpo que se rompe con UN golpe pesado o tajo de dash. Cada guardián cuenta 4 líneas de su historia antes del combate (la primera vez) y todas las líneas de la introducción esperan a que el jugador pulse Enter (mantener Enter salta la introducción). Ver `docs/HANDOFF.md` sección 28.

## Escenario interactivo del nivel 3 (Fase 15g)

El nivel 3 tiene ahora corrientes de aire (columnas que elevan al jugador), placas eléctricas (peligro de suelo con aviso), una ruta alta, decorado reactivo (charcos, lámparas, cadenas) y corrientes de aire también en la arena del jefe 3. Ver `docs/HANDOFF.md` sección 29.

## Huecos del nivel 3 (Fase 15h-bis)

Los enemigos de suelo ya no se acercan a menos de 250 px del borde de un hueco, y si el jugador cae 4 veces en el mismo hueco en una sesión aparece una plataforma de restos de 140 px en medio de ese hueco (solo en memoria, nunca se guarda). Los números están en `game/backend/progression/default_gap_safety_config.tres`.

## Finales cinematográficos (Fase 15i)

Los dos finales («Estrellas que suben» y «El acantilado») son cinematográficas dibujadas por código a partir de una lista de beats (`default_kept_beats.tres`, `default_released_beats.tres`), con el rostro del abuelo en el cielo. Ver `docs/STORY.md`.

## Jefe 3 rediseñado (Fase 15j)

El Ojo de la Tormenta es ahora el pato poseído: fase 1 en solitario tras su coraza; fase 2 de invocador (plataformas y percha, patitos corruptos con escudo, suelo que tiembla y se derrumba, andanada de proyectiles, ventana de agotamiento); fase 3 con el ojo rojo y su rayo rojo. Todos los números están en `game/backend/bosses/stage/default_stage_config.tres`.

## Finales en un acantilado (Fase 15i-bis)

Los dos finales ocurren ahora en un acantilado, se cortan a blanco antes del acto, llevan arrepentimientos del pato, graznidos y una música propia procesada por código; el mensaje de apoyo sale en los dos. Ver `docs/STORY.md`.

## Sangre en el combate (Fase 15k)

El combate tiene sangre estilizada dibujada por código: salpicaduras al golpear, ráfaga mayor al matar, ráfaga grande al derrotar a un jefe, una salpicadura pequeña cuando el jugador recibe daño y manchas en el suelo que se desvanecen (unos 8 s). Se activa y desactiva con la opción **«Sangre»** (Opciones del menú principal y del menú de pausa; activada por defecto; se guarda en `user://settings.cfg`, nunca en la partida). Es puramente cosmética y **nunca aparece en los finales, el prólogo ni las escenas de historia**. Todos los números están en `frontend/fx/default_blood_config.tres`.

## Venas de corrupción y absorción oscura (Fase 15l)

El pato lleva venas moradas desde el primer fragmento conservado (1 = brazo y cuello, 2 = pecho y borde de la cara, 3 = extendidas), con un pulso suave; en «Efectos de corrupción» desactivado son estáticas y más finas. Conservar un fragmento lanza una secuencia oscura de unos 3,6 s antes de la tarjeta (liberar conserva su animación luminosa). El final «Estrellas que suben» tiene el ojo, el ala y las venas rediseñados y un vigilante de rendimiento para que no se trabe.

## Tutorial reconstruido (Fase 15m)

El tutorial del prólogo ya no se puede bloquear: sus pasos son comprobaciones independientes (cualquier acción cuenta en cuanto se hace, aunque no se haya pedido), el muñeco revive solo a los 1,0 s si lo matan, y se puede saltar manteniendo la tecla de confirmar. Tiene una lista de tareas arriba a la izquierda, carteles de práctica con linterna que se pone verde, indicaciones con las teclas actuales (también las reasignadas) y un muñeco con frases. Se enseña mover, saltar, esquivar, golpe ligero, golpe pesado, el medidor de alma, curarse y (opcional) la pausa.

## Diálogos más cortos, fragmentos azules y más (Fase 15n)

Los guardianes dicen una sola línea corta al verlos y 2–3 líneas al caer (antes del fragmento); los enemigos normales sueltan un fragmento azul de alma que flota y vuela hacia el pato; cada golpe que aterriza en un pato enemigo arranca un graznido (con límites); el prólogo tiene música y efectos; el abuelo aparece en el cielo con su rostro al empezar los niveles; y tras el último jefe no sale tarjeta de habilidad: la absorción oscura o la liberación luminosa van directas al final.

## Absorción roja, nivel 3 sin corrientes, jefe 3 sin armadura y corrupción dentro del pato (Fase 15o)

La absorción al conservar un fragmento vuelve al fondo oscuro con toques rojos y el emblema abajo, con más animación: rayos rojos finos que salen del emblema, del fragmento y de los bordes y entran todos en el pato, partículas rojas y zarcillos; el pato convulsiona y su corrupción avanza a la vista. Se quitan las columnas de viento del nivel 3 y la armadura del jefe 3 (queda el escudo de la fase de los patitos). La corrupción del pato (venas, ojo nublado, plumas y ala) ahora se dibuja dentro de las piezas del propio pato y los finales usan un solo dibujo por pose; hay una ranura opcional para sustituir cualquier etapa o pose por una imagen propia.

## El abuelo desde su figura, siluetas en los finales y el alma de los guardianes (Fase 15r)

El abuelo del cielo (niveles y finales) es ahora su propia figura de cuerpo entero, con el cuerpo oculto en la niebla y solo la cara visible, borrosa y translúcida; no hay cara dibujada ni lágrimas. En los dos finales, sobre el blanco del corte aparecen siluetas planas oscuras del pato (arrodillado con la espada clavada al lado y luego quieto, o de pie en el borde mirando al cielo); el acto no se ve nunca. Al caer un guardián aparece su alma en azul, dice sus últimas palabras, se deshace en partículas y se convierte en el cristal del fragmento.
