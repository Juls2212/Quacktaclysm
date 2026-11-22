# Guía de traspaso: punto de entrada para Ingeniera 2 y para quien mantenga el proyecto

Para quien reemplazará los marcadores de posición por arte, audio y contenido definitivo. Todo lo jugable ya funciona (héroe, enemigos, jefes y escenarios dibujados por código, y audio con `AudioDirector`); la lógica está probada con pruebas automáticas, pero **nadie ha jugado el juego con ventana** (ver `docs/KNOWN_ISSUES.md`).

## 0. Estado actual (léelo primero)

**Fase:** 15a (medidor de alma y curación, después del cierre de la 14g). Todo el contenido jugable existe y está validado con pruebas automáticas **headless**: nadie lo ha probado en una ventana real. Lo que falta por mirar con ojos y oídos está en `docs/QA_CHECKLIST.md` (una fila por comprobación, en orden de juego) y, con más detalle, en `docs/KNOWN_ISSUES.md`. Las mediciones de balance de la Fase 14g están en `docs/BALANCE_REPORT.md`.

| Dato | Valor |
|---|---|
| Motor | Godot 4.7.2 (GDScript) |
| Autoloads (exactamente 3) | `GameState`, `SceneManager`, `AudioDirector` |
| Claves del archivo de guardado (exactamente 7) | `save_version`, `current_level`, `checkpoint`, `souls_released`, `souls_kept`, `decisions`, `adaptive_profile` (el final es `checkpoint = "ending"`) |
| Opciones y controles del jugador | `user://settings.cfg` y `user://controls.cfg` (archivos aparte de la partida) |
| Servicio de IA | Opcional (`ai-service/`, FastAPI). Sin él el juego funciona igual: lo decide la regla local (probado en `ai_down_phase14g_smoke_test`) |
| Pruebas | 26 escenas de Godot (`*_smoke_test`, `*_e2e_test`, `*_playthrough_test`, `*_soak_test`, `*_leak_test`) + las pruebas de Python del `.env` |
| Finales | 4, elegidos solo por las almas liberadas (3 / 2 / 1 / 0) |

### Cómo ejecutar

- **El juego:** abre `game/project.godot` en Godot 4.7.x y pulsa F5. Teclas de depuración (solo en depuración): F2 (arena del jefe), F3 (datos), F4 (matar al jefe), H (quitar el 10 % al jefe).
- **El servicio de IA (opcional):** `cd ai-service`, crea el entorno (`python -m venv .venv` y `pip install -r requirements-dev.txt`), copia `.env.example` a `.env` con TU clave y ejecuta `.venv\Scripts\python run_dev.py`. Nunca subas el `.env`. Ver `docs/ENVIRONMENT.md`.
- **Las pruebas:** `python tools/run_all_tests.py` (necesita `GODOT_BIN` o `--godot`). Opciones: `--only TEXTO` (solo las que contengan el texto), `--skip NOMBRE` (omite una prueba concreta; repetible), `--list`, `--verbose`. **El soak** (`bot_phase13_soak_test`, ≈ 9-22 min y mucha memoria) entra por defecto; para una pasada rápida usa `--skip bot_phase13_soak_test`. Debe terminar en `OVERALL: PASS` y con «Real save check: untouched». No ejecutes nada más en paralelo con la suite.
- **Mediciones de balance (no forman parte de la suite):** `godot --headless --fixed-fps 60 --path game res://frontend/scenes/test/balance_measure.tscn -- --only=dps|levels|duels|runs`.

### Dónde está cada recurso editable (índice)

| Qué se edita | Recurso |
|---|---|
| Estadísticas del jugador | `game/backend/player/default_player_stats.tres` |
| Onda de espada (niveles, daño, recarga) | `game/backend/player/default_sword_wave_config.tres` |
| Enemigos (vida, tiempos, daño) | `game/backend/enemies/stats/*.tres` |
| Jefes (vida, fases) y proyectiles | `game/backend/bosses/stats/*.tres`, `game/backend/combat/stats/enemy_projectile_stats.tres` |
| **Medidor de alma y curación** (cantidades, coste, tiempo de enfoque) | `game/backend/player/default_soul_config.tres` |
| Textos de la tarjeta «Nueva habilidad» | `game/backend/player/default_ability_texts.tres` |
| Perfiles adaptativos y regla local | `game/backend/ai/default_adaptive_config.tres` |
| Conexión con el servicio de IA | `game/backend/ai/default_ai_service_config.tres` |
| Escenas, orden de niveles, fundidos | `game/backend/progression/default_scene_registry.tres` |
| Fragmentos de alma | `game/backend/decisions/data/fragment_level_*.tres` |
| Textos de las consecuencias (HUD y nivel) | `game/backend/decisions/default_decision_texts.tres` |
| **Historia: almas, guardianes, abuelo, 4 finales** | `game/backend/story/default_story_texts.tres` (copia legible: `docs/STORY.md`) |
| Controles (acciones, nombres, textos) | `game/backend/controls/default_controls_catalog.tres` |
| **Aspecto de cada perfil** (fondo, viñeta, aura, brillo, música) | `game/frontend/presentation/default_profile_presentation.tres` |
| **Avisos de ataque y sonidos de preparación** | `game/frontend/fx/default_telegraphs.tres` |
| **Eventos de sonido, música de cada jefe, bajada de la música** | `game/frontend/audio/default_audio_events.tres` |
| Biomas (cielo, capas, suelo) | `game/frontend/levels/biome/*.tres` |
| Tema de la interfaz | `game/frontend/ui/theme/quack_theme.tres` |
| Paleta del epílogo de los finales | constante `EPILOGUE_LOOKS` en `game/frontend/prologue/prologue_shots.gd` |

### Reglas que no se deben romper (resumen; el detalle está en la sección 9)

1. Tres autoloads y siete claves de guardado, ni una más.
2. Ninguna lógica de juego en los nodos visuales; la IA nunca controla el combate.
3. Los tiempos, daños, vidas y alcances viven en recursos, no en el código.
4. Nada de rutas absolutas ni claves en el repositorio; `ai-service/.env` nunca se sube.
5. Las listas de recursos dentro de un recurso van **sin tipo** (`Array`): una lista tipada de clases de script hace que Godot imprima fugas al salir (`ERROR: ... leaked at exit`), que la suite cuenta como fallo. Tampoco referencies desde scripts de interfaz (p. ej. `options_board.gd`) clases que crean ciclos de scripts; usa el nombre del grupo como texto.
6. Las pruebas usan archivos `user://test_*` y nunca tocan la partida ni las opciones reales.


## 1. Qué es marcador de posición y qué es definitivo

