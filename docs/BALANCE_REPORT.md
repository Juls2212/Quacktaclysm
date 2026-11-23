# Medición de balance (Fase 14g, con la nueva medición de la Fase 15a al final)

> **Las cifras de orbes de las secciones 3, 4 y las propuestas con orbes (Fase 14g) están SUPERADAS:** los orbes de salud ya no existen (Fase 15a). La medición vigente es la sección «Fase 15a» al final de este documento. Los DPS y los datos estáticos de niveles (secciones 1 y 2) siguen valiendo, salvo la columna de orbes.

**Solo medida: no se cambió ningún valor del juego.** Las propuestas del final están sin aplicar.

## Cómo se midió y qué valor tiene

Todo se hizo en modo headless con el script `game/frontend/scenes/test/balance_measure.gd` (no es una prueba de la suite; `godot --headless --fixed-fps 60 --path game res://frontend/scenes/test/balance_measure.tscn -- --only=dps|levels|duels|runs`). Mide cuatro cosas:

1. **DPS** de cada ataque del jugador, calculado a partir de los recursos.
2. **Niveles (estático):** enemigos, vida, orbes, longitud y checkpoints de cada nivel con cada perfil.
3. **Duelos de jefe:** cada jefe en una arena plana contra un bot sencillo (camina hacia el jefe, golpea de cerca, lanza ondas de lejos, salta y esquiva de vez en cuando; casi no esquiva a propósito). Por perfil (agresividad 0,90 / 1,00 / 1,15) y vida (8 y 11 corazones), con 2 semillas.
4. **Recorridos:** un bot ingenuo recorre el nivel real (a la derecha, salta en muros y huecos, esquiva con dash los huecos anchos, golpea a los enemigos cercanos y luego pelea con el jefe), con una semilla, hasta 420 s simulados.

**Advertencia importante:** el bot es torpe (casi no esquiva, no usa plataformas altas con criterio, ignora los orbes). Las muertes y el daño que muestra son un **techo** de lo que sufriría una persona; los tiempos de un jugador real serán más cortos. Sirven para **comparar** combinaciones (8 frente a 11 corazones, perfiles, niveles), no como dificultad absoluta. Cada celda de recorridos es **una sola corrida** (hay ruido: p. ej. nivel 1 neutral con 8 corazones tuvo 1 muerte, con compasivo 0). Las muertes cuentan reapariciones en el último checkpoint (el bot sigue jugando); «vida en la puerta del jefe» es la vida al empezar el combate y vale siempre el máximo por la reaparición, por eso no es informativa; los orbes cuentan cada recogida, incluidas las repetidas tras reapariciones.

## 1. DPS de los ataques del jugador (de `default_player_stats.tres` y `default_sword_wave_config.tres`)

| Ataque | Daño | Ciclo (s) | DPS |
|---|---|---|---|
| Espada | 1 | 0,45 | 2,22 |
| Golpe pesado | 3 | 1,30 | 2,31 |
| Tajo de dash | 2 | 0,76 | 2,63 |
| Onda nivel 0 | 1 | 1,00 | 1,00 |
| Onda nivel 1 | 1 | 0,90 | 1,11 |
| Onda nivel 2 | 2 | 1,20 | 1,67 |

Tiempo ideal para matar a cada jefe (todos los golpes aciertan, sin pausas; no cuenta la invulnerabilidad de la transición a la fase 2, 1,0-1,5 s):

| Jefe | Vida | Espada | Pesado | Tajo de dash | Onda 0 | Onda 1 | Onda 2 |
|---|---|---|---|---|---|---|---|
| 1 (El Leñador) | 40 | 18 s | 17 s | 15 s | 40 s | 36 s | 24 s |
| 2 (La Cosa del Pantano) | 60 | 27 s | 26 s | 23 s | 60 s | 54 s | 36 s |
| 3 (El Ojo de la Tormenta) | 80 | 36 s | 35 s | 30 s | 80 s | 72 s | 48 s |

El tajo de dash es el ataque de más DPS (2,63) pero solo se puede encadenar cada ≈ 0,76 s; el golpe pesado es casi igual que la espada.

## 2. Niveles (estático)

| Nivel | Perfil | Enemigos (tipos) | Vida total | Orbes de enemigos | Orbes del jefe (fase 2 + muerte) | Longitud | Carrera mínima (a 300 px/s) | Checkpoints |
|---|---|---|---|---|---|---|---|---|
| 1 | todos | 6 (3 cuerpo a cuerpo, 2 rápidos, 1 a distancia) | 15 | 6 | 2 + 4 | 5520 px | 18,4 s | 2 |
| 2 | compasivo / neutral | 8 (3 / 3 / 2) | 19 | 8 | 2 + 4 | 5620 px | 18,7 s | 4 |
| 2 | corrupto | 10 (4 / 3 / 3) | 24 | 10 | 2 + 4 | 5620 px | 18,7 s | 4 |
| 3 | compasivo / neutral | 9 (3 / 3 / 3) | 21 | 9 | 2 + 4 | 6220 px | 20,7 s | 4 |
| 3 | corrupto | 12 (4 / 4 / 4) | 28 | 12 | 2 + 4 | 6220 px | 20,7 s | 4 |

(Tipos: cuerpo a cuerpo / a distancia / rápido; el nivel 1 es cuerpo a cuerpo 3, rápidos 2, a distancia 1.) La variante corrupta añade 0 / 2 / 3 enemigos en los niveles 1 / 2 / 3; la agresividad del jefe es 0,90 / 1,00 / 1,15 según el perfil.

## 3. Duelos de jefe (2 semillas; valores `[semilla 1, semilla 2]`)

Tiempo de muerte del jefe (s), muertes del jugador y vida perdida en el combate.

