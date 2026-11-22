# Lista de pruebas manuales (QA en ventana real)

Todo lo que sigue se probó solo con pruebas automáticas en modo headless (sin ventana, sin sonido, sin ojos). Esta lista reúne cada punto «sin verificar en una ventana real» de `KNOWN_ISSUES.md` y de las notas de las fases 14b a 14g, en el orden en que se puede jugar de una sola vez.

## Cómo usarla

1. Usa una **build de depuración** (el editor de Godot con F5, o `godot --path game`): las teclas de depuración solo existen ahí. Una build exportada de lanzamiento no las tiene.
2. Haz una copia de tu archivo de guardado antes de empezar si te importa (`%APPDATA%\\Godot\\app_userdata\\Quacktaclysm\\`). Las pruebas automáticas **nunca** lo tocan; jugar sí.
3. Rellena las dos últimas columnas de cada fila: **Resultado real** y **Gravedad** (Bloqueante / Alta / Media / Baja / Estética).

### Teclas de depuración (solo en depuración)

| Tecla | Hace |
|---|---|
| F2 | Te lleva al checkpoint de la arena del jefe |
| F4 | Mata al jefe de golpe (y el fragmento aparece) |
| H | Quita el 10 % de la vida del jefe |
| F3 | Muestra u oculta el panel de información |

### Formato para informar de un fallo

`ID / grupo / pasos / esperado / real / gravedad`, por ejemplo:
`COR-03 / aspecto corrupto / liberar 0 almas, entrar al nivel 3 / viñeta oscura en los bordes sin tapar el suelo / la viñeta tapa los pinchos de la derecha / Alta`.
Añade una captura o un vídeo corto si puedes.

### Atajos para ver los cuatro finales

Cada final depende solo de cuántas almas liberas (3, 2, 1, 0). El camino más rápido, en depuración: en cada nivel pulsa **F2** (arena) y **F4** (matar al jefe), camina hasta el fragmento que suelta, y elige **Liberar** o **Conservar** en el panel. Con el nivel 3 hecho, el juego abre el final solo.

| Final | Elecciones (nivel 1, 2, 3) |
|---|---|
| El cielo se abre | Liberar, Liberar, Liberar |
| La cicatriz del cielo | Liberar, Liberar, Conservar (o cualquier mezcla con 2 liberadas) |
| El filo y la duda | Conservar, Conservar, Liberar (o cualquier mezcla con 1 liberada) |
| La nueva estrella caída | Conservar, Conservar, Conservar |

Para repetir con otras elecciones: Menú principal → «Nueva partida» (confirma que reemplaza el guardado).

## La lista, en orden de juego

