# Problemas conocidos y puntos sin verificar

Lista honesta a fecha de la Fase 14g. **Nadie ha jugado el juego con ventana**: todo lo "sin verificar" son cosas que las pruebas automáticas no pueden juzgar (sensación, legibilidad, dificultad). Cada punto lleva gravedad (Alta / Media / Baja / Info) y una sugerencia.

## Sin verificar jugando

| # | Punto | Gravedad | Sugerencia |
| --- | --- | --- | --- |
| 1 | Sensación del movimiento, salto, dash, ataque de espada y onda; legibilidad de los avisos de ataque de enemigos y jefes | Alta | Una sesión de juego completa; anotar y ajustar los recursos (`PlayerStats`, `EnemyStats`, `BossStats`, patrones) |
| 2 | Dificultad y balance: vida de jefes (40/60/80), densidad de enemigos, recargas de la onda, daño | Alta | Jugar los tres niveles con los tres perfiles (liberar todo, conservar todo, mixto) |
| 3 | Cámara: límites por nivel, comportamiento cerca de huecos y de la arena | Media | Revisar en cada nivel; ajustar `camera_limits` |
| 4 | Legibilidad de los textos (tutorial, introducciones, finales) y del indicador de recarga de la onda | Media | Revisar tamaños y contraste al sustituir el arte |
| 5 | Fundidos entre escenas (0,35 s) y transición pausa/Game Over | Baja | Ajustar `fade_*_time` en `default_scene_registry.tres` |
| 6 | Teclas de depuración (F4, H, F2, F3) probadas con eventos sintéticos, no con teclado real | Baja | Probar a mano en un build de depuración |

## Limitaciones conocidas del código

