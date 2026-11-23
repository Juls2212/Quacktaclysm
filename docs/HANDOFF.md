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

- **Los dos finales (Fase 15h)** viven en `game/backend/story/default_story_texts.tres` (`StoryTexts`, ver sección 14) y se eligen **por la mayoría de las decisiones** (`EndingSelector`: guardadas > liberadas = `ending_kept`; si no, `ending_released`). La escena es `EndingController` (`ending.tscn`); ya no usa `ending_variant` del resultado adaptativo.
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
- **Final determinista:** `EndingSelector.ending_id_for(released, kept)` (`kept > released` → `ending_kept`; si no → `ending_released`). El perfil adaptativo y la IA ya no intervienen; `ending_variant` del resultado adaptativo sigue existiendo pero la escena no lo usa. Los nombres salen de `GameState.decisions` (sin datos nuevos; el marcador sigue siendo `checkpoint = "ending"`).
- **Escena del final:** `EndingController` reproduce un `EndingCinematic` (Fase 15i: guion de beats sobre una escena dibujada por código y el rostro del abuelo; ver la sección de la Fase 15i) y después muestra la tarjeta de resumen. Mantener Enter 1,2 s la salta.
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

## 21. Arreglos del jefe 2, nenúfares elevados y color de la onda (Fase 15d-bis)

- **Patrones de reserva:** `BossPattern.fallback_priority` (0 = rotación normal; 1, 2, 3... = reserva, nunca al azar) y `BossStats.max_idle_time`. `BossBase._update_idle` pide un patrón de la rotación; si no hay, `_choose_fallback(false)` (el de menor número que pueda empezar) y, pasado `max_idle_time`, `_choose_fallback(true)` (ignora recargas). En `boss_two.tscn`: `FallbackVolley` (1: `ProjectileVolleyPattern` con `allow_steep_aim`), `FallbackLeap` (2: `LeapPattern` con `target_mode = NEAREST_TO_PLAYER`) y `FallbackStomp` (3: `LeapPattern` con `target_mode = FLOOR`, `skip_perch`, sin recarga). Para dar la misma garantía a otro jefe: poner `max_idle_time` en sus estadísticas y añadir sus nodos de reserva.
- **Embestida con carril:** `ChargePattern.min_useful_lane` (220 px), `lane_available(boss, dirección)` (rayos contra la capa del mundo) y `planned_lane` (lo que dibuja el telegrafiado). Para que un patrón con trayecto no se desperdicie, hacer lo mismo: medir antes de `can_start`.
- **Nenúfar elevado:** `BounceConfig.pad_height` (56), `trigger_size` (72×40), `top_margin` (6), `launch_velocity` (−930). La posición del nodo es el centro del área de disparo: `y = suelo − pad_height + (trigger_size.y / 2 − top_margin)`; `BouncePad.top_y()` y `floor_y()` dan la cima y el suelo. El tallo (`BouncePadArt`) no tiene colisión; `compression` (−0,45 a 1) lo lee la prueba. Colocar un nenúfar nuevo: instanciar `bounce_pad.tscn` con el nodo a `y = suelo − 42` para un suelo de 56 px.
- **Onda por nivel:** cada `SwordWaveTier` tiene `tint`, `rim_color`, `core_color`, `glow_color`, `glow_strength` y `trail_length` (en `default_sword_wave_config.tres`); `ProjectileStats` los copia y `WaveGlow` (dos nodos `GlowBehind` / `RimFront` de `sword_wave_projectile.tscn`) los dibuja; `WaveBurst` es el destello del impacto. `AbilityCard.present(..., swatch)` recibe el nivel para enseñar el color.
- **Pruebas:** `phase15d2_smoke_test` (mide el barrido de inactividad, el margen de refugio, los números del nenúfar y el contraste de la onda).

## 22. Jefe 3: El Ojo de la Tormenta (Fase 15e-1)

- El jefe 3 tiene 70 de vida y tres fases: ojo flotante (1), Kenzo con guardia en el suelo (2) y ojo con la tormenta a tope (3). Líneas al 66,7 % y 33,3 %.
- **Añadir fases a un jefe:** rellena `phase_thresholds` en su `BossStats` (lista de ratios en orden descendente; vacía = `[phase_2_health_ratio]`, así los jefes 1 y 2 no cambian). `BossBase` cruza cada línea una vez: cancela el patrón, entra en transición, emite `phase_transition_started(n)` y luego `phase_changed(n)`. Los números de la fase 3 son `phase_3_speed_multiplier`, `phase_3_pattern_gap_multiplier` y `phase_3_cooldown_factor` (solo recorta enfriamientos, nunca telegraphs: `scale_telegraph_with_speed = false` en los patrones de tormenta). La barra de vida dibuja una marca por línea. La posesión corre en cada cruce (override propio en `default_possession_config.tres`).
- Piezas nuevas: `BossHover` (vuelo, picados y `max_unhittable_time`), `BossShield` (bloquea `light`/`wave`, se rompe con `heavy`/`dash_slash` tras `guard_break_hits`, aturdimiento, regeneración; engancha a `Hurtbox.hit_filter`), `BeamSweepPattern`, `LightningColumnsPattern` (siempre un carril seguro), `StompPattern`, `StormFx` y `ShieldFx` (dibujo por código). `DamageInfo.attack_kind` / `Hitbox.attack_kind` identifican el tipo de golpe.
- Prueba: `phase15e1_smoke_test`.

