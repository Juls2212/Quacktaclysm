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

## 2. Los guardianes (Fase 15n: diálogos cortos)

Cada guardián habla dos veces. **Al verlo por primera vez** (solo esa vez; un reintento o continuar desde el punto de control de la arena lo salta): UNA línea corta suya (hasta 80 caracteres) y a lo sumo una línea corta del pato; luego empieza el combate. **Al caer** (antes de la decisión del fragmento, una vez por derrota): 2 o 3 líneas suyas de hasta 120 caracteres con su historia y sus últimas palabras. Las líneas avanzan solo con la confirmación (Enter por defecto; mantener 1,2 s salta); el jugador queda bloqueado e invulnerable mientras hablan y el fragmento aparece al terminar. Nadie nombra al abuelo antes del nivel 3.

### Nivel 1: EL LEÑADOR
- *Al verlo:* «¿Quién viene a mi bosque? Hay que cortar. Hay que cortar.»
- *Pato:* «El filo no es rabia. Es respeto por aquello que cortas.»
- *Al caer:*
  1. «Aquí hubo un dojo y leña para todos. Yo silbaba al amanecer, pequeño.»
  2. «Cuando cayó la estrella nadie vino a buscarme. Por eso corté: para que alguien volviera a casa.»
  3. «El hacha pesa tanto... ¿Ya amanece?»

### Nivel 2: LA COSA DEL PANTANO
- *Al verla:* «Shhh... el agua duerme. No la despiertes.»
- *Pato:* Creí que la katana mataba. Solo separa el alma de la ruina.
- *Al caer:*
  1. «Curaba al barrio con hierbas y paciencia. Cuando subió el agua, sostuve a todos... menos a mí.»
  2. «A mí no me curó nadie. Por eso me quedé: alguien debía velar a los que el agua se llevó.»
  3. «Gracias por sacarme del agua.»

### Nivel 3: EL OJO DE LA TORMENTA
- *Al verlo:* «Tienes sus ojos. Él también llegó tarde.»
- *Pato:* Podría soltar la hoja. Pero las estrellas siguen cayendo.
- *Al caer (conserva la pista de la profecía):*
  1. «Juramos guardar la última torre juntos. Yo me quedé al pie del relámpago y la tormenta creció con mi espera.»
  2. «Mi hoja ya no distinguía entre guardar y castigar. La profecía lo dijo: quien la empuñe decidirá cada alma.»
  3. «Dile que no fue su culpa... o que sí. Ya no importa.»

(Las variantes por perfil y el monólogo largo del pato de las fases 15b y 15f ya no se dicen: se recortaron para que las introducciones sean breves.)

## 3. El abuelo vuelve (antes del jefe 3, al llegar al nivel 3)

Escena corta, se salta con Enter. La línea de ánimo se inserta antes de la última según las almas liberadas hasta ahora.

- Abuelo: Antes de la tormenta, termino la profecía que borré, nieto.
- Abuelo: «Quien la empuñe decidirá cada alma: liberarla o cargarla.»
- Abuelo: La hoja no mata: separa el alma de la ruina. El resto es tuyo.
- *(ánimo, 0 liberadas)* Abuelo: Guardaste todas. Tu hoja pesa. Yo también cargué; no te juzgo.
- *(ánimo, 1 liberadas)* Abuelo: Una liberada, una guardada. Dudas. Es lo único honesto.
- *(ánimo, 2 liberadas)* Abuelo: Liberaste a Daigo y a Hana. Hay luz en tu hoja. Cuídala.
- Abuelo: En la tormenta está Kenzo, mi hermano. No llegué a tiempo. Ve.

## 4. Los dos finales (Fases 15h, 15i y 15i-bis)

Solo hay **dos finales**, elegidos por la **mayoría** de las tres decisiones de fragmento: más almas guardadas que liberadas → *Estrellas que suben* (`ending_kept`); en cualquier otro caso → *El acantilado* (`ending_released`). Es determinista. Los títulos, los textos y el guion de cada final están en recursos (`default_story_texts.tres`, `default_kept_beats.tres`, `default_released_beats.tres`).