| # | Punto | Gravedad | Sugerencia |
| --- | --- | --- | --- |
| 7 | ~~El texto del tutorial para la onda tenía "clic derecho" escrito a mano~~ **Resuelto en la Fase 14b-2:** la pista se construye con las asignaciones actuales del InputMap | Resuelto | Ninguna |
| 8 | Los huecos de dash miden 285 px: solo ≈ 7 px más que el límite de un salto simple pegado al borde con coyote time (278 px). Cruzar con dash funciona con cualquier retraso probado (0,2–0,5 s), pero el margen es estrecho | Media | Jugar los huecos; si resultan injustos, pasar a ≈ 295 px o ensanchar la plataforma de llegada |
| 9 | `ai_phase10_integration_test` necesita un servicio real y la variable `QUACKTACLYSM_IT_EXPECT`; no entra en `tools/run_all_tests.py` | Info | Ejecutarlo con `ai-service/scripts/integration_mock.py` |
| 10 | El jugador solo se bloquea (`set_input_locked`) desde `LevelBase` durante transiciones; no hay un bloqueo global (por ejemplo, para futuras cinemáticas) | Baja | Si hacen falta cinemáticas, centralizar el bloqueo en un solo servicio |
| 11 | El autoguardado se suspende dentro del tutorial y dentro de un nivel abierto con la partida ya completada. Si el proceso se cierra de golpe en ese nivel, el indicador se pierde con el proceso (no queda nada en disco) | Baja | Aceptable; si se quiere, guardar al salir del tutorial en vez de suspender |
| 12 | `BossEncounter` exige que el centro del cuerpo esté dentro del disparador; el combate empieza unos píxeles más tarde que al tocar el borde | Baja | Aceptable (evita reactivar al jefe tras reaparecer) |
| 13 | La perforación de la onda solo cuenta golpes aplicados: una onda pasa de largo por un objetivo invulnerable sin gastar perforación | Baja | Decisión de diseño; cambiarlo en `projectile.gd` si se quiere lo contrario |
| 14 | La regla por defecto de mejora de la onda es "conservar" (`kept`) los fragmentos de los niveles 1 y 2; el del Nivel 3 no influye | Info | Cambiar `upgrade_rules` en `default_sword_wave_config.tres` |
| 15 | Tras completar el juego, "Continuar" solo reabre el final; para rejugar hay que usar "Nueva partida" | Info | Añadir selección de nivel si se quiere |
| 16 | Los tests con aserciones de tiempo real (p. ej. `level_phase12a_smoke_test`) no admiten `--fixed-fps`; solo el bot de resistencia y la prueba de fugas lo usan (el ejecutor lo pasa solo a ellos) | Info | No añadir `--fixed-fps` a todo el lote |
| 17 | Algunas pruebas imprimen `WARNING:` a propósito (escenas rechazadas, rutas inválidas). Cargar escenas normales no produce ninguno | Info | Ninguna |
| 18 | No existe un icono ni metadatos de ejecutable (`application/modify_resources=false` para no depender de `rcedit`) | Baja | Activarlo e indicar el icono cuando haya arte |
| 19 | ~~El ejecutable de Windows no se había podido generar~~ **Resuelto en la Fase 14g:** se exportó la build de lanzamiento (≈ 120 MB, `game/builds/`, ignorada por Git) y se ejecutó ≈ 20 s en headless sin errores de script ni de recursos; el paquete no contiene `ai-service/`, ni claves, ni las pruebas ni las escenas de vista previa. Las teclas de depuración no existen en esa build (`LevelDebug` se elimina fuera de depuración). El juego exportado sigue sin probarse en una ventana real | Resuelto | Seguir `docs/QA_CHECKLIST.md` con el `.exe` |
| 20 | ~~Conflicto de teclas en builds de depuración (K era dash y matar al jefe)~~ **Resuelto en la Fase 14b:** matar al jefe pasó a `F4` en los niveles y en `boss_test` (`enemy_test` conserva `K`) | Resuelto | Ninguna |
| 21 | **Riesgo de balance (Fase 13c):** jugador más fuerte (8 corazones, golpe pesado de 3 de daño, tajo de dash) frente a daño por contacto; la vida de los jefes (40/60/80) no se tocó. El tiempo de combate con jefes baja y el contacto sube la dificultad: ambos efectos sin probar jugando | Media (medido con bots en la Fase 14g: ver `docs/BALANCE_REPORT.md`) | Jugar los tres jefes; ajustar `contact_damage`, `heavy_*` y `dash_slash_*` | 
| 22 | ~~Los textos del tutorial para el golpe pesado y el tajo de dash asumían una tecla por acción~~ **Resuelto en la Fase 14b-2:** muestran las dos asignaciones actuales, ratón incluido | Resuelto | Ninguna |
| 23 | El tajo de dash convierte en tajo un ataque pulsado hasta 0,1 s antes del dash; un ataque pulsado durante la recuperación extra se guarda en el búfer y se ejecuta al terminar | Info | Ajustar `dash_slash_input_buffer_time` |
| 24 | ~~**Orbes de salud sin equilibrar ni medir**~~ **Sustituido en la Fase 15a:** ya no hay orbes; la curación sale del medidor de alma (ver #63-#67) | Resuelto | Ninguna |
| 25 | **Sonidos de `AudioDirector` sin verificar en una ventana real:** es silencioso en headless, así que ningún test oye nada; solo se comprueba el cableado de señales. Los sonidos de Liberar, Conservar y de la fase 2 del jefe reutilizan archivos existentes | Media | Escucharlos jugando y sustituir los archivos (`DECISION_SFX`, `PHASE_TWO_SFX`) |
| 26 | **Margen de los huecos de dash (285 px):** solo unos 7 px más que el límite de un salto simple pegado al borde (278 px). Ver también el punto 8 | Media | Jugar los huecos; subir a unos 295 px si resultan injustos |
| 27 | **Balance de la Fase 14b sin probar jugando:** hasta 11 corazones (+3) y un umbral de 1,0 (el perfil cambia con cada decisión: un nivel 3 corrupto llega ahora con solo dos fragmentos conservados) (la Fase 14g midió que los 3 corazones extra reducen mucho las muertes del bot, ver `docs/BALANCE_REPORT.md`) | Alta | Jugar las 8 combinaciones de decisiones |
| 28 | ~~El final neutral ya no se alcanza con tres decisiones y el texto compasivo decía "cada alma"~~ **Resuelto en la Fase 14d:** cuatro finales por almas liberadas, el de 2 almas nombra la guardada | Resuelto | Ninguna |
| 29 | El servicio remoto ya no puede cambiar el perfil (`max_profile_distance = 0`): si responde otro perfil, se rechaza toda la respuesta, también la variante narrativa | Info | Subir la distancia en `default_adaptive_config.tres` si se quiere |
| 30 | **El soak del bot es largo y consume mucha memoria:** `bot_phase13_soak_test` tardó entre 522 y 678 s en las últimas fases (502.9 s en la 14g; antes llegó a 1332 s en otra máquina; límite 1800 s) y una corrida fue detenida por falta de memoria | Media | Cerrar otros programas al ejecutar la suite; `--skip bot_phase13_soak_test` para una pasada rápida |
| 31 | La línea de consecuencias y el indicador del HUD no se han visto en una ventana real (legibilidad, solape con la tarjeta de título y la barra del jefe) | Media | Jugar el principio de cada nivel |
| 32 | **Controles sin verificar en una ventana real:** la captura de teclas y botones, el foco con teclado y la pausa se probaron con eventos sintéticos y en headless, no con un teclado y un ratón reales. Tampoco se ha visto el diseño de la página de controles (cabe en los paneles de opciones en teoría, 8 filas de 28 px) ni las teclas con nombres raros o de otros idiomas de teclado | Media | Probar el cambio de cada acción, el intercambio y la pausa jugando, y revisar el diseño |
| 33 | **El mando (gamepad) está fuera de alcance:** solo teclado y ratón; los botones del mando no se pueden asignar ni se muestran | Info | Añadirlo en otra fase si hace falta |
| 34 | La suite y las ejecuciones headless **no leen** el archivo real de controles del jugador (`user://controls.cfg`) para que no cambie las pruebas; solo la lectura al arrancar una ventana lo aplica | Info | Ninguna |
| 35 | Los valores por defecto cambiaron: el ataque ya no tiene la tecla X y la onda tiene U como principal. Quien tuviera memorizado X lo reasigna en Opciones | Info | Ninguna |
| 36 | **La presentación de la corrupción no se ha visto ni oído en una ventana real** (solo pruebas headless): colores, contraste, fuerza de la viñeta, aspecto del aura y del brillo de los enemigos, sensación de la música (tono 0.94, corte a 2400 Hz) y el destello. Lo más importante: **la legibilidad de plataformas, zonas de muerte (KillZone), enemigos y proyectiles en cada perfil** (el fondo corrupto multiplica por ~0.7 y la viñeta llega a 0.55 en las esquinas) | Alta | Jugar cada nivel con cada perfil (tomando decisiones distintas) y retocar `default_profile_presentation.tres` |
| 37 | No se hicieron capturas de pantalla por perfil y nivel: abrir los niveles en una ventana real guarda la partida (`set_current_level` + autosave) y no hay un arnés que redirija el guardado en ventana; no se intentó para no arriesgar la partida real | Baja | Hacerlas a mano |
| 38 | El **tono** de la música cambia también su velocidad (se usa `pitch_scale`); con el valor corrupto (0.94) es un 6 % más lenta | Info | Si no gusta, subir `music_pitch` o usar un efecto de cambio de tono |
| 39 | Con "Efectos de corrupción" apagado se apaga **todo** (tinte del fondo, viñeta, destellos, aura, brillo de enemigos y música); solo la placa del HUD (con su tinte) y la línea de consecuencias se quedan | Info | Decisión de diseño, ajustable en `ProfilePresenter._rebuild_target` |
| 40 | El interruptor del menú principal se añade por código bajo "Sacudida de cámara"; el panel de opciones podría quedarse corto de altura (sin verificar en ventana) | Media | Revisar el panel y, si hace falta, ampliar `OptionsPanel` |
| 41 | **La historia, los subtítulos y los finales no se han visto ni oído en una ventana real:** tiempos de los subtítulos (máquina de escribir a 35 car./s; ~35-60 s por final y ~20 s la escena del abuelo, calculados por fórmula), legibilidad sobre cada plano, composición de las poses del epílogo (patos con aura/ojo según el final), el cielo y las estrellas de cada estilo y si las pistas de música elegidas (`title_screen`, `castle_on_the_mountain`, `dungeon`, `the_evil_one`) encajan con cada final | Alta | Ver los cuatro finales jugando (3, 2, 1 y 0 almas liberadas) y retocar `default_story_texts.tres` y `EPILOGUE_LOOKS` en `prologue_shots.gd` |
| 42 | La escena del abuelo se lanza **al entrar al nivel 3** (llegada desde su checkpoint inicial), no justo ante la puerta del jefe; si el jugador muere en ese checkpoint inicial y reintenta, vuelve a verla (se salta con Enter) | Baja | Moverla al checkpoint de la arena si se prefiere |
| 43 | Enter (`ui_accept`) salta las líneas del guardián, pero Espacio también es `ui_accept` en Godot: saltar con la tecla de salto también las salta. No bloquea ni consume la tecla | Baja | Reasignar o usar una acción propia si molesta |
| 44 | Las líneas de los guardianes se muestran como subtítulo abajo (`BossDialogue`), no dentro de la presentación VS de `BossFightFx` (esa solo se dibuja en ventana real y es difícil de probar); durante la presentación VS el juego está en pausa y el subtítulo espera | Info | Integrarlas en la presentación VS si se quiere |
| 45 | ~~El soak no se ejecutó en la Fase 14d~~ **Resuelto en la Fase 14e:** la suite completa con el soak (533 s) pasó con `BossDialogue`, `ElderScene` y los avisos de ataque en los niveles | Resuelto | Ninguna |
| 46 | Las almas, los guardianes y los finales son un guion nuevo: nombres (Daigo, Hana, Kenzo), parentescos con el abuelo y el sentido de la profecía son una propuesta que hay que revisar con el equipo (`docs/STORY.md`) | Media | Revisar y editar el recurso |
| 47 | **Los avisos de ataque no se han visto ni oído en una ventana real** (solo pruebas headless): visibilidad y sensación del tiempo (cuánto se nota que se llenan), tamaño y posición de cada forma sobre los patos reales, colores contra los fondos y el suelo (el contraste calculado más bajo es 2,59: aceptable pero justo), si el signo de exclamación estorba y si los sonidos de preparación se distinguen entre sí (se reutilizan archivos con otro tono y volumen) | Alta | Jugar los tres niveles y retocar `default_telegraphs.tres` |
| 48 | El destello de golpe usa valores de color por encima de 1 (blanco incandescente); sobre plumas muy claras puede verse poco y en pantallas con HDR distinto podría variar | Baja | Subir o bajar `flash_color` del `EnemyVisual` / `BossVisual` |
| 49 | La línea de apunte del enemigo a distancia y el abanico del jefe apuntan al jugador en el momento de dibujar, pero el disparo real fija la dirección al empezar la fase activa: durante la preparación pueden moverse un poco respecto a donde acaba saliendo el proyectil | Baja | Ninguna: es un aviso aproximado (los tiempos no se tocan) |
| 50 | El enemigo robusto y el golpe del jefe usan arcos del mismo tipo que el cuerpo a cuerpo normal (cambian el color y el tamaño, no la forma) | Info | Decidir si merecen otra forma |
| 51 | Los cambios de comportamiento aplazados hasta la prueba manual (retirada del enemigo a distancia, recuperación del rápido, etc.) están listados en `HANDOFF.md` §15; ninguno está implementado | Info | Decidir tras jugar |
| 52 | **Nada del audio nuevo se ha oído en una ventana real** (las pruebas headless comprueban cableado y estado, no audibilidad): ritmo de los pasos (44 px por paso), equilibrio de la mezcla (los sonidos nuevos van de −16 a −7 dB frente a los avisos de preparación, con un pico mínimo de −3 dB), cuánto baja la música al hablar (−6 / −8 dB), si la música de cada jefe encaja y si los sonidos reutilizados con otro tono (`land.ogg` como paso, `dash.ogg` como cambio de escena...) suenan bien | Alta | Jugar y retocar `default_audio_events.tres` |
| 53 | **El contorno de los proyectiles enemigos no se ha visto en una ventana real:** legibilidad sobre cada fondo (contraste calculado 2,78), si el halo late demasiado y si se confunde con otros efectos rojos | Alta | Jugar los tres niveles y retocar `danger_outline.gd` |
| 54 | Los jefes 1 y 3 usan la **misma pista** (`the_evil_one`) a distinto tono (1,00 y 1,12): hay pocas pistas. El jefe 2 usa `treacherous_path`, que es también la música del tutorial | Baja | Pedir una pista más a Ingeniera 2 si no convence |
| 55 | Los pasos usan `land.ogg` a un tono alto: pueden sonar a golpecito. No hay sonido de pisadas distinto por superficie ni para los enemigos | Baja | Cambiar `files` del evento `footstep` |
| 56 | Los sonidos antiguos (salto, dash, golpes, graznidos, decisión, fase 2...) siguen escritos en `audio_director.gd`, no en la tabla; solo los añadidos en la Fase 14f y la música de los jefes están en ella | Info | Migrarlos a la tabla si se quiere un único sitio |
| 57 | La bajada de la música (ducking) solo afecta a la pista que suena en ese momento; durante un fundido entre pistas la pista que se apaga no baja | Info | Ninguna |
| 58 | **Medición de balance con un bot torpe (Fase 14g):** los números de `docs/BALANCE_REPORT.md` salen de un bot que casi no esquiva y de una sola corrida por celda; el nivel 3 no lo supera con ninguna combinación y el nivel 2 con 8 corazones tampoco. Sirve para comparar combinaciones, no como dificultad real. Hay propuestas de ajuste, ninguna aplicada | Alta | Jugar los tres niveles con 8 y 11 corazones antes de tocar valores |
| 59 | **`.gitattributes` ampliado en la Fase 14g** (todo texto a LF; antes solo `.gd`, `.tscn`, `.tres`, `.godot` y `.md`). Los archivos ya versionados con otro final de línea siguen igual hasta que se renormalicen a mano (comandos en el informe de la Fase 14g) | Baja | Renormalizar una vez y hacer un commit aparte |
| 60 | `game/frontend/ui/shadow_wave.gd` (`ShadowWave`, la ola de sombras del menú) no la referencia ningún script ni escena: puede ser arte a medias de Ingeniera 2 | Info | Confirmar con ella si se usa; si no, borrarlo |
| 61 | La exportación incluía escenas de vista previa que no se usan en el juego (`biome_preview`, `duck_arena_preview`, `duck_showcase`, `prologue_preview`, `type_specimen`, `balance_measure`): se añadieron a `exclude_filter` de `export_presets.cfg` | Resuelto | Ninguna |
| 62 | El aviso `Unicode parsing error ... Unexpected NUL character` al regenerar la caché de clases (Fase 14d) no se reprodujo y no hay bytes NUL en ningún archivo de texto del repositorio; el origen probable es la caché `.godot` o el editor | Info | Ninguna |
| 63 | **El medidor de alma y la curación no se han probado en una ventana real:** sensación de los 0,9 s de enfoque, ritmo con el que se reúne alma (11 / 22 / 16 / 8 por golpe, 11 y 33 por muerte) frente al coste (33 a 48), y si curarse en medio de un combate es demasiado fácil o demasiado arriesgado | Alta | Seguir `docs/QA_CHECKLIST.md` y retocar `default_soul_config.tres` |
| 64 | La **barra de alma del HUD** (bajo la placa de corrupción, con la marca del coste y el brillo) y el **efecto de enfoque** del pato (anillos y chispas) están dibujados por código y sin ver en ventana: legibilidad, tamaño de la marca y solapes con otros elementos | Media | Revisar en cada nivel; el arte definitivo puede sustituirlos |
| 65 | La **tarjeta «Nueva habilidad»** (diseño, tamaño del texto, que el texto largo quepa, que se lea la tecla) y su momento (tras el exorcismo al conservar) no se han visto en ventana; en el nivel 3 conservar no mejora la onda, así que **no sale tarjeta** aunque el coste suba | Media | Verlas jugando; decidir si el nivel 3 también merece tarjeta |
| 66 | Los **sonidos de alma y curación** (`soul_gain`, `focus_start`, `heal_done`, `heal_denied`, `soul_full`) son archivos reutilizados con otro tono y no se han oído; no hay sonido de carga continuo durante el enfoque | Media | Retocar `default_audio_events.tres` o pedir sonidos nuevos |
| 67 | El enfoque se **interrumpe con cualquier golpe**, también con los de un jefe en pleno combate: puede resultar casi imposible curarse cerca de uno. Curarse no tiene invulnerabilidad | Info | Decisión de diseño; ver `docs/BALANCE_REPORT.md` |
| 68 | El medidor de alma **no se guarda**: empieza en 0 al cargar un nivel, "Continuar" incluido, y se vacía al reaparecer tras morir | Info | Decisión deliberada (siguen siendo siete claves) |
| 69 | **Fase 15b sin ver en ventana real:** el ritmo y la legibilidad de la introducción del jefe (saludo del guardián + 6 líneas del pato, ~17-27 s, subtítulos de 24 px abajo mientras el jefe está quieto), si resulta pesada la segunda vez que se juega desde cero o si falta un botón claro para saltarla | Alta | Jugar los tres jefes; retocar `duck_lines` o el ritmo (`INTRO_TYPE_SPEED`, `INTRO_HOLD` en `boss_dialogue.gd`) |
| 70 | **El momento de la tarjeta tras la animación de corrupción** (cuánto espera, si queda un hueco incómodo entre el final de la animación y la tarjeta) y el tiempo máximo de seguridad (`step_timeout`, 20 s) | Media | Verlo conservando un fragmento en el nivel 1 y el 2 |
| 71 | **La arena del nivel 1 ya no tiene hueco** (suelo hasta el muro, x = 5490): verificado solo por cálculo con las formas de colisión; no se ha recorrido a mano ni se ha mirado el aspecto del borde del suelo contra el muro | Media | Recorrer el final de la arena en los tres niveles |
| 72 | **La sensación del dash totalmente invulnerable** (0,18 s sin recibir daño ni siquiera de proyectiles o del jefe): puede hacer el combate más fácil de lo medido en `docs/BALANCE_REPORT.md`; la medición del bot es anterior al cambio. Aura pálida del dash sin ver en ventana | Media | Probar contra los tres jefes; si es demasiado fácil, acortar `dash_duration` o subir `dash_cooldown` (no se ha tocado ninguno) |
| 73 | La introducción de jefe no se reproduce en las ejecuciones automáticas (headless) salvo que se active `play_when_headless`, y el jefe despierta entonces al instante como antes | Info | Decisión deliberada |
| 74 | **Fase 15c sin ver en ventana real:** la sensación y la altura del nenúfar (~300 px), la legibilidad del aviso y de los pinchos (rojo-naranja sobre el pantano), la legibilidad del salto del jefe (agacharse 0,7 s y marcador de aterrizaje) y la sensación del doble salto | Alta | Jugar el jefe 2 completo; ajustar `default_bounce_config.tres`, `default_floor_hazard_config.tres` y los nodos `Leap` |
| 75 | **La arena 2 puede estar muy cargada** (tres nenúfares, cinco plataformas, siete anclas, pinchos y el jefe saltando) en una pantalla de 1280×720: legibilidad, cámara y que el jefe se vea siempre | Media | Verlo en ventana |
| 76 | **El jefe pasa mucho tiempo en las plataformas** (el bot lo midió entre el 63 % y el 85 % del combate) y el bot no consigue golpearlo allí; un jugador real puede alcanzar el piso bajo saltando y el alto solo con nenúfar o doble salto. Puede ser demasiado difícil o frustrante | Alta | Ver `docs/BALANCE_REPORT.md` (propuestas sin aplicar: bajar el peso de `Leap`, alargar su recarga o acortar la percha) |
| 77 | El **bot de balance no usa los nenúfares ni el doble salto** y solo se refugia en las plataformas bajas: su simulación del jefe 2 no se puede comparar con la de la Fase 15a (0 de 12 duelos ganados en 240 s) | Info | La conclusión útil es la prueba manual |
| 78 | Un jugador que pasa por encima de un nenúfar **caminando no sale lanzado** (decisión: hay que caer sobre él); si se prefiere que lance también al pisarlo, cambiar `BouncePad._lands_on_top` | Info | Decisión de diseño |
| 79 | **La posesión de la Fase 15d no se ha visto en una ventana real:** ritmo de los 3 s, colores (rojo del fondo, viñeta, ojos), comodidad del temblor y de los dos destellos, legibilidad del fondo rojo durante el resto del combate y el cambio de pose del jefe (sube 38 px, se endereza y tiembla) | Alta | Jugar los tres jefes; ajustar `default_possession_config.tres` |
| 80 | El **contraste** sobre el fondo rojo se ha calculado (peor 2,59 contra el umbral 2,5), no mirado: queda poco margen en el pantano; las plataformas, los pinchos y los proyectiles pueden leerse peor sobre un fondo rojizo | Media | Comprobarlo en el nivel 2 en la fase 2 |
| 81 | La secuencia **alarga la transición de 1,5 s a unos 3 s** en las ejecuciones normales; en la fase 2 el jugador espera algo más quieto. En las automáticas (headless) no hay secuencia | Info | Decisión de diseño |
| 82 | El jefe se eleva solo **visualmente** (el cuerpo y su caja de colisión se quedan en el suelo): no se le puede golpear «en el aire» durante la secuencia porque es invulnerable, pero el dibujo y la caja no coinciden mientras dura | Info | Aceptado |
| 83 | **Sin verificar en una ventana real (Fase 15d-bis):** la sensación y la altura del nenúfar elevado (salto desde el suelo hasta una cima a 56 px, muelle del tallo), la duración del jefe 2 con 50 PV y la legibilidad de los tres colores de la onda y de su destello | Alta | Jugar el jefe 2; retocar `default_bounce_config.tres` y `default_sword_wave_config.tres` |
| 84 | **Los jefes 1 y 3 pueden quedarse sin atacar** hasta que termina una recarga (jefe 1: hasta unos 3 s con el pato lejos y la embestida en recarga en la fase 1; jefe 3: hasta unos 2,5 s). No se han tocado para no cambiar su equilibrio; el mecanismo (`max_idle_time` y patrones de reserva) está listo para la fase del jefe 3 | Media | Decidir en la fase del jefe 3 |
| 85 | Los **patrones de reserva** del jefe 2 (descarga apuntada, salto hacia el pato y pisotón) hacen que el jefe ataque más seguido en plataformas: puede subir la dificultad | Media | Probarlo; bajar su peso no hace falta (no entran al azar) pero se pueden alargar sus recargas |
| 86 | El suelo **bajo un nenúfar** sí lleva pinchos (el nenúfar ya no está a ras); quien se refugia bajo un nenúfar se pincha | Info | Decisión de diseño |
| 87 | **No se ha jugado el daño de la onda por nivel (Fase 15d-ter):** si 1 / 2 / 3 se siente como una mejora real y no se pasa de fuerte; el nivel 1 (2,22 de daño por segundo) iguala a la espada ligera y el 2 (2,50) la supera; el jefe 1 con la onda de nivel 2 sola cae a 16 s en teoría | Alta | Probar los tres niveles en el jefe 2 y el nivel 2 en el jefe 1; ajustar `damage` en `default_sword_wave_config.tres` |
| 88 | El daño de la onda es **entero**: no se puede afinar entre 1 y 2 sin cambiar la recarga (decisión de la Fase 15d-ter: no tocar nada más). Si el nivel 1 resulta demasiado fuerte, la alternativa es volver a daño 1 con más alcance o una recarga mayor | Info | Ver `docs/BALANCE_REPORT.md` |

## Resultado de las pruebas de resistencia (Fase 13a)

El bot de resistencia (5400 fotogramas por nivel, tres semillas por escena, más duelo con cada jefe) y la prueba de fugas de escenas **no encontraron errores**. Limitaciones del bot: no navega los huecos a propósito (muere y reaparece), casi nunca derrota a los jefes dentro de los niveles (el duelo con vida ampliada sí demuestra que los tres combates terminan) y no juzga la sensación de juego.

## Fase 15e-1 (jefe 3)

- Sin verificar jugando: sensación del rayo, columnas, guardia y destello de tormenta; los números salen de cálculos y de `phase15e1_smoke_test`.
- No se ejecutaron la suite completa ni la prueba de resistencia tras el cambio; las pruebas antiguas que tocan valores del jefe 3 se actualizaron a propósito pero no se volvieron a correr todas.
- La geometría del nivel 3 no cambia (la Fase 15e-2 se ocupa de los huecos); el rayo usa el suelo detectado por rayos y valores de reserva exportados.

## Fase 15e-2 (huecos del nivel 3)

- Sin verificar en ventana real: dificultad y ritmo de los tres huecos (el más duro deja un 14 % de margen y pide el doble salto tarde y el dash a mitad de la caída) y la duración del nivel 3 (725 px más largo).
- No se ejecutaron la suite completa, la prueba de resistencia ni las simulaciones de balance. Los bots de prueba se enseñaron a usar el doble salto; la próxima corrida completa debe confirmarlo.
- `phase15e1_smoke_test` tiene las coordenadas de la arena desplazadas +725 pero no se volvió a ejecutar tras el desplazamiento.

## Fase 15e-2b

- Sin verificar en ventana real: el ritmo de los huecos. El hueco 1 (380 px) deja solo 2 px de margen sobre el recorrido del centro de salto + doble salto (382,2), aunque el alcance efectivo con coyote y solape da 60 px; el hueco 3 (484 px) deja un 12,1 % sobre el recorrido del centro.
- No se ejecutaron la suite completa, el soak ni `phase15e1_smoke_test` tras el nuevo desplazamiento (sus coordenadas se movieron -156 px).

## Fase 15e-3: la barra del jefe 3 «no bajaba» tras la fase 1

- Encontrado: no era un fallo de la barra. `phase15e1_smoke_test` comprobó que la barra coincide con la vida del jefe tras cada tipo de golpe en las tres fases y tras las dos posesiones, y que el jefe no queda retenido ni invulnerable. La causa es el diseño de la guardia de Kenzo (fase 2): espada ligera, onda y el primer golpe pesado o de dash se bloquean sin daño, así que la barra solo se mueve con el segundo golpe pesado o de dash, y el jugador no lo notaba.
- Corregido (solo retroalimentación): etiqueta «BLOQUEADO» con escudo en el punto del golpe, medidor de guardia bajo la barra (con «ATURDIDO: ¡GOLPEA!» al romperla) y una pista, una vez por pelea: «Rompe la guardia con golpe pesado o tajo de dash». Con efectos de corrupción desactivados la etiqueta y la pista siguen, sin ascenso ni chispas.
- No verificado con el espadazo real en ventana; la prueba usa los mismos tipos de golpe contra la hurtbox. El ritmo de la fase 2 (dos golpes pesados seguidos antes de poder dañar) puede seguir sintiéndose duro: es una decisión de balance pendiente.

## Fase 16a (Director local)

- Sin verificar en ventana real: cuánto se nota el plan y el equilibrio de los enemigos extra y de los pesos (umbrales en `default_telemetry_config.tres`, pensados a ojo).
- Al continuar desde disco no hay telemetría: el nivel usa el plan neutro (por diseño).
- El plan de un nivel usa la telemetría del anterior, así que los pesos se aplican por identificador de patrón entre jefes distintos (por ejemplo `charge`); un patrón que el jefe no tiene se descarta.
- No se ejecutaron la suite completa ni el soak. Pruebas antiguas que podrían notar el cambio: `level_phase12b_smoke_test`, `adaptive_phase9_smoke_test`, `ai_phase10_smoke_test` y los tests de flujo (no se tocaron: con el plan neutro el comportamiento es el mismo).

## Fase 16b (Director remoto)

- Sin verificar: respuestas reales de OpenAI, la latencia en una partida real (presupuesto de 3 s, el modelo tiene 2,5 s sin reintento) y si el plan remoto se nota distinto del local.
- Las pruebas usan una red simulada; los tests de Python usan un cliente falso. Hace falta una pasada manual con el servicio en modo `openai`.
- El servicio no tiene autenticación: hace falta antes de alojarlo públicamente (el límite por IP no la sustituye).
- Un servicio en modo mock o respaldo devuelve el plan base, así que no cambia nada respecto a la Fase 16a (por diseño).
- No se ejecutaron la suite completa ni el soak. Pruebas antiguas que podrían notar el cambio: `ai_phase10_smoke_test` y `ai_phase10_integration_test` (flujo de decisión), `adaptive_phase9_smoke_test`, `phase14c_smoke_test` (opciones) y los tests de flujo/menú; no se tocaron.

## Fase 16c (línea del abuelo, reflejo y epílogos)

- Sin verificar en una ventana real: el tono de las líneas del banco y de los 12 epílogos (el responsable y la Ingeniera 2 deben revisar el español), la legibilidad y el tiempo de la línea (6,5 s), el aspecto del reflejo (silueta de estrellas borrosa/nítida) y que la línea no moleste en la práctica.
- La lista de palabras prohibidas está duplicada (recurso de Godot y `director.py`); si se cambia una, hay que cambiar la otra.
- No se ejecutaron la suite completa ni el soak. Se actualizaron a propósito dos comprobaciones de `phase16b_smoke_test` (la petición del nivel 3 ahora pide el final) y no se volvió a ejecutar esa escena. Pruebas antiguas que podrían notar el cambio: `phase14d_smoke_test` y los tests del final (la tarjeta tiene una etiqueta más), `phase14f_smoke_test` (la tabla de audio tiene un evento más) y los tests de nivel/flujo (cada nivel numerado tiene un nodo más).

## Fase 15f

- Sin verificar en una ventana real: la legibilidad de la capa de armadura (placas, grieta, fragmentos, regeneración), la duración y el ritmo de las introducciones de los tres guardianes y el tono de los textos en español (revisar con el responsable y la Ingeniera 2).
- Una introducción solo avanza con la acción de confirmar: si el jugador la reasigna a una tecla que no recuerda, el indicador muestra el nombre de la tecla actual.
- No se ejecutaron la suite completa ni el soak. Pruebas antiguas que podrían notar el cambio: `phase14d_smoke_test` (líneas de los guardianes), `phase15b_smoke_test` (introducción, que ahora espera a Enter; se actualizó), `phase15e1_smoke_test` (guardia; se actualizó y se ejecutó) y los tests de flujo de jefes.

## Fase 15g

- Sin verificar en una ventana real: la sensación y la altura de las corrientes, la legibilidad y la justicia de las placas, la utilidad de las rutas altas, y la legibilidad y el rendimiento del decorado.
- El nivel 3 está lleno de enemigos y de plataformas fijadas por la Fase 15e-2, así que el escenario nuevo cabe en pocos sitios: una banda de placas y una corriente en el primer tramo, una corriente con una plataforma alta cerca de la arena, y solo estos dos tramos tienen ruta alta nueva. La corriente del tramo final queda a 100 px del enemigo extra de ese tramo y del punto de control (no a 150 px como las placas).
- No se ejecutaron la suite completa ni el soak. Pruebas antiguas que podrían notar el cambio: `phase15e2_smoke_test` (geometría; se ejecutó y pasa) y `phase15e1_smoke_test` (arena; se ejecutó y pasa, con dos posiciones nuevas en el barrido), además de los tests de nivel 3 y de flujo.

## Fase 15h

- Sin verificar en una ventana real: el tono emocional y el ritmo de ambos finales, la legibilidad de las escenas dibujadas por código y la sensación del avance con Enter.
- La revisión del texto en español (sobre todo el final «El acantilado» y el mensaje de apoyo) la debe hacer el responsable del proyecto.
- `phase14d_smoke_test` conserva 2 fallos anteriores a esta fase (líneas de los guardianes de la Fase 15f más largas de 110 caracteres y con 3 a 5 líneas, y el test espera 2-3): son expectativas antiguas, no del final.
- No se ejecutaron la suite completa ni el soak. Pruebas antiguas que podrían notar el cambio: `adaptive_phase9_smoke_test` (usa el nombre `ending_corrupt` en su tabla), `phase16a_smoke_test`, `phase16b_smoke_test` y las de las fases 12b (actualizadas pero no ejecutadas).

## Fase 15h-bis

- **`phase15h2_smoke_test` NO está confirmada:** su única corrida se cortó a los 5 minutos y midió 0 ms por un error del propio test (faltaba reiniciar `PauseLock`, `AbilityCard` y `BossDialogue`, que bloquean los controles, y el nivel mostraba la pantalla de fin de partida). Ambos errores están corregidos pero la escena no se volvió a ejecutar, así que las ventanas reales de tolerancia siguen sin medir. Las comprobaciones del enemigo en el borde (aproximación mínima 244 px, sin golpes ni caídas) sí se midieron con el nivel real.
- Sin verificar en una ventana real: la sensación de cada hueco, las plataformas de restos y que el jugador no vea saltar un enemigo que se detiene antes del borde.
- Los enemigos a distancia (disparos) pueden seguir golpeando a un jugador parado en el borde: el retroceso solo se eliminó para los de contacto.
- Pruebas antiguas sin ejecutar que podrían notar el cambio: `phase15b`, `phase15e2` (ejecutada, pasa; Fast1, Fast2 y Melee2 salieron de su tabla de desplazamiento) y las del Director que cuentan enemigos.

## Fase 15i

- Sin verificar en una ventana real y en movimiento: el ritmo cinematográfico, el aspecto del retrato del abuelo (visto solo en imágenes fijas), el tono emocional de los dos finales y la legibilidad de la silueta durante el salto. Las imágenes fijas de revisión sí muestran el rostro, la ciudad, las venas y el acantilado.
- La revisión del texto en español de ambos finales la debe hacer el responsable del proyecto.
- La parte del pato que «extiende un ala» es un dibujo añadido sobre el rig (el rig no tiene ese gesto), así que puede notarse distinta del resto del cuerpo.
- La espada se oculta en el rig cuando cae y se dibuja aparte; la mano del rig no suelta nada, solo desaparece la hoja.
- Pruebas antiguas actualizadas pero sin ejecutar: `phase14d_smoke_test` (sus 2 fallos de la Fase 15f siguen pendientes), `phase14e_smoke_test`, `level_phase12b_smoke_test`, `level_phase12b_playthrough_test`.

## Fase 15j

- **Sin verificar en una ventana real:** el ritmo de los ciclos (unos 23 s cada uno), la legibilidad de la andanada y de los rayos rojos, lo justo que resulta el vacío, y la duración y la dificultad del jefe 3.
- `phase15j_smoke_test` falló una vez (el chequeo de las salvas del ojo, sin identificar la causa: parece intermitente) y pasó en la corrida siguiente, ya con diagnóstico en el mensaje.
- `phase15d_smoke_test` falla en «tuning: the spikes … and the pad launch are unchanged» (pinchos y trampolín del jefe 2): no tiene relación con esta fase; viene de un cambio anterior de esos números.
- Pruebas actualizadas pero **no ejecutadas**: `level_phase12b_smoke_test`, `phase14e_smoke_test`, `phase14f_smoke_test`, `phase15e2_smoke_test`, `phase16a_smoke_test` (ids de patrones del jefe 3 y clases quitadas).
- Quedan sin uso los estilos de aviso `boss_beam` y `boss_columns` del conjunto de telegrafías (`TelegraphSet`), porque `phase14e_smoke_test` comprueba que existan todos.
- La luz de los rayos rojos se compone con la tinta de posesión persistente: el peor contraste medido es 3,08 (aviso) y 3,73 con el rojo de la posesión.

## Fase 15i-bis

- Sin verificar en una ventana real y con sonido: el tono, la música procesada (tono bajo, filtro y reverb sobre pistas existentes), los graznidos reutilizados (no hay un graznido real de dolor o soledad: son el graznido del héroe y su quejido más graves), la pluma y el retrato impasible. Conviene añadir música y graznidos reales más adelante (ver HANDOFF).
- En las pruebas aceleradas algunos graznidos no suenan porque el recuperador de eventos cuenta tiempo real; a velocidad normal sí.
- El cambio a «cortar antes del acto» quita el paso al vacío que se pidió en la Fase 15i: es la regla de seguridad nueva.
- `phase14f_smoke_test` falló antes de estos cambios en el chequeo del cableado por `grandfather_voice` (de la Fase 16c); ahora lo cubre `phase16c` y los graznidos `phase15i`.

## Fase 15k

- Sin verificar en una ventana real: el aspecto de la sangre, la legibilidad con manchas en el suelo y el rendimiento. La capa z -2 queda debajo de los avisos; si el terreno de algún nivel se dibuja por encima, las manchas no se verían (habría que subir la capa por debajo de los avisos).
- Las manchas solo aparecen donde hay suelo debajo (trazo al mundo, 360 px); en el vacío las gotas simplemente se desvanecen.
- Contraste peor caso con manchas: 2,59 (aviso `melee_tough` contra el suelo), muy cerca del mínimo de 2,5; no se debe subir la opacidad de la mancha (0,45) sin volver a medir.
- `phase14e_smoke_test` tenía una línea obsoleta (`scar`, de la Fase 15h) que impedía cargarla; se corrigió. Además fallan en esa prueba comprobaciones de jefes (`charge` lane, `summon_cycle` del jefe 3) que ya venían del rediseño del jefe 3 (15j) y no tienen que ver con la sangre.

## Fase 15l

- Sin verificar en una ventana real por el dueño: el aspecto de las venas, la secuencia de absorción oscura y el rendimiento del final. El trabón original NO se pudo reproducir en el equipo de desarrollo (el final completo terminó en 78 s, unos 135 fotogramas por segundo sin límite): la causa más probable es el coste de dibujo por fotograma en equipos más modestos; se redujo (de 7,4 a 4,4 ms por fotograma en la medición) y se añadieron el vigilante y los topes. Si el trabón persiste hay que pedir el registro del equipo.
- El latido de la absorción usa el impacto de proyectil en el mundo con el tono muy bajo (no hay un latido real); conviene un archivo propio.
- Las líneas del final avanzan solas tras 120 s sin respuesta (seguridad contra bloqueos).
- La prueba de `phase15l` midió el final con el reloj acelerado; el coste por fotograma en un equipo sin GPU potente no está medido.

## Fase 15m

- Sin verificar por la dueña en una ventana real: la duración del tutorial (objetivo 2 a 3 minutos), la claridad de las indicaciones y las frases del muñeco. El prólogo en vídeo hay que saltarlo para ver el nivel (no se tocó).
- El texto de aviso (arriba, centrado) puede solaparse un poco con el indicador de vida cuando la frase es larga.
- La pulsación larga de confirmar para saltar usa la misma acción que las tarjetas: mantenerla con una tarjeta abierta cuenta igual.
- La fuzz-test usa señales simuladas del jugador (no teclas reales) salvo la muerte, las caídas y la pausa.
- Pruebas antiguas tocadas a propósito y que NO se ejecutaron: `combat_phase13c_smoke_test` y `wave_phase12c_smoke_test` (solo su parte del tutorial). Hay pruebas que no se tocaron (`flow_*`, `bot_phase13_soak_test`, `phase16*`) y que cargan el tutorial.

## Fase 15n

- Sin verificar por la dueña en una ventana real: la longitud de los diálogos, la sensación de los fragmentos azules, el volumen de los graznidos, el audio del prólogo y el retrato del abuelo en el cielo. El audio del prólogo reutiliza archivos existentes (sin un cierre propio de música).
- El enlace de sonidos de impacto del director no existe en las ejecuciones sin ventana: la prueba de graznidos lo conecta a mano, igual que lo haría el juego.
- El monólogo largo del pato y las variantes por perfil de los guardianes ya no se dicen (quedan los campos en el recurso).
- `phase15b_smoke_test` falla en 3 comprobaciones de los huecos del nivel 3 (anteriores a esta fase). Pruebas tocadas a propósito y NO ejecutadas: `phase14e`, `phase15f`, `phase15i`.

## Fase 15o

- Sin verificar por la dueña en una ventana real: el aspecto de la absorción roja (cantidad y grosor de los rayos, el emblema abajo, el brillo de los ojos), la calidad de los dibujos de la corrupción (las venas de la etapa 1 son muy tenues a propósito; el cuerpo se ve poco con la espada delante), el nivel 3 sin columnas y el jefe 3 sin armadura (la fase 1 es bastante más corta: puede hacer falta subir su vida).
- Los finales siguen sin vista frontal: todas las poses son de perfil (el rig solo se dibuja así). La pose «reach» sigue pasando el ala por delante de la cara.
- El fragmento de la absorción (`GemDrawer`) conserva su brillo azul propio sobre el fondo rojo.
- Pruebas tocadas a propósito y no ejecutadas: `phase15f` (sustituidas sus pruebas de la armadura por una de «sin armadura»); `phase15i` (cambia `_weapon` / `_arm_angle` por `figure`).

## Fase 15p

- Tras caer un jefe el jugador queda bloqueado e invulnerable mientras suenan sus últimas palabras y no avanzan solas: hay que pulsar la confirmación (o mantenerla) para continuar. Es intencionado (Fase 15n); si en ventana resulta incómodo se puede añadir un tiempo máximo.
- La fase 1 del jefe 3 dura ahora unos 24 s ideales: sin verificar en ventana.
- Pruebas ejecutadas más de una vez por errores de las propias pruebas durante esta fase: `phase15j` (3 veces) y `phase15f` (2).

## Fase 15q

- La prueba `phase15h2` mide ahora con 480 pasos de física por segundo a factor 8; dura unos 255 s y su presupuesto es de 290 s: en un equipo más lento puede agotarlo (lo dice con un fallo explícito, no con ceros).
- La telegrafía del ciclo de invocación del jefe 3 ya no se prueba en `phase14e` (necesita el escenario del nivel); la cubren `phase15d` y `phase15j`.
- Pendiente de ventana real: nada de esta fase cambia el aspecto ni el equilibrio.
- La prueba de resistencia de bots (`bot_phase13_soak_test`) no terminó dentro de 10 minutos en la verificación de la Fase 15q (75 comprobaciones correctas, ningún fallo y ninguna línea de «flushing queries»); su duración completa queda por confirmar en la ejecución de la suite.

## Fase 15r

- **Sin verificar en una ventana real por la dueña:** el aspecto del abuelo en el cielo (su figura es de perfil y encorvada: la cara se lee, pero es pequeña y su moño oscuro es poco legible sobre cielos claros), las tres siluetas (la del pato tumbado se lee como una forma baja; el moño y el ala dejan un contorno irregular) y el aspecto del alma de cada guardián (sobre fondos claros del nivel 1 el azul contrasta poco).
- El alma del Ojo de la Tormenta es su figura de pato poseído tal como la dibuja el rig, teñida de azul; no hay un diseño de espíritu aparte.
- El abuelo del cielo solo tiene las poses de su figura (quieto y hablando); la pena es la cabeza inclinada y el brillo tenue.
- Pruebas que mencionan el retrato antiguo y deben correr completas en la suite: `phase15i`, `phase15n`, `phase16c`.
