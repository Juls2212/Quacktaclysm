# Guion de la historia (Fase 14d; monólogos del pato añadidos en la Fase 15b)

Copia legible de `game/backend/story/default_story_texts.tres`. **La fuente de verdad es el recurso del juego**: edítalo en Godot (o aquí, y pásalo al recurso). Cada línea cabe en pantalla (máx. ~110 caracteres). `{kept}` y `{released}` se sustituyen por el nombre de la alma guardada / liberada.

Hechos que el guion respeta: abuelo samurái que entrenó al pato; las almas de los muertos se vuelven estrellas; una estrella corrupta cae y se vuelve una criatura deforme de otra época; tres guardianes (el Leñador en la ciudad en ruinas, la Cosa del Pantano en el suburbio inundado, el Ojo de la Tormenta en la zona industrial). Profecía del prólogo: «Solo una hoja heredada podrá separar el alma de la ruina. Y quien la empuñe...» (el resto estaba borrado).

## 1. Las almas

### Daigo, el Leñador (`fragment_level_1`)
- **Recuerdo (panel de decisión):** Daigo cortaba la leña del dojo y silbaba al amanecer. Nadie lo oyó caer.
- **Si la liberas:** Daigo suelta el hacha y sube. Su silbido se apaga entre las estrellas.
- **Si la conservas:** El filo de Daigo se queda en tu hoja. Su silbido suena lejos.

### Hana, la Herbolaria (`fragment_level_2`)
- **Recuerdo (panel de decisión):** Hana curaba con hierbas del pantano. Cuando se hundió, nadie fue a buscarla.
- **Si la liberas:** Hana sonríe, limpia de lodo, y el pantano guarda silencio.
- **Si la conservas:** La marea de Hana corre por tu espada. El lodo no se ha ido.

### Kenzo, hermano de espada (`fragment_level_3`)
- **Recuerdo (panel de decisión):** Kenzo fue el hermano de espada de tu abuelo. Él no llegó a tiempo para salvarlo.
- **Si la liberas:** Kenzo inclina la cabeza. Por fin alguien llegó a tiempo.
- **Si la conservas:** Kenzo arde en tu katana. Tu abuelo no podrá mirar esa hoja.

## 2. Los guardianes

Se dicen al empezar el combate (una sola vez por encuentro); la variante según el perfil se añade al final de las líneas. Enter las salta.

### Nivel 1: EL LEÑADOR

- «¿Quién viene a mi bosque? Hay que cortar. Hay que cortar.»
- «La leña no se calienta sola, pequeño.»
- *Variante compasivo:* «Esa mirada... se parece a la de un viejo samurái.»
- *Variante corrupto:* «Hueles a hierro y a rencor. Hueles a mí.»
- *Al caer:* «El hacha pesa tanto... ¿Ya amanece?»

### Nivel 2: LA COSA DEL PANTANO

- «Shhh... el agua duerme. No la despiertes.»
- «Curé a todos. A mí no me curó nadie.»
- *Variante compasivo:* «Tus manos no traen fuego. Hace tanto que nadie me toca así.»
- *Variante corrupto:* «El lodo también se te pega. Ya empieza.»
- *Al caer:* «Gracias por sacarme del agua.»

### Nivel 3: EL OJO DE LA TORMENTA

- «Tienes sus ojos. Él también llegó tarde.»
- «Te esperé en la tormenta. Cada trueno decía tu nombre.»
- *Variante compasivo:* «¿Y si esta vez nadie llega tarde?»
- *Variante corrupto:* «Ven. Enséñame cuánta alma cargas ya en la hoja.»
- *Al caer:* «Dile que no fue su culpa... o que sí. Ya no importa.»

## 3. El abuelo vuelve (antes del jefe 3, al llegar al nivel 3)

Escena corta, se salta con Enter. La línea de ánimo se inserta antes de la última según las almas liberadas hasta ahora.