| Elemento | Estado |
| --- | --- |
| Lógica de movimiento, combate, jefes, decisiones, guardado, perfil adaptativo, servicio de IA | Definitivo (se puede reajustar con datos) |
| Gráficos de jugador, enemigos y jefes | **Dibujados** por código con `DuckRig` (`game/frontend/animations/duck_rig.gd`): patos con tinta gruesa y animación procedural. Al morir se desarman en un ragdoll (`duck_ragdoll.gd`) |
| Escenarios (cielo, capas de parallax, pisos, partículas) | **Dibujados** por código por bioma (`game/frontend/levels/biome/`, `backdrop/`, `terrain/`): pradera (tutorial), bosque (nivel 1), pantano (nivel 2), tormenta (nivel 3) |
| Menú principal y tipografía de títulos | **Dibujados**: escena animada (`menu_stage.gd`), carteles (`sign_button.gd`) y la letra "Pato Tinta" (`game/frontend/ui/type/ink_type.gd`) |
| Proyectiles y puertas | **Marcador** (polígonos); los proyectiles enemigos llevan además un contorno de peligro dibujado (`danger_outline.gd`). El HUD, la pausa, el Game Over y los menús ya tienen el aspecto de piedra de `stone_ui.gd` |
| Animaciones del jugador, enemigos y jefes | Procedurales en `DuckRig` (correr, saltar, dash, tajo, golpe pesado, tajo de dash, onda, zarpazo, embestida, ráfaga, furia de fase 2, daño, muerte con ragdoll). Los sprites no existen; el audio (música y unos 70 efectos) lo reproduce `AudioDirector` (sección 7) |
| Textos (prólogo, introducciones de nivel, tutorial, abuelo, menús, créditos) | Escritos en español y editables. La explicación de las decisiones vive en `game/backend/decisions/default_decision_texts.tres`; las líneas de cada nivel, en `LevelBase.intro_lines`. Los finales son de una sola frase y se reescribirán en la Fase 14d |
| Nombres de jefes y fragmentos | Los nombres que ve el jugador (tarjeta VS, barra del jefe) viven en `game/frontend/fx/boss_names.gd`; `BossStats.display_name` y `SoulFragmentData` son datos internos |
| Geometría de los niveles 1–3 y del tutorial | Maqueta con `PlaceholderPlatform`; las medidas están calculadas con el salto real (ver sección 4) |
| Valores de balance (vida, daño, recargas, velocidades) | Provisionales: nadie ha jugado para ajustarlos. La Fase 14g los midió con bots (`docs/BALANCE_REPORT.md`) sin cambiar ninguno |

## 2. Cambiar los gráficos sin romper la lógica

Cada personaje separa lo visual de lo físico:

- **Jugador** (`game/backend/player/player.tscn`): el nodo `Visual` (script `player_visual.gd`) contiene `Rig`, un `DuckRig` con el aspecto `HERO` (kimono, pelo largo suelto, katana). `player_visual.gd` lee el estado del jugador y le pasa la pose cada fotograma (fase de cada ataque según los tiempos de `PlayerStats`). Se voltea con `scale.x` según la orientación. Para cambiar el dibujo edita `duck_rig.gd`; para usar sprites, sustituye `Rig` por un `AnimatedSprite2D` y lee las mismas señales.
- **Enemigos** (`game/backend/enemies/*.tscn`, base `enemy_base.tscn`): nodo `Visual` (script `enemy_visual.gd`) con un `Rig`. El export `look` elige el pato (Bruto, Bandido, Hondero) y `tough_look` se usa cuando `max_health` llega a `tough_health` (Bruto acorazado). Para revisar todos los patos y poses abre `game/frontend/scenes/test/duck_showcase.tscn` (F6); `duck_arena_preview.tscn` los muestra en juego con un piloto automático.
- **Jefes** (`game/backend/bosses/boss_base.tscn`): nodo `Visual` (script `boss_visual.gd`) con un `Rig`; el export `look` elige el guardián (Capataz en `placeholder_boss`, Pantano en `boss_two`, Tormenta en `boss_three`). Anima zarpazo, embestida y ráfaga según la fase del patrón en curso (`BossPattern.get_phase_progress()`), muestra la furia en la fase 2 y se desarma en un ragdoll al ser derrotado.
- **Proyectiles:** `projectile.tscn` (enemigos y jefes) y `sword_wave_projectile.tscn` (onda del jugador) tienen un nodo `Visual`. `ProjectileStats.size_scale` y `tint` se aplican a ese nodo.
- **Plataformas y muros:** `PlaceholderPlatform` y `placeholder_wall.tscn` (`game/frontend/levels/blocks/`) se dibujan con un `TerrainSkin` en el bioma del nivel. El export `skin` elige la forma (AUTO: los altos son muros de roca, los anchos altos son techos con estalactitas, los anchos bajos son suelo que sigue bajo la pantalla, el resto son islas flotantes con raíces; los `one_way` son tablones). `show_placeholder` vuelve al rectángulo plano (`Visual`). La colisión es una `CollisionShape2D` aparte que sigue a `size`; el labio de pasto sobresale unos píxeles por arriba a propósito.
- **Fondo de cada nivel:** el nodo `Backdrop` de `level_base.tscn` pinta el cielo (capa -5, encima del `BackgroundLayer` plano), cuatro capas `Parallax2D` detrás del juego (lejos → cerca, con bruma), una capa de siluetas delante (z 40) y partículas. Todo sale del `Biome` asignado en la raíz del nivel (`biome`); paletas en `game/frontend/levels/biome/*.tres`.
- **Puertas:** `ArenaGate` sigue con su `Polygon2D` llamado `Visual`.

El daño por contacto lo hace un `ContactHitbox` (hijo de cada enemigo y jefe) cuya forma se copia del cuerpo; no lo muevas ni lo reemplaces por un sprite.

**No toques:** los `CollisionShape2D`, los `Hitbox`/`Hurtbox`, los scripts ni las capas de colisión (nombradas 1–7 en Project Settings). Un cambio de tamaño en un hitbox cambia el combate.

## 3. Dónde vive cada valor ajustable

