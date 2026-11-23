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

### Atajos para ver los dos finales

El final depende de la mayoría de las tres decisiones (guardadas > liberadas → «Estrellas que suben»; si no, «El acantilado»).

| Final | Elecciones (nivel 1, 2, 3) |
|---|---|
| Estrellas que suben | Conservar ×3, o 2 conservadas y 1 liberada (cualquier orden) |
| El acantilado | Liberar ×3, o 2 liberadas y 1 conservada (cualquier orden) |

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
| FIN-01 | Finales | «Estrellas que suben»: 3/0 y 2/1 guardadas | Ciudad que recupera luz, pato que se apaga; termina en «Perdóname, nieto.» | |
| FIN-02 | Finales | «El acantilado»: 0/3 y 1/2 guardadas | Atardecer, acantilado, la cámara sube y funde a blanco; nada después | |
| FIN-03 | Finales | Avance solo con Enter, también con la tecla reasignada | Primera pulsación completa, segunda avanza; esperar no avanza | |
| FIN-04 | Finales | Saltar manteniendo confirmar 1,2 s y pausar con Esc | Salta a la tarjeta; la pausa congela la escena | |
| FIN-05 | Finales | «Efectos de corrupción» desactivado | Fundidos estáticos, mismo texto, sin destellos | |
| FIN-06 | Finales | Tarjeta de «El acantilado» | Línea de apoyo visible; no aparece en el otro final | |
| FIN-07 | Finales | Menú principal → Acerca de | Aviso de contenido visible (sin ventana emergente) | |
| FIN-08 | Finales | «Estrellas que suben»: ver el arco completo (venas que trepan, respiración jadeante, caída, primer plano, ala hacia las estrellas, último aliento) | Doloroso y triste pero sin nada gráfico; el latido se apaga y la música se va | |
| FIN-09 | Finales | El rostro del abuelo en los cuatro estados (observa, habla, sufre, se quiebra) | Se lee como un rostro de pato viejo (no una constelación); lágrimas que corren; sus ojos siguen al pato | |
| FIN-10 | Finales | «El acantilado»: el salto | Solo silueta; no se ve impacto ni suelo; la cámara se queda en el borde vacío con la bufanda, la espada y la pluma | |
| FIN-11 | Finales | Lo que viene tras el salto en «El acantilado» | Silencio y viento frío, sin música; duelo del abuelo; tarjeta con el mensaje de apoyo | |
| FIN-12 | Finales | Ritmo y duración | Cada final dura 45-75 s sin contar la lectura; las líneas solo avanzan con Enter | |
| FIN-13 | Finales | «El acantilado», plano del borde vacío | Sin barra rara, sin espada ni capa; una pluma pequeña que se lee como pluma | |
| FIN-14 | Finales | El corte en los dos finales | Se corta a blanco (o al cielo) lentamente ANTES del acto; no se ve ni se oye nada del acto; solo viento después | |
| FIN-15 | Finales | Tarjeta final de los dos finales | Aparece el mensaje de apoyo en ambos | |
| FIN-16 | Finales | Cierre de «El acantilado» | Rostro impasible del abuelo (sin lágrimas) y su única línea «Se ha sellado la profecía.» | |
| FIN-17 | Finales | Graznidos | Solo en los beats previstos; ninguno al arrodillarse, en el corte ni después; uno solitario en el acantilado | |
| FIN-18 | Finales | Silencio en el corte | Sin música ni voz del abuelo en el corte y después | |
| FIN-19 | Finales | Música de cada final | «Estrellas que suben» lenta y pesada; «El acantilado» escasa y fría; distintas entre sí | |
| FIN-20 | Finales | Saltar, pausar y salir durante un final | El audio se detiene y se devuelve (sin reverb ni filtro residuales) | |
| FIN-21 | Finales | Arrepentimientos | Los dos finales incluyen líneas de arrepentimiento del pato | |
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

## Director de IA local (Fase 16a)