## 23. Huecos del nivel 3 con doble salto (Fase 15e-2)

- **Cómo diseñar un hueco desde la tabla de alcance** (alcance efectivo = recorrido del centro con la mejor sincronía + 58 px de margen de las reglas reales: 14 de saliente al despegar, 30 de coyote, 14 de solape al aterrizar; `phase15e2_smoke_test` los calcula de las estadísticas reales):
  - salto 264, salto + doble salto 440, salto + dash 432, salto + doble salto + dash 609.
  - Para exigir el dash además del doble salto: ancho > 440 y <= 88 % de 609 (536). Como mucho un tercio de los huecos por encima del 85 % (518).
  - Tras cada hueco, un suelo de aterrizaje de al menos 200 px más 120 px de enfriamiento del dash (los suelos del nivel 3 miden >= 1025 px).
- Huecos actuales (antes -> ahora): 285 -> 485, 175 -> 460, 285 -> 525; todos necesitan doble salto + dash. Todo lo posterior se desplazó 200, 485 y 725 px; los checkpoints siguen sobre el suelo previo a cada hueco.
- Cambiar un ancho: mueve el suelo siguiente y todo lo que cuelga de él (plataformas, checkpoints, enemigos, puerta, muro, encuentro, jefe), la zona de bioma (centro del hueco), `camera_limits`, la zona de muerte y los límites `fallback_left/right` de los patrones de tormenta del jefe 3.
- Los bots de prueba (`bot_phase13_soak_test`, `balance_measure`) cruzan huecos con salto, doble salto a ~0,6 s (mantenido ~20 fotogramas) y dash a ~1,15 s.

## 24. Reequilibrio de los huecos del nivel 3 (Fase 15e-2b, sustituye a los valores de la sección 23)

- Reglas: un hueco que exige la cadena completa (salto + doble salto + dash) mide como máximo el 88 % del recorrido del centro (550,8 px, es decir 484 px). Un hueco fácil se cruza con salto + doble salto y no exige el dash (máximo 88 % del alcance efectivo de 440 px). Ritmo: fácil, medio, difícil.
- Huecos (antes -> ahora): 285 -> 380 (salto + doble salto, dash opcional), 175 -> 450 (las tres acciones), 285 -> 484 (las tres acciones).
- Desplazamientos respecto al nivel original: suelo B +95, C +370 y D +569 px (antes de este ajuste: +200, +485 y +725). Los límites `fallback_left/right` del jefe 3 son 5699 y 6709.

### Ajuste 15e-2c

Hueco 1: 380 -> 336 px (88 % de 382,2; más ancho que los 264 px del salto solo; el dash sigue opcional). Todo lo posterior se desplazó otros -44 px: suelo B +51, C +326 y D +525 respecto al nivel original. `fallback_left/right` del jefe 3: 5655 y 6665. La tabla vigente es: 285 -> 336, 175 -> 450, 285 -> 484.

## 25. Director de IA local (Fase 16a)

- **Arquitectura** (`game/backend/ai/director/`): `RunTelemetry` (cuentas en memoria por nivel) lo alimenta `TelemetryObserver` (nodo que `LevelBase` crea en `_ready`, solo escucha señales existentes) y lo guarda `Director`, un campo de `GameState` (`GameState.director`; no es autoload y no se guarda). `Director.plan_for_level(n)` devuelve el plan del nivel n a partir de la telemetría del nivel n-1: `RunTelemetry.summarize` (solo low/mid/high) -> `DirectorThemes.select` (tema) -> `LocalDirectorPlanner.plan` -> `DirectorPlanValidator` (la única puerta de planes). El plan se cachea por nivel (un reintento lo reutiliza) y se aplica una sola vez en `LevelBase._apply_adaptive`.
- **Qué aplica:** enemigos extra = clamp(extras del perfil + `extras_delta`, 0, 3) con los grupos `variant_groups` existentes (más extras = huecos de los otros grupos que estén a >= 150 px de los bordes de hueco) y `BossBase.apply_pattern_weights` (solo `weight` de los patrones de rotación). Nunca perfil, vida, daño, telegraphs, agresión ni enfriamientos.
- **Añadir un tema:** añade el nombre a `themes` de `default_telemetry_config.tres` y un `ThemeRule` (`theme` + `conditions`: métrica -> categorías) en `theme_rules`, antes de las reglas más generales (gana la primera que cumple).
- **Añadir un parámetro acotado al plan:** (1) campo en `DirectorPlan` y su clave en `DirectorPlan.KEYS`; (2) tope en `TelemetryConfig`; (3) limpieza en `DirectorPlanValidator`; (4) valor en `LocalDirectorPlanner`; (5) aplicación en `LevelBase._apply_adaptive`; (6) pruebas en `phase16a_smoke_test`. Si el parámetro no debe poder tocarse nunca (perfil, HP, daño...), añade su nombre a `forbidden_keys`.
- **Modo de plan fijo (solo compilaciones de depuración):** `GameState.director.set_forced_plan({...})`, `set_force_neutral(true)`, o las variables de entorno `QUACKTACLYSM_DIRECTOR_PLAN` (JSON) y `QUACKTACLYSM_DIRECTOR_NEUTRAL`. En una exportación de lanzamiento se rechazan. En depuración cada carga de nivel imprime en el log `[Director] level N plan: ...`.

## 26. Director de IA remoto (Fase 16b)