- Abuelo: Antes de la tormenta, termino la profecía que borré, nieto.
- Abuelo: «Quien la empuñe decidirá cada alma: liberarla o cargarla.»
- Abuelo: La hoja no mata: separa el alma de la ruina. El resto es tuyo.
- *(ánimo, 0 liberadas)* Abuelo: Guardaste todas. Tu hoja pesa. Yo también cargué; no te juzgo.
- *(ánimo, 1 liberadas)* Abuelo: Una liberada, una guardada. Dudas. Es lo único honesto.
- *(ánimo, 2 liberadas)* Abuelo: Liberaste a Daigo y a Hana. Hay luz en tu hoja. Cuídala.
- Abuelo: En la tormenta está Kenzo, mi hermano. No llegué a tiempo. Ve.

## 4. Los cuatro finales

Se eligen solo por las almas liberadas: 3 = *El cielo se abre*, 2 = *La cicatriz del cielo*, 1 = *El filo y la duda*, 0 = *La nueva estrella caída*. Cada uno dura unos 35-60 s y se salta manteniendo Enter; después viene la tarjeta de resumen.

### EL CIELO SE ABRE (`ending_full`, música `title_screen.ogg`)

1. Daigo, Hana y Kenzo subieron juntos, sin peso y sin hambre.
2. Las estrellas dejaron de caer. Una a una, volvieron a su sitio.
3. Abuelo: Yo no llegué a tiempo. Tú sí.
4. Abuelo: Ahora entiendo la piedra. «Quien la empuñe» no era un guerrero. Era alguien que supiera soltar.
5. La katana nunca fue una espada para matar. Era una hoja para dejar ir.
6. Esa noche el cielo se vio entero por primera vez desde la caída.
7. Y tres luces parpadearon allá arriba. Era una despedida.

*Tarjeta de resumen:* Liberaste las tres almas. El cielo volvió a ser un cielo.

### LA CICATRIZ DEL CIELO (`ending_scar`, música `castle_on_the_mountain.ogg`)

1. Dos almas subieron al cielo. La de {kept} se quedó contigo.
2. Las estrellas casi dejaron de caer. Casi.
3. Cada noche, la hoja susurra el nombre de {kept}.
4. Abuelo: Te dije que el resto era tuyo. No te dije cuánto pesaría: importa, y duele.
5. Abuelo: Pero cargar a una por amor no es cargar a todas por miedo.
6. La profecía se cumplió a medias: la hoja separó el alma de la ruina y tú guardaste su eco.
7. El cielo sanó con una cicatriz. Tú también.

*Tarjeta de resumen:* Liberaste dos almas y guardaste una. El cielo sanó con una cicatriz.

### EL FILO Y LA DUDA (`ending_doubt`, música `dungeon.ogg`)

1. Tu katana nunca fue tan poderosa. Nunca pesó tanto.
2. Solo {released} subió al cielo. Es la única luz que no cayó.
3. Las estrellas siguieron cayendo, pero ya no las temías. Tenías la hoja.
4. Abuelo: Eres más fuerte que yo. No sé si eso me alegra.
5. Abuelo: Dime, nieto. Cuando mires el cielo, ¿verás la estrella de {released} o las que faltan?
6. «Quien la empuñe», decía la piedra. Ahora sabes lo que seguía: tendrá poder, y tendrá dudas.
7. El duelo terminó. La duda, no.

*Tarjeta de resumen:* Liberaste una sola alma. Tienes el poder, y tienes la duda.

### LA NUEVA ESTRELLA CAÍDA (`ending_corrupt`, música `the_evil_one.ogg`)

1. Guardaste a Daigo, a Hana y a Kenzo. Su peso nunca te soltó.
2. La hoja ya no cortaba: bebía. Y tú, de tanto sostenerla, empezaste a brillar.
3. Abuelo: Nieto... tus ojos. Esos no son los tuyos.
4. Abuelo: La piedra no estaba borrada. La borré yo, por miedo a leer esto.
5. «Y quien la empuñe...» se levantará de las estrellas con un cuerpo que no es suyo.
6. Una luz violeta cruzó el cielo. Cayó despacio, sin ruido, sobre una ciudad que ya no existía.
7. En alguna parte, algo que antes fue un pato abrió los ojos. Tenía hambre.