| Qué | Dónde |
| --- | --- |
| Movimiento, salto, dash, ataque de espada, vida y reaparición del jugador | `game/backend/player/default_player_stats.tres` (`PlayerStats`) |
| Golpe pesado y tajo de dash (daño, tiempos, empuje, anchura del golpe, recarga) | Grupos "Heavy attack" y "Dash slash" de `PlayerStats` (`default_player_stats.tres`) |
| Daño por contacto (daño, empuje, intervalo de repetición, activo en estado de daño) | Grupo "Contact damage" de `EnemyStats` (`game/backend/enemies/stats/*.tres`) y de `BossStats`; el recorte de la forma del contacto es el export `contact_shape_inset` de `EnemyBase` / `BossBase` |
| Onda de espada (niveles, daño, alcance, recarga, reglas de mejora) | `game/backend/player/default_sword_wave_config.tres` (`SwordWaveConfig`) |
| Vida, velocidad y ataques de enemigos | `game/backend/enemies/stats/*.tres` (`EnemyStats`, `FastEnemyStats`, `RangedEnemyStats`) y `game/backend/combat/stats/enemy_projectile_stats.tres` |
| Vida y fases de cada jefe | `game/backend/bosses/stats/*.tres` (`BossStats`) |
| Medidor de alma y curación (alma por golpe, almas de enemigos y jefes, coste, tiempo de enfoque) | `game/backend/player/default_soul_config.tres` (`SoulConfig`) |
| Ragdoll de muerte (duración) | Export `ragdoll_lifetime` de `enemy_visual.gd` y `boss_visual.gd`; el del jugador dura hasta que reaparece |
| Patrones de cada jefe (pesos, tiempos, distancias, ráfagas) | Exports de los nodos bajo `Patterns` en `placeholder_boss.tscn`, `boss_two.tscn`, `boss_three.tscn` |
| Perfiles adaptativos (agresividad, variantes de encuentro/narrativa/final, umbrales) | `game/backend/ai/default_adaptive_config.tres` (`AdaptiveConfig`) |
| Conexión al servicio de IA | `game/backend/ai/default_ai_service_config.tres` (o `QUACKTACLYSM_AI_URL`) |
| Escenas, nuevo juego, orden de niveles y fundidos | `game/backend/progression/default_scene_registry.tres` (`SceneRegistry`) |
| Fragmentos de alma | `game/backend/decisions/data/*.tres` (`SoulFragmentData`) |
| Cada nivel (límites de cámara, fondo, introducciones, variantes, siguiente escena) | Exports de la raíz del nivel (`LevelBase`) |
| Bioma de cada nivel (cielo, capas, colores del suelo, partículas) | `biome` en la raíz del nivel y los recursos `game/frontend/levels/biome/*.tres` (`Biome`) |
| Opciones del jugador (pantalla completa, volumen) | `user://settings.cfg` vía `GameSettings` (`game/frontend/ui/game_settings.gd`); nunca en la partida guardada |
| Textos del final | `game/backend/story/default_story_texts.tres` (`StoryTexts`; copia legible en `docs/STORY.md`) |
| Textos del menú | Exports de `main_menu.gd` / `pause_menu.gd` / `game_over_panel.gd` |

Ningún valor de juego está escrito en el código: si encuentras uno, es un error y debe pasar a un recurso.

## 4. Construir o editar un nivel

1. Crea una escena **heredada** de `game/frontend/levels/level_base.tscn` (Escena → Nueva escena heredada).
2. En la raíz ajusta: `level_number` (0 = tutorial, 1–3), `level_id`, `start_checkpoint_id` (`level_N_start`), `next_scene_id` (id del registro; si no es un nivel, p. ej. `ending`, se escribe `checkpoint = "ending"`), `show_game_over`, `camera_limits` (`Rect2i`, tamaño cero = sin límites), `background_color`, `intro_lines`, `intro_duration`, `variant_groups`, y para niveles con jefe `boss`, `encounter`, `fragment_drop`, `arena_gates`.
3. Pon geometría, enemigos, checkpoints y jefe dentro del nodo `Content` (debe estar en el origen) y mueve `SpawnPoint`.
4. **Checkpoints:** `level_N_start` (`order` 0) y `level_N_arena` (el `order` más alto). El de la arena va justo ANTES de la puerta y **fuera** del área del `BossEncounter`; si no, al reaparecer se reactivaría el jefe. "Continuar" solo restaura si el checkpoint guardado pertenece al nivel.
5. **Arena:** una o más `ArenaGate` (se cierran al empezar el combate, se abren al reiniciarse o morir el jefe), techo y muro de cierre, `BossEncounter` con su `boss`, `SoulFragmentDrop` con el jefe, `fragment_data` y `fragment_scene`, y el export `drop` del nodo `DecisionFlow` apuntando a ese `SoulFragmentDrop` (se asigna en la escena del nivel).
6. **Variantes:** `variant_groups` = `{ "calm": [], "standard": [], "corrupted": [NodePath("Content/ExtraEnemigo"), ...] }`. Al cargar, los grupos que no coinciden con la variante de encuentro del resultado adaptativo se eliminan; lo que no está en ningún grupo es la base. `intro_lines` = `{ "mercy": "...", "balanced": "...", ... }` (variantes narrativas de `default_adaptive_config.tres`).
7. **Medidas del salto** (medidas con el jugador real; la prueba `level_phase12b_smoke_test` las vuelve a medir): salto solo ≈ 220 px, altura máxima ≈ 112 px, salto + dash (dash a 0,3 s) ≈ 328 px. Huecos de salto simple ≤ 85 % del salto (≈ 187 px); huecos de dash entre 110 % del salto y 90 % del salto + dash (≈ 242–295 px; se usan 285 px); escalones ≤ 85 % de la altura (se usan 80 px). Pon una `KillZone` bajo cada hueco.
8. Registra la escena en `default_scene_registry.tres` y, si es un nivel, añade su id a `level_scene_ids`.

## 5. Configurar un jefe nuevo desde datos

1. Crea un `BossStats` en `game/backend/bosses/stats/` (id, nombre, vida, ratio y multiplicadores de la fase 2, pausa entre patrones).
2. Crea una escena heredada de `boss_base.tscn`, asigna `stats` y añade nodos `SwipePattern` / `ChargePattern` / `ProjectileVolleyPattern` bajo `Patterns` (sus hitboxes bajo `AttackPivot`). Ver `boss_two.tscn` y `boss_three.tscn`. No hace falta código.
3. En el nivel asigna el jefe a `boss`, `BossEncounter.boss` y `SoulFragmentDrop.boss`, con un `SoulFragmentData` cuyo `boss_id` coincida con el id de los stats.
4. La agresividad adaptativa se aplica sola (`BossBase.set_aggression`, 0,5–2,0).

## 6. Textos del final y variantes narrativas

- **Los cuatro finales** viven en `game/backend/story/default_story_texts.tres` (`StoryTexts`, ver sección 14) y se eligen **solo por las almas liberadas** (`EndingSelector`: 3 = `ending_full`, 2 = `ending_scar`, 1 = `ending_doubt`, 0 = `ending_corrupt`). La escena es `EndingController` (`ending.tscn`); ya no usa `ending_variant` del resultado adaptativo.
- Las **variantes narrativas** (`mercy`, `balanced`, `burden`...) siguen existiendo solo para las líneas de introducción de cada nivel (`intro_lines` de `LevelBase`) y las elige el perfil o el servicio de IA. Qué perfil permite qué variante: `default_adaptive_config.tres`. Para añadir una variante hay que añadirla a `allowed_narrative_variants` y a `intro_lines` de los niveles.

## 7. Audio y skins de interfaz sin tocar la lógica

El audio lo reproduce `AudioDirector` (`game/frontend/audio/audio_director.gd`, el tercer autoload): engancha las señales de la sección 8 a medida que los nodos entran en el árbol, así que **no añadas llamadas de audio en los scripts de lógica**. Para un sonido nuevo, conecta otra señal ahí. Reproduce la música por escena en el bus `Music` y los efectos en `SFX` (silencioso en headless). Los sonidos de Liberar, Conservar y de la fase 2 del jefe reutilizan archivos existentes (`DECISION_SFX` y `PHASE_TWO_SFX` en ese script) hasta que haya assets propios. Los menús usan `Control` estándar: aplica un `Theme` en la raíz de cada escena de `game/frontend/ui/` en vez de editar colores en el código.

## 8. Señales útiles para efectos y audio (verificadas en el código)