| Jefe | Perfil (agresión) | Corazones | Tiempo | Muertes | Vida perdida | Orbes recogidos (de 6) |
|---|---|---|---|---|---|---|
| 1 | compasivo (0,90) | 8 | 19,5 / 17,8 | 1 / 0 | 10 / 8 | 2 / 2 |
| 1 | compasivo (0,90) | 11 | 18,4 / 19,5 | 0 / 0 | 10 / 10 | 2 / 2 |
| 1 | neutral (1,00) | 8 | 21,2 / 18,7 | 1 / 1 | 12 / 9 | 2 / 1 |
| 1 | neutral (1,00) | 11 | 17,9 / 17,8 | 0 / 0 | 8 / 9 | 2 / 2 |
| 1 | corrupto (1,15) | 8 | 20,7 / 19,0 | 1 / 1 | 9 / 9 | 1 / 1 |
| 1 | corrupto (1,15) | 11 | 19,0 / 19,1 | 0 / 0 | 10 / 12 | 2 / 2 |
| 2 | compasivo (0,90) | 8 | 24,2 / 29,3 | 1 / 1 | 12 / 14 | 2 / 2 |
| 2 | compasivo (0,90) | 11 | 27,1 / 29,0 | 1 / 1 | 15 / 15 | 2 / 1 |
| 2 | neutral (1,00) | 8 | 27,2 / 28,5 | 1 / 1 | 13 / 14 | 2 / 2 |
| 2 | neutral (1,00) | 11 | 30,2 / 27,6 | 1 / 1 | 14 / 13 | 2 / 1 |
| 2 | corrupto (1,15) | 8 | 28,6 / 28,2 | 1 / 1 | 14 / 14 | 2 / 2 |
| 2 | corrupto (1,15) | 11 | 31,2 / 24,9 | 1 / 0 | 16 / 11 | 2 / 2 |
| 3 | compasivo (0,90) | 8 | 37,3 / 34,6 | 2 / 1 | 21 / 14 | 2 / 2 |
| 3 | compasivo (0,90) | 11 | 33,1 / 39,4 | 1 / 1 | 18 / 22 | 0 / 2 |
| 3 | neutral (1,00) | 8 | 39,3 / 37,6 | 2 / 2 | 24 / 20 | 2 / 1 |
| 3 | neutral (1,00) | 11 | 37,7 / 35,1 | 2 / 1 | 24 / 17 | 2 / 2 |
| 3 | corrupto (1,15) | 8 | 40,6 / 37,2 | 2 / 2 | 23 / 23 | 2 / 1 |
| 3 | corrupto (1,15) | 11 | 39,0 / 33,6 | 2 / 1 | 24 / 16 | 0 / 2 |

El bot mata a los jefes casi tan rápido como el mínimo teórico solo con espada (18 / 27 / 36 s): casi todos sus golpes aciertan, así que el **tiempo de muerte lo marca el DPS del jugador, no el jefe**. La vida perdida (8-12 en el jefe 1, 11-16 en el 2, 14-24 en el 3) es **mayor que los corazones disponibles** (8 u 11): sin esquivar de verdad, los jefes 2 y 3 matan al jugador una o dos veces.

## 4. Recorridos del bot (una corrida por celda, hasta 420 s simulados)

| Nivel | Perfil | Corazones | Puerta del jefe (s) | Jefe muerto (s) | Muertes | Vida perdida | Orbes | Resultado |
|---|---|---|---|---|---|---|---|---|
| 1 | compasivo | 8 | 15,8 | 33,6 | 0 | 10 | 4 | superado |
| 1 | compasivo | 11 | 16,1 | 35,1 | 0 | 13 | 4 | superado |
| 1 | neutral | 8 | 35,5 | 51,9 | 1 | 19 | 5 | superado |
| 1 | neutral | 11 | 16,1 | 36,3 | 0 | 14 | 4 | superado |
| 1 | corrupto | 8 | 94,1 | 112,4 | 4 | 48 | 10 | superado |
| 1 | corrupto | 11 | 16,1 | 34,9 | 0 | 13 | 4 | superado |
| 2 | compasivo | 8 | 401,0 | no | 19 | 194 | 34 | tiempo agotado (jefe sin matar) |
| 2 | compasivo | 11 | 218,9 | 245,7 | 9 | 127 | 18 | superado |
| 2 | neutral | 8 | 409,8 | no | 21 | 207 | 35 | tiempo agotado |
| 2 | neutral | 11 | 143,1 | 168,5 | 5 | 82 | 17 | superado |
| 2 | corrupto | 8 | 412,3 | no | 21 | 208 | 34 | tiempo agotado |
| 2 | corrupto | 11 | 228,2 | 253,1 | 9 | 131 | 22 | superado |
| 3 | compasivo | 8 | 410,1 | no | 23 | 197 | 8 | tiempo agotado |
| 3 | compasivo | 11 | 411,2 | no | 16 | 209 | 29 | tiempo agotado |
| 3 | neutral | 8 | 413,8 | no | 23 | 197 | 12 | tiempo agotado |
| 3 | neutral | 11 | 411,6 | no | 16 | 206 | 27 | tiempo agotado |
| 3 | corrupto | 8 | 411,0 | no | 25 | 210 | 6 | tiempo agotado |
| 3 | corrupto | 11 | 417,4 | no | 17 | 219 | 30 | tiempo agotado |

(En el nivel 3 el bot llega a la puerta justo al final del tiempo y no llega a pelear con el jefe.)

## Qué se ve

