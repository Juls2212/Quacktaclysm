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
- ~~**Orbes de salud (extensión del diseño):**~~ **Sustituidos en la Fase 15a por el medidor de alma y la curación por enfoque** (ver abajo). Ya no hay orbes ni `HealthOrbStats`, ni `health_orb_count` / `health_orbs_on_*`.
- **Muerte con ragdoll:** jugador, enemigos y jefes se desarman en cuerpo, cabeza y arma con física al morir (solo visual; no afecta a la lógica ni a los tiempos de muerte).

## Arquitectura

- **Tres autoloads:** `GameState`, `SceneManager` y `AudioDirector` (solo audio; no hay lógica de juego en él). El resto (pausa, registro de escenas, servicio de IA) son nodos de escena o recursos.
- **Registro de escenas** (`SceneRegistry`, recurso) con ids (`tutorial`, `level_1`…`level_3`, `ending`, `main_menu`), orden de niveles y tiempos del fundido.
- **`PauseLock`:** contador central de quién pausa el árbol.
- **Guardado:** un único JSON con exactamente siete claves; copia `.bak` y cuarentena `.corrupt`; versión de guardado con gancho de migración.
- **Servicio de IA opcional** (FastAPI en `ai-service/`, modos `mock` y `openai`). El juego aplica siempre primero el perfil local y el servicio solo puede refinar el perfil (a distancia limitada) y elegir una variante narrativa; nunca fija valores numéricos de combate.

## Contenido

- **Tutorial** con nueve pasos (mover, saltar, esquivar, atacar, golpear al muñeco, lanzar la onda, golpe pesado, tajo de dash y, desde la Fase 15a, curarse). Antes de la 15a tenía ocho.
- **Tres niveles** con un jefe cada uno (vida 40 / 60 / 80), 6 / 8 / 9 enemigos base (más 0 / 2 / 3 en la variante "corrupted"; tres tipos: cuerpo a cuerpo, rápido y a distancia) y una escena de final con tres textos.
- **Decisiones:** un fragmento de alma por jefe (Liberar / Conservar); el del Nivel 3 se decide tras el último jefe y solo influye en el final.

## Cosas que el diseño original no especificaba y que se decidieron aquí

- Teclas de depuración (solo builds de depuración): F4 (mata al jefe), H, F2, F3 en los niveles; teclas propias en `boss_test`.
- Pantalla de Game Over con "Reintentar" / "Menú principal"; el tutorial reaparece solo sin pantalla de Game Over.
- Menú de pausa con Esc o P; "Menú principal" no guarda.
- Cámara con límites por nivel (`camera_limits`).
- Valores de balance de todos los jefes, enemigos y tiempos: provisionales, sin probar jugando.
- El arte (patos y escenarios dibujados por código), el audio (música y efectos) y la mayoría de los textos ya existen; los finales y parte del balance siguen siendo provisionales.

## Fase 14b: decisiones con consecuencias

- **Regla del perfil inmediata:** umbral de decisión 1,0 (antes 2,0). Cada fragmento liberado (+1) o conservado (−1) cambia el perfil del nivel siguiente. Con tres decisiones el score nunca es 0, así que **el final neutral ya no se alcanza** con decisiones normales (se tratará en la Fase 14d).
- **El servicio remoto no cambia el perfil:** `max_profile_distance = 0`; solo puede elegir la variante narrativa del perfil que ya fijó la regla local.
- **Liberar da +1 corazón máximo por fragmento** (hasta +3, 11 en total), calculado a partir de `souls_released` al aparecer y reaparecer; no hay clave de guardado nueva. Conservar mantiene la onda de espada más fuerte (fragmentos de los niveles 1 y 2) y su coste es el nivel corrupto.
- **Corrupción visible:** indicador en el HUD (perfil y score) y una línea al empezar cada nivel que explica las consecuencias (también el nivel 1, que ahora tiene introducción). Se corrigieron las tildes de las introducciones de los niveles 2 y 3.
- **HUD de vida para hasta 11 puntos** (segmentos más estrechos, sin salirse de la pantalla).
- **Sonidos de Liberar, Conservar y fase 2 del jefe** en `AudioDirector`, reutilizando archivos existentes.
- **Teclas de depuración:** matar al jefe pasó de `K` a `F4` (K es una tecla del dash).
- **Prólogo en headless:** `set_process(false)` junto al `queue_free()`.