- **Jugador** (`player.gd`): `state_changed(old, new)`, `dash_started`, `dash_finished`, `attack_started`, `attack_finished`, `heavy_attack_started`, `dash_slash_started`, `wave_cast(tier)`, `died`, `respawned`. `Player.current_sword_kind` (LIGHT / HEAVY / DASH_SLASH) indica a qué movimiento pertenece el golpe activo; el `DuckRig` dibuja una estela distinta para cada movimiento (`slash_color`, `heavy_color`, `dash_slash_color`). `HealthComponent` (nodo `Health`): `health_changed`, `damaged(info)`, `invulnerability_started/ended`, `died`.
- **Onda de espada** (`sword_wave_caster.gd`): `tier_changed(tier)`, `wave_cooldown_changed(remaining, total)`. `Projectile`: `despawned(reason)` con `hit`, `world` o `lifetime`.
- **Combate:** `Hitbox.hit_landed(hurtbox, info)`, `Hurtbox.hit_received(info, applied)`.
- **Enemigos** (`enemy_base.gd`): `target_acquired`, `target_lost`, `died(enemy)`, `state_changed`, `attack_phase_changed`, `attack_ended`.
- **Jefes** (`boss_base.gd`): `activated`, `encounter_reset`, `health_changed`, `phase_changed(phase)`, `pattern_started/finished/cancelled(id)`, `pattern_phase_changed(id, fase)`, `defeated(boss)`, `state_changed`. `BossEncounter`: `encounter_started`, `encounter_won`. `ArenaGate.state_changed(is_closed)`.
- **Decisiones:** `SoulFragmentDrop.fragment_spawned`, `SoulFragment.collected`, `DecisionPanel.choice_selected`, `DecisionFlow.decision_made(id, choice)`, `GameState.decision_recorded(entry)`, `GameState.state_changed`.
- **Niveles y escenas:** `Checkpoint.activated(id)`, `LevelBase.level_ready` y `level_completed(number)`, `TutorialController.step_completed(id)` y `tutorial_completed`, `SceneManager.transition_started/finished(id)` y `scene_change_failed`.
- **Adaptativo:** `AdaptiveRefiner.refinement_started`, `refinement_applied(result)`, `refinement_skipped(reason)`.

## 9. Reglas que no se deben romper

- Solo tres autoloads: `GameState`, `SceneManager` y `AudioDirector` (solo audio, sin lógica de juego). No añadas otros sin una razón fuerte y documentada.
- La IA **nunca** controla el combate: solo elige perfil y variante narrativa; los números salen de `AdaptiveConfig`.
- El archivo de guardado tiene exactamente siete claves (`save_version`, `current_level`, `checkpoint`, `souls_released`, `souls_kept`, `decisions`, `adaptive_profile`). La onda de espada, el final y demás se derivan de ellas.
- No pongas rutas absolutas ni claves en el repositorio. `.env` nunca se sube.
- Configuración del servicio de IA: cada ingeniera usa su propio `ai-service/.env` (copia de `ai-service/.env.example`, ver `docs/ENVIRONMENT.md`). El cargador está en `ai-service/app/config.py` (`prepare_settings`): el `.env` gana sobre el entorno del terminal y, sin `.env` o sin clave/modelo en modo `openai`, el servicio arranca en `mock` con un aviso. `/health` solo devuelve `mode` y `openai_configured`. Las pruebas de `ai-service` usan `AI_SERVICE_ENV_FILE` para no leer nunca el `.env` real.
- Ejecuta `python tools/run_all_tests.py` antes de cada fusión: debe terminar en `OVERALL: PASS`.
- Las pruebas usan rutas `user://test_save_*.json` y el servicio de IA desactivado; no las cambies para tocar el guardado real.

## 10. Primera hora

1. Instala Godot 4.7.x, abre `game/project.godot` y pulsa F5 (menú principal). Pulsa "Nueva partida".
2. Juega el tutorial y el Nivel 1 completos. Anota todo lo que se sienta mal en `docs/KNOWN_ISSUES.md` (o en la columna de resultado de `docs/QA_CHECKLIST.md`).
3. En un build de depuración usa `F4` (mata al jefe), `H` (10 %), `F2` (teletransporte a la arena) y `F3` (datos) para recorrer los niveles 2 y 3 rápido.
4. Ejecuta `python tools/run_all_tests.py` (necesita `GODOT_BIN` o `--godot`; usa `--skip bot_phase13_soak_test` para una pasada rápida). Debe pasar entero.
4b. Sigue `docs/QA_CHECKLIST.md` jugando una vez de principio a fin y anota los resultados reales.
5. Lee `docs/CHANGES_FROM_DESIGN.md` y actualiza los documentos de diseño.
6. Empieza por sustituir el `Visual` del jugador; vuelve a ejecutar las pruebas.

## 11. Fase 14b: decisiones con consecuencias (dónde vive cada cosa)

- **Regla del perfil:** `decision_margin_threshold = 1.0` en `game/backend/ai/default_adaptive_config.tres` (cada decisión se nota en el nivel siguiente: score ≥ 1 compasivo, ≤ −1 corrupto, 0 neutral) y `max_profile_distance = 0` (el servicio remoto solo puede elegir la variante narrativa; nunca cambia el perfil de la regla). El servicio mock de `ai-service/app/rules.py` usa el mismo umbral (`MOCK_THRESHOLD`).
- **Recompensa por liberar:** `health_per_released_soul` (1) y `released_souls_cap` (3) en `PlayerStats` / `default_player_stats.tres`. `Player.get_max_health_for_souls()` los aplica a partir de `GameState.souls_released` al aparecer y al reaparecer. No se guarda nada nuevo.
- **Coste de conservar:** la onda de espada más fuerte (reglas de `default_sword_wave_config.tres`) frente a un perfil corrupto (nivel 3 más difícil, enemigos extra, jefe más rápido). No hay mecánica nueva.
- **Indicador de corrupción:** `PlayerHealthHud` (perfil y score, con `GameState.get_adaptive_score()`); textos en `default_decision_texts.tres` (`DecisionTexts`).
- **Línea de consecuencias al empezar un nivel:** `LevelBase.build_consequence_line()` con el texto de `DecisionTexts`; se muestra junto a la línea narrativa (`LevelTitleCard` la dibuja). El tutorial no tiene.
- **HUD de vida:** los segmentos se estrechan para que la barra no pase de 176 px (22 px hasta 8 puntos, 16 px con 11).
- **Teclas de depuración:** `F4` mata al jefe (antes `K`, que es una tecla del dash), `H` lo daña, `F2` va al checkpoint de la arena y `F3` muestra los datos. En `boss_test` también `F4`.

## 12. Controles reasignables (Fase 14b-2)

