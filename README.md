# Quacktaclysm

Videojuego 2D de acción en vista lateral con combate con espada, enemigos y jefes, hecho con Godot 4 y GDScript para escritorio (prioridad Windows, compatible con macOS). El nombre oficial es Quacktaclysm (`config/name` en Project Settings).

## Estructura de carpetas

```
game/             Proyecto de Godot (raíz: game/project.godot)
  frontend/       Escenas, UI, animaciones, sprites, audio y niveles
  backend/        Lógica del juego (player, combat, enemies, bosses,
                  decisions, ai, persistence, progression)
ai-service/       Servicio de IA externo
  app/
docs/             Documentación
```

- **frontend** = escenas, UI, arte, audio y niveles.
- **backend** = lógica del juego.
- **ai-service** = servicio de IA externo.

## Cómo abrir el proyecto

1. Instalar Godot 4.7.2 (stable).
2. En el gestor de proyectos de Godot, importar `game/project.godot`.
3. Ejecutar (F5). Debe mostrarse la escena de prueba `base_check.tscn` con el texto "Project base OK — Godot 4.7.2".

## Partida guardada

El juego guarda su progreso en un único archivo JSON, `save_game.json`, dentro de la carpeta `user://` del proyecto (Godot la crea con el nombre del proyecto, `Quacktaclysm`). Junto a él puede haber `save_game.json.bak` (versión anterior), y `save_game.json.corrupt` (archivo ilegible puesto en cuarentena). Ubicación según el sistema:

