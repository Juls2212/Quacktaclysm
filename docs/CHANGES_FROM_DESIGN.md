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

## Fase 16a: Director de IA local

Nuevo: telemetría en memoria, planificador local determinista y plan por nivel (enemigos extra y pesos de patrones del jefe, dentro de topes). Activo desde el nivel 2. Sin red y sin IA remota todavía; sin claves de guardado ni autoloads nuevos. El nivel 1 y cualquier carga sin telemetría usan el plan neutro, idéntico al comportamiento anterior.

## Fase 16b: Director de IA remoto

La IA remota propone el plan del siguiente nivel (extras, pesos de patrones, tema y epílogo) dentro de los mismos topes y por la misma puerta de validación que el plan local, con el plan local como respaldo. Nueva opción «Adaptación con IA». Sin texto libre, sin claves de guardado ni autoloads nuevos; `max_profile_distance` sigue en 0.

## Fase 16c: la parte visible del Director

Nuevo: una línea breve del abuelo al empezar cada nivel (recuerdo en los niveles 1 y 2, voz directa en el 3), su reflejo de estrellas en el cielo y tres variantes de epílogo por final (12 textos). La petición al servicio admite `next_level = 4` (el final) y la respuesta un campo opcional `grandfather_line`. Los finales siguen decididos solo por las almas liberadas. Sin claves de guardado ni autoloads nuevos; la línea y la variante no se guardan.

## Fase 15f: capa de armadura e introducciones con Enter

La guardia de Kenzo pasa de 2 golpes a 1 y se dibuja como una capa de placas sobre su cuerpo (se quita el medidor de cajas bajo la barra). Cada guardián cuenta 4 líneas de su historia en la primera introducción, y todas las líneas de la introducción (guardián y pato) avanzan solo con Enter; antes avanzaban por tiempo y Enter saltaba todo (ahora lo hace mantener Enter).

## Fase 15g: escenario interactivo del nivel 3

Corrientes de aire, placas eléctricas, una ruta alta y decorado reactivo en el nivel 3, y tres corrientes en la arena del jefe 3 (sin plataformas ni placas). No cambian los huecos, los puntos de control ni los niveles 1 y 2.

## Fase 15h: dos finales

- Los cuatro finales (por almas liberadas) pasan a **dos**, por mayoría de las tres decisiones: guardadas > liberadas → «Estrellas que suben»; si no → «El acantilado». Los textos, estilos y pruebas de los cuatro finales antiguos se eliminaron. Los epílogos pasan de 12 a 6 (2 finales x 3 variantes).
- `EndingSelector.ending_id_for(released, kept)`. Las líneas del final avanzan solo con confirmar (desde la Fase 15i, `EndingCinematic`); la escena del abuelo antes del jefe 3 no cambia.
- «El acantilado» tiene manejo sensible (acto implícito, sin método, mensaje de apoyo en la tarjeta) y el menú «Acerca de» muestra un aviso de contenido; ambos viven en `default_story_texts.tres`. Sin claves de guardado ni autoloads nuevos.

## Fase 15h-bis: huecos del nivel 3

- Anchos de los huecos sin cambios (336 / 450 / 484 px): el modelo da ventanas de 360 ms (salto + doble salto), 375 ms (salto + dash) y 435 ms / 130 ms (cadena de tres acciones) en el hueco 1, y la cadena ya cumple los objetivos de los huecos 2 y 3. Falta la confirmación con el jugador real (ver KNOWN_ISSUES).
- Nueva regla: 250 px entre los enemigos y los bordes (antes 150) y enemigos de suelo que no se acercan al borde (`EnemyBase.set_edge_keepout`).
- Nuevo `GapGuard` en el nivel 3, `GapSafetyConfig` y la ayuda de la plataforma de restos tras 4 caídas; contador en memoria en `RunTelemetry.gap_falls`. Sin claves de guardado ni autoloads nuevos; los niveles 1 y 2 no cambian.