- **Qué se puede cambiar:** las acciones de `game/backend/controls/default_controls_catalog.tres` (`ControlsCatalog`): mover, saltar, dash, ataque, onda, golpe pesado y pausa. Las teclas de depuración y las acciones `ui_*` no están. Los nombres en español de las acciones, de las teclas y del ratón, y todos los textos de la pantalla, viven en ese recurso.
- **Lógica:** `ControlsConfig` (`game/backend/controls/controls_config.gd`, clase normal, no autoload): dos asignaciones por acción (principal y alternativa), `user://controls.cfg` (un `ConfigFile`, no la partida), conflictos (intercambiar o cancelar), la principal nunca queda vacía, Esc reservada, archivo ausente, dañado o parcial = valores por defecto por acción sin borrar lo válido. Los valores por defecto salen de los ajustes del proyecto (`input/<acción>` en `project.godot`), no del InputMap vivo. `SceneManager._ready` llama a `ControlsConfig.apply_saved()` (en ejecuciones headless, como la suite de pruebas, no lee el archivo real del jugador).
- **Pantalla:** `ControlsEditor` (`game/frontend/ui/controls_editor.gd`), dentro de `OptionsBoard` (pausa) y del panel de opciones de `main_menu.tscn`. Mientras espera una tecla consume el evento en `_input`, así no llega al juego ni a los menús.
- **Pistas en pantalla:** el tutorial usa `ControlsConfig.input_map_hint(acción)` (nombres legibles, ratón incluido) y `TutorialSign` dibuja esos nombres como teclas. Los scripts de juego leen solo acciones del InputMap.
- **Pausa:** `PauseMenu.is_pause_event()` acepta la acción `pause` o Esc.
- **Por defecto:** ataque = J + clic izquierdo (se quitó X para respetar el máximo de dos asignaciones), onda = U + clic derecho, golpe pesado = I + clic central.

## 13. Corrupción visible y audible (Fase 14c)

- **Qué se retoca (Ingeniera 2):** `game/frontend/presentation/default_profile_presentation.tres` (`ProfilePresentation`): una entrada `ProfileLook` por perfil con tinte del fondo, viñeta, tinte de la placa, aura y ojo del pato, brillo de enemigos, tono y corte (low-pass) de la música, color y duración del destello; más `fade_time` y el texto del interruptor. Los colores con "alfa = intensidad" (0 = apagado); el tinte del fondo multiplica (blanco = igual). **La entrada neutral debe seguir siendo la identidad** (la prueba lo comprueba).
- **Lógica:** `ProfilePresenter` (`frontend/presentation/profile_presenter.gd`), un nodo hijo de `level_base.tscn` (no autoload). Lee el perfil de `GameState` al cargar el nivel y en `DecisionFlow.decision_made` (sin sondeos); si el perfil cambió, mezcla al nuevo aspecto y da el destello (`pulses_fired`). Aplica: `Backdrop.set_grade` (cielo y capas de parallax, nunca la capa de juego), una superposición con `profile_overlay.gdshader` (viñeta + destello de pantalla; capa 1, bajo el HUD), `PlayerHealthHud.plaque_tint` / `pulse_plaque`, `DuckRig.aura_color` / `eye_tint` / `glow_color` (solo dibujo; con alfa 0 no se dibuja nada) y la música vía `AudioDirector.set_music_profile` (tono en los reproductores de música + `AudioEffectLowPassFilter` en el bus Music; se quita al salir del nivel, y fuera de un `LevelBase` siempre se limpia).
- **Enemigos y jefes:** `EnemyVisual` y `BossVisual` se registran por grupo (`profile_presenter`, `register_enemy_rig`), así los que aparecen más tarde también brillan.
- **Opción:** `GameSettings` clave `corruption_effects` (por defecto sí; `user://settings.cfg`). `OptionsBoard` (pausa) y el menú principal tienen el interruptor; `OptionsBoard` avisa al presentador del nivel abierto con `call_group(..., "refresh_settings")`. Apagado: todo vuelve a neutral salvo la placa y la línea de consecuencias.
- **Aviso técnico:** NO referenciar la clase `ProfilePresenter` desde `options_board.gd` ni desde otros scripts de la escena de pausa: crea un ciclo de scripts y la salida de Godot imprime fugas (`ERROR: ... leaked at exit`, que la suite cuenta como fallo). Se usa el nombre del grupo como literal.
- **Pruebas:** `phase14c_smoke_test` y el bucle "corrupto" añadido a `flow_phase13_leak_test`. `GameSettings.path_override` redirige el archivo de opciones en las pruebas.

## 14. Historia y finales (Fase 14d)

- **Qué edita Ingeniera 2:** `game/backend/story/default_story_texts.tres` (`StoryTexts`): `souls` (`SoulStory`: nombre, nombre corto, recuerdo, línea de liberar y de conservar), `bosses` (`BossStory`: 2-3 líneas, como mucho una línea extra por perfil `compassionate` / `corrupt`, y la línea al caer), `endings` (`EndingStory`: título, 5-8 líneas, estilo del epílogo `full` / `scar` / `doubt` / `corrupt`, pista de música existente, frase de la tarjeta), la escena del abuelo (`elder_lines`, `elder_mood_lines` según las almas liberadas, `elder_mood_index`) y los textos de la tarjeta de resumen. `{released}` y `{kept}` en una línea de final se sustituyen por el nombre corto del alma liberada / guardada. Cada línea, máximo ~110 caracteres. **`docs/STORY.md` es una copia legible; la fuente de verdad es el recurso.**
- **Final determinista:** `EndingSelector.ending_id_for(souls_released)` (3 → `ending_full`, 2 → `ending_scar`, 1 → `ending_doubt`, 0 → `ending_corrupt`). El perfil adaptativo y la IA ya no intervienen; `ending_variant` del resultado adaptativo sigue existiendo pero la escena no lo usa. Los nombres salen de `GameState.decisions` (sin datos nuevos; el marcador sigue siendo `checkpoint = "ending"`).
- **Escena del final:** `EndingController` reproduce un `StoryReel` (`frontend/story/story_reel.gd`: subtítulos, barras, títulos y fundidos sobre `PrologueShots`, que ahora tiene el plano `EPILOGUE` con los cuatro estilos) y después muestra la tarjeta de resumen. Mantener Enter 1,2 s la salta. En ejecuciones headless va directo a la tarjeta (`skip_reel_when_headless`).
- **Guardianes:** `BossDialogue` (`frontend/story/boss_dialogue.gd`, nodo de `level_base.tscn`): subtítulo abajo, una vez por encuentro (también tras reintentar o reaparecer), Enter lo salta sin consumir la tecla, nunca bloquea al jugador.
- **El abuelo:** `ElderScene` (nodo de `level_3.tscn`): al llegar al nivel 3 desde su checkpoint inicial y sin decisión del fragmento 3 (en headless solo con `play_when_headless`). Usa `StoryReel` con el plano de la cueva, pausa el juego (PauseLock) y se salta con Enter.
- **Panel de decisión:** muestra el nombre y el recuerdo del alma y, bajo LIBERAR / CONSERVAR, lo que le pasa en cada caso (los `.tres` de los fragmentos llevan los mismos textos).
- **Aviso técnico:** en los recursos con listas de otros recursos (`StoryTexts`) las listas van **sin tipo** (`Array`): una lista tipada de clases de script hace que Godot imprima fugas al salir (`ERROR: ... leaked at exit`), que la suite cuenta como fallo.
- **Pruebas:** `phase14d_smoke_test`. `python tools/run_all_tests.py --skip NOMBRE` omite una prueba (p. ej. `--skip bot_phase13_soak_test`).

## 15. Ataques legibles y sensación de golpe (Fase 14e)