- [ ] Nivel 1: plan neutro (nada cambia respecto a antes).
- [ ] Nivel 2 tras sufrir en el 1 (muchas muertes o daño): menos enemigos extra y el patrón que más dañó pesa menos.
- [ ] Nivel 2 tras un nivel 1 cómodo y largo: un enemigo extra más como mucho y el patrón que más dañó pesa más.
- [ ] Nunca hay más de 3 enemigos extra, ni uno a menos de 150 px de un borde de hueco.
- [ ] Los pesos de los patrones del jefe no se salen de 0,6 a 1,5; los patrones de reserva no cambian.
- [ ] Modo de plan fijo (`QUACKTACLYSM_DIRECTOR_NEUTRAL=1` o `QUACKTACLYSM_DIRECTOR_PLAN`) en depuración: cada carga usa ese plan y el log imprime `[Director]`.
- [ ] Morir y reintentar el nivel reutiliza el mismo plan; continuar desde disco usa el plan neutro.

## Director de IA remoto (Fase 16b)

- [ ] «Adaptación con IA» existe en el menú principal y en el de pausa, activada por defecto; apagada, no sale ninguna petición (comprobar el log del servicio).
- [ ] Servicio en modo `openai`: el plan del nivel 2 y 3 puede venir de la IA (log `[Director] level N plan (remote)`); nunca cambia el perfil, ni más de 3 extras, ni pesos fuera de 0,6 a 1,5.
- [ ] Servicio apagado antes de decidir un fragmento (sin conexión): el siguiente nivel carga igual con el plan local y sin ningún error en pantalla.
- [ ] Servicio parado a mitad de la partida (tras la petición): el nivel no espera y usa el plan local.
- [ ] Servicio en modo mock: el juego se comporta como la Fase 16a.
- [ ] Reintentar un nivel mantiene el mismo plan; continuar desde disco usa el plan neutro.

## Línea del abuelo, reflejo y epílogos (Fase 16c)

- [ ] Nivel 1: tras el título aparece un recuerdo («Recuerdas su voz…») con una silueta de estrellas borrosa en el cielo; se va sola y con Enter.
- [ ] Nivel 2: otro recuerdo, con el tema del jugador; silueta borrosa.
- [ ] Nivel 3: después de la escena del abuelo aparece su voz directa («Abuelo: …») y la silueta es nítida.
- [ ] Sin conexión, con «Adaptación con IA» apagada o con el servicio en mock: la línea sale igual, del banco.
- [ ] Con «Efectos de corrupción» apagado: el reflejo solo se desvanece (sin parpadeo).
- [ ] La línea nunca aparece en una pelea, sobre la intro del jefe, sobre una tarjeta de habilidad ni al continuar en el checkpoint de la arena; se cierra si empieza el encuentro.
- [ ] Al reintentar el nivel la línea no se repite.
- [ ] Los 4 finales x 3 variantes: el final que suena es el mismo y la tarjeta cambia el cierre (probar con `QUACKTACLYSM_DIRECTOR_PLAN` y `epilogue_variant` 0, 1 y 2).

## Capa de armadura e introducciones (Fase 15f)

- [ ] Kenzo (fase 2) lleva una capa de placas sobre el cuerpo; la espada ligera y la onda rebotan (chispa, grieta, «BLOQUEADO»).
- [ ] UN golpe pesado o tajo de dash rompe la capa: salen fragmentos, el cuerpo brilla (2,5 s, «ATURDIDO: ¡GOLPEA!») y luego las placas vuelven una a una (3,0 s).
- [ ] La pista «Rompe la capa con golpe pesado o tajo de dash» sale una vez por pelea; ya no hay cajas bajo la barra.
- [ ] Con «Efectos de corrupción» apagado: sin partículas ni pulso, la capa solo cambia con un desvanecimiento corto.
- [ ] Introducción de El Leñador, La Cosa del Pantano y El Ojo de la Tormenta: cada guardián dice 4 líneas, el pato su monólogo, y NADA avanza solo: Enter completa la línea y luego pasa a la siguiente («Enter ▸»); mantener Enter salta todo.
- [ ] Al morir y reintentar, o al continuar desde la arena, la introducción no se repite; la pausa detiene la introducción.

## Escenario del nivel 3 (Fase 15g)