## Fase 15i: finales cinematográficos

- Los finales dejan de ser un `StoryReel` sobre `PrologueShots` y pasan a `EndingCinematic` + `EndingScene` + `GrandfatherPortrait`, con guion de beats en recursos. Se eliminó el código del epílogo de `PrologueShots` (el disparo `EPILOGUE`), el modo manual de `StoryReel` y la silueta de estrellas del abuelo en los finales (el recurso `default_ending_grandfather.tres`).
- «Estrellas que suben» pasa a una muerte larga y dolorosa del pato (unos 56 s de beats); «El acantilado» muestra el salto como silueta (unos 58 s de beats), con las reglas de seguridad del cierre. Textos de los dos finales reescritos; los 6 epílogos, la regla de selección, la línea de apoyo y el aviso de contenido no cambian.
- `EndingController` ya no tiene `reel_hold_scale`. `AudioDirector.play_event` gana un parámetro opcional de tono. Sin claves de guardado ni autoloads nuevos.

## Fase 15j: el jefe 3, rediseño v2

- **Quitado:** el ojo flotante de la fase 1 (`BossHover`, las inmersiones, la forma de ojo del `DuckRig`), el haz barredor (`BeamSweepPattern`), el patrón de columnas (`LightningColumnsPattern`, su matemática vive ahora en `StageMath`), `StormFx` y las 3 vigas de viento de la arena (con su `arena_wind_vent_config.tres`).
- **Fase 1:** el pato poseído solo (tajo, carga, andanada) y la coraza de la Fase 15f (solo en esta fase). **Fase 2:** ciclo de invocador. **Fase 3:** el ojo rojo en el cielo con rayo rojo y el pato sin coraza.
- Nuevo: `BossStage`, `SummonerCyclePattern`, `PlatformBarrage`, `StormEye`, `Duckling` («Patito corrupto», 1 PV, vale 5 de alma), `StageConfig`, el escudo en `BossShield`, `BossPattern.excluded_phases`, `BossBase.gravity_scale` y `exhausted`, `CombatLayers.LAYER_BOSS_PERCH`, `SoulComponent` admite que un enemigo fije lo que vale su golpe.
- Sin claves de guardado ni autoloads nuevos; el pasillo, los huecos y los enemigos del nivel 3 no cambian; los niveles 1 y 2 siguen idénticos.

## Fase 15i-bis: finales en un acantilado, cortes y arrepentimientos

- Los dos finales en un acantilado; los dos se cortan a blanco o al cielo antes del acto. El paso al vacío de «El acantilado» (Fase 15i) se quitó: la regla de seguridad nueva prohíbe mostrarlo; el pato llega al borde, baja la cabeza y la cámara sube al cielo. Se quitaron también la espada y la capa del borde (la causa de la barra rara) y la espada que caía.
- «El acantilado»: el abuelo ya no llora; aparece impasible (estado nuevo `solemn` del retrato) y dice solo «Se ha sellado la profecía.». «Estrellas que suben»: la corrupción le toma la mano, el pato se resiste y se arrepiente, y el final se corta a blanco antes de nada.
- Las líneas, los guiones de beats y los 6 epílogos se reescribieron; el mensaje de apoyo sale en los dos finales y el aviso de contenido dice «dos finales».
- Audio: 4 ranuras de graznidos y 2 ranuras de música (`EndingMusicSlot`) en `default_audio_events.tres`; `EndingStory.music` desaparece. Sin claves de guardado ni autoloads nuevos.

## Fase 15k: sangre en el combate