- **Flujo:** tras la decisión de un fragmento (`DecisionFlow`, justo después de la llamada narrativa existente) `GameState.get_director_client().request_plan(nivel)` pide el plan del SIGUIENTE nivel. `DirectorClient` (nodo hijo de `GameState`, no autoload, así la petición sobrevive al cambio de escena) arma la petición con la telemetría categórica, el tema y el plan local como base (`build_payload`) y usa `AiClient.request_director` (presupuesto de 3 s, `director_timeout_seconds` en `default_ai_service_config.tres`). La respuesta pasa por `DirectorPlanValidator` y, si el servicio dice `source = "openai"`, se guarda en memoria en `GameState.director` (`set_remote_plan`, por nivel). `LevelBase._apply_adaptive` -> `Director.plan_for_level` usa: plan forzado de depuración > plan en caché > plan remoto listo > plan local. Nunca espera a la red: una respuesta tardía (el nivel ya cargó), un fallo, un tiempo agotado, un plan inválido, la opción apagada o un servicio en modo mock/fallback acaban con el plan local y sin error visible. Una respuesta de otra partida (`Director.run_id`) se descarta.
- **Servicio:** `ai-service/app/director.py` (topes y saneado), `ratelimit.py`, `schemas.py` (`DirectorRequest`/`DirectorResponse`), `openai_client.py` (`plan`: salida estructurada estricta, `store=False`, 2,5 s y sin reintento) y `main.py` (`/v1/director/plan`). Cualquier fallo responde 200 con el plan base y `source = "fallback"`; sin clave, `mock` devuelve el plan base. El servicio vuelve a recortar la salida del modelo y, si el jugador tiene dificultades (muertes o daño altos), solo permite ayudar (sin extras ni patrones más pesados).
- **Opción del jugador:** «Adaptación con IA» (`ai_adaptation` en `settings.cfg`, texto en `default_profile_presentation.tres`), en el menú principal y en el de pausa.
- **Fase 16c** añadirá UNA línea de texto opcional: el campo irá en `DirectorResponse` y en el validador; ahora la respuesta no tiene texto libre.

## 27. La parte visible del Director (Fase 16c)

- **Línea del abuelo:** `GrandfatherVoice` (hijo de cada nivel numerado, lo crea `LevelBase`) espera a que acaben el título y la introducción (`LevelBase.intro_finished`) y, en el nivel 3, la escena del abuelo (`ElderScene.scene_finished`); entonces encola un paso `grandfather_line` en la `PresentationQueue`. Nivel 1: un recuerdo del banco; niveles 2 y 3: la línea remota válida si el plan de ese nivel es el remoto, si no una línea del banco para el tema del plan (determinista: tema, nivel y decisiones guardadas; no repite una línea ya mostrada en la sesión). Una vez por nivel y sesión; nunca en pelea, nunca en el checkpoint de arena, se cierra al empezar el encuentro o al morir, se salta con Enter y no bloquea al jugador. Los textos de presentación y todos los números están en `default_grandfather_presentation.tres`.
- **Reflejo:** `GrandfatherReflection` (capa -5, entre el cielo y el campo de juego), silueta de estrellas sin cara: borrosa en los niveles 1 y 2, nítida en el 3 (`sharp_levels`). Con «Efectos de corrupción» apagado, solo un desvanecimiento.
- **Validador de líneas:** `GrandfatherLineValidator` (cliente) y `validate_line` en `ai-service/app/director.py` aplican las mismas reglas; la lista de palabras prohibidas vive en `default_grandfather_lines.tres` (y se refleja en Python: cámbiala en los dos sitios).
- **Añadir una línea al banco:** añade el texto a la lista del tema en `default_grandfather_lines.tres`; `phase16c_smoke_test` comprueba que pasa el validador. **Añadir un tema:** además de lo de la sección 25, una lista de >= 3 líneas con ese nombre en `themes`. **Añadir una variante de epílogo:** una entrada más en `epilogues` de cada `EndingStory` y subir `epilogue_max`.
- **Epílogos:** 3 textos por final (`EndingStory.epilogues`) que se muestran en la tarjeta final. La variante sale del plan del «nivel 4» (el final): `Director.epilogue_variant()`; se precarga al decidir el fragmento del nivel 3 (`next_level = 4`, sin ids de patrones). El final que suena no cambia: lo decide solo `souls_released`.

## 28. Capa de armadura de Kenzo e historias de los guardianes (Fase 15f)

- **Editar la guardia:** `guard_break_hits` (ahora 1), `stagger_time` (2,5 s) y `regen_delay` (3,0 s) son exportaciones del nodo `Guard` de `boss_three.tscn`. El dibujo de la capa vive en `frontend/fx/shield_fx.gd` (placas y capa, geometría en `PLATES`) y todos sus colores y tiempos en `frontend/fx/default_guard_shell.tres` (`GuardShellStyle`): estados intacta, agrietada al bloquear, rota (fragmentos y cuerpo brillante) y regenerándose (las placas vuelven una a una). Con «Efectos de corrupción» apagado no hay partículas ni brillo pulsante, solo un cambio con desvanecimiento corto. La pista de una vez por pelea y el texto «ATURDIDO» están en `StoryTexts` (`guard_hint`, `guard_stagger_text`).
- **Añadir líneas a la introducción de un guardián:** edita `pre_lines` de su `BossStory` en `default_story_texts.tres` (3 a 5 líneas, máximo unas 140 letras cada una; la línea extra del perfil se añade después) y `duck_lines` para el monólogo del pato. Todas las líneas de la introducción avanzan solo con la acción de confirmar (`ui_accept`, respeta la reasignación): el primer toque completa la línea que se escribe y el siguiente pasa a la siguiente; mantener la acción `intro_skip_hold_seconds` salta toda la introducción. Los textos del indicador («Enter ▸») y de la ayuda están en `StoryTexts`. Ninguna línea de la introducción avanza por tiempo; el paso de la cola tiene un tope de seguridad de `intro_step_timeout` (2 horas).

