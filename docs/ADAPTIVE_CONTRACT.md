# Contrato del perfil adaptativo

Fase 9: sistema local (fallback obligatorio sin conexión) y contrato que usará el servicio remoto. El servicio HTTP todavía no está documentado ni implementado.

## Perfiles

Escala ordenada: `compassionate` = 0, `neutral` = 1, `corrupt` = 2. Los ids viven en `AdaptiveIds` (`game/backend/ai/adaptive_ids.gd`); `GameState` apunta a los mismos valores.

## Regla local

`LocalProfileClassifier` (puro y determinista, sin autoloads ni archivos):

`score = Σ peso(nivel) × (+1 si "released", −1 si "kept")`

- `score >= umbral` → `compassionate`
- `score <= −umbral` → `corrupt`
- en otro caso (o sin decisiones) → `neutral`

Valores por defecto (`default_adaptive_config.tres`, marcadores de posición): umbral 2.0, pesos `[1, 1, 1]` (un índice ausente cuenta 1.0), `max_profile_distance` 1.

## Valores de salida (controlados)

Todo sale de la tabla del perfil en `AdaptiveConfig`:

| Perfil | narrativa (por defecto / permitidas) | encuentro | final | agresión del jefe |
|---|---|---|---|---|
| compassionate | `mercy` / `mercy`, `mercy_hopeful` | `calm` | `ending_compassionate` | 0.9 |
| neutral | `balanced` / `balanced` | `standard` | `ending_neutral` | 1.0 |
| corrupt | `burden` / `burden`, `burden_bitter` | `corrupted` | `ending_corrupt` | 1.15 |

Las variantes y parámetros no se guardan en la partida: se derivan del perfil guardado (`adaptive_profile`).

## JSON remoto esperado

```json
{ "profile": "compassionate|neutral|corrupt", "narrative_variant": "<opcional>" }
```

## Reglas de validación (`AdaptiveResponseValidator`)

1. La respuesta debe ser un `Dictionary` y `profile` un `String`.
2. Si `profile` mide más de 64 caracteres se rechaza antes de comparar.
3. Se normaliza con `strip_edges()` y minúsculas; debe ser IGUAL a uno de los tres ids (sin coincidencias parciales ni texto libre).
4. `narrative_variant` es opcional: si no es un `String` de ≤ 64 caracteres o no está en la lista permitida del perfil, se usa la variante por defecto y se añade una advertencia (la respuesta se acepta).
5. Se rechaza si la distancia entre el perfil remoto y el local supera `max_profile_distance`.
6. Cualquier otra clave se ignora.

El resultado aceptado tiene `source = "remote"`. Nunca lanza errores por entradas malas: devuelve `{ok, result, reason}`.

## El remoto nunca fija parámetros numéricos

Solo puede elegir un perfil (a distancia limitada del local) y una variante narrativa de la lista permitida. Variante de encuentro, final y `boss_aggression` salen SIEMPRE de la tabla del perfil validado; un `boss_aggression`, `encounter_variant` o texto extra enviado por el remoto no tiene efecto.

## Orden en el flujo de decisión

`record_decision` → `refresh_adaptive_profile(POINT_AFTER_DECISION)` → `autosave()`. Una decisión rechazada no refresca ni guarda. El refinamiento remoto futuro será asíncrono, posterior a este resultado local inmediato, y nunca bloqueará el flujo.

## Contrato HTTP del servicio de IA (Fase 10)

El servicio (`ai-service/`) implementa el JSON remoto de arriba. El juego lo consulta DESPUÉS del resultado local y de forma asíncrona; si falla, se conserva el resultado local.

### `GET /health`

`{ "status": "ok", "mode": "mock"|"openai", "openai_configured": bool }` (nunca revela la clave).

### `POST /v1/adaptive/profile`

Petición (estricta; cualquier campo extra, tipo o rango incorrecto → 422; cuerpo máximo 16 KB → 413):

```json
{
  "released": 0,            // int 0-10
  "kept": 0,                // int 0-10
  "current_level": 1,       // int 1-3
  "evaluation_point": "after_decision",   // after_decision | level_start | ending (AdaptiveInput.POINT_*)
  "local_profile": "neutral",             // compassionate | neutral | corrupt
  "decisions": [            // máximo 10
    { "fragment_id": "fragment_level_1", "boss_id": "placeholder_boss", "level": 1, "choice": "released" }
  ]
}
```

`fragment_id` y `boss_id` deben cumplir `^[a-z0-9_]{1,64}$`; `choice` es `released` o `kept`.

Respuesta 200:

```json
{ "profile": "compassionate|neutral|corrupt", "narrative_variant": "<de la lista permitida del perfil>", "source": "openai"|"mock" }
```

Variantes permitidas (reflejan `default_adaptive_config.tres`): compassionate → `mercy`, `mercy_hopeful`; neutral → `balanced`; corrupt → `burden`, `burden_bitter`.

### Errores

| Estado | Significado |
|---|---|
| 413 | Cuerpo demasiado grande |
| 422 | Petición inválida (respuesta sin eco de los datos enviados) |
| 502 | OpenAI falló o devolvió una respuesta inutilizable (mensaje genérico) |
| 503 | Modo `openai` sin `OPENAI_API_KEY` u `OPENAI_MODEL` |
| 504 | Tiempo de espera agotado con OpenAI |

Los mensajes de error son genéricos: no incluyen claves, prompts ni texto de excepciones del SDK.

### Tiempos y salida del modelo

- Servicio → OpenAI: `OPENAI_TIMEOUT_SECONDS` (8 s por defecto), un reintento como máximo.
- Juego → servicio: `request_timeout_seconds` (10 s por defecto) y `max_response_bytes` (4096).
- Se usa la Responses API de OpenAI con salida estructurada (JSON Schema estricto con enums para `profile` y `narrative_variant`). La salida se trata como no confiable y se valida otra vez en Python y de nuevo en Godot (`AdaptiveResponseValidator`, incluida la distancia máxima respecto al perfil local).
- En Godot, el resultado remoto solo cambia el perfil y la variante narrativa (en memoria, no se guarda). `AdaptiveRefiner` descarta respuestas obsoletas (otra petición posterior o decisiones nuevas) y solo guarda la partida si el perfil cambió.
