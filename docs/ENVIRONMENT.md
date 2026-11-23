# Entorno

- **Versión de Godot detectada:** 4.7.2.stable.official.ed1daf0bf
- **Disponible desde la terminal:** no está en el PATH (`godot` y `godot4` no se encuentran). Se ejecuta por ruta directa al ejecutable de consola descargado:
  `Godot_v4.7.2-stable_win64_console.exe --version`. `tools/run_all_tests.py` lee la ruta de `--godot` o de la variable de entorno `GODOT_BIN` (nunca va escrita en el repositorio).
- **Plantillas de exportación:** no instaladas para 4.7.2.stable (la carpeta `%APPDATA%\Godot\export_templates` está vacía). Ver el README para instalarlas.
- **Sistema operativo:** Windows 11 Pro (10.0.26200)
- **Python:** 3.11.9
- **Servicio de IA (`ai-service/.venv`):** FastAPI 0.162.0, Pydantic 2.14.1, SDK de OpenAI 2.54.0 (rangos permitidos en `ai-service/requirements.txt`)
- **Fecha:** 2026-11-20
- **Configuración del servicio de IA (`ai-service/.env`):** cada ingeniera crea su propio `ai-service/.env` en su portátil copiando `ai-service/.env.example` (versionado, sin valores) y rellenando `OPENAI_API_KEY` y `OPENAI_MODEL` (el modelo lo eliges tú entre los disponibles en tu cuenta de OpenAI; no está en el código). El archivo nunca se sube a Git (`.gitignore`) y la clave nunca se comparte por chat. El servicio carga ese archivo con `python-dotenv` por una ruta relativa al código (no al directorio de trabajo) y el `.env` gana sobre las variables del terminal. Sin `.env`, o en modo `openai` con clave o modelo vacíos, arranca en `mock` y lo avisa una vez. Comprobación: `http://127.0.0.1:8000/health` → `mode` y `openai_configured` (solo booleanos). El juego no lee ninguna clave.

El proyecto apunta a **Godot 4.7** (`config/features=PackedStringArray("4.7")` en `game/project.godot`).