## 29. Escenario interactivo del nivel 3 (Fase 15g)

> **Fase 15o:** las corrientes de aire (`WindVent`) y la ruta alta se quitaron; lo que sigue sobre ellas es historia. Quedan las placas eléctricas y el decorado.

- **Piezas** (misma arquitectura que los nenúfares y los pinchos): lógica en `backend/arena` (`WindVent`, `ElectricPlate`), dibujo por código en `frontend/arena` (`WindVentArt`, `ElectricPlateArt`, `StormDecor`) y todos los números en recursos exportados: `default_wind_vent_config.tres`, `arena_wind_vent_config.tres` (columna más baja para la arena), `default_electric_plate_config.tres` y `default_storm_decor_config.tres`. Los recursos de nenúfares y pinchos no se tocaron.
- **Corriente de aire:** un Area2D que, mientras está ACTIVA y el jugador está dentro, llama a `Player.apply_updraft` (sube a 380 px/s como máximo; un salto más rápido no se frena). Ciclo aviso 1,0 s / activa 3,5 s / reposo 2,5 s. Altura de la columna 250 px: los pies llegan a 250 + 40 (inercia) = 290 px, así que una plataforma a 240 px se alcanza con 50 px de margen. Enemigos y jefes la ignoran. Con `boss` asignado (arena) solo corre durante la pelea y se detiene durante la posesión.
- **Placa eléctrica:** banda de suelo con aviso 1,2 s / activa 2,0 s / reposo 3,0 s, 1 corazón, el dash es inmune; no es una zona de muerte.
- **Añadir una corriente, una placa o una ruta alta** (nodos de `Content` en `level_3.tscn`): instancia `wind_vent.tscn` (posición = centro de la corriente sobre el suelo) o `electric_plate.tscn` (posición = extremo izquierdo, `length` 220 a 320), y para la ruta una plataforma de un solo sentido a unos 240 px sobre el suelo junto a la columna (no encima).
- **Reglas de colocación** (las comprueba `phase15g_smoke_test`): corrientes a 300 px o más de cualquier borde de hueco; placas a 350 px o más de los bordes de hueco y de los puntos de reaparición; ningún enemigo de suelo a menos de 150 px de una placa ni a menos de 100 px del centro de una corriente; plataformas elevadas a 350 px o más de los bordes de hueco; nada en el suelo de la arena salvo corrientes; los huecos, los puntos de control y los suelos de la Fase 15e-2 no cambian.
- **Decorado reactivo:** `StormDecor` (3 capas de dibujo): charcos que salpican, lámparas que parpadean (máximo 2,5 veces por segundo, nunca por encima de 0,3), cadenas que se balancean y torres rotas de fondo; tope de partículas y de nodos en el recurso. Con «Efectos de corrupción» apagado todo queda estático.

## Fase 15h: los dos finales

- `EndingSelector.ending_id_for(released, kept)`: `kept > released` → `ending_kept`; si no → `ending_released`. Los textos, los títulos, los 6 epílogos, la línea de apoyo (`EndingStory.support_line`), el aviso de contenido y las listas de términos prohibidos están en `default_story_texts.tres`.
- Las líneas avanzan solo con confirmar (máquina de escribir, aviso «Enter ▸», mantener 1,2 s salta, pausable); desde la Fase 15i lo hace `EndingCinematic`.
- Prueba: `phase15h_smoke_test`.

## Fase 15h-bis: huecos del nivel 3

- **Causa del hueco «imposible»:** un enemigo rápido (`Fast3`, a 300 px del primer borde) perseguía al jugador hasta el mismo borde (los enemigos giran en el borde, no antes), lo golpeaba y el retroceso lo lanzaba al foso. En una medición con el nivel real y el jugador parado en el borde, el jugador recibió dos golpes y cayó en menos de 5 s. La estructura oscura de la captura es escenografía (terreno, fondo, decorado de la tormenta): ningún nodo con colisión hay dentro de ningún hueco.
- **Regla de tolerancia** (`GapSafetyConfig`, `default_gap_safety_config.tres`): hueco 1 ≥ 0,15 s de ventana en la segunda acción y ≥ 20 px de ventana de despegue (salto + doble salto y salto + dash); hueco 2 ≥ 0,10 s y hueco 3 ≥ 0,06 s con la cadena de tres acciones; el hueco 1 nunca baja de 290 px. Si un hueco no la cumple, se estrecha al mayor ancho que sí la cumple y se desplaza todo lo que viene después como en las Fases 15e-2b/2c.
- **Cómo medir un hueco con el jugador real:** `phase15h2_smoke_test` construye dos suelos con el hueco, hace correr al `Player` real y barre el fotograma de la segunda y la tercera acción (pasos de 1 fotograma = 16,7 ms) y la posición de despegue (de -30 a +14 px, pasos de 3). La ventana es la racha más larga de éxitos consecutivos. El reloj va acelerado (`Engine.time_scale`), la parte lenta es la física, y hay un presupuesto de 290 s.
- **Enemigos y bordes:** `GapGuard` (nodo del nivel) da a cada enemigo de suelo `EnemyBase.set_edge_keepout(250)`: su sonda de borde mira 250 px más lejos y se detiene antes. Ningún enemigo se coloca a menos de 250 px de un borde (movidos `Fast1` 2601→2481, `Fast2` 3376→3476 y `Melee2` 4076→3951).
- **Ayuda:** `RunTelemetry.gap_falls` cuenta en memoria las caídas por hueco (se vacía con `reset()`: partida nueva y partida cargada) y no es una métrica; a la cuarta caída `GapGuard` añade `AssistWreckN` (una plataforma de una vía de 140 px, a la altura del suelo, centrada en el hueco).
- **Doble salto:** se desbloquea con `GameState.decisions.size() >= 2` (`PlayerStats.double_jump_unlock_decisions`); las decisiones se guardan, así que cargar, continuar o reaparecer lo conservan. Con menos de 2 decisiones no está (por diseño): el hueco 1 se cruza con salto + dash y la ayuda cubre los demás.