- **Demasiado fácil (candidato):** el **nivel 1 con 11 corazones**: 0 muertes y 34-36 s con cualquier perfil; y el **jefe 1 con 11 corazones** (0 muertes en los duelos). Como primer nivel puede ser lo deseado.
- **Demasiado difícil (candidato):** el **nivel 3** (el bot no lo supera con ninguna combinación: 16-25 muertes en 420 s) y el **nivel 2 con 8 corazones** (19-21 muertes y no mata al jefe en 420 s, frente a 5-9 muertes y 169-253 s con 11 corazones). Los duelos con el **jefe 3** cuestan 14-24 de vida con 1-2 muertes incluso con 11 corazones.
- **Los 3 corazones extra pesan mucho:** nivel 2, de 19-21 muertes (8 corazones) a 5-9 (11 corazones). Un jugador que conserve todas las almas tiene a la vez **menos corazones** y **más enemigos** (la variante corrupta añade 2 en el nivel 2 y 3 en el 3): la decisión de conservar se castiga dos veces.
- **El perfil casi no cambia al jefe:** con agresividad 0,90 / 1,00 / 1,15 el tiempo de muerte y la vida perdida varían menos que el ruido entre semillas (jefe 1: 17,8-21,2 s). Lo que cambia la dificultad es el número de enemigos extra y los corazones.
- **Orbes:** los duelos recogen 0-2 de los 6 que suelta cada jefe (el bot no los busca); en los recorridos se recogen más, pero a costa de muchas muertes. Nadie ha comprobado si curan lo suficiente (KNOWN_ISSUES #24).
- El bot **no está calibrado con personas**: úsalo para decidir qué probar primero, no para fijar valores.

## Propuestas de ajuste (SIN aplicar; decidir tras la prueba manual)

| Dónde | Hoy | Propuesta | Motivo |
|---|---|---|---|
| `boss_three_stats.tres` `max_health` | 80 | 70 | El jefe 3 es la pelea más cara (14-24 de vida perdida) |
| Descarga pesada del jefe 3 (`boss_three.tscn`, `VolleyHeavy`) `projectile_count` / `spread_angle_degrees` | 7 / 70° | 5 / 60° | Menos proyectiles que esquivar sin quitarle presión |
| `boss_three_stats.tres` `phase_2_pattern_gap_multiplier` | 0,5 | 0,6 | La fase 2 deja muy poco respiro |
| Variante corrupta del nivel 3 (`ExtraRanged`, `ExtraMelee`, `ExtraFast`) | +3 enemigos | +2 (quitar `ExtraFast`) | El nivel 3 es el más duro y el corrupto añade más |
| Variante corrupta del nivel 2 | +2 | +1 | Conservar se castiga dos veces (corazones y enemigos) |
| `ranged_basic_stats.tres` `attack_cooldown` | 1,5 s | 1,8 s | Hay 3 enemigos a distancia en los niveles 2 y 3 |
| `default_player_stats.tres` `health_per_released_soul` / `released_souls_cap` | 1 / 3 | probar 1 / 2 | Con +3 el nivel 2 pasa de 19-21 a 5-9 muertes del bot: puede ser demasiado premio |
| Orbes del jefe (`health_orbs_on_phase_2`) | 2 | 3 | Solo si tras jugar los combates largos faltan curas |

Ninguna se ha aplicado.

---

## Fase 15a: nueva medición con el medidor de alma y la curación por enfoque

Mismo método que la 14g (bot sin calibrar con personas, 60 fps simulados, 2 semillas en los duelos, una corrida por celda en los recorridos, tope de 420 s) pero **el bot ahora usa la curación**: en el duelo se cura cuando le faltan 2 o más corazones, hay alma suficiente y está lejos del jefe (o le quedan ≤ 2 corazones); en el recorrido, cuando no hay enemigos a menos de 260 px. Los orbes ya no existen. Valores: alma por golpe 11 / 22 / 16 / 8, alma de enemigo 11 y de jefe 33, coste 33 con 0 fragmentos conservados (el bot no conserva: coste fijo 33), enfoque 0,9 s, 1 corazón por cura. El alma «desperdiciada» es la que no cabía en el medidor (tope 99).

### Duelos de jefe (valores `[semilla 1 / semilla 2]`)

| Jefe | Perfil (agresión) | Corazones | Tiempo (s) | Muertes | Vida perdida | Curas | Alma reunida | Alma desperdiciada |
|---|---|---|---|---|---|---|---|---|
| 1 | compasivo (0,90) | 8 | 24,4 / 22,6 | 0 / 0 | 11 / 10 | 6 / 5 | 253 / 242 | 96 / 110 |
| 1 | compasivo (0,90) | 11 | 21,4 / 24,6 | 0 / 0 | 11 / 11 | 3 / 2 | 165 / 165 | 195 / 192 |
| 1 | neutral (1,00) | 8 | 23,0 / 25,6 | 0 / 1 | 11 / 14 | 5 / 4 | 209 / 263 | 137 / 93 |
| 1 | neutral (1,00) | 11 | 20,8 / 17,7 | 0 / 0 | 11 / 9 | 3 / 1 | 187 / 132 | 164 / 200 |
| 1 | corrupto (1,15) | 8 | 27,1 / 22,4 | 1 / 0 | 14 / 10 | 5 / 5 | 260 / 231 | 95 / 115 |
| 1 | corrupto (1,15) | 11 | 26,9 / 24,8 | 1 / 0 | 15 / 14 | 4 / 5 | 233 / 181 | 107 / 173 |
| 2 | compasivo (0,90) | 8 | 36,3 / 36,4 | 1 / 1 | 17 / 17 | 8 / 9 | 401 / 371 | 111 / 148 |
| 2 | compasivo (0,90) | 11 | 36,5 / 35,2 | 1 / 1 | 19 / 16 | 7 / 5 | 360 / 269 | 169 / 247 |
| 2 | neutral (1,00) | 8 | 37,1 / 40,7 | 0 / 1 | 16 / 21 | 11 / 11 | 379 / 505 | 142 / 38 |
| 2 | neutral (1,00) | 11 | 33,9 / 36,1 | 0 / 1 | 15 / 18 | 7 / 5 | 308 / 308 | 235 / 233 |
| 2 | corrupto (1,15) | 8 | 34,7 / 34,6 | 1 / 1 | 19 / 20 | 6 / 5 | 296 / 239 | 246 / 282 |
| 2 | corrupto (1,15) | 11 | 35,2 / 30,4 | 1 / 1 | 18 / 14 | 5 / 2 | 299 / 217 | 222 / 312 |
| 3 | compasivo (0,90) | 8 | 46,9 / 53,9 | 2 / 2 | 24 / 28 | 8 / 12 | 451 / 450 | 253 / 256 |
| 3 | compasivo (0,90) | 11 | 45,6 / 40,4 | 1 / 1 | 24 / 20 | 7 / 5 | 379 / 308 | 321 / 384 |
| 3 | neutral (1,00) | 8 | 51,1 / 56,5 | 2 / 1 | 28 / 29 | 9 / 14 | 467 / 552 | 235 / 161 |
| 3 | neutral (1,00) | 11 | 39,5 / 42,8 | 1 / 1 | 21 / 21 | 3 / 7 | 242 / 368 | 463 / 321 |
| 3 | corrupto (1,15) | 8 | 53,0 / 51,8 | 2 / 2 | 30 / 31 | 13 / 9 | 573 / 494 | 139 / 212 |
| 3 | corrupto (1,15) | 11 | 50,4 / 44,0 | 2 / 1 | 32 / 24 | 10 / 6 | 396 / 327 | 317 / 386 |

### Recorridos del bot (hasta 420 s simulados)

| Nivel | Perfil | Corazones | Puerta del jefe (s) | Jefe muerto (s) | Muertes | Vida perdida | Curas | Alma reunida | Alma desperdiciada | Resultado |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | compasivo | 8 | 15,8 | 41,1 | 0 | 13 | 8 | 318 | 221 | superado |
| 1 | compasivo | 11 | 19,3 | 37,1 | 0 | 11 | 3 | 198 | 347 | superado |
| 1 | neutral | 8 | 29,4 | 56,2 | 1 | 22 | 9 | 407 | 242 | superado |
| 1 | neutral | 11 | 16,1 | 45,3 | 0 | 17 | 8 | 275 | 274 | superado |
| 1 | corrupto | 8 | 50,0 | 74,5 | 2 | 32 | 10 | 528 | 385 | superado |
| 1 | corrupto | 11 | 17,8 | 37,0 | 0 | 11 | 3 | 176 | 345 | superado |
| 2 | compasivo | 8 | 22,7 | 58,7 | 1 | 24 | 11 | 484 | 281 | superado |
| 2 | compasivo | 11 | 22,7 | 51,0 | 1 | 24 | 5 | 330 | 413 | superado |
| 2 | neutral | 8 | 44,0 | 79,1 | 2 | 36 | 15 | 676 | 316 | superado |
| 2 | neutral | 11 | 27,2 | 56,3 | 2 | 35 | 5 | 373 | 345 | superado |
| 2 | corrupto | 8 | 399,6 | no | 15 | 205 | 78 | 3314 | 1946 | tiempo agotado (jefe sin matar) |
| 2 | corrupto | 11 | 24,2 | 58,7 | 0 | 21 | 11 | 415 | 369 | superado |
| 3 | compasivo | 8 | 394,6 | no | 12 | 198 | 94 | 3608 | 1598 | tiempo agotado (jefe sin matar) |
| 3 | compasivo | 11 | 418,0 | no | 13 | 205 | 60 | 2772 | 3300 | tiempo agotado (jefe sin matar) |
| 3 | neutral | 8 | 416,3 | no | 15 | 205 | 84 | 3483 | 1822 | tiempo agotado (jefe sin matar) |
| 3 | neutral | 11 | 388,4 | no | 13 | 219 | 67 | 2876 | 2860 | tiempo agotado (jefe sin matar) |
| 3 | corrupto | 8 | 408,0 | no | 13 | 209 | 100 | 4017 | 1131 | tiempo agotado (jefe sin matar) |
| 3 | corrupto | 11 | 415,0 | no | 13 | 219 | 73 | 2861 | 2833 | tiempo agotado (jefe sin matar) |

### Comparación con la 14g (orbes) y qué se ve

- **Los duelos duran más:** el jefe 1 pasa de ~18-21 s a ~21-27 s, el 2 de ~24-31 s a ~30-41 s y el 3 de ~34-40 s a ~40-57 s. El bot gasta varios segundos por cura enfocando parado (5-14 curas por duelo con 8 corazones); en un duelo real un jugador curaría menos y a mejor momento.
- **La vida perdida y las muertes en los duelos casi no cambian** (jefe 1: 9-15; jefe 2: 14-21; jefe 3: 20-32) a pesar de las curas. Cada cura devuelve 1 corazón, pero el bot recibe golpes mientras se enfoca (un golpe lo interrumpe sin gastar alma), así que **curarse en plena pelea rinde poco**. Con 8 corazones los jefes 2 y 3 siguen costando 1-2 muertes por duelo.
- **Mejora real en el recorrido del nivel 2:** con 8 corazones los perfiles compasivo y neutral ahora **superan** el nivel (antes: tiempo agotado con 19-21 muertes); el corrupto con 8 corazones sigue sin superarse (15 muertes, 78 curas). Con 11 corazones el nivel 2 baja de 5-9 muertes a 0-2. El nivel 1 sigue siendo fácil (0-2 muertes; el corrupto con 8 corazones, 2).
- **El nivel 3 sigue sin superarse:** el bot llega a la puerta del jefe al final del tiempo (388-418 s) y no llega a pelear; 12-15 muertes y 60-100 curas. Las curas no cambian el resultado del bot, así que sigue siendo el candidato a «demasiado difícil» de la 14g.
- **Alma reunida y desperdiciada:** el medidor se llena de sobra: con 11 corazones el bot desperdicia más alma de la que usa (p. ej. nivel 1 con 11 corazones: 176-275 reunida, 345-347 desperdiciada; duelo 3 con 11 corazones: 242-396 reunida y 317-463 desperdiciada), porque se cura menos al faltarle menos vida. Con 8 corazones la proporción es más equilibrada (≈ 25-40 % desperdiciada). Es decir, **la alma sobra**: solo hay escasez cuando se pierde mucha vida de golpe.
- **Demasiado fácil (candidato):** nivel 1 con 11 corazones (0 muertes, ~37 s) y el jefe 1 con 11 corazones; ahora con la cura además hay alma de sobra.
- **Demasiado difícil (candidato):** el nivel 3 completo; y el nivel 2 corrupto con 8 corazones. En ambos conservar fragmentos (menos corazones, curarse más caro) empeora algo que ya era duro.
- **Aviso sobre el coste:** el bot mide con coste 33 (no conserva fragmentos). Con 3 fragmentos conservados el coste es 48: una cura cuesta casi la mitad del medidor y harían falta ≈ 4,4 golpes ligeros por cura. No está medido; se recomienda probarlo a mano (ver `docs/QA_CHECKLIST.md` ALM-07).
- El bot sigue **sin estar calibrado con personas**.

### Propuestas de ajuste (SIN aplicar; decidir tras la prueba manual)

| Dónde | Hoy | Propuesta | Motivo |
|---|---|---|---|
| `default_soul_config.tres` `heal_cost_base` | 33 | 33 (mantener) y subir `heal_cost_per_kept` solo si la prueba manual dice que conservar es gratis | La alma sobra con 11 corazones; hoy el coste no es el cuello de botella |
| `default_soul_config.tres` `wisp_boss` | 33 | 22 | Un jefe da tanto como 3 golpes ligeros y el medidor ya se desborda en los duelos |
| `default_soul_config.tres` `gain_wave` / `gain_light` | 8 / 11 | probar 6 / 9 si la cura resulta demasiado fácil de conseguir | El bot desperdicia 25-60 % del alma reunida |
| `default_soul_config.tres` `focus_time` | 0,9 s | probar 0,8 s si en la prueba manual casi nunca se logra curar en combate | Un golpe interrumpe el enfoque y la cura rinde poco en duelos |
| Mantener las propuestas de la 14g sobre el nivel 3 (`boss_three_stats.tres`, `VolleyHeavy`, variante corrupta) | ver arriba | igual | Las curas no cambian que el bot no supere el nivel 3 |
| Variante corrupta del nivel 2 | +2 enemigos | +1 | El nivel 2 corrupto con 8 corazones sigue sin superarse |
| `health_per_released_soul` / `released_souls_cap` | 1 / 3 | probar 1 / 2 | Con 11 corazones el nivel 2 pasa de 15 muertes (8 corazones, corrupto) a 0 |

Ninguna se ha aplicado.

---

## Fase 15c: alcance con el doble salto y simulación del jefe 2 rediseñado

### Alcance medido con el jugador real (suelo plano, carrera de arranque, mantener el salto)

| Maniobra | Subida | Alcance horizontal | Tiempo en el aire |
|---|---|---|---|
| Salto | 112 px | 220 px | 0,73 s |
| Salto + doble salto | 192 px | 355 px | 1,18 s |
| Salto + dash (mejor momento) | 112 px | 388 px | 1,05 s |
| Salto + doble salto + dash (mejor momento) | 192 px | 538 px | 1,55 s |

(La cifra de 328 px de «salto + dash» de la 14g salía de un momento fijo del dash; con el mejor momento se miden 388 px.) El doble salto **solo añade**: todo hueco que se cruzaba antes se sigue cruzando. La subida del nenúfar es de 310 px.

### Huecos del nivel 3 con el doble salto (propuesta sin aplicar: pertenece a la fase del jefe 3)

- El doble salto se desbloquea al decidir sobre el jefe 2, así que los niveles 1 y 2 se juegan siempre sin él (sus huecos de 285 px y de 170-175 px no cambian). **El nivel 3 se juega siempre con el doble salto** (ya hay 2 decisiones).
- Los **huecos de 285 px** del nivel 3 (tres, hasta la arena) exigían salto + dash (alcance 328-388 px). Con el doble salto el alcance sin dash es 355 px: pasan a ser **triviales** (margen de 70 px y sin gastar el dash).
- El **hueco de 175 px** del nivel 3 ya se cruzaba con un salto (220 px); sigue igual.
- Propuesta (sin aplicar; pertenece a la fase del jefe 3): para que el dash siga haciendo falta en el nivel 3, los huecos deberían medir **más de 355 px**, por ejemplo **420-480 px** (el máximo con salto + doble salto + dash es 538 px; dejar un 10-20 % de margen), o rediseñar el nivel con plataformas intermedias. Medir de nuevo con el jugador real.

### Refugio ante los pinchos

Peor caso: **0,73 s** (en x = 4620, junto a la puerta), contra 1,2 s de aviso: 0,47 s de margen sin contar el tiempo de reacción. Se calcula, para cada x del suelo de la arena, con el tiempo real medido de caminar y saltar, el más corto entre caer sobre un nenúfar (andar hasta poder caer sobre él + 0,73 s de salto) y subir a una plataforma baja (andar hasta estar debajo + 0,22 s).

### Contraste de los pinchos

Peor contraste del aviso y de los pinchos contra los colores del fondo y del suelo de los biomas del nivel 2 (la regla de la 14e, mejor de las dos tonalidades): **2,80** (umbral 2,5).

### Simulación del duelo del jefe 2 en la arena real (comparación con la Fase 15a)

| Perfil | Corazones | Jefe vivo al final (de 60 PV) | Tiempo del jefe en plataformas | Muertes | Vida perdida | Golpes de pinchos | Saltos del jefe | Curas | Resultado |
|---|---|---|---|---|---|---|---|---|---|
| neutral | 8 | 60 / 45 | 63 % / 70 % | 5 / 4 | 57 / 51 | 0 / 2 | 19 / 19 | 12 / 7 | 0 de 2 derrotado en 240 s |
| neutral | 11 | 39 / 43 | 67 % / 85 % | 4 / 2 | 61 / 43 | 1 / 1 | 17 / 22 | 9 / 14 | 0 de 2 derrotado en 240 s |

(Los otros dos perfiles, medidos sin las columnas de vida y de plataformas: 0 de 8 duelos derrotados en 240 s, 2-5 muertes y 34-66 de vida perdida.) En la Fase 15a el bot derrotaba al jefe 2 en 30-41 s con 1 muerte; **ahora no lo derrota en ningún duelo de 240 s**.

**Cómo leerlo (límites del bot):** el bot solo camina, salta de forma aleatoria y ataca de cerca; se refugia en las plataformas bajas cuando hay pinchos y se coloca debajo del jefe si está arriba, pero **no usa los nenúfares ni el doble salto** y no puede golpear al jefe cuando está en el piso alto. Como el jefe pasa entre el 63 % y el 85 % del tiempo en las plataformas, casi todo el daño se pierde: la simulación demuestra que el combate es muy distinto, **no** cuánto cuesta a una persona. Los pinchos casi no le llegan al bot (0-2 golpes por duelo), señal de que el refugio es fácil.

**Marcado:** *demasiado difícil* (candidato) por la cantidad de tiempo que el jefe pasa fuera de alcance; *pinchos demasiado fáciles* de esquivar (0-2 golpes) con el margen de 0,47 s.

**Propuestas de ajuste (SIN aplicar; decidir tras la prueba manual):**

| Dónde | Hoy | Propuesta | Motivo |
|---|---|---|---|
| Nodo `Leap` (fase 2) de `boss_two.tscn`: `weight` | 1,8 | 1,0 | El jefe pasa demasiado tiempo en plataformas |
| `Leap` / `LeapLight`: `cooldown` | 5,0 / 6,0 s | 8,0 / 9,0 s | Menos saltos seguidos |
| Descarga de la percha (`LeapVolley`): `telegraph_time`, `recovery_time` | 0,8 / 0,7 s | 0,6 / 0,4 s | Percha más corta (entra menos tiempo arriba) |
| `LeapPattern.aim_at_player_chance` | 0,7 | 0,5 | Que a veces suba a plataformas lejanas al jugador (más variedad) |
| `default_floor_hazard_config.tres`: `warning_time` / `rest_time` | 1,2 / 4,0 s | 1,0 / 3,0 s | El refugio cuesta 0,73 s: se puede apretar sin hacerlo injusto |
| `default_bounce_config.tres`: `launch_velocity` | −1030 | mantener | Ya llega a las plataformas altas con margen (310 px sobre 250 px) |

Ninguna se ha aplicado.

---

## Fase 15d: ajuste del jefe 2 y contraste de la posesión

### Ajuste aplicado (el único cambio de valores de la fase)

| Valor | Antes | Ahora | Motivo (de la medición de la 15c) |
|---|---|---|---|
| Peso del salto en la fase 2 (`Leap`) | 1,8 | 1,2 | El jefe pasaba entre el 63 % y el 85 % del combate en plataformas |
| Recarga del salto de la fase 2 (`Leap`) | 5 s | 7 s | Menos saltos seguidos |
| Recarga del salto de la fase 1 (`LeapLight`) | 6 s | 8 s | Idem |

No se tocaron el aviso de los pinchos (1,2 s, margen de refugio 0,47 s), su descanso, los nenúfares ni ningún otro número. No se ha vuelto a simular el duelo: el bot sigue sin usar nenúfares ni doble salto, así que la prueba útil sigue siendo la manual (`docs/QA_CHECKLIST.md`, BAL-02).

### Contraste sobre el fondo poseído (umbral 2,5 de las fases 14e y 14f)

Peor valor de cada bioma de los tres niveles (todos los telegrafiados, el aviso y los pinchos, los proyectiles enemigos y el pato, contra el fondo con el tinte de cada perfil y el rojo de la posesión, en su pico y persistente, y contra el suelo, que no se tiñe):

| Bioma | Peor contraste |
|---|---|
| ruined_city | 2,72 |
| forest | 2,62 |
| flooded_suburb | 2,64 |
| swamp | 2,59 |
| industrial | 2,66 |
| storm | 3,11 |

Peor valor general: **2,59** (telegrafiado del bruto sobre el bioma del pantano). El margen es corto: si en ventana real el rojo estorba, bajar `sky_tint` / `persistent_sky` en `default_possession_config.tres`.

---

## Fase 15d-bis: jefe 2 con 50 PV

Cambio aplicado: vida del jefe 2 de 60 a 50 (línea de la fase 2 en el 55 %: de 33 a 27,5 PV). Ningún otro valor del jefe 2 cambia (el salto de la 15d se mantiene).

Tiempo ideal para matarlo (todos los golpes aciertan, sin pausas; calculado con la tabla de DPS de la sección 1; no cuenta la transición de la fase 2, de unos 3 s con la posesión):

| Ataque | DPS | 60 PV (antes) | 50 PV (ahora) |
|---|---|---|---|
| Espada | 2,22 | 27 s | **22,5 s** |
| Golpe pesado | 2,31 | 26 s | 21,7 s |
| Tajo de dash | 2,63 | 23 s | 19,0 s |
| Onda nivel 0 | 1,00 | 60 s | 50 s |
| Onda nivel 1 | 1,11 | 54 s | 45 s |
| Onda nivel 2 | 1,67 | 36 s | 30 s |

No se han repetido las simulaciones del bot en esta fase (el bot sigue sin usar nenúfares ni el doble salto); la prueba útil es la manual (`docs/QA_CHECKLIST.md`, LAR-01).

### Números del nenúfar elevado (calculados a partir de las estadísticas del jugador, sin simulación)

| Valor | Cifra |
|---|---|
| Cima del nenúfar sobre el suelo | 56 px (el salto del pato sube 112 px) |
| Velocidad de lanzamiento | −930 px/s (antes −1030 desde el suelo) |
| Subida desde la cima | 930² / (2 · 1800) = 240 px |
| Los pies llegan a (56 + 6 de margen + 240) | ≈ 302 px sobre el suelo |
| Piso alto de la arena | 250 px (margen de 52 px) |
| Espacio hasta el techo (440 px − 302 px − 52 px del pato) | 86 px |
| Doble salto desde el suelo (112 + 77 px) | 189 px, no llega al piso alto |

El margen de refugio ante los pinchos con los nenúfares elevados lo calcula la prueba `phase15d2_smoke_test` con las estadísticas reales (línea `MEASURE|shelter with raised pads`). Una simulación previa fuera del juego dio un peor caso de 0,60 s de 1,2 s de aviso, es decir un margen de 0,60 s (se exige al menos 0,3 s).

### Barrido de inactividad del jefe 2

Rejilla de 7 posiciones del jefe (3 de suelo y 4 de plataforma) por 8 del pato (3 de suelo, 4 de plataforma y en el aire sobre un nenúfar), en la fase 1, y una rejilla menor en la fase 2 (91 combinaciones). En la primera ejecución de la prueba **las 91 combinaciones empezaron un ataque** (ninguna se quedó sin atacar): salieron 52 saltos (normales y de reserva), 19 embestidas, 11 tajos y 9 descargas. El jefe espera el hueco entre patrones (1,1 s en la fase 1, menos en la 2) y ese hueco ahora está limitado por `max_idle_time` (1,5 s). La cifra del peor tiempo de esa primera ejecución no es fiable (se contó en ticks de física con la escala de tiempo a 4): la prueba ya corregida mide el tiempo de juego real y lo imprime en la línea `MEASURE|boss 2 idle sweep`; por diseño el techo es 1,1-1,2 s (el hueco) y nunca más de 1,5 s.

### Contraste de los colores de la onda

Calculado fuera del juego con la regla de la 14e (el mejor entre el color, el borde claro, el núcleo oscuro y el contorno oscuro) contra los tres perfiles y los biomas de los tres niveles: nivel 0 4,19, nivel 1 4,04, nivel 2 3,79 en el peor caso; el violeta contra el fondo corrupto (solo borde claro y núcleo oscuro) 3,91. La prueba nueva vuelve a medirlos con los recursos del juego (líneas `MEASURE|wave contrast`).

---

## Fase 15d-ter: daño de la onda por nivel

Solo cambia el daño de los niveles 1 y 2 de la onda (recarga, velocidad, alcance, perforación, caja de golpe y alma por golpe: igual).

| Nivel | Daño antes → ahora | Recarga | Velocidad | Caja de golpe | Daño por segundo antes → ahora |
|---|---|---|---|---|---|
| 0 | 1 → 1 | 1,0 s | 520 px/s | 16 × 44 px | 1,00 → 1,00 |
| 1 | 1 → **2** | 0,9 s | 580 px/s | 21,6 × 59,4 px | 1,11 → **2,22** |
| 2 | 2 → **3** | 1,2 s | 640 px/s | 27,2 × 74,8 px | 1,67 → **2,50** |

Referencias de la tabla de la sección 1: espada 2,22, golpe pesado 2,31, tajo de dash 2,63. El nivel 2 queda por debajo del tajo de dash y un 8 % por encima del golpe pesado (límite pedido: 15 %).

### Tiempo ideal para matar a cada jefe solo con la onda (todos aciertan, sin pausas)

| Jefe (vida) | Nivel 0 | Nivel 1 | Nivel 2 | Golpes de la onda (0 / 1 / 2) | Espada sola |
|---|---|---|---|---|---|
| 1 (40) | 40 s | 18,0 s | 16,0 s | 40 / 20 / 14 | 18 s |
| 2 (50) | 50 s | 22,5 s | 20,0 s | 50 / 25 / 17 | 22,5 s |
| 3 (80) | 80 s | 36,0 s | 32,0 s | 80 / 40 / 27 | 36 s |

**Desviación del objetivo y de la regla:**
- Objetivo del jefe 2: nivel 0 ≈ 50 s (cumplido), **nivel 1 ≈ 32 s (no alcanzable: 22,5 s)** y nivel 2 ≈ 20 s (cumplido). Con daño entero y la misma recarga el nivel 1 solo puede dar 45 s (daño 1) o 22,5 s (daño 2); se eligió 2.
- Regla del jefe 1: el nivel 2 solo con la onda baja a **16 s**, algo por debajo del límite de unos 18 s. Bajar el daño del nivel 2 a 2 lo arreglaría (24 s) pero igualaría su daño al del nivel 1 y no cumpliría «el daño crece en cada nivel». Se mantiene 3 y se deja marcado (KNOWN_ISSUES #87). Jefe 3 con el nivel 2: 32 s (la espada sola: 36 s).
- Alternativa si se quiere afinar sin tocar el daño: subir la recarga del nivel 2 (de 1,2 s a 1,35 s con daño 3 da 2,22 de daño por segundo: jefe 1 en 18 s y jefe 2 en 22,5 s, como el nivel 1), o dar al nivel 1 más recarga.

### Enemigos normales (golpes de onda para matar)

| Enemigo (vida) | Nivel 0 | Nivel 1 | Nivel 2 |
|---|---|---|---|
| Rápido (2) | 2 | **1** | **1** |
| A distancia (2) | 2 | **1** | **1** |
| Cuerpo a cuerpo (3) | 3 | **2** | **1** |
| Bruto acorazado (8) | 8 | **4** | **3** |

El nivel 0 no cambia. Los niveles superiores matan a algunos en menos golpes (permitido). La onda sigue dando 8 de alma por golpe, así que con menos golpes por enemigo se junta algo menos de alma por enemigo.

## Fase 15e-1: jefe 3

Medido por `phase15e1_smoke_test` (tiempo de juego real).

- Vida 70: fase 1 = 24, fase 2 = 23, fase 3 = 23. Golpe máximo 1 corazón.
- Solo espada ligera ideal: 31,5 s de daño + 6,4 s de posesiones = 39,8 s (por debajo de 60 s). Con la guardia, Kenzo ronda 12,2 s.
- Solo onda (todos aciertan): nivel 0 = 70,0 s (70 golpes), nivel 1 = 31,5 s (35), nivel 2 = 28,0 s (24).
- Ojo: altura 170 px, picado a 80 px cada 3,0 s durante 1,2 s (máximo sin picado medido 3,00 s de 4,0 permitidos); apogeo salto simple 106,8 px, doble 183,9 px.
- Rayo: 34 x 110 px a 420 px/s, sobre un punto 0,386 s; ventana de salto 0,553 s, doble salto 0,972 s, solape en dash 0,145 s de 0,18 s.
- Columnas: peor margen del carril seguro 0,67 s (mínimo exigido 0,3 s); hueco mínimo 120 px.
- Inactividad máxima del jefe: 1,00 s (límite 1,5 s).
- Contraste peor caso: telegraph rayo 4,18, telegraph columna 4,04, rayo activo 4,83, columna activa 4,83, brillo 3,44; con el rojo de posesión 6,05 (mínimo 2,5).

## Fase 15e-2: alcance y huecos del nivel 3

Alcance medido por `phase15e2_smoke_test` con un modelo paso a paso del movimiento real (recorrido del centro con la mejor sincronía; efectivo = + 58 px de margen de las reglas reales).

| Combinación | Centro (px) | Efectivo (px) |
|---|---|---|
| Salto | 206,4 | 264 |
| Salto + doble salto | 382,2 | 440 |
| Salto + dash | 374,4 | 432 |
| Salto + doble salto + dash | 550,8 | 609 |

Mejor sincronía de las tres: doble salto 0,59 s y dash 1,15 s tras el salto.

| Hueco | Antes | Ahora | % del alcance máximo | Necesita |
|---|---|---|---|---|
| 1 (x 1300-1785) | 285 | 485 | 80 % | doble salto + dash |
| 2 (x 2900-3360) | 175 | 460 | 76 % | doble salto + dash |
| 3 (x 4385-4910) | 285 | 525 | 86 % | doble salto + dash |

Desplazamientos acumulados: +200, +485, +725 px. Enemigo más cercano a un borde: 150 px. Cruce con el jugador real: los tres huecos se cruzan con las tres acciones y no con doble salto solo, dash solo ni salto solo.

## Fase 15e-2b: huecos del nivel 3 reequilibrados

| Hueco | Original | 15e-2 | Ahora | Necesita | Margen (recorrido del centro) | Margen (efectivo) |
|---|---|---|---|---|---|---|
| 1 (x 1300-1680) | 285 | 485 | 380 | salto + doble salto (dash opcional) | 0,6 % (2 px de 382,2) | 13,7 % (60 px de 440) |
| 2 (x 2795-3245) | 175 | 460 | 450 | las tres acciones | 18,3 % (101 px de 550,8) | 26,1 % (159 px de 609) |
| 3 (x 4270-4754) | 285 | 525 | 484 | las tres acciones | 12,1 % (67 px de 550,8) | 20,5 % (125 px de 609) |

Las cifras de alcance no cambian (206,4 / 382,2 / 374,4 / 550,8 en recorrido del centro). Desplazamientos: +95, +370 y +569 px. El jugador real cruza cada hueco con sus acciones y no sin ellas.

## Fase 15e-2c: tabla vigente de huecos del nivel 3

| Hueco | Original | Ahora | Necesita | Margen (centro) | Margen (efectivo) |
|---|---|---|---|---|---|
| 1 (x 1300-1636) | 285 | 336 | salto + doble salto (dash opcional) | 12,1 % (46 px de 382,2) | 23,6 % (104 px de 440) |
| 2 (x 2751-3201) | 175 | 450 | las tres acciones | 18,3 % (101 px de 550,8) | 26,1 % (159 px de 609) |
| 3 (x 4226-4710) | 285 | 484 | las tres acciones | 12,1 % (67 px de 550,8) | 20,5 % (125 px de 609) |

Desplazamientos respecto al original: +51, +326 y +525 px.

## Fase 15f: la capa de Kenzo con un golpe

Calculado en `phase15f_smoke_test` (golpe pesado = 3 de daño y 1,3 s por ciclo, ventana vulnerable de 5,5 s: aturdido 2,5 s más regeneración 3,0 s).

- Fase 2 (23 de vida) solo espada, ideal: 10,3 s con la capa (10,4 s sin capa); con dos golpes eran 12,2 s. Pelea entera con las posesiones: unos 37,8 s (bajo el tope de 60 s).
- Solo onda (todos aciertan): nivel 0 = 65,4 s, nivel 1 = 31,4 s, nivel 2 = 28,1 s en toda la pelea (la fase 2 dura 18,4 / 10,3 / 9,3 s; hace falta un tajo pesado para romper la capa).
- Contraste del borde de la capa (la mejor de la arista clara o el contorno oscuro): peor caso 3,85 sobre todos los colores del escenario, los tres perfiles y el rojo de la posesión (3,87 con el rojo); el relleno frente al contorno 5,34 (mínimo 2,5).

## Fase 15g: placas eléctricas (las corrientes de aire se quitaron en la Fase 15o)

Calculado en `phase15g_smoke_test` con las estadísticas reales del jugador (gravedad 1800, velocidad 300 px/s). La tabla de corrientes y de la ruta alta `UpperRouteD` ya no existe: el nivel 3 no tiene corrientes y la ruta alta se retiró con ellas.

| Placa | Ciclo | Caminar fuera desde el centro | Margen sobre el aviso de 1,2 s |
|---|---|---|---|
| Tramo A, 220 px | 1,2 / 2,0 / 3,0 s | 0,48 s | 0,72 s (mínimo exigido 0,3 s) |

Contraste (la mejor de la figura o el contorno oscuro) sobre todos los fondos y perfiles: aviso de placa 3,75; descarga 3,99; rayo 4,18; aire de corriente 3,77 (mínimo 2,5). Parpadeo de lámparas: 2,5 por segundo, máximo 0,30 de opacidad.

## Fase 15h-bis: ventanas de tolerancia de los huecos del nivel 3

Medidas **del modelo** (misma física que `player.gd`: velocidad 300, salto 620, doble salto 527, gravedad 1800, dash 700 px/s durante 0,18 s, despegue con el centro en el borde). Las ventanas del jugador real las mide `phase15h2_smoke_test`; **esa medición no se completó** (ver KNOWN_ISSUES).

| Hueco | Ancho antes | Ancho después | Estrategia | Ventana de la 2.ª acción (modelo) | Margen de despegue (modelo) |
|---|---|---|---|---|---|
| 1 | 336 | 336 | salto + doble salto | ≈ 360 ms | 60 px de recorrido de sobra |
| 1 | 336 | 336 | salto + dash | ≈ 375 ms | 53 px |
| 1 | 336 | 336 | las tres | doble salto ≥ 400 ms, dash ≈ 375 ms | > 200 px |
| 2 | 450 | 450 | las tres | doble salto ≈ 435 ms, dash ≈ 130 ms | 112 px |
| 3 | 484 | 484 | las tres | doble salto ≈ 435 ms, dash ≈ 130 ms | 78 px |

Salto + doble salto solo llega a 440 px y salto + dash solo a 433 px (con la tolerancia de 58 px del cuerpo), de modo que el hueco 2 (450) y el hueco 3 (484) siguen sin poder cruzarse con ellos, pero el margen en el 2 es de solo ~10 px.

Medido con el nivel real (antes de arreglarlo): con el jugador parado en el borde del hueco 1, `Fast3` llegó en 2 s, lo golpeó dos veces y cayó al foso en menos de 5 s. Después: aproximación mínima de los enemigos a un borde 244 px, sin golpes ni caídas en 15 s.

## Fase 15j: el jefe 3 de invocador (cálculo con los números reales del jugador)

| Dato | Valor |
|---|---|
| PV por fase | fase 1: 24 PV (70 → 46), fase 2: 23 PV (46 → 23), fase 3: 23 PV |
| Ciclo de la fase 2 con juego perfecto | ≈ 23 s (0,8 s + 2 × 2,5 s de invocación, 0,5 s de espera, 1,5 s de temblor, 0,6 s de salto, 0,7 s de derrumbe, 5,0 s de andanada, 1,0 s de brillo, 0,5 s de aterrizaje, 6,0 s de ventana, 0,9 s de vuelta) |
| Daño por ventana (6 s menos 0,8 s de acercamiento) | espada ligera 11,6 · pesada 12,0 · onda nivel 0: 5,2 · nivel 1: 11,5 · nivel 2: 13,0 |
| Ciclos de la fase 2 | espada sola: 2 · onda nivel 0: 5 · nivel 1: 2 · nivel 2: 2 |
| Tiempos ideales solo con espada | fase 1 ≈ 11 s · fase 2 ≈ 44 s · fase 3 ≈ 10 s (más las dos posesiones) |
| Tiempos ideales solo con onda (fase 3) | nivel 0: 23 s · nivel 1: 10 s · nivel 2: 9 s |
| Margen de la andanada | peor caso 0,36 s sobre 0,3 s (de 600 planes; hace falta 0,78 s para pasar a la plataforma vecina y la proyectil tarda ≥ 1,14 s) |
| Margen de los rayos rojos | peor caso 0,74 s sobre 0,3 s (1584 planes); carril de 130 px a ≤ 110 px del jugador |
| Contraste (≥ 2,5) | aviso del rayo 3,08 · núcleo del rayo 4,64 · marcador de carril 3,11 · ojo 3,96 · peor con el rojo de posesión 3,73 |
| Tiempo ocioso máximo | fase 1: 0,90 s · fase 2 (entre ciclos): 0,63 s · fase 3: 0,37 s (límite 1,5 s) |

## Fase 15o y 15p: duración de la fase 1 del jefe 3 sin armadura

Medido por `phase15j_smoke_test` («boss 3 ideal times», juego perfecto con la espada ligera, 2,22 PV por segundo):

| | Fase 1 | Fase 2 | Fase 3 |
|---|---|---|---|
| Fase 15j (con armadura), 70 PV | 24 PV, ≈ 11 s | 23 PV, ≈ 44 s (2 ciclos) | 23 PV, ≈ 10 s |
| Fase 15o (sin armadura, 70 PV) | 24 PV, **≈ 10 s** | igual | igual |
| Fase 15p (102 PV, líneas 0,451 y 0,2255) | **56 PV, ≈ 24 s** | 23 PV, ≈ 44 s | 23 PV, ≈ 10 s |

Los PV absolutos de las fases 2 y 3 no cambian (23 PV cada una): la línea 1 cae en 46 PV (102 × 0,451 = 46,0) y la línea 2 en 23 PV (102 × 0,2255 = 23,0). Las cifras de «≈ 30 s» y «65 s» que se escribieron en la Fase 15o eran estimaciones sin medir y quedan sustituidas por esta tabla.

## Fase 15p: alcance de los huecos del nivel 3 (tabla de la prueba de la Fase 15b)

Huecos 336 / 450 / 484 px (sin cambios). Con el doble salto y el dash ya disponibles en el nivel 3: salto + doble salto llega a 440 px y salto + dash a 433 px (hueco 1, 2 acciones); la cadena de tres acciones cruza los huecos 2 y 3. Los niveles 1 y 2 siguen con saltos y salto + dash (≤ 328 px).