- **Qué edita Ingeniera 2:** `game/frontend/fx/default_telegraphs.tres` (`TelegraphSet`): un `TelegraphStyle` por tipo (`melee`, `melee_tough`, `fast`, `ranged`, `boss_swipe`, `boss_charge`, `boss_volley`) con la forma (arco, carril, línea de apunte, abanico), color, tamaño, ancho, ángulo del arco, signo de exclamación y los **sonidos de preparación** (entradas `[archivo de frontend/audio/sfx, variación de tono, volumen en dB, tono]`, solo archivos existentes). El color debe seguir leyéndose sobre todos los fondos: la prueba `phase14e_smoke_test` calcula el contraste contra los 7 biomas con los 3 aspectos de perfil y contra los colores del suelo (umbral 2,5).
- **Cómo funciona:** `TelegraphDrawer` (`frontend/fx/telegraph_drawer.gd`) es un hijo del enemigo o del jefe (no de su `Visual`, así los tintes no lo recolorean). Lo muestra, actualiza y oculta `EnemyVisual` / `BossVisual` con las señales que ya existían (`attack_phase_changed`, `attack_ended`, `pattern_phase_changed`, `pattern_finished`, `pattern_cancelled`, `phase_changed`, `defeated`, `encounter_reset`); no hay sondeo de estado. El avance sale de los tiempos de siempre (`_phase_time / duración` en enemigos, `pattern.get_phase_progress()` en jefes). Dibuja con llamadas de dibujo sin reservar memoria por fotograma.
- **Sonidos:** `AudioDirector._play_windup` (con `windup_count` y `last_windup_kind` para las pruebas): uno por preparación, nunca para algo ya muerto. Sustituye al graznido aleatorio de antes.
- **Golpe y muerte:** destello blanco (`flash_color` > 1: enemigos 2,2, jefes 2,7; la duración es la de siempre), rebote del `DuckRig` (`pop_time`, `pop_strength`), tinte de recuperación (`recovery_color`) y `SoulWisp` (`frontend/fx/soul_wisp.gd`) al morir un enemigo.
- **Garantía:** ningún tiempo, daño, vida, velocidad, alcance, hitbox, drop ni número de enemigos cambió; `phase14e_smoke_test` compara explícitamente la preparación, la fase activa y la recuperación de cada tipo de enemigo y de cada patrón de jefe con los valores de la auditoría.
- **Aviso técnico:** las listas de recursos (`TelegraphSet.entries`) van sin tipo (`Array`), igual que en `StoryTexts`: las listas tipadas de clases de script provocan fugas al salir.

### Cambios de comportamiento aplazados hasta la prueba manual (ideas, NO implementadas)

- Que el enemigo a distancia retroceda menos o más rápido, o que se detenga al apuntar.
- Ajustar la recuperación del enemigo rápido (0,7 s es larga frente a su embestida de 0,25 s).
- Alargar un poco la preparación del enemigo cuerpo a cuerpo normal (0,35 s) o acortar la del robusto.
- Un aviso audible distinto para la fase 2 de cada jefe.
- Que la descarga ligera del jefe 3 dispare un abanico más estrecho.
- Un contorno de peligro para los proyectiles (queda para la Fase 14f).

## 16. Audio que faltaba y proyectiles legibles (Fase 14f)

- **La tabla de eventos (Ingeniera 2 edita aquí):** `game/frontend/audio/default_audio_events.tres` (`AudioEvents`). Cada evento (`AudioEvent`) tiene `files` (archivos de `frontend/audio/sfx`, con extensión y subcarpeta; se elige uno al azar), `volume_db` (relativo a `AudioDirector.SFX_DB`, −4), `pitch_min` / `pitch_max`, `cooldown` (s) y `max_voices` (copias simultáneas). Para **cambiar o reemplazar un sonido**: pon el archivo nuevo en `sfx/` (Godot lo importa) y cambia `files` del evento; no hace falta tocar código. La prueba `phase14f_smoke_test` comprueba que cada archivo existe, tiene su `.import` y carga.
- **Cómo suena un evento:** `AudioDirector.play_event(id, fuente)`: respeta el cooldown y `max_voices` (se lleva la cuenta con la duración del sonido) y no suena si la fuente se liberó o está muerta. Se engancha por señales: pasos (`PlayerVisual.footstep`), impactos (`Projectile.despawned` y `Hitbox.hit_landed`), exorcismo y título del nivel (al entrar el nodo en el árbol), acorde del jefe (`BossEncounter.encounter_started`), Game Over (`GameOverPanel.opened`), portal (`StarPortal.portal_lit` / `portal_entered`) y cambio de escena (`SceneManager.transition_started`). Sin sondeos.
- **Pasos:** `PlayerVisual` suma los píxeles recorridos en el suelo en estado de carrera y emite `footstep` cada `step_distance` (44 px, export de `PlayerVisual`); no cuentan en el aire ni muerto. No se tocó `player.gd`.
- **Música por jefe:** `boss_music` de la misma tabla (nivel → `[archivo, tono]`): jefe 1 `the_evil_one` a 1,00; jefe 2 `treacherous_path` a 0,92; jefe 3 `the_evil_one` a 1,12. El tono de la pista se multiplica por el del perfil adaptativo (Fase 14c, que sigue encima y se devuelve al cerrar el nivel). Al caer el jefe, al reaparecer o al cambiar de escena vuelve la música del nivel.
- **Bajada de la música (ducking):** `AudioDirector.set_music_duck(dueño, dB)` baja la música del jugador activo; `BossDialogue` (−6 dB), `StoryReel` (−8 dB) y `BossFightFx` (−8 dB) lo piden mientras dura y lo sueltan; un cambio de escena suelta todos. Los valores están en la misma tabla.
- **Mezcla:** todos los sonidos nuevos van entre −16 y −7 dB y los avisos de preparación (Fase 14e) tienen su pico más bajo en −3 dB: la prueba exige al menos 3 dB de margen (hoy 4 dB). Los pasos van a −16 dB con cooldown de 0,16 s. Los volúmenes de los sonidos antiguos siguen en `audio_director.gd`.
- **Contorno de los proyectiles enemigos:** `DangerOutline` (`frontend/fx/danger_outline.gd`), un nodo hijo de `projectile.tscn` (la escena de la onda de espada no lo tiene). Contorno oscuro, halo rojo-anaranjado que late y anillo claro; solo lee `stats.size_scale` para seguir el tamaño. Contraste mínimo calculado contra los 7 biomas con los 3 aspectos de perfil y el suelo: 2,78 (umbral 2,5).
- **Eventos de la lista de la auditoría y dónde suenan:**

