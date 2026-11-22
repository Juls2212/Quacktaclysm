# El plan del Director (Fase 16a)

Un plan decide lo que cambia en UN nivel. Tiene exactamente cuatro campos y nada más. Todo número vive en `game/backend/ai/director/default_telemetry_config.tres`.

| Campo | Tipo y tope | Qué hace |
|---|---|---|
| `theme` | uno de calma, paciencia, distancia, ritmo, recursos, valor, equilibrio | Tema local elegido por reglas; se guarda para la línea del abuelo (Fase 16c) |
| `extras_delta` | entero de -2 a +1 | Se suma a los enemigos extra del perfil; el total final se limita a 0..3 |
| `boss_pattern_weights` | id de patrón -> multiplicador de 0,6 a 1,5, nunca 0 | Multiplica el peso de los patrones de rotación del jefe (no los de reserva) |
| `epilogue_variant` | entero de 0 a 2 | Se guarda; lo usará el epílogo (Fase 16c) |

## Lo que un plan nunca puede llevar ni cambiar
Perfil de corrupción, vida del jefe, daño (nunca más de 1 corazón), tiempos de aviso (telegraph), multiplicadores de agresión 0,9/1,0/1,15 y enfriamientos. Un plan con una clave como `profile`, `hp`, `damage`, `aggression` o `cooldown` se rechaza entero; cualquier otra clave desconocida se descarta.

## Cómo se decide (planificador local)
- Telemetría del nivel anterior, solo en categorías low/mid/high (umbrales en el recurso).
- Con dificultades (muertes altas o daño alto): -1 extra y el patrón que más dañó a 0,8; si ambos son altos, -2 y 0,6.
- Cómodo (sin muertes, poco daño y el nivel realmente jugado): +1 extra y el patrón que más dañó a 1,4.
- Si no, el plan neutro. Nivel 1 y cargas sin telemetría (por ejemplo al continuar desde disco): plan neutro.
- Misma entrada, mismo plan. El plan se guarda en caché por nivel durante la sesión.

## Dónde se aplica
Una sola vez, en `LevelBase._apply_adaptive`, al cargar el nivel; nunca durante una pelea.

## Validación
`DirectorPlanValidator.validate` es la única puerta (la IA remota de la Fase 16b la usará igual): recorta valores, sustituye pesos nulos o negativos por 1,0, descarta patrones desconocidos y cambia un tema inválido por el local.

# Endpoint del plan remoto (Fase 16b)

`POST /v1/director/plan` (no cambia `GET /health` ni `POST /v1/adaptive/profile`).

## Petición (todo estricto, claves extra prohibidas, nunca texto libre)
| Campo | Tipo |
|---|---|
| `next_level` | entero 1 a 3 |
| `local_profile` | `compassionate`, `neutral` o `corrupt` |
| `summary` | las 18 métricas de la Fase 16a, cada una `low`, `mid` o `high` (sin cifras) |
| `local_theme` | uno de los 7 temas |
| `baseline` | `extras_delta` (-2 a 1), `boss_pattern_weights` (id de patrón -> peso), `epilogue_variant` (0 a 2) |
| `allowed_pattern_ids` | hasta 16 ids con el patrón `^[a-z0-9_]{1,64}$` |

## Respuesta
`theme` (enum), `extras_delta` (-2 a 1), `boss_pattern_weights` (solo ids permitidos, 0,6 a 1,5, nunca 0; un peso nulo, negativo o no numérico pasa a 1,0), `epilogue_variant` (0 a 2) y `source` (`openai`, `mock` o `fallback`). La Fase 16c podrá añadir UN campo opcional de línea de texto.

## Comportamiento
- Con IA (`openai`): salida estructurada estricta (el modelo devuelve los pesos como lista de `{pattern_id, multiplier}`), `store=False`, 2,5 s y sin reintento; el servicio vuelve a recortar la respuesta. Si el jugador va mal (`deaths` o `damage_taken` altos), solo se permite ayudar: sin extras y sin pesos mayores que 1,0.
- Cualquier error, tiempo agotado o respuesta inservible: 200 con el plan base y `source = "fallback"`. Sin clave: `mock` devuelve el plan base.
- Límite por IP (30 por minuto por defecto, 429 al pasarlo) y cuerpo máximo de 16 KB; los registros no guardan cuerpos.
- Autenticación necesaria antes de alojarlo públicamente (no para uso local).
- El juego solo guarda en memoria un plan remoto si `source` es `openai` y pasa por `DirectorPlanValidator`.

# Fase 16c: línea del abuelo y final

- **`next_level = 4`** es el final: la petición lleva `allowed_pattern_ids` vacío y solo importa `epilogue_variant`. Es compatible con las peticiones anteriores (1 a 3). Se envía al decidir el fragmento del nivel 3 (el mismo presupuesto de 3 s y el mismo respaldo local).
- **`grandfather_line`** (cadena o `null`, opcional en la respuesta): UNA línea en la voz del abuelo para el tema de la respuesta. El servicio la valida (8 a 18 palabras, 110 caracteres, sin cifras, enlaces, marcas, saltos de línea ni emojis, sin reproche ni mecánicas); si no cumple, `null`. En `next_level = 4`, en modo mock y en fallback siempre es `null`. El juego la valida otra vez; si falla o falta, usa el banco local. La petición sigue sin llevar texto libre del jugador.
- La línea se usa solo si el plan de ese nivel es el remoto; no se guarda ni se registra su contenido.
