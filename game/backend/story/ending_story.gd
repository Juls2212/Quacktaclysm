class_name EndingStory
extends Resource
## One of the four endings: its title, 5-8 subtitle lines, the look of the epilogue and the music.
## `{released}` and `{kept}` in a line become the soul's name (the one released / the one kept).

@export var ending_id: String = ""
@export var title: String = ""
@export var lines: Array[String] = []
## Epilogue look drawn by PrologueShots: "full", "scar", "doubt" or "corrupt".
@export var style: String = "full"
## File name in frontend/audio/music (an existing track).
@export var music: String = "title_screen.ogg"
## One sentence on the summary card.
@export var summary_line: String = ""
