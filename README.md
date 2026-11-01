# Quacktaclysm

Videojuego 2D de acción en vista lateral con combate con espada (cuerpo a cuerpo y una onda a distancia), enemigos y jefes, hecho con Godot 4 y GDScript para escritorio (prioridad Windows, compatible con macOS). El nombre oficial es Quacktaclysm (`config/name` en Project Settings). El jugador recorre un tutorial y tres niveles; tras cada jefe decide **Liberar** o **Conservar** un fragmento de alma, y esas decisiones cambian la dificultad de los jefes, los enemigos extra, la potencia de la onda y el final. Un servicio de IA opcional puede refinar ese perfil.

> **Estado:** todo el contenido jugable existe. El héroe, los enemigos y los jefes son patos dibujados y animados por código (`DuckRig`) que caen como ragdoll al morir; escenarios, proyectiles e interfaz siguen con arte provisional (rectángulos de colores). Nadie lo ha jugado con ventana todavía: ver `docs/KNOWN_ISSUES.md`.

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

| Acción | Teclas |
| --- | --- |
| Mover | A / D o flechas izquierda / derecha |
| Saltar | Espacio o flecha arriba |
| Dash | Shift o K |
| Ataque de espada | J, X o clic izquierdo |
| Onda de espada (a distancia) | **clic derecho o U** |
| Golpe pesado | **I o clic central** |
| Tajo de dash | pulsar **ataque durante el dash** (sin tecla propia) |
| Pausa | Esc o P |

La pausa no se abre si otro sistema ya tiene el juego pausado (panel de decisión, Game Over), durante una transición o con el jugador muerto. "Menú principal" **no guarda**: se pierde el progreso posterior al último guardado automático. En un build de depuración además: `K` mata al jefe (¡coincide con el dash!, ver `docs/KNOWN_ISSUES.md`), `H` le quita el 10 %, `F2` te lleva al checkpoint de la arena y `F3` muestra datos de depuración; las escenas de pruebas (`boss_test`, etc.) tienen sus propias teclas.

## Flujo del juego

menú principal → **tutorial** (mover, saltar, esquivar, atacar, golpear al muñeco, lanzar la onda) → **Nivel 1** → **Nivel 2** → **Nivel 3** → **final** → menú principal.

En cada nivel: recorrer, llegar al checkpoint de la arena, derrotar al jefe (las puertas se cierran durante el combate), recoger el fragmento de alma y decidir. Tras la decisión el nivel avanza solo. Al completar el Nivel 3 se guarda `checkpoint = "ending"` y se abre el final.

- **Nueva partida:** reinicia el estado y abre el tutorial. Si ya hay partida guardada pide confirmación; el archivo no se borra, se reemplaza en el próximo guardado automático.
- **Continuar:** carga el archivo y abre el nivel guardado; si la partida está **completada** (`checkpoint = "ending"`) reabre el final. Si el archivo está dañado o es de una versión más nueva, muestra un mensaje y no cambia nada (la copia `.bak` se usa automáticamente si existe).
- **Game Over:** "Has caído" con Reintentar (reaparece en el último checkpoint) y Menú principal; el tutorial reaparece solo.

**Vida y daño por contacto:** el jugador tiene **8 corazones** (`max_health` en `PlayerStats`). Tocar a un enemigo vivo o a un jefe en combate hace daño (1 por defecto, con empuje y un intervalo de repetición); el dash, la invulnerabilidad tras un golpe y la de reaparecer protegen igual que contra un ataque. Un enemigo en estado de daño, muerto, un jefe sin activar, en la transición de fase o derrotado no hacen daño. Los valores están en `EnemyStats` / `BossStats` (grupo "Contact damage").

**Orbes de salud:** cada enemigo derrotado suelta orbes (1 por defecto, 2 el bruto acorazado) y cada jefe suelta 2 al entrar en la fase 2 y 4 al ser derrotado. Los orbes saltan, rebotan en el suelo y vuelan hacia el jugador si está cerca **y le falta vida**; cada uno cura 1 corazón. Con la vida llena se quedan en el suelo y desaparecen a los 12 s (parpadean antes). Se ajustan en `default_health_orb_stats.tres` y en los grupos "Drops" de `EnemyStats` / `BossStats`.

