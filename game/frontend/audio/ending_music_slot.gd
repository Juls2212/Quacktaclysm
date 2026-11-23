class_name EndingMusicSlot
extends Resource
## The music of one ending (Phase 15i-bis): which file of frontend/audio/music plays and how it is processed by code (a lower pitch, a low-pass
## filter and a reverb on the Music bus, a base duck). A slot of default_audio_events.tres: replace `file` with a real track (and set the
## processing to neutral if you like) without touching any code.

## A file name in frontend/audio/music.
@export var file: String = ""
## Pitch multiplier of the track (1 = as recorded).
@export_range(0.5, 1.5, 0.01) var track_pitch: float = 1.0
## Low-pass cutoff (Hz) of the Music bus while the ending plays; 20000 or more means no filter.
@export_range(500.0, 20000.0, 10.0, "suffix:Hz") var cutoff_hz: float = 20000.0
## Reverb mix (0 = none) and its room size.
@export_range(0.0, 1.0, 0.01) var reverb_wet: float = 0.0
@export_range(0.0, 1.0, 0.01) var reverb_room: float = 0.8
## How quiet the track sits under the scene (dB, negative), before the beats duck it further.
@export_range(-40.0, 0.0, 0.5, "suffix:dB") var base_duck_db: float = -8.0