**Los dos ocurren en un acantilado** sobre la ciudad. Cada final es una cinematográfica dibujada por código (guion de beats): los beats temporizados corren solos; cada línea espera la acción de confirmar (primera pulsación completa, segunda avanza; Enter por defecto, se respeta la reasignación); mantener 1,2 s salta; Esc/pausa funcionan; con «Efectos de corrupción» desactivado son imágenes fijas con fundidos y el mismo texto (el audio sigue sonando).

### Reglas de seguridad (obligatorias en los dos finales)
- **El acto nunca se muestra ni se oye**: ni hoja que toque o entre en el cuerpo, ni herida, ni sangre, ni impacto, ni suelo, ni cuerpo después. En los dos la escena **se corta a blanco o al cielo ANTES del acto** (un fundido lento de más de 1 s, nunca un destello). Después solo hay viento frío.
- Ningún texto nombra ni describe un método (lista de términos prohibidos ampliada en `default_story_texts.tres`: sangre, herida, clavar, atravesar, vientre, tajo…).
- **No se honra ni se romantiza**: la lista de términos prohibidos incluye honor, honra, deshonra, ritual, dignidad, única salida, único camino, liberación, descanso, paz… El acto no es el único desenlace posible: en los dos finales el pato expresa **arrepentimientos** y el sentido de que no debería estar solo.
- Sin música y sin graznido en el momento del corte ni después.
- El **mensaje de apoyo** sale en la tarjeta final de AMBOS finales y el aviso de contenido de «Acerca de» dice que dos finales tratan el suicidio de forma implícita: «Este juego trata temas de pérdida, duelo y muerte, incluido el suicidio de forma implícita en sus dos finales.»

### El rostro del abuelo
Retrato luminoso con el diseño de su rig (pato viejo de plumas crema, moño deshecho, cejas largas, bolsas, pico naranja, bigote caído, barba larga). Cinco estados: **observa**, **habla**, **sufre** (lágrimas), **se quiebra** y **impasible** (*solemn*: ojos firmes, sin lágrimas, sin temblor, sin sonrisa). En modo reducido es un retrato fijo y las expresiones cambian con un fundido.

### ESTRELLAS QUE SUBEN (`ending_kept`)
El pato en un acantilado sobre la ciudad liberada, consumido por la corrupción: venas, ojo nublado, respiración jadeante, tos, tambaleo, rodillas, ala temblorosa hacia las estrellas. Luego la corrupción le toma la mano y el pato **se resiste** (el ala va hacia la cadera y se retira, sacude la cabeza, grita), dice sus arrepentimientos (haberlas guardado, no haber dicho que tenía miedo, que nadie sepa quién salvó la ciudad) y se arrodilla en el borde; aparece el rostro del abuelo, que sufre; baja la cabeza y la escena se corta a blanco antes de que ocurra nada.
| # | Beat | s | Qué se ve y se oye |
|---|---|---|---|
| 1 | `city_dawn` | 6 | Plano general: el pato en un acantilado sobre la ciudad que se enciende ventana a ventana; suben estrellas |
| 2 | línea 1 | (Enter) | |
| 3 | `cliff_duck` | 4 | Respira con esfuerzo; latido grave; graznido débil |
| 4 | línea 2 | (Enter) | |
| 5 | `corruption_spreads` | 7 | Las venas oscuras trepan, el ojo se nubla, el color se va; jadeo, tos y un graznido débil |
| 6 | línea 3 | (Enter) | |
| 7 | `stagger_and_fall` | 5 | Se tambalea y cae de rodillas; graznido de dolor (la espada sigue en su mano) |
| 8 | `closeup_pain` | 5 | Primer plano del dolor; graznido de dolor |
| 9 | línea 4 | (Enter) | |
| 10 | `reach_for_stars` | 5 | Intenta levantarse, falla y extiende un ala temblorosa hacia las estrellas; graznido de dolor |
| 11 | línea 5 | (Enter) | |
| 12 | `corruption_takes_hand` | 5 | La corrupción le toma la mano: el ala va hacia la cadera y se retira, sacude la cabeza; graznido forzado de resistencia; la música se apaga |
| 13-15 | líneas 6, 7 y 8 | (Enter) | El pato resiste y dice sus arrepentimientos |
| 16 | `kneel_at_edge` | 5 | Se arrodilla en el borde; sin música, solo viento (el abuelo ya no aparece aquí: solo dice la última línea) |
| 17 | `bow_and_cut` | 3 | Baja la cabeza y la escena **se funde a blanco, lentamente (sin destello)** ANTES de que ocurra nada; no se ve ni se oye el acto |
| 18 | `white_hold` | 2 | Blanco, silencio |
| 19 | `empty_edge` | 5 | El borde vacío (el blanco se retira); solo viento |
| 20 | `line_prophecy` | (Enter) | El abuelo, sereno, dice la última línea (Fase 15t): «Se ha sellado la profecía.» (sin sonido) |
| 21 | `hold_quiet` | 5 | Fundido lento a blanco y los créditos |