**Movimientos de espada nuevos** (disponibles desde el inicio, sin desbloqueo ni guardado):
- **Golpe pesado** (I / clic central): preparación visible (el cuerpo se tiñe y se aplasta), golpe ancho de 3 de daño, recuperación larga en la que el jugador es vulnerable y recarga. No se puede cancelar con otras acciones (solo el daño o la muerte lo interrumpen; si te golpean en la preparación no hay golpe ni recarga).
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

**Configuración:** copia `ai-service/.env.example` a `ai-service/.env` y rellena `OPENAI_API_KEY` y `OPENAI_MODEL` (el modelo solo se lee del entorno; no está en el código). `AI_SERVICE_MODE` puede ser `mock` (reglas deterministas, sin red, para desarrollo y pruebas) o `openai`.

**Arrancar el servicio** (escucha en `127.0.0.1:8000` por defecto):

```
cd ai-service
.venv\Scripts\python run_dev.py                          # usa AI_SERVICE_MODE del .env (mock por defecto)
set AI_SERVICE_MODE=openai && .venv\Scripts\python run_dev.py   # modo openai (PowerShell: $env:AI_SERVICE_MODE="openai")
```

Comprobación rápida: `http://127.0.0.1:8000/health` devuelve `{"status":"ok","mode":"mock",...}`. En modo `openai` sin clave o sin modelo, el servicio arranca igualmente (`/health` funciona) y el endpoint de perfil responde 503.

**URL del servicio en el juego:** por defecto `http://127.0.0.1:8000` (recurso `game/backend/ai/default_ai_service_config.tres`). Para usar otra URL, define la variable de entorno `QUACKTACLYSM_AI_URL` antes de abrir Godot o del juego exportado, o edita el recurso. En la escena `boss_test`, la tecla `7` pide un refinamiento. **Sin el servicio** (por ejemplo, en el `.exe` exportado sin nada escuchando), el juego usa el clasificador local.

**Pruebas de Python** (sin red y sin clave real; solo hace falta ejecutarlas si se toca `ai-service/`):

```
cd ai-service
.venv\Scripts\python -m pytest -q
```

**Prueba de integración con Godot** (servicio en modo mock en el puerto 8765 + Godot headless; detiene el servicio al terminar):

```
ai-service\.venv\Scripts\python ai-service\scripts\integration_mock.py --godot <ejecutable de consola de Godot>
```

> **Advertencia:** nunca subas `.env` al repositorio ni pegues claves de API en issues, chats o capturas. Solo `.env.example` (con valores vacíos) está versionado.

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
godot --headless --path game --export-release "Windows Desktop" ../builds/Quacktaclysm.exe
```

La salida queda en `builds/` (ignorada por Git; créala si no existe). Una build de lanzamiento no incluye las ayudas de depuración (`OS.is_debug_build()` es falso). Para apuntar el juego exportado a otro servicio de IA, define `QUACKTACLYSM_AI_URL` antes de ejecutarlo; sin servicio usa el clasificador local.

## Convenciones de Git

- Mensajes de commit en inglés, en imperativo y descriptivos (por ejemplo, "Add boss aggression multiplier"). Un cambio coherente por commit.
- **Nunca** se sube `.env` ni claves de API (`.gitignore` ya lo cubre; solo se versiona `.env.example`).
- Etiqueta prevista para la primera versión jugable completa: `core-gameplay-v1` (aún no creada).
- Ejecutar `python tools/run_all_tests.py` antes de fusionar.

## Documentación

- `docs/HANDOFF.md` — guía para quien sustituya los marcadores de posición por arte y contenido.
- `docs/ADAPTIVE_CONTRACT.md` — contrato del perfil adaptativo y del servicio de IA.
- `docs/CHANGES_FROM_DESIGN.md` — diferencias entre el diseño original y la implementación.
- `docs/KNOWN_ISSUES.md` — límites conocidos y todo lo que falta por verificar jugando.
- `docs/ENVIRONMENT.md` — versiones y entorno detectados.