| Evento | Archivo | Dónde está definido |
|---|---|---|
| Pasos | `land.ogg` (tono alto) | tabla |
| Aterrizaje | `land.ogg` | `audio_director.gd` (ya existía) |
| Salto / dash | `jump.ogg` / `dash.ogg` | `audio_director.gd` (ya existían) |
| Exorcismo | `soul_fragment.wav` (grave) | tabla |
| Acorde de la presentación del jefe | `boss_start.wav` (grave) | tabla |
| Título del nivel | `checkpoint.ogg` (grave) | tabla |
| Portal encendido / entrar | `checkpoint.ogg` / `wave_cast.wav` | tabla |
| Cambio de escena | `dash.ogg` (grave) | tabla |
| Proyectil: escenario / pato / enemigo | `hit_1.ogg` / `hit_2.ogg` / `hit_1.ogg` | tabla |
| Onda de espada: enemigo / escenario | `swords/clash_3.ogg` / `swords/clash_7.ogg` | tabla |
| Game Over | `player_die.ogg` (grave) | tabla |
| Recoger alma, curarse, checkpoint, muerte del pato, menús (navegación y confirmar) | `soul_gain`, `heal_done` / `heal_denied` (tabla), `checkpoint.ogg`, `player_die.ogg`, `ui_hover.ogg` / `ui_click.ogg` |

## 17. Medidor de alma y curación (Fase 15a)

- **Qué edita Ingeniera 2:** `game/backend/player/default_soul_config.tres` (`SoulConfig`): alma máxima (99), alma por golpe (espada 11, pesado 22, tajo de dash 16, onda 8), alma de los enemigos (11) y de los jefes (33), tiempo de enfoque (0,9 s), corazones que cura (1) y la fórmula del coste (`heal_cost_base` 33 + `heal_cost_per_kept` 5 × fragmentos conservados). Los textos de la tarjeta, en `default_ability_texts.tres`; la línea del coste, en `default_decision_texts.tres` (`heal_cost_line`). El arte del efecto de enfoque está en `DuckRig._draw_focus_effect` y el de la barra de alma en `PlayerHealthHud._draw_soul_meter` (se sustituyen por arte cuando exista).
- **Lógica (nada de esto está en nodos visuales):** `SoulComponent` (hijo `Soul` del jugador: reúne el alma, calcula el coste y emite `soul_changed`, `soul_gained`, `soul_full`, `heal_denied`), el estado `FOCUS` de `Player` (`_try_start_focus`, `_update_focus`, `_complete_focus`, `_cancel_focus`; señales `focus_started`, `focus_cancelled`, `focus_completed(healed)`), `SoulPickup` (la alma que sale de lo que muere y se absorbe en ≤ 0,8 s) y `SwordWaveCaster.wave_hit`. El coste **sale de `GameState.souls_kept` cada vez** (no se guarda).
- **Reglas:** el enfoque solo empieza en el suelo, vivo, sin bloqueo de entrada, en reposo o corriendo, con vida < máxima y alma ≥ coste; la tecla se mantiene; soltarla, un golpe, un dash, caer o un bloqueo (cutscene) lo cancelan sin gastar. Al terminar cura exactamente `heal_hearts` (sin pasar del máximo, 8 a 11) y gasta el coste. En el tutorial (`Player.focus_practice`) también termina con la vida llena: gasta el alma y no cura.
- **HUD:** barra de alma bajo la placa de corrupción, con una marca en el coste que se mueve a la derecha al conservar fragmentos y un brillo cuando se puede pagar; `PlayerHealthHud.get_soul_rect()` / `get_plaque_rect()` dan las posiciones (la prueba comprueba que no se solapan con 11 corazones).
- **Tarjeta «Nueva habilidad»:** `AbilityCard` (`frontend/ui/ability_card.gd`): pausa el juego, lee las teclas del InputMap en el momento, se cierra con Enter o clic y no repite un mismo evento (ids en memoria; no se guarda nada). La usan `TutorialController` (paso de curarse) y `AbilityIntro` (nodo de `level_base.tscn`: al conservar un fragmento que mejora la onda, tras el exorcismo). En ejecuciones headless no se muestra salvo `play_when_headless` / `show_card_when_headless`.
- **Sonidos:** cinco eventos nuevos en `default_audio_events.tres`: `soul_gain`, `focus_start`, `heal_done`, `heal_denied`, `soul_full` (enganchados a las señales del jugador y del medidor).
- **Orbes:** eliminados (`health_orb*.gd/.tscn`, `HealthOrbStats`, `health_orb_count`, `health_orbs_on_phase_2`, `health_orbs_on_defeat`).
- **Pruebas:** `phase15a_smoke_test`; el bucle corrupto de `flow_phase13_leak_test` sale de un nivel en medio de un enfoque con almas volando; `balance_measure` usa el enfoque (informe en `docs/BALANCE_REPORT.md`).

## 18. Correcciones de la Fase 15b

- **Dash:** `Player.is_dash_invulnerable` es `state == DASH` (más `dash_invulnerability_grace`, 0 por defecto, tras terminar). Todo el daño pasa por `Hurtbox.receive_hit` → `Player.is_invulnerable()`, y las zonas de muerte usan `HealthComponent.kill`, que ignora la invulnerabilidad. El aura pálida del dash (`DuckRig.dash_shield`) cubre toda la ventana.
- **Cola de presentación:** `PresentationQueue` (`frontend/ui/presentation_queue.gd`, nodo `PresentationQueue` de `level_base.tscn`). `enqueue(id, starter, timeout)`: el *starter* arranca algo y devuelve la `Signal` que hay que esperar (o una `Signal()` vacía = nada que mostrar). Los pasos nunca se solapan, el primero empieza en una llamada diferida (así todos los oyentes del mismo evento ya han corrido) y un paso que no avisa se abandona al pasar `step_timeout` (20 s por defecto). `AbilityIntro` encola «corrupción» (señal `ExorcismCutscene.finished`) y luego la tarjeta; el tutorial encola su tarjeta. Para añadir una tarjeta futura basta `queue.enqueue("card_x", starter)` con un starter que devuelva `Signal(card, &"dismissed")`.
- **Introducción de jefe:** `BossIntro` (`frontend/story/boss_intro.gd`, nodo de `level_base.tscn`). `BossEncounter` le pregunta `begin(player)` antes de despertar al jefe; si devuelve true se emite `encounter_started` (cierra la arena, empieza el VS) pero el jefe sigue `INACTIVE` hasta `BossIntro.finished`. Orden: VS (`BossFightFx.presentation_finished`) → saludo del guardián → historia del pato (`BossDialogue.play_intro`, señal `sequence_finished`) → combate. Durante la introducción: `Player.set_input_locked(true)`, `Player.story_invulnerable = true` y el hurtbox del jefe apagado. Se salta con Enter (una pulsación salta todo, con 0,4 s de guarda). «Solo la primera vez» usa la memoria por ejecución de `BossDialogue` (`was_spoken` / `mark_spoken`): morir y reintentar no la repite y un nivel abierto desde su checkpoint de arena (el de mayor `order`) la da por vista. Si el pato muere durante ella se cancela y el jefe no despierta. En ejecuciones headless no se reproduce salvo `play_when_headless`.
- **Textos:** `BossStory.duck_lines` (6 por jefe, ≤ 110 caracteres, ~17 s cada uno) y `StoryTexts.duck_speaker` («Pato») en `default_story_texts.tres`; copia legible en `docs/STORY.md` sección 5.
- **Arena:** `level_1.tscn` `FloorEnd` ahora cubre x = 2685-5490 (antes 2685-5400). La prueba `phase15b_smoke_test` calcula la cobertura de suelo de las tres arenas desde sus formas de colisión.
- **Pruebas:** `phase15b_smoke_test`; el bucle corrupto de `flow_phase13_leak_test` sale de un nivel en plena introducción con un paso de la cola que nunca termina.