*Tarjeta de resumen:* No liberaste ninguna alma. La profecía se cumplió contigo.

## 5. La historia del pato antes de cada jefe (Fase 15b)

La **primera vez** que el pato entra en la arena de un jefe pasa esto, en este orden: la presentación «VS», los saludos del guardián (sección 2) y **el pato cuenta su historia** (6 líneas, unos 20 s por jefe; Enter las salta). Durante todo ello el jefe está quieto y el pato no puede moverse ni recibir daño. No se repite si el pato muere y reintenta, ni si la partida se continúa desde el checkpoint de la arena. Son tres capítulos de una misma historia; hablan por «Pato». Fuente: `duck_lines` de cada `BossStory` en `default_story_texts.tres`.

### Capítulo 1 (EL LEÑADOR): el entrenamiento y la noche de la primera estrella

1. Pato: Mi abuelo me enseñó a sostener la katana antes de que yo supiera para qué servía.
2. Pato: Cada amanecer, cien cortes al aire. Él, en silencio, contando.
3. Pato: «El filo no es rabia, nieto. Es respeto por aquello que cortas.»
4. Pato: La noche en que cayó la primera estrella, el cielo entero crujió como el hielo.
5. Pato: Abuelo me tapó los ojos con su manga. Aun así vi cómo ardía al caer.
6. Pato: Desde esa noche, entrenar dejó de ser un juego. Y yo dejé de ser un niño.

### Capítulo 2 (LA COSA DEL PANTANO): lo que hace la hoja y el silencio del abuelo

1. Pato: Creí que la katana servía para matar. No corta la carne: separa el alma de la ruina.
2. Pato: Cuando cae un guardián, su alma queda ahí, colgando. Y me toca decidir a mí.
3. Pato: Abuelo lo sabía. Siempre lo supo. Y nunca me lo dijo.
4. Pato: Al terminar la profecía solo dijo: «El resto está borrado. No importa.»
5. Pato: Pero nadie borra lo que no le importa. Su silencio pesa más que la hoja.
6. Pato: Si él no habla, tendré que descubrirlo yo, alma por alma.

### Capítulo 3 (EL OJO DE LA TORMENTA): Kenzo, la duda y por qué no hay vuelta atrás

1. Pato: Kenzo fue el hermano de espada de mi abuelo. Ahora su alma arde en la tormenta.
2. Pato: Cada alma que decidí, la decidí con las manos temblando. No sé si fue piedad o hambre.
3. Pato: A veces la hoja pesa tanto que dudo de quién sostiene a quién.
4. Pato: Podría soltarla y volver a la cueva. Pero las estrellas siguen cayendo.
5. Pato: Si me detengo ahora, todo lo que perdí habrá sido en vano.
6. Pato: Abuelo llegó tarde una vez. Yo no puedo volver atrás. Tampoco puedo llegar tarde.

## 6. La voz del abuelo en el cielo y los epílogos (Fase 16c)

Copia legible de `game/backend/ai/director/default_grandfather_lines.tres` (la fuente de verdad) y de los epílogos de `default_story_texts.tres`.

Reglas de una línea: 8 a 18 palabras y como mucho 110 caracteres, una sola línea, sin cifras, enlaces, marcas ni emojis, sin reproche (moriste, fallaste, errores...) y sin nombrar mecánicas. En los niveles 1 y 2 se presenta como un recuerdo («Recuerdas su voz… «…»»); en el nivel 3 como su voz directa («Abuelo: «…»»), después de su escena de entrada.

### Nivel 1 (recuerdos)
- El filo no es rabia, nieto. Es respeto por aquello que cortas.
- Cien cortes al amanecer, nieto, y ninguno con prisa. Así se aprende.
- Quien mira el cielo con respeto no teme a la noche, nieto.
- Antes de empuñar la hoja, nieto, aprende a escuchar el silencio.

### Tema: calma
- Respira, nieto. La cabeza fría esquiva lo que la prisa no ve.
- El agua turbia se aclara cuando dejas de agitarla. Quédate quieto un instante, nieto.
- Un filo tranquilo corta más limpio que uno temblando. Suelta los hombros, nieto.
- La calma no es lentitud, nieto. Es saber dónde poner el siguiente paso.