## Fase 15i: finales cinematográficos

- **Cómo se construye una escena de historia:** un `EndingBeatList` (recurso) con `EndingBeat`s en orden. Cada beat fija la cámara (foco y zoom al empezar y al acabar), la pose del pato y cuánto avanza, la respiración, las venas, el color, la luz, el viento, la expresión y la posición del retrato del abuelo, un sonido puntual y uno repetido (con su ritmo y tono), cuánto se apaga la música y el fundido. Un beat con `line >= 0` muestra esa línea del final y espera la confirmación; los demás duran `seconds`. Para añadir un final nuevo basta una lista nueva y el campo `beats` de su `EndingStory`.
- **Piezas:** `EndingCinematic` (reproductor, UI, sonido, saltar), `EndingScene` (cinco capas con paralaje, el pato con tres piezas del rig, venas, sombras), `GrandfatherPortrait` (el rostro). `EndingController` solo elige el final y construye el reproductor. `StoryReel` vuelve a servir solo a la escena del abuelo antes del jefe 3.
- **Calibración del rig:** el pato mide unas 50 unidades (los pies en 0, el centro de la cabeza en (5, -36)); las coordenadas de las venas están en ese sistema.
- `AudioDirector.play_event` admite un factor de tono (el latido se ralentiza bajando el tono).
- Prueba: `phase15i_smoke_test`.

## Fase 15j: el jefe 3 de invocador

- **Piezas:** `BossStage` (nodo del nivel junto al jefe: plataformas y percha, suelo, vacío, patitos, escudo, andanada y ojo; `cancel_all` deja la arena en orden desde cualquier momento), `SummonerCyclePattern` (la fase 2 entera como UN patrón con pasos: `rise`, `to_perch`, `summon`, `wait_kills`, `tremble`, `leap_up`, `collapse`, `barrage`, `shimmer`, `land`, `window`, `back_to_perch`, `done`), `PlatformBarrage`, `StormEye`, `Duckling`, `StageMath` (funciones puras con los números reales del jugador), `StageConfig` (todos los números) y `BossStageFx` (todo el dibujo). `BossShield` ganó el escudo (`shield_up`) y la coraza solo existe en la fase 1.
- **Cómo añadir una mecánica a un jefe:** 1) un paso nuevo en el patrón (o un patrón nuevo con `excluded_phases` para las fases donde no corre); 2) lo físico en el escenario (`BossStage`) con su limpieza en `cancel_all`; 3) los números en `StageConfig`; 4) el dibujo en un `Fx` que solo lee; 5) una prueba que barra los márgenes con los números reales de `PlayerStats`.
- **Plataformas:** cuatro, de 62 a 248 px sobre el suelo en pasos de 62 px (un solo salto: el salto sube 106,8 px, el doble 183,9), con la percha del jefe a 310 px en una capa de colisión solo del jefe (`CombatLayers.LAYER_BOSS_PERCH`). Se crean al primer uso, nunca están en la escena del nivel, y el suelo de la arena se cambia por dos partes solo durante el derrumbe.
- **Andanada:** `StageMath.barrage_plan` reparte 5 carriles (nunca el mismo ni vecinos seguidos, lados alternos); una plataforma vecina siempre es segura y el peor caso para llegar a ella deja ≥ 0,3 s del aviso (se mide en la prueba con los números reales).
- **Si se cruza un umbral:** `BossStage._on_transition_started` llama a `cancel_all(false)` antes de la posesión; en la fase 3 las plataformas se hunden y aparece el ojo (`StormEye`).
- Sustituye a las secciones del jefe 3 de la Fase 15e-1 (ojo flotante, haz, columnas) y a las vigas de viento de la arena (la clase `WindVent` y las del pasillo no cambian).

## Fase 15i-bis: cómo sustituir la música y los graznidos por archivos reales

- **Graznidos:** en `game/frontend/audio/default_audio_events.tres`, los eventos `duck_cry_weak`, `duck_cry_pain`, `duck_cry_resist` y `duck_cry_lonely`: cambia su `files` por un archivo real de `frontend/audio/sfx` (y ajusta tono y volumen). No hay que tocar código. Mantén cada uno al menos 3 dB por debajo de los avisos de ataque (la prueba `phase14f` lo mide).
- **Música:** los recursos `ending_kept_music` y `ending_released_music` (clase `EndingMusicSlot`) de la misma tabla: `file` (en `frontend/audio/music`), `track_pitch`, `cutoff_hz` (20000 = sin filtro), `reverb_wet` y `base_duck_db`. Con una pista real basta con dejar el procesado neutro (tono 1, 20000 Hz, reverb 0).
- **Cómo suena:** `EndingCinematic` empieza la pista con `AudioDirector.play_music`, le pone el perfil (`set_music_profile`) y una reverberación en el bus de música, la atenúa beat a beat (`music_db`) y lo devuelve todo al saltar, pausar o salir.
- **Un beat sin sonido:** `EndingBeat.voiced = false` quita el soplido de voz del abuelo; `fade_white` hace el fundido blanco del corte.

