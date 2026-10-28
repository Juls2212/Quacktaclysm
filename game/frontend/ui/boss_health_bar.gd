class_name BossHealthBar
extends CanvasLayer
## Placeholder boss bar: name, health ratio and a marker at the phase 2 threshold.
## Visible only while the encounter is active. The boss does not know about this bar.

var displayed_name: String = ""
var displayed_ratio: float = 0.0
var marker_ratio: float = 0.0

var _boss: BossBase

@onready var name_label: Label = $Root/NameLabel
@onready var fill: ColorRect = $Root/Background/Fill
@onready var marker: ColorRect = $Root/Background/Marker


func _ready() -> void:
	visible = false


func bind(boss: BossBase) -> void:
	_boss = boss
	displayed_name = boss.stats.display_name
	name_label.text = displayed_name
	marker_ratio = boss.stats.phase_2_health_ratio
	marker.anchor_left = marker_ratio
	marker.anchor_right = marker_ratio
	_update_ratio(boss.health.current_health, boss.health.max_health)
	boss.activated.connect(_on_activated)
	boss.health_changed.connect(_update_ratio)
	boss.encounter_reset.connect(_hide)
	boss.defeated.connect(_on_defeated)


func _on_activated() -> void:
	_update_ratio(_boss.health.current_health, _boss.health.max_health)
	visible = true


func _update_ratio(current: int, maximum: int) -> void:
	displayed_ratio = float(current) / float(maximum) if maximum > 0 else 0.0
	fill.anchor_right = displayed_ratio


func _hide() -> void:
	visible = false


func _on_defeated(_defeated_boss: BossBase) -> void:
	visible = false