# Guía de traspaso (arte y contenido)

Para quien reemplazará los marcadores de posición por arte, audio y contenido definitivo. Todo lo jugable ya funciona con rectángulos de colores; la lógica está probada con pruebas automáticas, pero **nadie ha jugado el juego con ventana** (ver `docs/KNOWN_ISSUES.md`).

## 1. Qué es marcador de posición y qué es definitivo

| Elemento | Estado |
| --- | --- |
| Lógica de movimiento, combate, jefes, decisiones, guardado, perfil adaptativo, servicio de IA | Definitivo (se puede reajustar con datos) |
| Gráficos de jugador, enemigos y jefes | **Dibujados** por código con `DuckRig` (`game/frontend/animations/duck_rig.gd`): patos con tinta gruesa y animación procedural. Al morir se desarman en un ragdoll (`duck_ragdoll.gd`) |
| Escenarios (cielo, capas de parallax, pisos, partículas) | **Dibujados** por código por bioma (`game/frontend/levels/biome/`, `backdrop/`, `terrain/`): pradera (tutorial), bosque (nivel 1), pantano (nivel 2), tormenta (nivel 3) |
| Menú principal y tipografía de títulos | **Dibujados**: escena animada (`menu_stage.gd`), carteles (`sign_button.gd`) y la letra "Pato Tinta" (`game/frontend/ui/type/ink_type.gd`) |
| Gráficos de proyectiles, puertas, HUD, pausa y Game Over | **Marcador** (polígonos, `ColorRect` y fuente por defecto) |
| Animaciones del jugador, enemigos y jefes | Procedurales en `DuckRig` (correr, saltar, dash, tajo, golpe pesado, tajo de dash, onda, zarpazo, embestida, ráfaga, furia de fase 2, daño, muerte con ragdoll). Sprites, audio y música no existen todavía |
| Textos (introducciones de nivel, finales, tutorial, abuelo, menús) | **Marcador** en español, marcados como "texto provisional" |
| Nombres de jefes y fragmentos | **Marcador** (`BossStats.display_name`, `SoulFragmentData`) |
| Geometría de los niveles 1–3 y del tutorial | Maqueta con `PlaceholderPlatform`; las medidas están calculadas con el salto real (ver sección 4) |
| Valores de balance (vida, daño, recargas, velocidades) | Provisionales: nadie ha jugado para ajustarlos |

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
| Orbes de salud (curación, ráfaga, imán, duración) | `game/backend/combat/default_health_orb_stats.tres` (`HealthOrbStats`); cuántos suelta cada enemigo: `health_orb_count` (grupo "Drops") de `EnemyStats`; cada jefe: `health_orbs_on_phase_2` y `health_orbs_on_defeat` de `BossStats` |
| Ragdoll de muerte (duración) | Export `ragdoll_lifetime` de `enemy_visual.gd` y `boss_visual.gd`; el del jugador dura hasta que reaparece |
| Patrones de cada jefe (pesos, tiempos, distancias, ráfagas) | Exports de los nodos bajo `Patterns` en `placeholder_boss.tscn`, `boss_two.tscn`, `boss_three.tscn` |
| Perfiles adaptativos (agresividad, variantes de encuentro/narrativa/final, umbrales) | `game/backend/ai/default_adaptive_config.tres` (`AdaptiveConfig`) |
| Conexión al servicio de IA | `game/backend/ai/default_ai_service_config.tres` (o `QUACKTACLYSM_AI_URL`) |
| Escenas, nuevo juego, orden de niveles y fundidos | `game/backend/progression/default_scene_registry.tres` (`SceneRegistry`) |
| Fragmentos de alma | `game/backend/decisions/data/*.tres` (`SoulFragmentData`) |
| Cada nivel (límites de cámara, fondo, introducciones, variantes, siguiente escena) | Exports de la raíz del nivel (`LevelBase`) |
| Bioma de cada nivel (cielo, capas, colores del suelo, partículas) | `biome` en la raíz del nivel y los recursos `game/frontend/levels/biome/*.tres` (`Biome`) |
| Opciones del jugador (pantalla completa, volumen) | `user://settings.cfg` vía `GameSettings` (`game/frontend/ui/game_settings.gd`); nunca en la partida guardada |
| Textos del final y del menú | Exports de `ending_controller.gd` (en `ending.tscn`) y de `main_menu.gd` / `pause_menu.gd` / `game_over_panel.gd` |

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

- Final: exports `ending_texts` (diccionario `ending_variant → texto`), `fallback_text`, `title_text`, formatos de los contadores en `ending_controller.gd` (nodo raíz de `ending.tscn`). Variantes: `ending_compassionate`, `ending_neutral`, `ending_corrupt`.
- Qué perfil produce cada variante, y las variantes narrativas permitidas por perfil: `default_adaptive_config.tres`. Para añadir una variante narrativa hay que añadirla a `allowed_narrative_variants` y a `intro_lines` de los niveles.

## 7. Audio y skins de interfaz sin tocar la lógica

Conecta señales; no añadas llamadas de audio en los scripts de lógica. Un nodo `AudioStreamPlayer` hijo del personaje o del nivel puede conectarse a las señales de la sección 8 desde un script propio de "presentación". Los menús usan `Control` estándar: aplica un `Theme` en la raíz de cada escena de `game/frontend/ui/` en vez de editar colores en el código.

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

- Solo dos autoloads: `GameState` y `SceneManager`. No añadas otros sin una razón fuerte y documentada.
- La IA **nunca** controla el combate: solo elige perfil y variante narrativa; los números salen de `AdaptiveConfig`.
- El archivo de guardado tiene exactamente siete claves (`save_version`, `current_level`, `checkpoint`, `souls_released`, `souls_kept`, `decisions`, `adaptive_profile`). La onda de espada, el final y demás se derivan de ellas.
- No pongas rutas absolutas ni claves en el repositorio. `.env` nunca se sube.
- Ejecuta `python tools/run_all_tests.py` antes de cada fusión: debe terminar en `OVERALL: PASS`.
- Las pruebas usan rutas `user://test_save_*.json` y el servicio de IA desactivado; no las cambies para tocar el guardado real.

## 10. Primera hora

1. Instala Godot 4.7.x, abre `game/project.godot` y pulsa F5 (menú principal). Pulsa "Nueva partida".
2. Juega el tutorial y el Nivel 1 completos. Anota todo lo que se sienta mal en `docs/KNOWN_ISSUES.md`.
3. En un build de depuración usa `K` (mata al jefe), `H` (10 %), `F2` (teletransporte a la arena) y `F3` (datos) para recorrer los niveles 2 y 3 rápido.
4. Ejecuta `python tools/run_all_tests.py` (necesita `GODOT_BIN` o `--godot`). Debe pasar entero.
5. Lee `docs/CHANGES_FROM_DESIGN.md` y actualiza los documentos de diseño.
6. Empieza por sustituir el `Visual` del jugador; vuelve a ejecutar las pruebas.