### Tema: paciencia
- El bambú no corre hacia el cielo, nieto. Crece un nudo cada vez.
- Quien espera el momento justo no pierde el paso. Aguanta un poco más.
- La piedra del río se pulió con paciencia, nieto, no con prisa.
- Todo lo bueno madura despacio. Dale tiempo al camino, nieto.

### Tema: distancia
- Lo que muerde de cerca, calla de lejos. Mide el espacio, nieto.
- Un buen guerrero elige dónde pisar antes de elegir dónde cortar.
- La distancia también es un escudo, nieto. Úsala con inteligencia.
- Cuando algo te acecha desde lejos, acércate a tu manera y a tu tiempo.

### Tema: ritmo
- Todo golpe tiene su respiración, nieto. Escucha el silencio antes del trueno.
- La hoja llega cuando el viento se detiene. Aprende a esperar ese instante.
- Hay una música en cada embestida, nieto. Aprende su compás y baila fuera.
- Antes de cada tormenta se oye un compás. Escúchalo y deja pasar el trueno.

### Tema: recursos
- Una brasa bien guardada calienta toda la noche. Cuida tus fuerzas, nieto.
- El sabio no gasta todo su aliento en la primera colina.
- Quien reparte bien sus fuerzas llega lejos, nieto. Descansa cuando el camino lo permita.
- Guarda un poco de luz para el tramo más oscuro, nieto.

### Tema: valor
- El miedo también camina contigo, nieto. Que vaya detrás, no delante.
- Dar un paso temblando sigue siendo dar un paso. Avanza, nieto.
- El valor no grita, nieto. A veces solo se levanta una vez más.
- Acércate a lo que temes con el corazón abierto y la hoja serena.

### Tema: equilibrio
- Soltar y cargar pesan distinto, nieto. Elige con el corazón despierto.
- La luz no se gasta al compartirla. Recuérdalo cuando dudes, nieto.
- Entre la fuerza y la ternura hay un camino estrecho. Camínalo con calma.
- Cada elección deja huella, nieto, pero ninguna huella es el final del camino.

### Epílogos (variante 0 neutra, 1 jugó con comodidad, 2 lo pasó mal)
Solo cambian el cierre de la tarjeta final; el final (3, 2, 1 o 0 almas liberadas) no cambia nunca.

**EL CIELO SE ABRE (`ending_full`)**
0. Abuelo: Mira el cielo entero, nieto. Cada estrella volvió a casa gracias a tus manos.
1. Abuelo: Caminaste ligero y el cielo lo notó. Descansa, nieto: la noche ya es tuya.
2. Abuelo: El camino pesó y aun así llegaste. Esa constancia también ilumina, nieto.

**LA CICATRIZ DEL CIELO (`ending_scar`)**
0. Abuelo: Toda cicatriz recuerda que hubo amor. Llévala con la cabeza alta, nieto.
1. Abuelo: Fuiste firme y sereno hasta el final. La cicatriz será solo un recuerdo tibio.
2. Abuelo: Fue un camino duro y lo recorriste entero. Tu cicatriz es la de quien no se rindió.

**EL FILO Y LA DUDA (`ending_doubt`)**
0. Abuelo: Dudar no es perder el rumbo, nieto: es escuchar al corazón. Aún estás a tiempo.
1. Abuelo: Tu filo fue seguro y limpio. Ahora déjalo aprender a soltar, nieto.
2. Abuelo: Cada tropiezo te enseñó a pesar la hoja. Sigue aprendiendo; yo camino contigo.

**LA NUEVA ESTRELLA CAÍDA (`ending_corrupt`)**
0. Abuelo: Aun en la noche más honda queda una estrella despierta. Búscala, nieto.
1. Abuelo: Fuiste fuerte, nieto, y la fuerza sola pesa. Todavía puedes volver a la luz.
2. Abuelo: Sé cuánto cargaste. No estás solo en esta oscuridad: mi voz aún te espera.
