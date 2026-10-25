# Ducks of the Fallen Stars

Videojuego 2D de acción en vista lateral con combate con espada, enemigos y jefes, hecho con Godot 4 y GDScript para escritorio (prioridad Windows, compatible con macOS). El nombre es provisional y se puede cambiar en Project Settings.

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

## AI service (to be documented in a later phase)

Pendiente de documentar en una fase posterior.

## Git

Nunca subir al repositorio archivos `.env` ni claves de API.