- La propuesta del proyecto prometía sangre en el combate y solo había chispas. Se añade sangre estilizada (gotas, salpicaduras cortas y manchas que se desvanecen; sin desmembramientos, vísceras ni gore persistente) con la opción «Sangre» (activada por defecto, solo en `settings.cfg`).
- Solo en el combate de juego: nunca en los finales, el prólogo ni las escenas de historia (una prueba lo comprueba).
- El aviso de contenido de «Acerca de» menciona ahora la violencia estilizada con sangre.
- Sin claves de guardado ni autoloads nuevos; es un nodo hijo de `level_base.tscn`.
- El «bruto con armadura» del encargo no existe como mecánica en los enemigos: la regla general (golpe aplicado = sangra, golpe bloqueado = solo chispas) cubre cualquier armadura o guardia que use `hit_filter`.

## Fase 15l: final sin trabones, arte del final, venas reutilizables y absorción oscura

- «Estrellas que suben»: las capas grandes ya no se redibujan en cada fotograma (frecuencia exportada), hay un vigilante de rendimiento (modo ligero) y topes de seguridad: ningún beat dura más que el máximo y una línea sin respuesta avanza tras el límite (antes solo avanzaba con la confirmación; el límite es muy largo, 120 s).
- Ojo, ala y venas rediseñados (ojo con borde oscuro, iris violeta con grietas y brillo; ala del rig con plumas y manga en el hombro; venas ramificadas que siguen el cuerpo).
- Venas moradas del pato en el juego desde el primer fragmento conservado, según el número de fragmentos (sin claves de guardado nuevas).
- Absorción al conservar un fragmento: secuencia oscura de 3,6 s en lugar del exorcismo rojo de 6 s; la liberación no cambia.

## Fase 15m: tutorial reconstruido

- Los pasos dejan de ser una cadena ordenada: son comprobaciones independientes que se acreditan en cualquier orden (también antes de pedirlas). El muñeco revive tras 1,0 s y hay una pulsación larga de confirmar para saltar el tutorial.
- Se quitan los pasos de la onda de espada y del tajo de dash (la onda llega después con los fragmentos); se añade el paso del medidor de alma y el de la pausa (opcional). Lista de tareas, carteles de práctica y frases del muñeco.
- Siete pasos son obligatorios para abrir la salida; ninguna clave de guardado ni autoload nuevo. Los niveles 2 y 3 no cambian.

## Fase 15n: diálogos cortos, fragmentos azules, graznidos, sonido del prólogo, rostro del abuelo y final sin tarjeta

- Las introducciones de 4 líneas + monólogo del pato (Fases 15b/15f) se sustituyen por UNA línea del guardián y a lo sumo una del pato; al caer, 2–3 líneas con su historia y últimas palabras antes de la decisión. Se quitan las variantes por perfil de esas líneas.
- Los enemigos normales sueltan un fragmento azul (antes un destello pálido); los patitos del jefe 3 sueltan uno pequeño con su valor y su golpe mortal ya no paga por sí mismo (se cuenta una sola vez).
- Cada golpe que aterriza en un pato enemigo graznido (varios sonidos, tono aleatorio, límites por objetivo y global); antes era un solo graznido por objetivo.
- El prólogo tiene música (procesada) y efectos; el abuelo aparece con su retrato en el cielo en lugar de la silueta de estrellas.
- Tras el jefe 3 ya no sale tarjeta: el fragmento 3 no otorgaba ningún poder mecánico (la onda sube solo con los fragmentos 1 y 2); solo sube el coste de curar (+5 por fragmento conservado), que se mantiene.

## Fase 15o: absorción roja, sin columnas de viento, sin armadura del jefe 3 y corrupción dentro del rig

- La absorción de la Fase 15l (viñeta morada) se sustituye por el fondo oscuro con toques rojos y el emblema abajo, con rayos rojos, partículas y zarcillos que convergen en el pato; dura lo mismo (3,6 s) y la liberación luminosa no cambia. Sin tarjeta tras el jefe 3 (Fase 15n, se mantiene).
- Nivel 3: fuera las dos columnas de viento y la ruta alta que dependía de una; el nivel se completa igual (nunca fueron obligatorias).
- Jefe 3: sin armadura en ninguna fase (vida y umbrales iguales). En la fase 1 antes solo el golpe pesado y el tajo de dash hacían daño; ahora cualquier golpe. Con la onda y la espada ligera la fase 1 pasa de unos 65 s a unos 30 s; el escudo de la fase 2 (patitos) se mantiene.
- La corrupción del pato deja de ser capas encima: venas recortadas a cada pieza, iris, plumas, manga y ala cambian dentro del propio rig. Los finales usan un solo dibujo por pose. Nueva ranura opcional de imágenes propias.

