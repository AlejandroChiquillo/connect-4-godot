class_name Slot
extends Node2D

# ── Textures ──────────────────────────────────────────────────────────────────
const SLOT_TEXTURE := preload("uid://fq3wt4jijuw7")

# ── Hover colours ─────────────────────────────────────────────────────────────
const HOVER_MODULATE:   Color = Color(1.3, 1.3, 1.3)
const DEFAULT_MODULATE: Color = Color.WHITE

const TWEEN_DURATION: float = 0.15

# ── Node references ───────────────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D
@onready var area:   Area2D   = $Area2D

# ── State ─────────────────────────────────────────────────────────────────────
var grid_position: Vector2i
var filled:        int = 0  # 0 = empty, 1 = player 1, 2 = player 2

var _tween: Tween


func _ready() -> void:
	sprite.texture = SLOT_TEXTURE
	area.mouse_entered.connect(func(): Global.hover_column.emit(grid_position.x))
	area.mouse_exited.connect(func():  Global.unhover_column.emit(grid_position.x))
	area.input_event.connect(_on_input_event)


# Sets the hover highlight on or off with a smooth colour tween.
func set_hover(active: bool) -> void:
	_animate_modulate(HOVER_MODULATE if active else DEFAULT_MODULATE)


func _animate_modulate(target: Color) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(sprite, "self_modulate", target, TWEEN_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("add_piece"):
		Global.place_piece.emit(grid_position.x)