## Fase 14b-2: controles reasignables

- **Controles personalizables** (teclado y ratón, dos asignaciones por acción) desde Opciones, en el menú principal y en la pausa. Se guardan en `user://controls.cfg`, aparte de la partida (siguen siendo siete claves de guardado y tres autoloads).
- **Cambios en los valores por defecto:** el ataque pierde la tecla X (ahora J y clic izquierdo) para respetar el máximo de dos asignaciones; la onda pasa a tener U como principal y el clic derecho como alternativa (antes al revés).
- **Esc está reservada:** cancela una captura y siempre pausa, aunque se reasigne `pause`.
- Las pistas del tutorial muestran las asignaciones actuales; los textos de la onda y del golpe pesado ya no escriben "clic derecho" / "clic central" a mano.
- El mando (gamepad) queda fuera de alcance.

## Fase 14c: corrupción visible y audible

- El perfil adaptativo ahora tiene presentación en el mundo (fondo, viñeta, aura, brillo de enemigos, música más grave y apagada si es corrupto; cálido si es compasivo; sin cambios si es neutral) y un destello al cambiar de perfil con una decisión. **Solo presentación:** ningún valor de juego, regla adaptativa ni clave de guardado cambia (siguen siete claves y tres autoloads).
- Nuevo interruptor **"Efectos de corrupción"** en Opciones (activado por defecto), guardado en `user://settings.cfg`.
- Todos los valores se editan en `default_profile_presentation.tres`.

## Fase 14d: historia y finales

- **Cuatro finales deterministas** por almas liberadas (antes tres, por perfil): 3 / 2 / 1 / 0. El final neutral desaparece (era inalcanzable desde la 14b). La escena pasa de una pantalla estática a una secuencia de subtítulos de ~35-60 s (saltable manteniendo Enter) más una tarjeta de resumen con los nombres de las almas; se quitó la "Variante narrativa" de la pantalla.
- **Almas con nombre y recuerdo**, **diálogo de los guardianes** (una vez por encuentro) y **vuelta del abuelo** antes del jefe 3 (escena de ~20 s). La profecía del prólogo se resuelve en los cuatro finales.
- Sigue habiendo siete claves de guardado y tres autoloads; sin arte ni audio nuevos (se reutilizan `DuckRig`, `PrologueShots` y las pistas existentes).

## Fase 14e: ataques legibles y sensación de golpe

- Avisos dibujados en código para cada ataque enemigo y de jefe (arco, carril, línea o abanico que se llena durante la preparación), sonido de preparación distinto por tipo, destello blanco y rebote al golpear, tinte de recuperación y alma al morir. Antes solo había un tinte amarillo, una postura agachada y un graznido.
- **Solo presentación:** ningún tiempo ni valor de juego cambia (siguen siete claves de guardado y tres autoloads; sin arte ni audio nuevos). Los avisos se ven siempre, también con "Efectos de corrupción" desactivado.
- El destello de golpe pasa de rojizo a blanco (más fuerte en los jefes).

## Fase 14f: audio que faltaba y proyectiles legibles

- Sonidos nuevos (pasos, impactos de proyectil y de onda, exorcismo, presentación del jefe, título, portal, cambio de escena, Game Over) en una tabla editable; música propia por jefe; la música baja mientras alguien habla; contorno de peligro en los proyectiles enemigos.
- Solo presentación: ningún valor de juego cambia (siguen siete claves de guardado y tres autoloads; sin audio ni arte nuevos, se reutilizan archivos con otro tono y volumen).

## Fase 14g: cierre, higiene y traspaso

- Sin cambios de juego. Se midió el balance con bots (`docs/BALANCE_REPORT.md`, sin aplicar ninguna propuesta), se comprobó que el juego sigue sin el servicio de IA (`ai_down_phase14g_smoke_test`), se exportó y ejecutó una build de lanzamiento y se escribió la lista de pruebas manuales (`docs/QA_CHECKLIST.md`).
- Higiene: `.gitattributes` ampliado (todo texto a LF), escenas de vista previa fuera de la exportación, nombres internos de los jefes sin "(placeholder)".
- `HANDOFF.md` pasa a ser el punto de entrada único (sección 0).

