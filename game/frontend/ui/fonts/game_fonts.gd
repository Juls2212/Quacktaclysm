class_name GameFonts
extends RefCounted
## The game's three typefaces (Google Fonts; their licences sit next to each font file):
## TITLE "Rubik Wet Paint" for the big titles (through InkType), BODY "Patrick Hand" for buttons,
## labels and subtitles (the theme's default font), TYPEWRITER "Special Elite" for old documents.

const TITLE: FontFile = preload("res://frontend/ui/fonts/rubik_wet_paint/RubikWetPaint-Regular.ttf")
const BODY: FontFile = preload("res://frontend/ui/fonts/patrick_hand/PatrickHand-Regular.ttf")
const TYPEWRITER: FontFile = preload("res://frontend/ui/fonts/special_elite/SpecialElite-Regular.ttf")
## Height of a capital as a fraction of the font size (from each font's OS/2 table).
const TITLE_CAP: float = 0.7
const BODY_CAP: float = 0.661


## Font size at which TITLE capitals are `cap_height` pixels tall.
static func title_size(cap_height: float) -> int:
	return maxi(int(roundf(cap_height / TITLE_CAP)), 1)