- [ ] Corriente de aire (primer tramo y cerca de la arena): avisa (rejilla brillante y aire que se junta), eleva mientras está activa y deja subir hasta las plataformas altas; el salto y el doble salto siguen funcionando; no ayuda a cruzar los huecos.
- [ ] Placa eléctrica (primer tramo): aviso de 1,2 s con borde discontinuo, descarga de 2 s que quita 1 corazón, el dash es inmune; las plataformas encima son seguras y siempre da tiempo de salir andando.
- [ ] Ruta alta: se llega con la corriente, se puede bajar caminando por el extremo (sin trampas).
- [ ] Decorado: los charcos salpican al caer o hacer dash, las lámparas parpadean al pasar (nunca con destellos fuertes), las cadenas se balancean y hay torres rotas de fondo.
- [ ] Arena del jefe 3: tres corrientes bajas que ayudan a alcanzar el ojo; sin plataformas ni placas; se detienen durante la posesión.
- [ ] Con «Efectos de corrupción» apagado: sin partículas, parpadeo ni balanceo; todo cambia de estado sin movimiento.

### Huecos del nivel 3 (Fase 15h-bis)

| ID | Área | Comprobación | Resultado esperado | Estado |
|---|---|---|---|---|
| HUE-01 | Nivel 3 | Quedarse en el borde del hueco 1 con enemigos vivos | Ningún enemigo llega a menos de ~250 px, ni golpea ni empuja | |
| HUE-02 | Nivel 3 | Cruzar el hueco 1 con salto + doble salto, y con salto + dash | Se cruza sin precisión extrema (ventana amplia) | |
| HUE-03 | Nivel 3 | Cruzar los huecos 2 y 3 con salto + doble salto + dash | Posible, más exigente en el 3; con solo doble salto, solo dash o salto simple no se cruza | |
| HUE-04 | Nivel 3 | Jugar con menos de 2 decisiones (partida creada a mano) | Hueco 1 cruzable con salto + dash | |
| HUE-05 | Nivel 3 | Caer 3 veces en el mismo hueco | No aparece nada | |
| HUE-06 | Nivel 3 | Caer una cuarta vez | Aparece una plataforma de restos de 140 px en medio de ese hueco (solo ese) y sigue ahí al reaparecer | |
| HUE-07 | Nivel 3 | Empezar partida nueva o cargar un guardado | La plataforma ya no está | |

### Jefe 3 rediseñado (Fase 15j)