## Fase 15k: sangre en el combate

- **Dónde está:** `frontend/fx/blood_fx.gd` (nodo `BloodFx`, hijo de `level_base.tscn`, capa z -2: debajo de los avisos (z -1), peligros, placas y plataformas de jefe (z 2) y la interfaz) y `frontend/fx/blood_config.gd` + `default_blood_config.tres` (cantidades, topes, tiempo de la mancha, opacidad, colores). Solo escucha señales: `Hurtbox.hit_received`, `EnemyBase.died`, `BossBase.defeated` y `Player.died/respawned`. Nunca cambia el daño ni las colisiones.
- **Regla:** un golpe que **aterriza** (`applied = true`) salpica; uno bloqueado o esquivado (armadura con `hit_filter`, guardia, burbuja de escudo, invulnerabilidad del dash) no; la muerte hace una ráfaga; el duckling usa `duckling_scale`; el modo reducido usa `reduced_scale`.
- **Añadir sangre a un tipo de enemigo nuevo:** si el enemigo es un `EnemyBase` con `Hurtbox`, ya sangra sin hacer nada. Si es un ser sin vida (espíritu, caparazón), ponle `set_meta(&"no_blood", true)` en su `_ready` y solo dará chispas. Para un tipo con menos sangre, añade su cantidad al `config` y úsala en `BloodFx.scale_for`.
- **Opción «Sangre»:** clave `blood` de `GameSettings` (por defecto `true`); el texto sale de `blood_toggle_text` en `default_profile_presentation.tres`. `BloodFx` relee los ajustes cada medio segundo; al apagarla se vacía todo.
- **Sprite propio:** hoy todo se dibuja con `draw_*`; si se quiere arte, basta con sustituir `_draw` por texturas exportadas.

## Fase 15l: CorruptionVeins, absorción oscura y el final sin trabones

- **CorruptionVeins** (`frontend/fx/corruption_veins.gd` + `corruption_veins_style.gd` + `default_corruption_veins.tres`): venas moradas orgánicas que crecen desde unas raíces del pato y nunca salen de su silueta. Uso: añádelo como hijo del pato (coordenadas del rig, pies en 0), asigna `style` (si está vacío usa el de por defecto), `growth` (0..1), `max_tier` (1..3: cuántos fragmentos conservados), `region` (cuerpo, cabeza o todo; para una cabeza que se inclina, un segundo nodo dentro del soporte de la cabeza con `origin` = el cuello), `reduced` (estático y más fino, sin pulso) y `strength`. Solo se redibuja cuando cambia el crecimiento; el pulso solo cambia la opacidad. `visible_points()` devuelve los puntos para comprobar la silueta. Todos los números (raíces, ramas, anchos, colores, pulso, silueta) están en el recurso de estilo.
- **Ojo nublado:** `CorruptionVeins.draw_clouded_eye(canvas, centro, radio, nube, pulso)`.
- **En el juego:** `PlayerCorruptionView` (nodo `Visual/CorruptionView` de `player.tscn`) lee `GameState.souls_kept` (ya está en la partida: ninguna clave nueva), no tiene colisiones y se oculta con 0 fragmentos conservados.
- **Absorción oscura:** `ExorcismCutscene` con los números de `default_absorption_config.tres` (duración 3–4 s, colores, viñeta, convulsión, latido —un evento existente con tono bajo—, atenuación de la música y los límites de fotosensibilidad: el brillo nunca pasa del tope y hay como máximo 3 pulsos por segundo). Esc salta a la tarjeta; la tarjeta empieza después de la secuencia.
- **Finales sin trabones:** `EndingBeatList` lleva ahora los topes de seguridad (`max_beat_seconds`, `max_line_seconds`, `max_total_seconds`), el umbral del vigilante de fotogramas (`slow_frame_ms`, `slow_window_seconds`), la frecuencia de redibujado de las capas (`layer_redraw_hz`) y los presupuestos de las pruebas. Si los fotogramas van lentos la escena pasa a modo ligero (capas estáticas).

## Fase 15m: cómo añadir un paso al tutorial

1. Añade un diccionario a `steps` de `backend/progression/default_tutorial_texts.tres` con `id`, `kind` (la clase de acción que lo completa), `text` (el aviso, con fichas `{accion}` que se sustituyen por la tecla actual), `short` (nombre corto de la lista), `station` (título del cartel) y `required` (si la salida lo espera).
2. Conecta la acción: en `TutorialController._ready` conecta la señal del jugador a `_on_action.bind("tu_kind")` (los pasos son independientes: no hay orden ni contador).
3. Si quieres un cartel en el nivel, añade un nodo con `tutorial_station.gd` y `step_id` a `frontend/levels/tutorial.tscn`.
4. Los números (tiempo de reaparición del muñeco, tiempo de la pulsación larga, distancia de «mover») están en `default_tutorial_config.tres`; las frases del muñeco, por evento, en `dummy_lines` del recurso de textos.
- La lista de tareas y la barra de saltar son `TutorialHud` (`frontend/ui/tutorial_hud.gd`); el controlador solo le pasa el estado.

