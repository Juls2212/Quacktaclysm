# Entorno

- **Versión de Godot detectada:** 4.7.2.stable.official.ed1daf0bf
- **Disponible desde la terminal:** no está en el PATH (`godot` y `godot4` no se encuentran). Se ejecuta por ruta directa al ejecutable de consola descargado:
  `Godot_v4.7.2-stable_win64_console.exe --version`. `tools/run_all_tests.py` lee la ruta de `--godot` o de la variable de entorno `GODOT_BIN` (nunca va escrita en el repositorio).
- **Plantillas de exportación:** no instaladas para 4.7.2.stable (la carpeta `%APPDATA%\Godot\export_templates` está vacía). Ver el README para instalarlas.
- **Sistema operativo:** Windows 11 Pro (10.0.26200)
- **Python:** 3.11.9
- **Servicio de IA (`ai-service/.venv`):** FastAPI 0.162.0, Pydantic 2.14.1, SDK de OpenAI 2.54.0 (rangos permitidos en `ai-service/requirements.txt`)
- **Fecha:** 2026-10-31

El proyecto apunta a **Godot 4.7** (`config/features=PackedStringArray("4.7")` en `game/project.godot`).
