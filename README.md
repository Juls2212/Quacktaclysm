# Quacktaclysm

Videojuego 2D de acción en vista lateral con combate con espada, enemigos y jefes, hecho con Godot 4 y GDScript para escritorio (prioridad Windows, compatible con macOS). El nombre oficial es Quacktaclysm (`config/name` en Project Settings).

## Estructura de carpetas

```
game/             Proyecto de Godot (raíz: game/project.godot)
  frontend/       Escenas, UI, animaciones, sprites, audio y niveles
  backend/        Lógica del juego (player, combat, enemies, bosses,
                  decisions, ai, persistence, progression)
ai-service/       Servicio de IA externo
  app/
docs/             Documentación
```

- **frontend** = escenas, UI, arte, audio y niveles.
- **backend** = lógica del juego.
- **ai-service** = servicio de IA externo.

## Cómo abrir el proyecto

1. Instalar Godot 4.7.2 (stable).
2. En el gestor de proyectos de Godot, importar `game/project.godot`.
3. Ejecutar (F5). Debe mostrarse la escena de prueba `base_check.tscn` con el texto "Project base OK — Godot 4.7.2".

## Partida guardada

El juego guarda su progreso en un único archivo JSON, `save_game.json`, dentro de la carpeta `user://` del proyecto (Godot la crea con el nombre del proyecto, `Quacktaclysm`). Junto a él puede haber `save_game.json.bak` (versión anterior), y `save_game.json.corrupt` (archivo ilegible puesto en cuarentena). Ubicación según el sistema:

- Windows: `%APPDATA%\Godotpp_userdata\Quacktaclysm\`
- macOS: `~/Library/Application Support/Godot/app_userdata/Quacktaclysm/`
- Linux: `~/.local/share/godot/app_userdata/Quacktaclysm/`

Para borrar la partida basta con eliminar esos archivos con el juego cerrado (o usar la tecla 3 de la escena de pruebas `boss_test`). Estos archivos viven fuera del repositorio y nunca se suben a Git.

## Servicio de IA

**Para qué sirve:** un servicio local (FastAPI) que, tras cada decisión Liberar/Conservar, puede *refinar* el perfil adaptativo (`compassionate` / `neutral` / `corrupt`) y elegir una variante narrativa consultando a OpenAI. El resultado local (`LocalProfileClassifier`) se aplica siempre primero; el servicio es opcional. **El juego funciona igual sin él**: si no está disponible, el resultado local se mantiene y no se muestra ningún error al jugador.

**Preparar el entorno** (desde la raíz del repositorio; las dependencias se instalan SOLO dentro del venv):

```
cd ai-service
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements-dev.txt     # Windows
# macOS/Linux: .venv/bin/python -m pip install -r requirements-dev.txt
```

**Configuración:** copia `ai-service/.env.example` a `ai-service/.env` y rellena `OPENAI_API_KEY` y `OPENAI_MODEL` (el modelo solo se lee del entorno; no está en el código). `AI_SERVICE_MODE` puede ser `mock` (reglas deterministas, sin red, para desarrollo y pruebas) o `openai`.

**Arrancar el servicio** (escucha en `127.0.0.1:8000` por defecto):

```
cd ai-service
.venv\Scripts\python run_dev.py                          # usa AI_SERVICE_MODE del .env (mock por defecto)
set AI_SERVICE_MODE=openai && .venv\Scripts\python run_dev.py   # modo openai (PowerShell: $env:AI_SERVICE_MODE="openai")
```

Comprobación rápida: `http://127.0.0.1:8000/health` devuelve `{"status":"ok","mode":"mock",...}`. En modo `openai` sin clave o sin modelo, el servicio arranca igualmente (`/health` funciona) y el endpoint de perfil responde 503.

**URL del servicio en el juego:** por defecto `http://127.0.0.1:8000` (recurso `game/backend/ai/default_ai_service_config.tres`). Para usar otra URL, define la variable de entorno `QUACKTACLYSM_AI_URL` antes de abrir Godot, o edita el recurso. En la escena `boss_test`, la tecla `7` pide un refinamiento y la etiqueta de depuración muestra el estado.

**Pruebas de Python** (sin red y sin clave real):

```
cd ai-service
.venv\Scripts\python -m pytest -q
```

**Prueba de integración con Godot** (servicio en modo mock en el puerto 8765 + Godot headless; detiene el servicio al terminar):

```
ai-service\.venv\Scripts\python ai-service\scripts\integration_mock.py --godot <ejecutable de consola de Godot>
```

> **Advertencia:** nunca subas `.env` al repositorio ni pegues claves de API en issues, chats o capturas. Solo `.env.example` (con valores vacíos) está versionado.

**Antes de publicar el servicio en internet:** este servicio NO tiene autenticación ni límite de peticiones. Hace falta añadir autenticación (p. ej. una clave de cliente o token), rate limiting por IP/usuario, HTTPS (proxy inverso) y revisar los límites de coste en OpenAI. El juego ya admite una URL configurable (`QUACKTACLYSM_AI_URL` o el recurso de configuración).

## Git

Nunca subir al repositorio archivos `.env` ni claves de API.