## Fase 15n

- **Diálogos de guardián:** `BossStory` (`pre_lines`: 1 línea ≤ 80; `duck_lines`: ≤ 1 línea ≤ 80; `defeat_lines`: 2–3 líneas ≤ 120) en `default_story_texts.tres`. `BossDialogue._on_boss_defeated` retiene el fragmento (`SoulFragmentDrop.hold/release`), bloquea al jugador y reproduce las líneas con Enter; `StoryTexts.defeat_dialogue_delay` es la espera tras caer.
- **Fragmentos azules:** `SoulPickup` (estilos `FRAGMENT`, `SMALL`, `WISP`); todos los números (valor del patito, tiempos, velocidad, tope de fragmentos, color) están en `SoulConfig`. Un enemigo nuevo suelta el fragmento por `EnemyBase._release_soul`.
- **Graznidos al golpear:** archivos, tono, volumen y límites en `AudioEvents` (grupo «Cries on hits»); la lógica está en `AudioDirector._hit_cry`.
- **Sonido del prólogo:** `frontend/prologue/default_prologue_audio.tres` (pista, tono, filtro, atenuación y los efectos por plano). Para poner música o efectos reales, cambia `music_file` o el `event` de cada efecto.
- **Rostro en el cielo:** `GrandfatherFace` (usa `GrandfatherPortrait`); opacidades, escala y brillo en `GrandfatherPresentation`. La silueta de estrellas (`GrandfatherReflection`) se eliminó.
- **Sin tarjeta tras el último jefe:** `AbsorptionConfig.no_card_fragments`.

## Fase 15o

- **Absorción al conservar** (`ExorcismCutscene`, números en `default_absorption_config.tres`): fondo casi negro con toques rojos (resplandor en los bordes, brasas que suben, halo rojo), el emblema del guardián abajo (hacha, gota u ojo, dibujado por código) que se enciende y pulsa, el fragmento que se oscurece y tiembla, rayos rojos delgados con ramas (se rehacen `bolt_refresh_hz` veces por segundo, nunca cada fotograma) desde el emblema, el fragmento y los bordes hasta el pecho del pato, partículas y zarcillos, latido y música atenuada. El pato es el propio `DuckRig`: su etapa de corrupción crece durante la secuencia y sus ojos se encienden con el aspecto de posesión del rig. Límites de fotosensibilidad en el recurso (`flare_cap`, `max_flashes_per_second`: el único destello de pantalla completa es el latido). Modo reducido: fundido rojo quieto con el emblema y unos pocos rayos fijos. Tras el jefe 3 no hay tarjeta (`no_card_fragments`).
- **Corrupción dentro del rig:** `DuckRig.corruption_stage` (0..3), `corruption_growth` (0..1, crece la etapa actual), `corruption_reduced`, `corruption_strength`, `head_bow` y `wing_angle` (poses de los finales). `CorruptionMarks` (`frontend/fx/corruption_marks.gd`) crece las ramas desde las raíces de `default_corruption_veins.tres` y las recorta con `Geometry2D` al polígono de cada pieza (túnica, cuello, cabeza) con el margen `clip_margin`; el ojo, la cola, la manga y el ala cambian por etapa dentro de sus propias piezas. `PlayerVisual` copia `GameState.souls_kept` al rig (sin claves nuevas). Ya no existen `CorruptionVeins` ni `PlayerCorruptionView`.
- **Poses de los finales:** `EndingScene` dibuja UN `DuckRig` (`figure`) con un solo halo detrás; la inclinación de cabeza, el ala y la corrupción son parámetros del rig. Las poses son `stand, labored, stagger, kneel, kneel_edge, reach, resist, head_down, walk` (todas de perfil).
- **Imágenes propias (ranura opcional):** `CorruptionSpriteSet` (`frontend/fx/corruption_sprite_set.gd`, instancia `default_corruption_sprites.tres`, vacía por defecto). `stage_textures[1..3]` sustituyen al pato en gameplay por etapa; `pose_textures["kneel"]` (etc.) sustituyen una pose de los finales; la de la pose gana a la de la etapa. Se dibujan con los pies en el origen, mirando a la derecha (`texture_scale`, `feet_anchor`). Con la ranura vacía se usa el dibujo por código. Para ver el resultado: `godot --path game res://frontend/scenes/test/corruption_contact_sheet.tscn` (necesita ventana; guarda `sheet_*.png` en la carpeta de datos del usuario y se cierra solo).
- **Nivel 3 sin corrientes:** se quitaron `VentA`, `VentD` y `UpperRouteD` (la ruta alta solo se alcanzaba con la corriente), y las clases `WindVent`, `WindVentConfig`, `WindVentArt`, su recurso y `Player.apply_updraft`. Huecos (336 / 450 / 484), suelos A–D y puntos de control sin cambios.
- **Jefe 3 sin armadura:** `BossShield` se queda solo con el escudo de la fase de los patitos (`shield_up`, `set_shield`); `ShieldFx` solo dibuja la burbuja del escudo y la etiqueta BLOQUEADO; desaparecen `GuardShellStyle` y su recurso, el aviso de aturdimiento y el de «rompe la capa».

## Fase 15p