Líneas:
1. La ciudad se encendió ventana a ventana, y las almas subieron como ríos de luz sobre ella.
2. Pato: Las guardé a todas. Creí que podría cargar con ellas y seguir en pie.
3. Pato: Me arden las venas. Cada respiración pesa más que la anterior.
4. Pato: Tengo miedo, abuelo. Duele, y no quiero estar solo en esto.
5. Pato: Mira cuántas estrellas suben... y a mí se me va apagando todo.
6. Pato: No es mi mano. ¡Suéltame! No quiero... no quiero.
7. Pato: Me arrepiento de haberlas guardado, y de no decirte que tenía miedo, abuelo.
8. Pato: Me arrepiento de que nadie en la ciudad sepa quién la salvó. Debí pedir ayuda.
9. Abuelo: Se ha sellado la profecía.

### EL ACANTILADO (`ending_released`)
| # | Beat | s | Qué se ve y se oye |
|---|---|---|---|
| 1 | `dusk_wide` | 6 | Atardecer, viento, acantilado, ciudad liberada a lo lejos, estrellas que suben |
| 2 | línea 1 | (Enter) | |
| 3 | `grandfather_proud` | 4 | El rostro del abuelo en el cielo |
| 4 | línea 2 | (Enter) | «Bien hecho, nieto.» |
| 5-6 | `duck_closeup`, `still_wide` | 5 + 4 | Planos quietos y largos del pato en el borde, con sus líneas entre medias |
| 7 | `still_close` | 4 | Baja la mirada |
| 8 | `long_still` | 5 | Plano largo; **un solo graznido lejano y solitario** |
| 9-11 | líneas 6 y 7 | (Enter) | Sus arrepentimientos |
| 12 | `walk_to_edge` | 6 | Camina hasta el borde, ya en silueta; la música se apaga; solo viento |
| 13 | `stop_at_edge` | 4 | Se detiene y baja la cabeza |
| 14 | `look_to_sky` | 4 | La cámara sube al cielo y la escena se **funde a blanco lentamente (sin destello)**; el pato sale de cuadro por abajo, de pie |
| 15 | `white_hold` | 2 | Blanco, silencio |
| 16 | `empty_edge` | 5 | El borde vacío (nada en él: ni espada, ni capa); solo viento |
| 17 | `grandfather_solemn` | 4 | El rostro del abuelo, **impasible**: sin lágrimas ni temblor ni sonrisa |
| 18 | línea 8 | (Enter) | «Se ha sellado la profecía.» (sin sonido) |
| 19 | `fade_out` | 5 | Fundido lento a negro y tarjeta final |

Líneas:
1. Cuando la última alma subió, la ciudad se encendió allá abajo y las estrellas ascendieron sobre ella.
2. Abuelo: Bien hecho, nieto.
3. Pato: Bien hecho. Eso era todo lo que me pedían. Para eso me criaste, para eso empuñé la hoja.
4. Pato: Ya no queda nadie a quien salvar. Estoy tan solo, y tan cansado de estar solo.
5. Pato: Se acabó la misión. No sé quién soy sin ella, y no sé cómo seguir.
6. Pato: Nunca te dije que tenía miedo, abuelo. Nunca vi el mar que me prometiste.
7. Pato: Me arrepiento de no haber pedido ayuda. Habría bastado una sola palabra.
8. Abuelo: Se ha sellado la profecía.

**La profecía** ya está establecida: la escena del abuelo antes del jefe 3 (sección 3: «termino la profecía que borré, nieto» y «Quien la empuñe decidirá cada alma: liberarla o cargarla»). No se añadió ninguna mención nueva; el cierre «Se ha sellado la profecía.» la retoma.

