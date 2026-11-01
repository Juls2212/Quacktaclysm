# Problemas conocidos y puntos sin verificar

Lista honesta a fecha de la Fase 13a. **Nadie ha jugado el juego con ventana**: todo lo "sin verificar" son cosas que las pruebas automáticas no pueden juzgar (sensación, legibilidad, dificultad). Cada punto lleva gravedad (Alta / Media / Baja / Info) y una sugerencia.

## Sin verificar jugando

| # | Punto | Gravedad | Sugerencia |
| --- | --- | --- | --- |
| 1 | Sensación del movimiento, salto, dash, ataque de espada y onda; legibilidad de los avisos de ataque de enemigos y jefes | Alta | Una sesión de juego completa; anotar y ajustar los recursos (`PlayerStats`, `EnemyStats`, `BossStats`, patrones) |
| 2 | Dificultad y balance: vida de jefes (40/60/80), densidad de enemigos, recargas de la onda, daño | Alta | Jugar los tres niveles con los tres perfiles (liberar todo, conservar todo, mixto) |
| 3 | Cámara: límites por nivel, comportamiento cerca de huecos y de la arena | Media | Revisar en cada nivel; ajustar `camera_limits` |
| 4 | Legibilidad de los textos (tutorial, introducciones, finales) y del indicador de recarga de la onda | Media | Revisar tamaños y contraste al sustituir el arte |
| 5 | Fundidos entre escenas (0,35 s) y transición pausa/Game Over | Baja | Ajustar `fade_*_time` en `default_scene_registry.tres` |
| 6 | Teclas de depuración (K, H, F2, F3) probadas con eventos sintéticos, no con teclado real | Baja | Probar a mano en un build de depuración |

## Limitaciones conocidas del código

| # | Punto | Gravedad | Sugerencia |
| --- | --- | --- | --- |
| 7 | El texto del tutorial para la onda dice "clic derecho o {wave}": la parte "clic derecho" está escrita a mano y solo la tecla (U) sale del `InputMap` | Baja | Construir la pista desde todos los eventos de la acción (incluido el botón del ratón) |
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
| 19 | El ejecutable de Windows no se ha podido generar en esta máquina (faltan plantillas de exportación); el comportamiento de una build de lanzamiento (sin ayudas de depuración, sin servicio de IA) solo está verificado por pruebas del código, no ejecutando el `.exe` | Media | Instalar las plantillas y seguir el README |
| 20 | **Conflicto de teclas en builds de depuración:** `K` es una de las teclas del dash (acción `dash`) y también la tecla de depuración que mata al jefe en los niveles (`LevelDebug`) y en `boss_test`. En un build de depuración, dashear con K mata al jefe si está vivo. Las builds de lanzamiento no tienen las ayudas | Media | Mover las teclas de depuración a otras que no usen las acciones del juego (p. ej. F5–F8 o Ctrl+tecla), o cambiar la tecla secundaria del dash |
| 21 | **Riesgo de balance (Fase 13c):** jugador más fuerte (8 corazones, golpe pesado de 3 de daño, tajo de dash) frente a daño por contacto; la vida de los jefes (40/60/80) no se tocó. El tiempo de combate con jefes baja y el contacto sube la dificultad: ambos efectos sin probar jugando | Media | Jugar los tres jefes; ajustar `contact_damage`, `heavy_*` y `dash_slash_*` | 
| 22 | Los textos del tutorial para el golpe pesado ("clic central o {heavy_attack}") y el tajo de dash ("Pulsa atacar ({attack}) durante el dash ({dash})") asumen que cada acción tiene una tecla y que la primera tecla es la que se muestra; "clic central" está escrito a mano | Baja | Construir la pista con todos los eventos de la acción |
| 23 | El tajo de dash convierte en tajo un ataque pulsado hasta 0,1 s antes del dash; un ataque pulsado durante la recuperación extra se guarda en el búfer y se ejecuta al terminar | Info | Ajustar `dash_slash_input_buffer_time` |

## Resultado de las pruebas de resistencia (Fase 13a)

El bot de resistencia (5400 fotogramas por nivel, tres semillas por escena, más duelo con cada jefe) y la prueba de fugas de escenas **no encontraron errores**. Limitaciones del bot: no navega los huecos a propósito (muere y reaparece), casi nunca derrota a los jefes dentro de los niveles (el duelo con vida ampliada sí demuestra que los tres combates terminan) y no juzga la sensación de juego.