- **Tras caer un jefe:** `BossDialogue` bloquea al jugador (`set_input_locked`) y lo hace invulnerable (`story_invulnerable`) mientras dura el diálogo de despedida (se avanza con la confirmación; mantenerla salta) y el fragmento (`SoulFragmentDrop.hold/release`) espera. Todo se devuelve al terminar o saltar el diálogo y también al salir el nodo del árbol; no hay límite de tiempo a propósito (no avanza solo). Después viene la decisión, la absorción o la liberación y, en los niveles 1 y 2, la tarjeta.
- **Vida del jefe 3:** `boss_three_stats.tres` tiene 102 PV con líneas en 0,451 y 0,2255 (fase 1 = 56 PV, fases 2 y 3 = 23 PV cada una). Para cambiar la fase 1 sin tocar las otras: nuevo `max_health = 46 + fase1` y líneas `46 / max_health` y `23 / max_health` (un poco por encima, para que el producto no baje de 46,0 / 23,0).
- **`BossShield`** (antes `BossGuard`; nodo `Shield`) es solo el escudo de la fase de los patitos; `ShieldFx` dibuja su burbuja.

## Fase 15q

- **Regla de física (siempre diferido):** dentro de un callback de física (`body_entered`, `area_entered`, manejadores de golpe, de muerte, de recogida, de generación) NO se cambia `monitoring`, `monitorable`, `disabled` de una forma, capa o máscara de colisión ni se añade un `CollisionObject2D` al árbol: se usa `set_deferred` o `call_deferred`. Caso corregido: `GapGuard._add_assist` (la muerte del jugador llega dentro del `body_entered` de la zona letal) ahora añade la plataforma de ayuda con `call_deferred` (`_attach_assist`); el hueco ya cuenta como ayudado al instante (`assists`).
- **Regla de arreglos con instancias liberadas:** nunca `erase()` ni asignar una instancia LIBERADA a través de un `Array` tipado (da un error de motor en cada llamada). `BossStage.ducklings` se recorre por índice como `Variant`, se guardan solo las válidas y se reconstruye la lista (`_update_ducklings`, `alive_count`, `vanish_ducklings`).
- **Objetivo liberado en los enemigos:** `EnemyBase` recuerda con `_had_target` que tuvo un objetivo y lo suelta en cuanto `is_instance_valid` falla, antes de leer su posición (el jugador se libera con su nivel).
- **Pruebas:** el reloj acelerado de `Engine.time_scale` también multiplica el delta de física; para medir saltos hay que subir a la vez `physics_ticks_per_second` y el factor (ver `phase15h2_smoke_test`: 480 pasos por segundo a factor 8 siguen siendo pasos de 1/60 s). Las pruebas que esperan el fragmento tras un jefe deben saltar las últimas palabras (`BossDialogue.skip()`), porque ahora van antes del fragmento. Toda instancia de prueba (`instantiate`, `.new()` de un `Node`) se libera.

## Fase 15r

- **`GrandfatherSky`** (`frontend/story/grandfather_sky.gd`) sustituye a `GrandfatherPortrait`/`GrandfatherFace` dibujados. Dibuja el `DuckRig` del abuelo (`Look.GRANDFATHER`) en un `SubViewport` pequeño (el reescalado es el desenfoque), lo muestra con un `Sprite2D` y un sombreador (máscara vertical que oculta el cuerpo, desenfoque de 5 muestras), con un resplandor cálido detrás y jirones de niebla encima. API: `alpha` (opacidad final), `set_expression(&"watching" | &"speaking" | &"grieving" | &"breaking" | &"solemn")`, `talking`, `reduced`. Cifras en `default_grandfather_presentation.tres` (`face_memory_alpha` 0,4, `face_solid_alpha` 0,6, `face_ending_alpha` 0,7, `sky_*`). Modo reducido: la imagen se renderiza una vez por cambio. `GrandfatherFace` (inicio de nivel) y `EndingCinematic` lo usan; se borró `grandfather_portrait.gd`.
- **Siluetas** (`EndingSilhouette`, `frontend/story/ending_silhouette.gd`): tres estampas (`kneel_sword`, `lying_sword`, `edge_sky`) dibujadas con el `DuckRig` del héroe y un sombreador plano de un solo color; se dibujan por encima del velo blanco del `EndingCinematic`. Las pide cada `EndingBeat` con `white_silhouette` (+ `_from`/`_to`) y `leave_items` (espada y sombrero en el borde del acantilado, dibujados por `EndingScene._left_items`). Reglas: nada de contacto espada-cuerpo (`SWORD_GAP`), nada de sangre ni de caída, ningún pose de salto.
- **Alma del guardián** (`GuardianSpirit`, `frontend/fx/guardian_spirit.gd`, números en `default_guardian_spirit.tres`): la crea `BossDialogue._spawn_spirit` al caer el jefe, con el `look` y la escala de su `DuckRig`; sin colisiones. Estados `RISING`, `HOLD`, `DISSOLVING`, `DONE`; la señal `dissolved` libera el fragmento. `BossDialogue` etiqueta las líneas con `BossStory.spirit_speaker`; si se salta (`skip`), el alma desaparece y el fragmento sale enseguida. `SoulFragmentDrop.expedite()` quita la espera restante y `SoulFragment.appear()` lo condensa. Una vez por derrota (`spirits_spawned`).
- Imágenes de prueba: `frontend/scenes/test/sky_contact_sheet.tscn` (necesita ventana; guarda `sheet15r_*.png` en la carpeta de datos del usuario).