## Fase 15a: medidor de alma y curación por enfoque (cambio deliberado de diseño)

- **Qué cambia:** los orbes de salud (que añadió Ingeniera 2 y no estaban en el diseño original) desaparecen. En su lugar, al estilo de Hollow Knight, el jugador **reúne alma** golpeando a enemigos y jefes y la **gasta para curarse** manteniendo una tecla (E o Q) 0,9 s. Cada fragmento **conservado** hace que curarse cueste más (33 + 5 por fragmento); liberar sigue dando +1 corazón máximo (hasta +3) y conservar sigue mejorando la onda. Así la corrupción tiene un coste visible: más poder de ataque, curación más cara.
- **Medidor:** máximo 99; espada 11, golpe pesado 22, tajo de dash 16, onda 8; almas de los enemigos +11 y de los jefes +33. Empieza en 0 al cargar un nivel y vuelve a 0 al reaparecer tras morir (no se guarda: siguen siendo siete claves).
- **Nueva acción `heal`** (E y Q por defecto, reasignable en Opciones → Controles). Cinco sonidos nuevos en la tabla de audio, un efecto de enfoque dibujado en el pato, una barra de alma en el HUD y una línea de consecuencias que dice el coste.
- **Tarjeta «Nueva habilidad»** a pantalla completa (tutorial y al conservar un fragmento que mejora la onda), sin ningún dato guardado.
- **El tutorial pasa de 8 a 9 pasos** (nuevo: curarse; en el tutorial el enfoque puede completarse con la vida llena, gasta el alma y no cura).

## Fase 15b: correcciones (esquive, tarjeta, introducción de jefe, agujero)

- **El dash es invulnerable durante TODO el dash** (antes solo los primeros 0,12 s de 0,18 s). La ventana termina exactamente con el estado `DASH`; el campo `dash_invulnerability_time` se elimina y se sustituye por `dash_invulnerability_grace` (extra opcional tras el dash, 0 por defecto). Las zonas de muerte siguen matando. No cambia ningún otro valor del dash.
- **La tarjeta «Nueva habilidad» espera a la animación de corrupción** (antes salía encima porque su aviso se ejecutaba antes de que se creara la animación). Nueva cola de presentación secuencial (`PresentationQueue`, un nodo de cada nivel, sin autoload): decisión → animación (señal `finished` de `ExorcismCutscene`, con tiempo máximo de seguridad) → tarjetas → siguiente. Reutilizable (la tarjeta del doble salto futuro).
- **Introducción de jefe con la historia del pato (solo la primera vez):** antes los saludos del guardián sonaban con el combate ya activo. Ahora el jefe está inactivo, el pato bloqueado e invulnerable y se reproduce, por la cola: presentación «VS» → saludo del guardián → historia del pato (tres capítulos, uno por jefe) → combate. Enter salta los subtítulos. No se repite tras morir y reintentar ni al continuar desde el checkpoint de la arena. Textos en `BossStory.duck_lines` y en `docs/STORY.md` (sección 5).
- **Agujero de la arena del nivel 1:** el suelo (`FloorEnd`) terminaba en x = 5400 y el muro derecho empieza en x = 5450: un hueco de 50 px al final de la arena por el que se caía a la zona de muerte. Ahora el suelo llega hasta el muro (x = 5490). Las arenas de los niveles 2 y 3 ya eran continuas. Los saltos intencionales de antes de las arenas (285 px con dash, 170-175 px con salto) no cambian.

## Fase 15c: jefe 2 rediseñado y doble salto (cambio deliberado de diseño)