## 19. Jefe 2, nenúfares, pinchos y doble salto (Fase 15c)

- **Nenúfar trampolín** (`backend/arena/bounce_pad.tscn`, `BouncePad`): `Area2D` que ve solo al jugador; lanza con `config.launch_velocity` (−1030 px/s, ~300 px de subida) si el jugador cae sobre él (`velocity.y > 20` y el centro del jugador por encima), con `cooldown` 0,35 s. El nodo se coloca con su posición en el CENTRO del área (alto 44): `y = suelo − 22`. Dibujo en `frontend/arena/bounce_pad_art.gd`; `texture` (en el nenúfar) lo sustituye. `Player.launch_up()` protege el salto del recorte al soltar la tecla. Números: `default_bounce_config.tres`.
- **Pinchos del suelo** (`backend/arena/floor_hazard.tscn`, `FloorHazard`): su posición es el extremo izquierdo del suelo (a ras de la superficie) y `length` llega hacia la derecha; `boss` es el jefe que lo arranca (fase 2) y lo para (muerte, reinicio del encuentro, muerte del jugador). Los nenúfares quedan fuera de la banda peligrosa y las plataformas están por encima. Daño por `Hitbox` (equipo ENEMY) con `DamageInfo`, no por `KillZone`. Dibujo en `frontend/arena/floor_hazard_art.gd` (`spike_texture` opcional). Números: `default_floor_hazard_config.tres` (aviso 1,2 / activo 3,0 / descanso 4,0 s).
- **Salto del jefe** (`backend/bosses/patterns/leap_pattern.gd`, nodos `LeapLight` y `Leap` de `boss_two.tscn`): fases telegrafiado (agacharse + marcador de aterrizaje `LeapMarker`) → salto balístico a un `BossAnchor` de plataforma → percha (descarga `LeapVolley` apuntada hacia abajo) → salto de vuelta al suelo → recuperación. Los vuelos terminan al aterrizar, no por un temporizador. `BossAnchor` (`Marker2D` del grupo `boss_anchors`; `tier` FLOOR/PLATFORM): su posición es el centro del CUERPO del jefe (suelo 600 − 44, plataformas baja 510 − 44 y alta 350 − 44). Para añadir un ancla basta colocar un `BossAnchor` en el nivel; para una plataforma nueva, un `StaticBody2D` de un solo sentido y su ancla.
- **Arte propio:** `BouncePad.texture`, `FloorHazardArt.spike_texture` y el estilo `boss_leap` de `default_telegraphs.tres` (forma `MARKER`) sustituyen el dibujo por código sin tocar el código.
- **Doble salto** (`Player`): `max_air_jumps`, `double_jump_velocity` (−527) y `double_jump_unlock_decisions` (2) en `PlayerStats`; `Player.has_double_jump()` lee `GameState.decisions`. Señales `double_jumped` y `launched`. Anillo bajo los pies en `DuckRig.double_jump_t`.
- **Tarjeta:** `AbilityIntro` encola, tras la decisión del jefe 2 (`fragment_level_2`): animación de corrupción (si se conserva) → tarjeta de la onda (si se conserva) → tarjeta «Doble salto» (siempre). Textos en `default_ability_texts.tres`.
- **Sonidos:** `pad_bounce`, `double_jump`, `spike_warning`, `spike_rise`, `boss_leap`, `leap_land` en `default_audio_events.tres` (archivos reutilizados).
- **Pruebas:** `phase15c_smoke_test` (también mide el alcance y el tiempo de refugio: líneas `MEASURE|`), la prueba de fugas sale de la fase 2 con los pinchos en marcha, y `balance_measure.gd --only=boss2` simula el duelo en la arena real.

## 20. Posesión al cambiar de fase (Fase 15d)

- **Piezas:** `PossessionDirector` (`frontend/presentation/possession_director.gd`, nodo de `level_base.tscn`), `PossessionConfig` / `PossessionOverride` (recursos), `PossessionLayer` + `possession_overlay.gdshader` (viñeta y destello), `BossBase.phase_transition_started` / `hold_transition` / `release_transition`, `BossVisual.set_possession` / `clear_possession`, `DuckRig.possession*` (aura, ojos y pose), `Backdrop.possession_grade` (segundo multiplicador sobre el del perfil 14c), `BossFightFx.kick` (temblor) y los cambios de `BossHealthBar`.
- **Flujo:** el jefe cruza su línea → `_on_damaged` lo pone en `PHASE_TRANSITION` y emite `phase_transition_started(2)` → el director llama a `hold_transition` (el jefe no sale de la transición hasta `release_transition`), limpia proyectiles enemigos y para los `FloorHazard` ligados a ese jefe, bloquea al jugador y lo hace invulnerable → durante `duration` s aplica las intensidades (subida, brillo, tinte, viñeta, destello, temblor) → al acabar libera todo y el jefe entra en la fase 2 (`phase_changed(2)`: aquí arrancan los pinchos del jefe 2) → queda el aspecto persistente hasta que el jefe muere (`defeated`) o se cancela el combate (`encounter_reset`); entonces se desvanece en `fade_out_time`. Cancelar (muerte del jugador, reinicio, salir del nivel) lo deshace todo al instante. Una fase no se repite en el mismo combate (`phases_shown`), y un combate nuevo empieza limpio.
- **Reutilizarla en otra fase (jefe 3):** emitir `phase_transition_started(n)` al entrar en la fase n (el director no distingue la fase) y esperar `release_transition` antes de salir de la transición; el sonido de sting de la fase se omite solo (`boss.has_meta("possession_played")`). Para una fase con otro aspecto, añadir al recurso un `PossessionOverride` con su `boss_id` y su color/duración.
- **Ajustes por jefe:** en `default_possession_config.tres`, `overrides = [PossessionOverride(boss_id = &"boss_two", duration = 3.4, color = Color(...))]` (duración 0 y color con alfa 0 = valor por defecto; la duración se limita a 2,5-4 s).
- **Modo reducido y headless:** sin «Efectos de corrupción» solo hay una pausa de `reduced_freeze` (1 s) con pose y sonido; en ejecuciones headless no se retiene nada (el jefe hace su rugido de 1,5 s de siempre) salvo `play_when_headless`.
- **Arte propio:** el aspecto del jefe (aura, ojos, pose) está en `DuckRig._draw_possession_aura` / `_draw_possession_eyes`; la viñeta, en `possession_overlay.gdshader`; no hay texturas que sustituir salvo las del jefe mismo.
- **Sonidos:** `possession_start`, `possession_roar`, `possession_slam` en `default_audio_events.tres` (archivos reutilizados, graves). El sting de la fase 2 de la 14b no suena cuando la secuencia ha corrido.
- **Pruebas:** `phase15d_smoke_test`; el bucle corrupto de `flow_phase13_leak_test` sale de la fase 2 del jefe 2 con la posesión en marcha.