## Fase 15p: restos de la 15o

- La vida del jefe 3 sube a 102 PV (líneas 0,451 y 0,2255) para que la fase 1 sin armadura dure unos 24 s ideales; las fases 2 y 3 conservan sus 23 PV.
- `BossGuard` pasa a `BossShield` y `GuardFx` a `ShieldFx` (sin cambio de comportamiento).
- Dos pruebas antiguas estaban desfasadas, no el juego: la que esperaba que el jefe cayera en cualquier estado (desde la Fase 15e-1 solo cae en la última fase) y la que esperaba huecos de 285/175/285 px en el nivel 3.

## Fase 15q: arreglos tras la suite completa

- Sin cambios de diseño. Dos errores reales del juego corregidos (la plataforma de ayuda de los huecos se añadía dentro de un callback de física; la lista de patitos del jefe 3 borraba instancias liberadas a través de un arreglo tipado) y uno más (un enemigo con el jugador liberado leía su posición). El dibujo de la imagen propia del pato se separó en una consulta pura (`DuckRig.override_texture`) y el dibujo.
- Pruebas puestas al día con el diseño vigente: la carga del jefe solo es elegible con un carril de al menos 220 px (Fase 15d-bis), el lanzamiento del nenúfar es −930 (15d-bis), el jefe 3 no tiene caparazón (15o), sus últimas palabras retienen al jugador y retrasan el fragmento (15n), y el ciclo de invocación del jefe 3 necesita el escenario del nivel.

## Fase 15r: el abuelo desde su figura, siluetas en los finales y el alma del guardián

- La cara dibujada del abuelo (Fase 15i) se sustituye por su figura de cuerpo entero con el cuerpo en la niebla (opacidad 0,4 / 0,6 / 0,7). Se retira el código de lágrimas.
- Los dos finales muestran siluetas planas sobre el blanco del corte; el blanco dura 0,5 s más. El acto sigue sin mostrarse y las reglas de seguridad no cambian.
- Los guardianes dejan un alma que dice las líneas de despedida y se convierte en el fragmento; el fragmento sale al terminar el alma, sin la espera restante de antes.
- Pruebas puestas al día a propósito: `phase15i` (el retrato dibujado y sus lágrimas por la figura y la niebla), `phase15n` y `phase16c` (estados y lágrimas del retrato).

## Fase 15t: última línea, créditos animados, créditos únicos y ambiente

- La última línea del final conservado pasa de «Perdóname, nieto.» a «Se ha sellado la profecía.», igual que el del acantilado. El abuelo solo aparece (sereno) para decirla; se quitan sus compases de pena (`grandfather_breaking`, `grandfather_solemn`) y su presencia llorosa junto al pato arrodillado. Los estados `grieving`/`breaking` siguen existiendo en `GrandfatherSky` para el resto del juego, pero ningún final los usa.
- Tras la última línea hay una secuencia de créditos y estadísticas animada (antes, la tarjeta de estadísticas salía de golpe). Un salto (mantener Enter) va directo a la tarjeta final, como antes.
- La sección «Créditos» del menú y los créditos del final comparten un recurso; se retiran los cargos del equipo (solo nombres) y se amplía el contenido.
- El viento de los finales dejó de ser el sonido del dash bajado de tono y repetido: ahora son ráfagas suaves de un espacio de ambiente.
- Pruebas puestas al día a propósito: `phase15i`, `phase15h`, `phase14e` (la última línea y los estados del abuelo en los finales).