- **El jefe 2 (La Cosa del Pantano) se vuelve más difícil y más vertical:** nenúfares trampolín, dos pisos de plataformas en su arena, un patrón de salto (`LeapPattern`) y pinchos en el suelo durante la fase 2. Sus 60 PV, la armadura, la transición de fase y los tiempos de sus patrones antiguos (tajo, embestida, descarga) no cambian; se añaden dos nodos `LeapLight` (fase 1, peso 0,6) y `Leap` (fase 2, peso 1,8).
- **Recompensa: doble salto.** Una habilidad nueva del jugador (un salto extra en el aire con la misma acción de salto, 85 % del primer salto, una vez por salto, que el dash no gasta). Se desbloquea cuando `GameState.decisions` tiene 2 o más entradas (la decisión del jefe 2), así que no hay clave de guardado nueva y también vale tras continuar una partida. Tarjeta «Nueva habilidad: Doble salto» en la cola de presentación después de la animación de corrupción y de la tarjeta de la onda (conservar) o sola (liberar).
- **Los nenúfares lanzan al caer sobre ellos desde arriba**, no al caminar sobre ellos (para que cruzar la arena no te lance sin querer).
- **Consecuencia para el nivel 3 (sin aplicar):** con el doble salto los saltos de 285 px (que exigían dash) y el de 175 px pasan a ser triviales; ver `docs/BALANCE_REPORT.md`. Rediseñarlos corresponde a la fase del jefe 3.

## Fase 15d: posesión al cambiar de fase del jefe (cambio deliberado de diseño)

- **Qué cambia:** al cruzar la línea de su barra de vida el jefe ya no hace solo un rugido de 1,5 s: empieza una secuencia de posesión (exorcismo) de unos 3 s en la que el jefe se eleva, el fondo se vuelve rojo y todo brilla como poseído. La fase 2 empieza después, exactamente igual que antes (patrones, armadura, pinchos del jefe 2). Ningún valor de juego cambia: vida del jefe, umbral, armadura, daño y tiempos de los patrones son los mismos.
- **Reutilizable:** la secuencia escucha `BossBase.phase_transition_started(next_phase)`, así que sirve tal cual para los varios cambios de fase del jefe 3. Está en un nodo de cada nivel (`PossessionDirector`), sin autoload, y todos sus números en un recurso (`default_possession_config.tres`) con ajustes opcionales por jefe.
- **Mientras dura:** el jefe está retenido en su transición (inactivo, invulnerable, sin avanzar las recargas de sus patrones), los proyectiles enemigos en el aire desaparecen, los peligros del jefe se detienen y el jugador queda bloqueado e invulnerable (`story_invulnerable`).
- **Después:** brillo rojo del jefe y tinte rojo sutil del fondo hasta que el jefe muere o se cancela el combate; la barra del jefe queda teñida y su línea de mitad late al cruzarla.
- **Accesibilidad:** con «Efectos de corrupción» desactivado no hay tinte, destello, viñeta ni temblor, solo una pausa de 1 s con el cambio de pose y el sonido. Ningún destello es más rápido que 3 por segundo (hay 2 en 3 s), su opacidad máxima es 0,3 y son rojos, nunca blancos.
- **Ajuste del jefe 2 (el único cambio de valores de la fase):** peso del salto de la fase 2 de 1,8 a 1,2 y recargas de `Leap` y `LeapLight` de 5 s y 6 s a 7 s y 8 s. Los pinchos (aviso 1,2 s, descanso 4 s), los nenúfares y todo lo demás quedan igual.

## Fase 15d-bis: arreglos del jefe 2, jefe 2 más corto y color de la onda por nivel

