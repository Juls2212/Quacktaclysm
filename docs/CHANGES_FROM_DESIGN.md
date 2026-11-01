# Diferencias entre el diseño original y la implementación

Lista para actualizar los documentos de diseño del proyecto. Solo recoge lo que está en el código actual.

## Nombre y alcance

- **Nombre del proyecto:** Quacktaclysm (`config/name` de `game/project.godot`; también el nombre de la carpeta de datos de usuario).
- **Plataforma:** escritorio, prioridad Windows (compatible con macOS). Resolución base 1280×720, escalado `canvas_items`.

## Mecánicas añadidas o definidas durante la implementación

- **Onda de espada (ataque a distancia):** el diseño original solo documenta la katana. Se añadió un ataque a distancia disponible desde el inicio (clic derecho o U) con tres niveles de potencia. El nivel se calcula con las decisiones de fragmentos: cada fragmento de las reglas (`upgrade_rules`) cuya elección coincide suma un nivel; por defecto, **conservar** los fragmentos de los niveles 1 y 2. Está pensada para no superar el daño sostenido de la espada. Configuración en `default_sword_wave_config.tres`.
- **Marcador de fin de partida:** al completar el último nivel se guarda `checkpoint = "ending"` (sin claves nuevas); "Continuar" reabre la escena del final.
- **Variantes de encuentro por perfil:** `LevelBase.variant_groups` elimina al cargar los nodos de las variantes que no corresponden (enemigos extra en la variante "corrupted") y `BossBase.set_aggression` escala la velocidad de los jefes (0,9 / 1,0 / 1,15). Los parámetros adaptativos solo se aplican al cargar un nivel, nunca en caliente.
- **Líneas de introducción** por variante narrativa al inicio de cada nivel (`intro_lines`).

- **Dos movimientos de espada nuevos (extensión del diseño):** golpe pesado (acción `heavy_attack`: I / clic central) y tajo de dash (ataque durante el dash). Disponibles desde el inicio, sin desbloqueos.
- **Daño por contacto:** enemigos y jefes hacen daño al tocarlos (antes solo atacaban con golpes). El entrenador del tutorial no.
- **Vida máxima del jugador: 8** (antes 5).
- **Orbes de salud (extensión del diseño):** los enemigos derrotados y los jefes (al entrar en la fase 2 y al ser derrotados) sueltan orbes que curan 1 corazón al jugador herido. Datos en `HealthOrbStats` y en el grupo "Drops" de `EnemyStats` / `BossStats`.
- **Muerte con ragdoll:** jugador, enemigos y jefes se desarman en cuerpo, cabeza y arma con física al morir (solo visual; no afecta a la lógica ni a los tiempos de muerte).

## Arquitectura

- **Solo dos autoloads:** `GameState` y `SceneManager`. El resto (pausa, registro de escenas, servicio de IA) son nodos de escena o recursos.
- **Registro de escenas** (`SceneRegistry`, recurso) con ids (`tutorial`, `level_1`…`level_3`, `ending`, `main_menu`), orden de niveles y tiempos del fundido.
- **`PauseLock`:** contador central de quién pausa el árbol.
- **Guardado:** un único JSON con exactamente siete claves; copia `.bak` y cuarentena `.corrupt`; versión de guardado con gancho de migración.
- **Servicio de IA opcional** (FastAPI en `ai-service/`, modos `mock` y `openai`). El juego aplica siempre primero el perfil local y el servicio solo puede refinar el perfil (a distancia limitada) y elegir una variante narrativa; nunca fija valores numéricos de combate.

## Contenido

- **Tutorial** con seis pasos (mover, saltar, esquivar, atacar, golpear al muñeco, lanzar la onda).
- **Tres niveles** con un jefe cada uno (vida 40 / 60 / 80), 6 / 8 / 9 enemigos base (más 0 / 2 / 3 en la variante "corrupted"; tres tipos: cuerpo a cuerpo, rápido y a distancia) y una escena de final con tres textos.
- **Decisiones:** un fragmento de alma por jefe (Liberar / Conservar); el del Nivel 3 se decide tras el último jefe y solo influye en el final.

## Cosas que el diseño original no especificaba y que se decidieron aquí

- Teclas de depuración (solo builds de depuración): K, H, F2, F3 en los niveles; teclas propias en `boss_test`.
- Pantalla de Game Over con "Reintentar" / "Menú principal"; el tutorial reaparece solo sin pantalla de Game Over.
- Menú de pausa con Esc o P; "Menú principal" no guarda.
- Cámara con límites por nivel (`camera_limits`).
- Valores de balance de todos los jefes, enemigos y tiempos: provisionales, sin probar jugando.
- Todo el arte, audio y los textos son marcadores de posición.
