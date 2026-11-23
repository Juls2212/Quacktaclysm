class_name EndingStory
extends Resource
## One of the two endings: its title, 5-8 subtitle lines, the look of the epilogue and the music.
## `{released}` and `{kept}` in a line become the soul's name (the one released / the one kept).

@export var ending_id: String = ""
@export var title: String = ""
@export var lines: Array[String] = []
## Epilogue look drawn by PrologueShots: "kept" or "released".
@export var style: String = "full"
## One sentence on the summary card.
@export var summary_line: String = ""
## Three closing texts (Phase 16c), shown on the summary card: 0 neutral, 1 for a player who played comfortably, 2 for one who
## struggled. They only change the closing text, never which ending plays.
@export var epilogues: Array[String] = []
## A line of support shown on the final card (Phase 15h); empty = none. Both endings have one.
@export_multiline var support_line: String = ""
## The script of the cinematic: camera, duck, portrait, sound and timing beat by beat (Phase 15i).
@export var beats: EndingBeatList = null