- **Embestida en plataformas:** el jefe 2 elegía la embestida estando en una plataforma, corría hasta el borde y se paraba sin hacer nada. Ahora la embestida mide su carril antes de empezar (rayos hasta el primer muro o el primer borde; hace falta un carril útil de 220 px) y no es elegible si no lo hay; el telegrafiado dibuja el carril real (recortado por un muro) y la caja de golpe va activa a lo largo de todo él. Si el pato cambia de lado durante el telegrafiado, el jefe solo se vuelve si el otro lado también tiene carril útil.
- **El jefe nunca se queda sin atacar:** nuevo campo `fallback_priority` en los patrones y `max_idle_time` en las estadísticas del jefe (1,5 s en el jefe 2, 0 = sin garantía en los otros). Si ningún patrón de la rotación es elegible usa un patrón de reserva por orden: (1) descarga apuntada (permite apuntar hacia arriba o abajo), (2) salto hacia el anclaje más cercano al pato, (3) pisotón al suelo (sin recarga). Los bosses 1 y 3 no se tocan (ver `docs/KNOWN_ISSUES.md` #84).
- **Nenúfares elevados:** a 56 px del suelo sobre un tallo-muelle dibujado por código (no sólido); el área de disparo pasa a la parte alta del nenúfar; hay que saltar (el salto sube 112 px) y caer encima; andar por debajo no lo activa. Lanzamiento de −1030 a −930 px/s (sube 240 px desde la cima del nenúfar: los pies llegan a unos 302 px sobre el suelo, 52 px por encima del piso alto, que sigue siendo accesible solo por nenúfar o doble salto). El suelo bajo el nenúfar ya no se salva de los pinchos (`cut_out_pads` apagado): el nenúfar y las plataformas están por encima de la banda peligrosa.
- **Jefe 2 más corto:** 60 → 50 PV. La línea de la fase 2 (55 %) pasa de 33 a 27,5 PV y la posesión se dispara igual, una vez.
- **Onda de espada:** colores por nivel (azul-blanco, esmeralda, violeta con núcleo oscuro y borde claro), estela más larga y brillo más intenso por nivel, sin tocar la caja de golpe, la velocidad, el daño ni la recarga; la tarjeta de la mejora de la onda enseña el color y el destello del impacto lo usa.

## Fase 15d-ter: daño de la onda de espada por nivel

- **Conservar un fragmento ahora se nota:** el daño de la onda pasa de 1 / 1 / 2 a **1 / 2 / 3** por golpe (niveles 0 / 1 / 2). Contra el jefe 2 (50 PV) son 50, 25 y 17 golpes. Solo cambia el daño: recarga, velocidad, alcance, perforación, caja de golpe y alma por golpe (8) son los de antes; el nivel 0 queda exactamente igual.
- **Límite del equilibrio:** el daño de la onda es un entero, así que con las recargas actuales los únicos valores posibles son 1 → 45 s o 2 → 22,5 s en el nivel 1. No se puede llegar a los 32 s del objetivo; se eligió 2 (el paso mínimo por encima del nivel 0). El nivel 2 con 3 de daño (2,50 de daño por segundo) queda por debajo del tajo de dash (2,63) y un 8 % por encima del golpe pesado (2,31): dentro del 15 % pedido. A cambio, el jefe 1 con el nivel 2 sólo con la onda caería a 16 s (el límite pedido era unos 18 s): ver `docs/BALANCE_REPORT.md`.
- **Tarjeta y destello:** la tarjeta de la mejora de la onda dice «Daño ×2,0 (de 1 a 2 por golpe)» (el multiplicador sale del recurso) y el destello del impacto crece por nivel (×1,0 / ×1,25 / ×1,5), solo visual.

## Fase 15e-1: jefe 3 rediseñado en tres fases (cambio deliberado de diseño)

El jefe 3 pasa de 80 a 70 de vida y de una línea (50 %) a dos (66,7 % y 33,3 %). Se pierden sus dos volleys de proyectiles; ahora tiene rayo barredor y columnas de relámpago (ojo flotante), guardia (Kenzo) y ambas cosas más agresivas en la fase 3. Los jefes 1 y 2 no cambian. No hay claves de guardado ni autoloads nuevos.

## Fase 15e-2: huecos del nivel 3 rediseñados para el doble salto (cambio deliberado de diseño)

Los tres huecos del nivel 3 pasan de 285/175/285 px a 485/460/525 px y exigen salto + doble salto + dash. El nivel es 725 px más largo y su arena se desplazó entera sin cambiar su forma. Niveles 1 y 2 sin cambios. Sin claves de guardado ni autoloads nuevos.

## Fase 15e-2b: reequilibrio de los huecos del nivel 3

Los huecos pasan de 485/460/525 a 380/450/484 px para dar ritmo (fácil, medio, difícil): el primero ya no exige el dash. El nivel 3 es 569 px más largo que el original (antes 725).

## Fase 15e-2c: hueco 1 del nivel 3 a 336 px

El primer hueco pasa de 380 a 336 px (regla del 88 % del alcance de salto + doble salto). Los huecos 2 y 3 siguen en 450 y 484 px. El nivel 3 es 525 px más largo que el original.

## Fase 15e-3: retroalimentación de la guardia del jefe 3

Sin cambios de balance: se añadieron la etiqueta «BLOQUEADO», el medidor de guardia bajo la barra del jefe y una pista de una vez por pelea. Jefes 1 y 2 sin cambios.