| ID | Grupo | Pasos | Resultado esperado | Resultado real | Gravedad |
|---|---|---|---|---|---|
| MEN-01 | Menús | Abre el juego. Mira el menú principal; pasa el ratón y el teclado por los botones | Se ve la ola de sombras y el título; los botones se pueden usar con ratón y teclado; cada hover/foco suena (`ui_hover`) y cada confirmación suena (`ui_click`) | | |
| MEN-02 | Menús | Opciones desde el menú principal: mira que quepan todas las filas (pantalla completa, 3 volúmenes, sacudida de cámara, «Efectos de corrupción», «Controles…») | Todo cabe en el panel sin salirse; nada se solapa (#40) | | |
| MEN-03 | Menús | «Nueva partida» con un guardado existente | Pide confirmación; al aceptar empieza el prólogo | | |
| HIS-01 | Historia / finales | Prólogo completo sin saltar (≈ 2 min) | Los subtítulos se leen con comodidad; el ritmo de cada plano es bueno; la música acompaña (#41) | | |
| HIS-02 | Historia / finales | Repite el prólogo y salta con Esc, luego con clic en «Saltar» | Salta limpio, el tutorial queda jugable, el jugador no queda bloqueado | | |
| NIV-00 | Niveles | Tutorial: mover, saltar, esquivar, atacar, muñeco, onda, golpe pesado, tajo de dash, curarse (9 pasos) | Cada paso se completa; los textos muestran las teclas actuales (también tras remapear) | | |
| MOV-01 | Niveles | En el tutorial, sensación general: movimiento, salto, dash, espada, onda (#1) | Responde bien; sin retrasos raros ni atascos | | |
| AUD-01 | Audio | Corre por el suelo en el tutorial y en un nivel | Se oye un paso rítmico, bajo, que acompaña el ciclo de carrera (#52, #55); no suena en el aire ni al parar | | |
| AUD-02 | Audio | Salta, aterriza, esquiva, ataca, lanza la onda | Todos suenan distintos y a un volumen cómodo | | |
| NIV-00b | Niveles | Termina el tutorial: pisa el portal | El portal se enciende con un sonido grave y entrar suena distinto; después hay un cambio de escena con su sonido | | |
| NIV-01 | Niveles | Nivel 1: observa la tarjeta de título y la línea de consecuencias | El título aparece y sube sin tapar nada; suena el sonido del título; la línea («Cada alma que liberes…») se lee (#31) | | |
| HUD-01 | HUD | En el nivel 1 mira la vida, la barra de la onda y la placa de corrupción | 8 corazones en la barra; la placa dice «Neutral 0»; nada se solapa con el jugador | | |
| ENE-01 | Enemigos | Cada tipo de enemigo en el nivel 1: cuerpo a cuerpo, rápido, a distancia | Cada uno muestra su aviso (arco, carril, línea) que **se llena** durante la preparación, con exclamación sobre la cabeza y un sonido distinto; el aviso desaparece al empezar el golpe (#47) | | |
| ENE-02 | Enemigos | Golpea a un enemigo | Destello blanco corto, un pequeño rebote, sonido de golpe; no cambia lo lejos que sale despedido | | |
| ENE-03 | Enemigos | Fíjate en un enemigo justo después de atacar | Se ve apagado un instante (la ventana para castigarlo) | | |
| ENE-04 | Enemigos | Mata a un enemigo | Plumas y una pequeña alma azul que sube | | |
| PRO-01 | Enemigos | Deja que te dispare el enemigo a distancia | El proyectil se ve con contorno oscuro y halo rojo-anaranjado; se distingue claramente de la onda azul del jugador (#53); suena al chocar con el suelo y al alcanzarte | | |
| PRO-02 | Enemigos | Lanza tu onda de espada contra un enemigo y contra una pared | La onda suena distinta de los proyectiles enemigos en ambos casos | | |
| NIV-01b | Niveles | Nivel 1: recorre hasta el jefe, comprueba cámara y huecos | La cámara no se pasa de los límites; los huecos de dash (285 px) se cruzan sin sufrir (#3, #8, #26) | | |
| BOS-01 | Jefes | Entra en la arena del jefe 1 | La presentación VS aparece con acorde grave; se salta con Enter/clic; la música cambia a la del jefe 1 (`the_evil_one` normal) y baja un poco durante la presentación (#52) | | |
| BOS-02 | Jefes | Al empezar el combate escucha y lee los subtítulos del guardián | Dice 2 o 3 líneas («El Leñador: …») sin bloquearte; Enter las salta; no se repiten si mueres y reintentas | | |
| BOS-03 | Jefes | Observa los tres ataques del jefe 1 (golpe, embestida, descarga en fase 2) | Cada aviso tiene su forma: arco ancho, carril largo, abanico; se llenan al ritmo de la preparación; suenan distintos (#47) | | |
| BOS-04 | Jefes | Llega a la fase 2 del jefe 1 | Sonido de rabia; el aviso no se rompe; la música no cambia de forma rara | | |
| BOS-05 | Jefes | Mata al jefe 1 (o F4) | Una línea de despedida; la música vuelve a la del nivel; aparece el fragmento | | |
| DEC-01 | Decisiones | Recoge el fragmento del nivel 1 | El panel muestra «Daigo, el Leñador», su recuerdo y, bajo cada botón, qué le pasa al alma (que se lean los textos largos) | | |
| DEC-02 | Decisiones | Elige **Liberar** | Suena el sonido de liberar; la placa de corrupción cambia a «Compasivo +1» con un destello; el aspecto del mundo se vuelve cálido poco a poco | | |
| COR-01 | Aspecto corrupto | Nivel 2 tras liberar (compasivo): mira fondo, viñeta, aura del pato | Más cálido y dorado; el aura del pato se ve sin tapar nada (#36) | | |
| HUD-02 | HUD | Tras liberar una alma, mira la barra de vida en el nivel 2 | 9 corazones (+1 por alma liberada); la barra cabe | | |
| NIV-02 | Niveles | Nivel 2: recorrido completo | Dificultad razonable; sin zonas injustas; enemigos extra según perfil (#2, #21) | | |
| BOS-06 | Jefes | Jefe 2 (La Cosa del Pantano) | Música distinta (`treacherous_path`); subtítulos; avisos de golpe, embestida y descarga | | |
| DEC-03 | Decisiones | Nivel 2: elige **Conservar** | Suena distinto al de liberar; placa «Neutral 0»; el pato gana el poder de la espada (la onda mejora) | | |
| HIS-03 | Historia / finales | Entra al nivel 3 desde su inicio | Aparece la escena del abuelo (≈ 20 s) con la cueva y su antorcha, sus líneas se leen, cambia según las almas liberadas, y Enter la salta; el juego queda en pausa mientras dura (#41, #42) | | |
| NIV-03 | Niveles | Nivel 3: recorrido completo | Dificultad razonable, avisos legibles con la tormenta de fondo | | |
| BOS-07 | Jefes | Jefe 3 (El Ojo de la Tormenta) con cada variante de perfil | Música `the_evil_one` algo más rápida; sus líneas y su variante según el perfil; descarga ligera, embestida y descarga pesada legibles | | |
| COR-02 | Aspecto corrupto | Repite un nivel con **0 liberadas** (perfil corrupto) | Fondo violeta frío, viñeta en los bordes, ojos y aro brillantes en los enemigos, música más grave y apagada | | |
| COR-03 | Aspecto corrupto | Con el aspecto corrupto, comprueba la legibilidad de plataformas, pinchos y proyectiles | Todo se sigue leyendo bien (el fondo corrupto va a ×0,7 y la viñeta a 0,55 en las esquinas) | | |
| COR-04 | Aspecto corrupto | Opciones → apaga «Efectos de corrupción» con un nivel abierto | Vuelve todo a neutral (sin viñeta, sin tinte, sin brillo, sin filtro de música); la placa y la línea de consecuencias se quedan; los avisos de ataque siguen visibles (#39) | | |
| AUD-03 | Audio | Escucha un nivel con el aspecto corrupto | La música suena más grave y apagada sin ser molesta (#52) | | |
| AUD-04 | Audio | Habla un guardián / se muestra el abuelo | La música baja un poco y vuelve al terminar (#52, #57) | | |
| FIN-01 | Historia / finales | Final «El cielo se abre» (3 liberadas) | Secuencia de ≈ 35-60 s con título, 7 líneas, epílogo dorado con estrellas que suben y música `title_screen`; mantener Enter la salta; luego la tarjeta de resumen con los nombres | | |
| FIN-02 | Historia / finales | Final «La cicatriz del cielo» (2 liberadas) | Nombra el alma guardada en las líneas 1 y 3; epílogo al atardecer; música `castle_on_the_mountain`; resumen correcto | | |
| FIN-03 | Historia / finales | Final «El filo y la duda» (1 liberada) | Nombra la única alma liberada; epílogo nocturno con una estrella brillante; música `dungeon` | | |
| FIN-04 | Historia / finales | Final «La nueva estrella caída» (0 liberadas) | Epílogo rojo, estrellas que caen, el pato con aura y ojos violetas; música `the_evil_one`; la tarjeta dice «Liberadas: ninguna» | | |
| FIN-05 | Historia / finales | En cada final, pulsa Enter una vez y luego mantenlo | Una pulsación corta no salta; mantener ≈ 1,2 s salta a la tarjeta | | |
| FIN-06 | Historia / finales | En la tarjeta pulsa «Volver al menú principal» | Vuelve al menú; la música vuelve a la del menú sin filtro ni pitch raro | | |
| CON-01 | Controles | Opciones → «Controles…»: cambia una acción (p. ej. saltar a otra tecla) | La captura funciona con teclado y ratón; el cambio se aplica al instante; Esc cancela la captura (#32) | | |
| CON-02 | Controles | Asigna una tecla ya usada por otra acción | Pregunta si intercambiar o cancelar | | |
| CON-03 | Controles | Cierra el juego y ábrelo otra vez | Los controles cambiados siguen; los textos del tutorial muestran las teclas nuevas | | |
| CON-04 | Controles | «Restaurar valores por defecto» | Todo vuelve a la tabla por defecto | | |
| CON-05 | Controles | Abre las opciones desde la pausa de un nivel | Misma pantalla de controles; el juego sigue pausado; al cerrar se puede jugar | | |
| ALM-01 | Alma y curación | En el nivel 1 golpea a un enemigo con la espada, el golpe pesado, el tajo de dash y la onda; mira la barra de alma del HUD (bajo la placa de corrupción) | La barra sube a trompicones (11 / 22 / 16 / 8 de 99); suena un tic suave sin molestar al golpear rápido (#63, #64, #66) | | |
| ALM-02 | Alma y curación | Mata a un enemigo y a un jefe | Sale una alma azul que vuela hacia el pato y sube la barra al llegar (+11 enemigo, +33 jefe); si mueres antes de que llegue no se absorbe | | |
| ALM-03 | Alma y curación | Con la vida a medias y el alma por encima de la marca, mantén **E** (o **Q**) | El pato queda quieto 0,9 s con un efecto de anillos y chispas; recupera 1 corazón, gasta el coste y suena el final (#63) | | |
| ALM-04 | Alma y curación | Empieza a enfocar y suelta la tecla a la mitad; luego empieza otra vez y deja que te golpeen; luego esquiva (dash) | En los tres casos se interrumpe y **no** gasta alma ni cura | | |
| ALM-05 | Alma y curación | Pulsa curar con la vida llena y con poca alma | No empieza el enfoque, no gasta nada y suena un tono bajo de "no se puede" | | |
| ALM-06 | Alma y curación | Pulsa curar en el aire, mientras estás pausado y durante una cinemática | No hace nada | | |
| ALM-07 | Alma y curación | Conserva un fragmento (y luego otro) y mira la marca de coste en la barra de alma y la línea de consecuencias del nivel siguiente | El coste sube de 33 a 38, 43 y 48; la marca se mueve a la derecha; la línea dice «curarse cuesta N de alma» | | |
| ALM-08 | Alma y curación | Llega al máximo de alma | La barra se llena, brilla cuando alcanza el coste y suena el aviso de "lleno" | | |
| ALM-09 | Alma y curación | Muere y reaparece en el checkpoint; carga otro nivel | El medidor vuelve a 0 en ambos casos | | |
| ALM-10 | Alma y curación | Intenta curarte en plena pelea con un jefe | Se puede, pero un golpe lo interrumpe; anota si es viable o frustrante (#67) | | |
| TAR-01 | Tarjeta de habilidad | En el tutorial llega al paso de curarse | Aparece la tarjeta «Nueva habilidad: Curarse» a pantalla completa con las teclas actuales (E o Q) y «Puedes cambiarla en Opciones → Controles»; el juego queda en pausa; Enter la cierra y no vuelve a salir (#65) | | |
| TAR-02 | Tarjeta de habilidad | En el tutorial golpea al muñeco para reunir alma y mantén la tecla | El paso se completa (con la vida llena gasta el alma y no cura) y se abre la salida | | |
| TAR-03 | Tarjeta de habilidad | Conserva el fragmento del nivel 1 o 2 | Tras el exorcismo aparece la tarjeta con el nivel nuevo de la onda de espada y el nuevo coste de curarse; Enter la cierra | | |
| TAR-04 | Tarjeta de habilidad | Reasigna «Curarse» en Opciones → Controles y repite TAR-01 o TAR-03 | La tarjeta muestra la tecla nueva | | |
| CON-06 | Controles | En Opciones → Controles mira la fila «Curarse (enfocar)» y reasígnala | Aparece con E y Q por defecto; se puede cambiar, intercambiar y restaurar como las demás | | |
| DSH-01 | Dash invulnerable | Esquiva (dash) dentro de un ataque de enemigo, de un proyectil y de un golpe de jefe, varias veces, hasta el último instante del dash | No recibes daño en ningún momento del dash; un aura pálida te rodea mientras dura; justo al terminar sí puedes recibir daño (#72) | | |
| DSH-02 | Dash invulnerable | Haz un dash hacia un hueco del suelo sin suelo al otro lado, o hacia la zona de muerte | Caes y mueres igual: el dash no protege de caerse | | |
| TAR-05 | Tarjeta tras la animación | Conserva un fragmento del nivel 1 o 2 | Primero ocurre toda la animación de corrupción y **solo después** aparece la tarjeta «Nueva habilidad»; nunca encima de la animación ni dos a la vez (#70) | | |
| TAR-06 | Tarjeta tras la animación | Libera un fragmento | Sale su animación y no aparece ninguna tarjeta | | |
| JEF-10 | Introducción del jefe | Entra por primera vez en la arena de cada jefe (partida nueva) | Presentación «VS», saludo del guardián y 6 líneas del pato (capítulo del abuelo / el filo y el silencio / Kenzo y la duda); el jefe no se mueve ni ataca y tú no puedes moverte ni recibir daño; al acabar empieza el combate (#69) | | |
| JEF-11 | Introducción del jefe | Pulsa Enter durante las líneas | Se saltan todas a la vez y el combate empieza de inmediato; una pulsación justo al empezar no las salta | | |
| JEF-12 | Introducción del jefe | Muere en el jefe y reintenta; luego sal, usa «Continuar» desde el checkpoint de la arena y entra | No se repite ninguna de las dos veces: el combate empieza en cuanto entras | | |
| ARE-01 | Arena continua | Recorre cada arena de la puerta al muro derecho (salta y esquiva por el borde) en los tres niveles | El suelo es continuo, no hay hueco ni forma de caer fuera; en el nivel 1 el final de la arena es sólido (#71) | | |
| ARE-02 | Arena continua | Antes de cada arena cruza los saltos de 170-175 px (solo salto) y 285 px (con dash) | Siguen estando y siguen siendo posibles | | |
| NEN-01 | Nenúfares | En la arena del nivel 2 salta y cae sobre un nenúfar; luego camina por encima de otro | Cayendo te lanza unos 300 px hacia arriba con un chasquido y el nenúfar se aplasta; caminando no pasa nada; soltar la tecla de salto en pleno vuelo no corta el impulso (#74) | | |
| NEN-02 | Nenúfares | Mira cómo sube el jefe; intenta que un enemigo o el jefe pise un nenúfar | Los enemigos y el jefe lo ignoran | | |
| PLA-01 | Plataformas | Sube al piso bajo saltando; intenta llegar al alto saltando (con dash) sin nenúfar | El piso bajo se alcanza con un salto normal; el alto no | | |
| PLA-02 | Plataformas | Llega al piso alto con un nenúfar; después de liberar o conservar el alma del jefe 2, sube al alto desde el bajo con el doble salto | Las dos formas funcionan; la cámara muestra toda la altura (#75) | | |
| PIN-01 | Pinchos | En la fase 2 del jefe 2 observa el suelo | Aviso 1,2 s (el suelo brilla y burbujea, asoman las puntas), 3 s de pinchos, 4 s de descanso; legibles sobre el pantano (#74) | | |
| PIN-02 | Pinchos | Déjate pinchar; luego esquiva con el dash por encima; sube a una plataforma o a un nenúfar | 1 corazón por golpe y 1 s de invulnerabilidad; el dash los atraviesa; plataformas y nenúfares son seguros | | |
| PIN-03 | Pinchos | Mata al jefe, muere tú o sal al menú con los pinchos activos | Los pinchos desaparecen al instante | | |
| SAL-01 | Salto del jefe | Observa los saltos del jefe en las dos fases | Se agacha 0,7 s con el marcador amarillo en el suelo/plataforma donde caerá; salta, dispara hacia abajo desde arriba y vuelve a bajar; el aterrizaje hace daño en una zona pequeña; se le puede golpear arriba (#74, #76) | | |
| SAL-02 | Salto del jefe | Pásale la barra de vida a la fase 2 en pleno salto | El salto se cancela limpio: sin marcador, sin disparos sueltos y el jefe cae al suelo | | |
| DOB-01 | Doble salto | Antes de decidir sobre el jefe 2 intenta saltar dos veces; después de decidir repítelo | Antes no hay segundo salto; después hay uno (85 % del primero), una vez por salto, con un anillo bajo los pies; el dash no lo gasta | | |
| DOB-02 | Doble salto | Decide sobre el alma del jefe 2 conservándola y luego liberándola (partidas distintas) | Conservar: animación de corrupción, tarjeta de la onda y tarjeta «Doble salto»; liberar: solo la tarjeta «Doble salto»; la tarjeta nombra la tecla de salto actual | | |
| DOB-03 | Doble salto | Tras decidir sobre el jefe 2, cierra el juego y usa «Continuar» | El doble salto sigue desbloqueado (y la tarjeta no vuelve a salir) | | |
| POS-01 | Posesión | Lleva a cada jefe (1, 2 y 3) justo por debajo de la línea de su barra | Empieza la secuencia de ~3 s: el jefe se eleva y tiembla con los ojos rojos, el fondo y el cielo se vuelven rojos con una viñeta que late, sube un temblor ligero y hay dos destellos rojos suaves; la línea de la barra late; el pato queda quieto e invulnerable (#79) | | |
| POS-02 | Posesión | Cruza la línea con enemigos disparando proyectiles y, en el jefe 2, observa el suelo | Los proyectiles enemigos en el aire desaparecen; los pinchos del jefe 2 NO salen durante la secuencia y empiezan al terminar | | |
| POS-03 | Posesión | Tras la secuencia, sigue peleando la fase 2 | El jefe conserva un brillo rojo y el fondo un tinte rojo sutil; se lee bien el suelo, las plataformas, los pinchos y los proyectiles (#80); al matar al jefe o morir el aspecto se desvanece | | |
| POS-04 | Posesión | Desactiva «Efectos de corrupción» en Opciones y repite POS-01 | Sin tinte, destello, temblor ni viñeta: una pausa de 1 s con el cambio de pose del jefe y el sonido; el pato se libera igual | | |
| POS-05 | Posesión | Muere en plena secuencia (por ejemplo cayendo) o pausa con Esc durante ella | Al morir se cancela limpia, el jefe vuelve al inicio y el pato reaparece libre; con la pausa la secuencia se detiene y sigue al reanudar | | |
| POS-06 | Posesión | Reintenta el combate tras morir en la fase 2 | Empieza en la fase 1 sin rojo; la secuencia vuelve a ocurrir al cruzar la línea; no suena el sting de la fase 2 encima de los sonidos de la posesión | | |
| BAL-02 | Jefe 2 | Pelea el jefe 2 completo | El salto del jefe se ve menos seguido que antes (peso 1,2 en la fase 2; recargas 7 s y 8 s); sigue siendo difícil pero se puede golpear (#76) | | |
| IDL-01 | Jefe 2 sin pausas | Pelea el jefe 2 quedándote en otra plataforma, al otro lado, encima o sobre un nenúfar | El jefe siempre acaba atacando en menos de ~1,5 s (descarga hacia ti, salto hacia tu plataforma o pisotón); nunca se queda quieto (#84, #85) | | |
| EMB-01 | Embestida | Lleva al jefe 2 a una plataforma y espera su embestida; luego míralo en el suelo cerca de un muro | En una plataforma nunca embiste; en el suelo el telegrafiado muestra el carril real (más corto junto a un muro) y el golpe cubre todo el carril | | |
| NEN-03 | Nenúfares elevados | Salta desde el suelo hacia un nenúfar; camina por debajo; fíjate en el tallo | Los nenúfares flotan a unos 56 px; el tallo curvo se comprime como un muelle al lanzar; se camina por debajo sin que se active; hay que caer encima (#83) | | |
| NEN-04 | Nenúfares elevados | Usa un nenúfar durante los pinchos de la fase 2 | La cima del nenúfar es un refugio; el suelo bajo él no (#86); el margen de refugio sigue siendo cómodo | | |
| LAR-01 | Jefe 2 más corto | Pelea el jefe 2 completo | Dura menos que antes (50 PV); la línea de la barra está en 27,5 PV y la posesión sale una vez (#83) | | |
| ONDA-01 | Colores de la onda | Lanza la onda sin fragmentos conservados, conservando uno del nivel 1 y conservando los dos | Azul-blanco, esmeralda y violeta con núcleo oscuro; cada uno con más estela y brillo; ninguno parece un proyectil enemigo (esos son rojo-naranja); el violeta se ve sobre el fondo corrupto | | |
| ONDA-02 | Colores de la onda | Conserva el fragmento del nivel 1 o del 2 | La tarjeta «Onda de espada» enseña el color nuevo; el destello al impactar es del mismo color | | |
| ONDA-03 | Daño de la onda | Contra el jefe 2, lanza solo ondas con el nivel 0 (sin fragmentos conservados) durante ~10 golpes y mira cuánta barra baja | Cada onda quita 1 PV de 50; se tardan unos 50 golpes (unos 50 s) | | |
| ONDA-04 | Daño de la onda | Igual, con un fragmento conservado (nivel 1, esmeralda) | Cada onda quita 2 PV: unos 25 golpes (unos 22 s); se nota el doble que en el nivel 0; la tarjeta dice «Daño ×2,0» | | |
| ONDA-05 | Daño de la onda | Igual, con los dos conservados (nivel 2, violeta) | Cada onda quita 3 PV: unos 17 golpes (unos 20 s); la tarjeta dice «Daño ×3,0»; el destello del impacto es el más grande; no resulta trivial contra el jefe 1 (#87) | | |
| PAU-01 | Menús | Pausa con Esc y con P en un nivel; reanuda | Se abre y cierra bien; la música sigue; ninguna entrada se pierde | | |
| PAU-02 | Menús | Ajusta los volúmenes en la pausa | La música y los efectos obedecen a los deslizadores y al volumen general | | |
| GAM-01 | Menús | Muere a propósito (cae a un pozo o deja que te maten) | Sonido de muerte, música de Game Over, panel con sonido; «Reintentar» y «Menú» funcionan; el jefe no repite sus líneas | | |
| GAM-02 | Menús | Muere en medio del combate con un jefe y reintenta | El jefe se reinicia; la música del jefe vuelve a su pista; no queda la música de Game Over | | |
| CNT-01 | Menús | Cierra a mitad del nivel 2 y usa «Continuar» | Retoma en el último checkpoint con el perfil y los corazones correctos | | |
| CNT-02 | Menús | Tras ver un final, cierra y usa «Continuar» | Reabre el final correspondiente | | |
| MEN-04 | Menús | Fundidos entre escenas y entre pausa y Game Over | Suaves, ni muy lentos ni bruscos (#5) | | |
| GEN-01 | General | Una sesión completa de principio a fin | Sin errores en la consola de Godot; sin cuelgues; sin música apilada tras cambiar de nivel varias veces | | |
| GEN-02 | General | Apunta la sensación de dificultad de cada nivel con cada perfil | Anota si algún jefe es demasiado fácil o difícil (compara con `docs/BALANCE_REPORT.md` si existe) (#2, #21, #24, #27) | | |

## Jefe 3: El Ojo de la Tormenta (Fase 15e-1)

- [ ] Fase 1: el ojo flota, baja cada ~3 s y puede golpearse con onda desde el suelo en el picado, y con espada desde el salto (simple o doble).
- [ ] El rayo avisa >= 0,9 s con carril y chevrones; se esquiva saltando o con dash.
- [ ] Las columnas avisan >= 1,0 s, golpean 0,4 s y siempre queda un carril seguro alcanzable.
- [ ] Fase 2 (66,7 %): posesión; Kenzo con guardia (espada ligera y onda rebotan con chispa); tajo fuerte o tajo de dash x2 la rompe; aturdido 2,5 s; se regenera.
- [ ] Fase 3 (33,3 %): segunda posesión, cae la guardia, el ojo vuelve, rayo y columnas más frecuentes.
- [ ] La barra de vida muestra dos marcas que pulsan al cruzarse.
- [ ] Con "Efectos de corrupción" desactivado no hay destellos.
- [ ] Morir o reintentar en cualquier fase reinicia todo en la fase 1.

## Nivel 3: huecos (Fase 15e-2)

- [ ] Hueco 1 (485 px): necesita salto + doble salto + dash. Con solo doble salto o solo dash se cae.
- [ ] Hueco 2 (460 px, el más fácil): igual combinación; el punto de reaparición es el checkpoint 1 de antes del hueco.
- [ ] Hueco 3 (525 px, el más duro): doble salto tarde y dash a mitad de la caída; reaparece en el checkpoint 2.
- [ ] Tras cada hueco hay suelo de sobra para esperar el enfriamiento del dash y ningún enemigo a menos de 150 px del borde (también las variantes corruptas).
- [ ] Caer en cualquier hueco reaparece en el último checkpoint, sobre suelo firme, nunca pasado el hueco.
- [ ] La arena del jefe 3 no tiene agujeros en ningún extremo ni se puede salir de ella.

## Nivel 3: huecos tras el reequilibrio (Fase 15e-2b)

- [ ] Hueco 1 (380 px, fácil): se cruza con salto + doble salto, sin dash.
- [ ] Hueco 2 (450 px, medio): hacen falta las tres acciones.
- [ ] Hueco 3 (484 px, difícil): las tres acciones con buena sincronía (doble salto tarde, dash a mitad de la caída).
- [ ] El checkpoint anterior a cada hueco queda en el suelo previo, con carrera suficiente.

## Nivel 3: hueco 1 tras el ajuste (Fase 15e-2c)

- [ ] Hueco 1 (336 px): se cruza cómodamente con salto + doble salto, sin dash; el salto solo no llega.

## Jefe 3: barra y guardia legibles (Fase 15e-3)

- [ ] La barra baja en las tres fases: con espada ligera y onda en las fases 1 y 3, y con golpe pesado o tajo de dash en la fase 2.
- [ ] En la fase 2 un golpe bloqueado muestra «BLOQUEADO» con escudo, chispa y sonido, y no mueve la barra.
- [ ] Bajo la barra se ve el medidor de guardia (cajas de escudo) y «ATURDIDO: ¡GOLPEA!» al romperla.
- [ ] La pista «Rompe la guardia con golpe pesado o tajo de dash» sale una vez por pelea (otra vez tras reintentar).
- [ ] Con "Efectos de corrupción" desactivado la etiqueta y la pista siguen sin movimiento.