| ID | Área | Comprobación | Resultado esperado | Estado |
|---|---|---|---|---|
| J3-01 | Fase 1 | Pelear contra el pato solo | Tajo, carga y andanada; coraza que se rompe con un golpe pesado; sin plataformas, patitos ni ojo | |
| J3-02 | Umbrales | Bajar el jefe al 66,7 % y al 33,3 % | Una posesión en cada cruce, en orden | |
| J3-03 | Fase 2 | Plataformas y percha | Suben en ~1,2 s; todas se alcanzan con salto simple; la percha no se pisa | |
| J3-04 | Fase 2 | Invocación | Patitos de 2 en 2 cada 2,5 s hasta 6; máximo 6 vivos | |
| J3-05 | Fase 2 | Escudo | Burbuja visible y «BLOQUEADO» mientras viva un patito; pista «Derrota a los patitos» una vez | |
| J3-06 | Fase 2 | Derrumbe | El suelo tiembla 1,5 s (grietas, sacudida), el jefe salta y el suelo cae | |
| J3-07 | Fase 2 | Andanada | 5 s de proyectiles a la altura de cada plataforma, avisados 0,8 s; siempre hay una plataforma segura | |
| J3-08 | Fase 2 | Vacío | Caer cuesta 1 corazón y devuelve al jugador a la plataforma más baja; nunca al punto de control | |
| J3-09 | Fase 2 | Suelo y ventana | El contorno brilla 1 s, el suelo vuelve, las plataformas se quedan; el jefe cae agotado 6 s sin escudo ni coraza | |
| J3-10 | Fase 2 | Ciclos | Con solo espada la fase 2 pide 2 o 3 ciclos | |
| J3-11 | Fase 3 | Ojo rojo | Las plataformas se hunden; el ojo rojo es invulnerable; el pato sin coraza; rayos avisados ≥ 1 s con un carril seguro | |
| J3-12 | Robustez | Cruzar un umbral en medio de cada mecánica; morir, reintentar, salir y pausar | La arena queda limpia y el reintento empieza en la fase 1 | |
| J3-13 | Reducido | «Efectos de corrupción» desactivado | Sin partículas, sacudida ni destellos; cambios de estado estáticos | |
| SAN-01 | Sangre | Opciones (menú principal y de pausa) | Aparece «Sangre», activada por defecto; al desactivarla no sale sangre, solo chispas | |
| SAN-02 | Sangre | Golpear a un enemigo vivo, a un duckling y al bruto bloqueado | Salpica (el duckling menos); con armadura o escudo bloqueando solo chispas | |
| SAN-03 | Sangre | Matar enemigos y derrotar un jefe | Ráfaga mayor al matar; ráfaga grande con el jefe | |
| SAN-04 | Sangre | Recibir daño y usar el dash | Salpicadura pequeña al recibir daño; ninguna durante el dash | |
| SAN-05 | Sangre | Los finales, el prólogo y las escenas de historia | No aparece sangre en ninguno | |
| SAN-06 | Sangre | Avisos, pinchos y placas con manchas en el suelo | Siguen legibles; las manchas se desvanecen en unos 8 s | |
| SAN-07 | Sangre | Reiniciar nivel, reintentar y pausar | No queda sangre; en pausa se queda quieta | |
| VEN-01 | Venas | «Estrellas que suben» completo | Termina sin trabarse; el ojo, el ala y las venas se ven bien, sin barras ni discos planos | |
| VEN-02 | Venas | Primer fragmento conservado, en el juego | Venas moradas tenues en brazo y cuello; con dos, pecho y cara; con tres, extendidas | |
| VEN-03 | Venas | Fragmentos liberados | No aparecen venas | |
| VEN-04 | Venas | Avisos y proyectiles con venas | Siguen legibles; la silueta del pato no se pierde | |
| VEN-05 | Venas | «Efectos de corrupción» desactivado | Venas estáticas y finas, sin pulso | |
| ABS-01 | Absorción | Conservar un fragmento | Secuencia oscura de unos 3,6 s con latido, viñeta morada y música atenuada; la tarjeta aparece después | |
| ABS-02 | Absorción | Esc durante la secuencia y modo reducido | Salta a la tarjeta; en reducido es un fundido oscuro estático | |
| ABS-03 | Absorción | Liberar un fragmento | Conserva su animación luminosa | |
| TUT-01 | Tutorial | Matar al muñeco antes de que hable | Revive solo a ~1 s; el tutorial no se bloquea | |
| TUT-02 | Tutorial | Hacer las acciones en otro orden o antes de pedirlas | Cuentan igual, se tachan en la lista y el muñeco lo comenta | |
| TUT-03 | Tutorial | Mantener la tecla de confirmar ~2 s | La barra de abajo se llena, el tutorial se salta y la salida se abre | |
| TUT-04 | Tutorial | Reasignar una tecla (por ejemplo saltar) | El aviso del tutorial muestra la tecla nueva | |
| TUT-05 | Tutorial | Lista de tareas arriba a la izquierda | Un paso hecho se marca y el cartel de su estación se pone verde | |
| TUT-06 | Tutorial | Morir, caerse, pausar y pulsar sin parar | No se pierde progreso ni se bloquea nada | |
| TUT-07 | Tutorial | Entrar en la salida sin terminar y terminado | Sin terminar dice qué falta; terminado pasa al nivel 1 | |
| DLG-01 | Diálogos | Ver a un guardián por primera vez | Una línea suya y a lo sumo una del pato; luego combate; un reintento no repite | |
| DLG-02 | Diálogos | Derrotar a un guardián | 2–3 líneas con Enter (mantener salta), el fragmento aparece después, sin repetir | |
| FRG-01 | Fragmentos | Matar enemigos normales y patitos | Fragmento azul que flota y vuela al pato; suma alma una sola vez; el patito, menos | |
| CRY-01 | Graznidos | Golpear enemigos, patitos y jefes | Graznido en cada golpe que aterriza (sin ruido excesivo); ninguno en golpes bloqueados | |
| PRO-01 | Prólogo | Ver, saltar, pausar y salir del prólogo | Hay música y efectos; se detienen limpiamente; respetan los volúmenes | |
| ABU-01 | Abuelo | Línea del abuelo al empezar los niveles | Rostro en el cielo: recuerdo tenue en los niveles 1 y 2, nítido en el 3; sin lágrimas | |
| ULT-01 | Final | Conservar o liberar el fragmento del jefe 3 | Sin tarjeta de habilidad: va directo al final (absorción oscura / liberación luminosa) | |
| ABS-01 | Absorción | Conservar el fragmento de un jefe | Fondo oscuro con toques rojos, emblema abajo, rayos rojos finos que entran en el pato, partículas, el pato convulsiona y su corrupción avanza; 3–4 s; Esc salta; sin destellos fuertes | |
| ABS-02 | Absorción | Lo mismo con «Efectos de corrupción» apagado | Fundido rojo quieto con el emblema y unos pocos rayos fijos, sin parpadeo | |
| N3-01 | Nivel 3 | Recorrer «La tormenta» | Ya no hay columnas con flechas; los huecos y los puntos de control son los de siempre; se llega al jefe | |
| J3-01 | Jefe 3 | Pelear la fase 1 | Sin capa de armadura: cualquier golpe hace daño; la fase de los patitos sigue con su escudo | |
| COR-01 | Pato | Jugar con 0, 1, 2 y 3 fragmentos conservados | Venas, ojo nublado, plumas y ala oscuros cambian por etapa, dentro del cuerpo, sin capas sueltas | |
| COR-02 | Finales | Ver los dos finales | Cada pose es un solo dibujo coherente (cabeza, ala, venas, ojo); sin sangre ni herida; la luz suave solo detrás | |
| DER-01 | Jefes | Derrotar a cada jefe y leer sus últimas palabras | El jugador no puede moverse (y no recibe daño) mientras habla; con Enter avanza, manteniéndolo salta; al terminar el fragmento aparece y el jugador vuelve a moverse | |
| DER-02 | Jefes | Pausar o salir durante las últimas palabras | Nada queda bloqueado al volver; al decidir el fragmento se ve la absorción o la liberación y luego la tarjeta (niveles 1 y 2) o el final (nivel 3) | |
| J3-02 | Jefe 3 | Fase 1 con solo espada | Dura unos 25 s de juego perfecto (más si se falla); las fases 2 y 3 igual que antes | |
| REG-01 | Niveles | Morir cuatro veces en el mismo hueco del nivel 3 | Aparece la plataforma de ayuda sin errores en la consola; el resto de huecos no la tienen | |
| ABU-01 | Abuelo | Empezar los niveles 1, 2 y 3 y ver los dos finales | Se ve su figura entera en el cielo con el cuerpo en la niebla y solo la cara clara, algo borrosa y translúcida (tenue en 1 y 2, más presente en 3 y en los finales); sin lágrimas ni formas encima; con efectos apagados es una imagen quieta | |
| FIN-01 | Finales | Ver el final conservado | Tras el corte a blanco se ve la silueta oscura del pato arrodillado con la espada clavada a su lado y luego quieta junto a ella; nada de sangre ni contacto; solo viento frío | |
| FIN-02 | Finales | Ver el final del acantilado | Sobre el blanco, la silueta del pato en el borde mirando al cielo, que se desvanece; después el borde vacío con su espada y su sombrero; el pato nunca salta ni cae | |
| ALM-01 | Jefes | Derrotar a cada guardián | El cuerpo se desvanece, aparece su alma en azul y dice las líneas con su nombre («Alma del Leñador»…); al terminar se deshace en partículas que forman el cristal; la decisión llega después; saltar (mantener Enter) va directo al cristal | |