### Diseño del audio
- **Graznidos** (ranuras de `default_audio_events.tres`, solo en las cinematográficas): `duck_cry_weak` (graznido del héroe más grave), `duck_cry_pain` (el quejido del héroe más grave), `duck_cry_resist` (el graznido del héroe muy grave y forzado), `duck_cry_lonely` (el graznido 2 muy grave y lejano). Archivos usados: `ducks/quack_hero.wav`, `ducks/quack_hurt.wav`, `ducks/quack_2.wav`. «Estrellas que suben»: débil en la respiración y la tos, de dolor en el tambaleo, la caída y el ala, forzado cuando la corrupción le toma la mano; ninguno al arrodillarse ni en el corte. «El acantilado»: uno solo, lejano, en los planos largos antes del paseo.
- **Música** (ranuras `ending_kept_music` y `ending_released_music`): pistas existentes procesadas por código (tono más bajo, filtro paso bajo y reverberación en el bus de música). «Estrellas que suben»: `castle_on_the_mountain.ogg`, tono ×0,78, 1500 Hz, reverb 0,35, se apaga cuando la corrupción toma la mano. «El acantilado»: `dungeon.ogg`, tono ×0,70, 1100 Hz, reverb 0,50 y muy baja (−14 dB); en silencio desde el paseo al borde. No hay pad procedural.

### Epílogos
Los seis epílogos (dos finales × tres variantes) viven ahora en la sección 4.

## 7. Historias de los guardianes

La historia de cada guardián está ahora repartida entre su línea al verlo y sus últimas palabras (sección 2).

## Fase 15r: el alma del guardián y el abuelo en el cielo

- **El alma como narradora.** Cuando un guardián cae, su cuerpo se desvanece y **su alma** aparece donde cayó: la misma figura (con su hacha, sus juncos y su loto, o su hoja de tormenta) en azul translúcido, flotando. Las dos o tres líneas de despedida las **dice el alma** («Alma del Leñador», «Alma de la Cosa del Pantano», «Alma del Ojo de la Tormenta»). Al terminar, el alma se deshace en partículas que fluyen hacia el fragmento y este se condensa en el cristal; solo entonces llega la decisión. El texto de las líneas no cambia.
- **El abuelo.** En los finales y al empezar cada nivel ya no se ve una cara dibujada: se ve **su propia figura completa**, grande en el cielo, con el cuerpo oculto en la niebla y solo el rostro claro, un poco borroso y translúcido (recuerdo tenue en los niveles 1 y 2, más presente en el 3 y en los finales). La pena se muestra con la cabeza baja y un brillo más tenue, nunca con lágrimas dibujadas.
- **Los finales, sobre el blanco.** Final conservado: sobre el blanco, la silueta oscura del pato arrodillado con la cabeza baja y la espada clavada a su lado, sin tocarlo; después, la silueta quieta junto a la espada. Final del acantilado: la silueta del pato de pie en el borde, mirando al cielo, que se desvanece; tras el blanco, el borde vacío con su espada y su sombrero. El acto nunca se muestra y el pato nunca se ve saltar ni caer.

## Fase 15t: la última línea, el abuelo sereno y los créditos animados

- **La última línea de AMBOS finales** es «Abuelo: Se ha sellado la profecía.» (sustituye a «Perdóname, nieto.» del final conservado). El abuelo aparece **solo para decirla**, en su estado sereno de hablar: sin llanto, sin cabeza baja, sin brillo apagado, sin lágrimas. Las líneas del pato (sus arrepentimientos) no cambian.
- **Después de la última línea** la escena se funde despacio a blanco y de ahí amanece el cielo nocturno de los créditos. Final conservado («Estrellas que suben»): estrellas pequeñas suben despacio desde la ciudad liberada, cuya silueta se desplaza con un suave paralaje. Final del acantilado: un cielo frío y casi quieto, pocas estrellas lejanas, una niebla fina y el borde del acantilado con la espada y el sombrero; mucho más callado.
- **Los créditos** suben sobre ese cielo (el mismo contenido que la sección «Créditos» del menú). Después las estadísticas aparecen como una tarjeta animada: los contadores suben suavemente y cada dato entra en su turno con un fundido suave. Luego, la tarjeta final con la línea de apoyo (en los dos finales) y la vuelta al menú.
- **Lo que no cambia:** el acto nunca se muestra, sin sangre en los finales, corte a blanco lento antes del acto, aviso de contenido en los créditos, solo viento frío en y después del corte, sin destellos.