- Windows: `%APPDATA%\Godotpp_userdata\Quacktaclysm\`
- macOS: `~/Library/Application Support/Godot/app_userdata/Quacktaclysm/`
- Linux: `~/.local/share/godot/app_userdata/Quacktaclysm/`

Para borrar la partida basta con eliminar esos archivos con el juego cerrado (o usar la tecla 3 de la escena de pruebas `boss_test`). Estos archivos viven fuera del repositorio y nunca se suben a Git.

## Flujo del juego y menús

El juego arranca en el **menú principal** (`game/frontend/ui/main_menu.tscn`) y de ahí pasa a la partida. Las escenas de prueba siguen pudiendo abrirse directamente desde el editor (F6).

- **Nueva partida:** reinicia el estado en memoria (`GameState.start_new_game()`) y abre la escena `tutorial`. Si ya existe una partida guardada (o una guardada de versión más nueva que bloquea el guardado), pide confirmación; **no se borra el archivo**: se reemplaza en el próximo guardado automático.
- **Continuar:** solo está activo si hay partida guardada. Carga el archivo y abre la escena del nivel guardado (si la partida ya está **completada**, es decir `checkpoint = "ending"`, reabre el final; si esa escena falla, vuelve al último nivel y lo indica). Si el archivo está dañado, es de una versión más nueva o no es válido, muestra un mensaje en el menú y no cambia nada (la copia de seguridad se usa automáticamente si existe).
- **Salir:** cierra el juego.

**Controles:** movimiento, salto, dash y ataque como hasta ahora; **Esc o P** abren y cierran el menú de pausa (Continuar / Menú principal). La pausa no se abre si otro sistema ya tiene el juego pausado (panel de decisión, Game Over), durante una transición de escena o con el jugador muerto. "Menú principal" **no guarda**: se pierde el progreso posterior al último guardado automático.

**Game Over:** al morir el jugador aparece "Has caído" con Reintentar (reaparece en el último checkpoint con la vida completa) y Menú principal.

**Pausa central:** `PauseLock` (`game/backend/progression/pause_lock.gd`) cuenta quién pausó el árbol; solo se reanuda cuando el último lo libera. `SceneManager` (autoload) hace los cambios de escena con fundido y limpia cualquier pausa.

**Registro de escenas:** `game/backend/progression/default_scene_registry.tres` (ids → rutas, ids de nuevo juego/menú/niveles y tiempos del fundido). `tutorial` y `level_1` apuntan a las escenas reales (`game/frontend/levels/`). `level_2`, `level_3` y `ending` (final, fuera de `level_scene_ids`) también son escenas reales. La escena de pruebas `boss_test.tscn` ya no está en el flujo.

## Niveles

Recorrido actual: menú → **tutorial** (aprender mover, saltar, esquivar, atacar y golpear al muñeco; al completarlo se abre la salida) → **Nivel 1** (combate, un hueco que exige salto + dash, enemigos a distancia, sala del jefe con puertas que se cierran, fragmento de alma y decisión) → **Nivel 2** (pantano) → **Nivel 3** (tormenta) → **final**. El tutorial no guarda partida; los niveles guardan al llegar, en cada checkpoint y al decidir.

**Plantilla (`LevelBase`):** `game/backend/progression/level_base.gd` + `game/frontend/levels/level_base.tscn` contienen los servicios comunes (jugador con cámara, HUD, barra de jefe, panel de decisión, `DecisionFlow`, `AdaptiveRefiner`, menú de pausa, Game Over, ayudas de depuración). Para crear un nivel nuevo:

1. Crea una escena heredada de `level_base.tscn`.
2. Ajusta los exports de la raíz: `level_number`, `level_id`, `start_checkpoint_id` (`level_N_start`), `next_scene_id`, `show_game_over`, `camera_limits`, y si hay jefe: `boss`, `encounter`, `fragment_drop`, `arena_gates`.
3. Coloca geometría, enemigos, checkpoints y jefe dentro del nodo `Content`, y mueve el nodo `SpawnPoint`.
4. Si hay fragmento: añade un `SoulFragmentDrop` y asigna su ruta en el export `drop` del nodo `DecisionFlow`.
5. Registra la escena en `default_scene_registry.tres`.

**Convenciones de checkpoints:** `level_N_start` (`order` 0, junto al `SpawnPoint`) y `level_N_arena` (`order` mayor), este último justo ANTES de la arena y **fuera** del área del `BossEncounter`, para que al reaparecer no se reactive el jefe. "Continuar" restaura al jugador en el checkpoint guardado si pertenece al nivel.

**Bloques de maqueta:** `PlaceholderPlatform` (`game/frontend/levels/blocks/`, `@tool`: rectángulo con colisión cuyo `size`, `one_way` y `color` se ven en el editor), `placeholder_wall.tscn` (la misma plataforma como muro) y `ArenaGate` (puerta que se cierra al empezar el combate y se abre al reiniciarse o morir el jefe).

**Teclas de depuración de niveles (solo builds de depuración):** `K` mata al jefe, `H` le quita el 10 %, `F2` te lleva al checkpoint de la arena, `F3` muestra/oculta datos de depuración. (La escena `boss_test` mantiene sus propias teclas.)

### Flujo provisional completo

menú principal → tutorial → Nivel 1 → Nivel 2 → Nivel 3 → final → menú principal. En cada nivel: recorrer, llegar al checkpoint `level_N_arena`, entrar a la arena (las puertas se cierran), derrotar al jefe, recoger el fragmento de alma y decidir (Liberar / Conservar). Tras la decisión el nivel avanza solo (espera a que acabe un posible refinamiento remoto, con tiempo máximo). Nivel 2: tres huecos (uno de salto simple y dos que exigen salto + dash), una zona de plataformas verticales y 8 enemigos (más ranged que el Nivel 1). Nivel 3: dos huecos de dash y uno de salto simple, grupos de enemigos en dos alturas y 9 enemigos. Jefes: `boss_two.tscn` (60 vida, embestida y barrido ancho) y `boss_three.tscn` (80 vida, los tres patrones y una ráfaga pesada en la fase 2).

### Cómo se consumen los parámetros adaptativos

Solo **al cargar el nivel** (`LevelBase._ready`, una única vez; nada cambia en caliente):

1. **Agresividad del jefe:** `boss.set_aggression(result.boss_aggression)` (0.9 compasivo, 1.0 neutral, 1.15 corrupto; se limita a 0.5–2.0). Multiplica la velocidad efectiva de los patrones (junto con el multiplicador de fase 2) y divide la pausa entre patrones. Con 1.0 el comportamiento es idéntico al anterior. Una llamada en mitad de un patrón se ignora.
2. **Grupos de variante:** el export `variant_groups` (`Dictionary`: id de variante de encuentro → lista de `NodePath` relativos al nivel) lista nodos opcionales (p. ej. enemigos extra) que solo existen en esa variante. Los grupos que NO coinciden con `encounter_variant` se eliminan del árbol al cargar (`calm` y `standard` están vacíos; `corrupted` añade 2 enemigos en el Nivel 2 y 3 en el Nivel 3). Los nodos que no están en ningún grupo son la base. Una variante desconocida elimina todos los grupos. Una ruta inválida solo da un aviso.
3. **Texto de introducción:** `intro_lines` (`Dictionary`: variante narrativa → línea corta) e `intro_duration`. Se muestra si hay entrada para la variante narrativa actual; si no, nada.
4. **Final:** la escena `ending` lee `ending_variant` una vez (`ending_compassionate`, `ending_neutral`, `ending_corrupt`; una variante desconocida usa el texto neutral).

El `DecisionFlow` del Nivel 3 usa `refinement_point = "ending"` (el resto, `after_decision`).

### Marcador del final

Al completar el último nivel (cuyo `next_scene_id` no está en `level_scene_ids`) `LevelBase` escribe `checkpoint = "ending"` (`GameState.CHECKPOINT_ENDING`), mantiene `current_level`, guarda y abre la escena `ending`. No hay claves nuevas: el archivo sigue teniendo exactamente siete. `GameState.is_game_completed()` indica el estado. **Nueva partida** empieza de cero; **Continuar** reabre el final tras completar el juego. Entrar a un nivel con la partida completada (solo desde el editor o depuración) no la restaura ni reescribe: el autoguardado se suspende mientras el nivel esté cargado para no pisar el marcador.

### Crear un jefe desde datos

1. Crea un `BossStats` (`game/backend/bosses/stats/`): id, nombre, vida, ratio y multiplicadores de la fase 2, pausa entre patrones.
2. Crea una escena heredada de `boss_base.tscn`, asigna `stats` y añade nodos `SwipePattern` / `ChargePattern` / `ProjectileVolleyPattern` bajo `Patterns` (sus hitboxes bajo `AttackPivot`). Todo se ajusta con exports; no hace falta código. Ver `boss_two.tscn` y `boss_three.tscn`.
3. En el nivel: asigna el jefe al export `boss`, al `BossEncounter` y al `SoulFragmentDrop`, y usa un `SoulFragmentData` cuyo `boss_id` coincida con el de los stats.

### Cómo dimensionar huecos y escalones

Alcances medidos con el `Player` real (salto sin soltar, a máxima velocidad): salto solo ≈ 220 px, altura máxima ≈ 112 px, salto + dash (dash 0.3 s después de saltar) ≈ 328 px (hasta ≈ 388 px con el dash en el mejor momento). Reglas usadas: hueco de salto simple ≤ 85 % del salto (≈ 187 px); hueco de dash entre el 110 % del salto y el 90 % del salto + dash (≈ 242–295 px; los de los niveles 2 y 3 miden 285 px, más que el límite pegado al borde con coyote time, 278 px); escalón vertical ≤ 85 % de la altura máxima (≈ 95 px, se usan 80 px). La prueba `level_phase12b_smoke_test` lo vuelve a medir y comprueba cada nivel.

### Pendiente / marcadores de posición que reemplazará la siguiente fase

Gráficos y animaciones (todo son rectángulos de colores), audio, textos finales y de introducción (marcados "texto provisional"), nombres de los jefes, ajuste de dificultad tras jugar, el ataque a distancia de la espada, cinemáticas/diálogos y un menú de ajustes. El pantano y la tormenta solo se distinguen por el color de fondo.

### Pruebas de Fase 12b

`level_phase12b_smoke_test` (agresividad, jefes 2 y 3, variantes, final, menú, escena final, análisis de alcanzabilidad con medidas reales y cruces físicos de cada hueco) y `level_phase12b_playthrough_test` (tres partidas completas con cambios de escena reales y el servicio de IA desactivado). Ambas usan rutas de guardado de prueba.

## Servicio de IA

**Para qué sirve:** un servicio local (FastAPI) que, tras cada decisión Liberar/Conservar, puede *refinar* el perfil adaptativo (`compassionate` / `neutral` / `corrupt`) y elegir una variante narrativa consultando a OpenAI. El resultado local (`LocalProfileClassifier`) se aplica siempre primero; el servicio es opcional. **El juego funciona igual sin él**: si no está disponible, el resultado local se mantiene y no se muestra ningún error al jugador.

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

**URL del servicio en el juego:** por defecto `http://127.0.0.1:8000` (recurso `game/backend/ai/default_ai_service_config.tres`). Para usar otra URL, define la variable de entorno `QUACKTACLYSM_AI_URL` antes de abrir Godot, o edita el recurso. En la escena `boss_test`, la tecla `7` pide un refinamiento y la etiqueta de depuración muestra el estado.

**Pruebas de Python** (sin red y sin clave real):

```
cd ai-service
.venv\Scripts\python -m pytest -q
```

**Prueba de integración con Godot** (servicio en modo mock en el puerto 8765 + Godot headless; detiene el servicio al terminar):

```
ai-service\.venv\Scripts\python ai-service\scripts\integration_mock.py --godot <ejecutable de consola de Godot>
```

> **Advertencia:** nunca subas `.env` al repositorio ni pegues claves de API en issues, chats o capturas. Solo `.env.example` (con valores vacíos) está versionado.

**Antes de publicar el servicio en internet:** este servicio NO tiene autenticación ni límite de peticiones. Hace falta añadir autenticación (p. ej. una clave de cliente o token), rate limiting por IP/usuario, HTTPS (proxy inverso) y revisar los límites de coste en OpenAI. El juego ya admite una URL configurable (`QUACKTACLYSM_AI_URL` o el recurso de configuración).

## Git

Nunca subir al repositorio archivos `.env` ni claves de API.
