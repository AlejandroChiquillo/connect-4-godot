class_name Piece
extends Node2D

# ── Textures ────────────────────────────────────────────────────────────────
const TEXTURES: Array[Texture2D] = [
	preload("uid://h23x60o5qxdj"),  # Player 1 texture
	preload("uid://c5rlbqxuvpk7y"), # Player 2 texture
]

# ── Audio ────────────────────────────────────────────────────────────────────
const SOUNDS: Array[AudioStream] = [
	preload("uid://dgvsdlk4835bh"),
]

const PITCH_MIN: float = 0.92
const PITCH_MAX: float = 1.08
const DB_MIN:    float = -3.0
const DB_MAX:    float = -1.0

# ── Animation constants ───────────────────────────────────────────────────────
const POP_SCALE_BIG:  Vector2 = Vector2(1.15, 1.15) # Initial pop overshoot
const POP_SCALE_NORM: Vector2 = Vector2(1.0,  1.0)  # Resting scale
const POP_SCALE_INIT: Vector2 = Vector2(0.6,  0.6)  # Starting scale before pop

const MAX_FALL_DISTANCE: float = 500.0  # Reference distance to normalise fall duration
const FALL_DURATION_MIN: float = 0.4    # Minimum fall time (short distances)
const FALL_DURATION_MAX: float = 0.6    # Maximum fall time (long distances)

const BOUNCE_HEIGHT:   float = 42.0  # Peak height of the first bounce
const BOUNCE_DURATION: float = 0.13  # Duration of one bounce leg

const HIGHLIGHT_MODULATE: Color = Color(1.5, 1.5, 1.5) # Winning-piece flash colour
const HIGHLIGHT_DURATION: float = 0.5                   # Duration of one flash cycle

# ── Signals ──────────────────────────────────────────────────────────────────
# Emitted after the death animation completes, just before queue_free
signal died

# ── Node references ───────────────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D

# ── State ─────────────────────────────────────────────────────────────────────
var piece_type:      int     # 1 = player 1, 2 = player 2
var target_position: Vector2 # World position of the destination slot


func _ready() -> void:
	sprite.texture = TEXTURES[piece_type - 1]
	_play_pop_then_fall()


# Plays a small pop-in animation, then falls to target_position with bounces.
func _play_pop_then_fall() -> void:
	scale = POP_SCALE_INIT

	# Pop: scale up with overshoot, then settle
	var pop := create_tween()
	pop.tween_property(self, "scale", POP_SCALE_BIG, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(self, "scale", POP_SCALE_NORM, 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await pop.finished

	# Scale fall duration to the distance so far drops feel heavier
	var dist     := position.distance_to(target_position)
	var t        := clampf(dist / MAX_FALL_DISTANCE, 0.0, 1.0)
	var duration := lerpf(FALL_DURATION_MIN, FALL_DURATION_MAX, t)

	# Fall to the target slot
	var fall := create_tween()
	fall.tween_interval(0.2)
	fall.tween_property(self, "position", target_position, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await fall.finished

	# Impact feedback: sound + squash
	_play_drop_sound()
	_squash_on_impact()

	# Three progressively smaller bounces
	await _bounce(BOUNCE_HEIGHT * 0.75, BOUNCE_DURATION)
	await _bounce(BOUNCE_HEIGHT * 0.50, BOUNCE_DURATION * 0.8)
	await _bounce(BOUNCE_HEIGHT * 0.25, BOUNCE_DURATION * 0.6)


# Moves the piece up by 'height' pixels then back down to target_position.
func _bounce(height: float, duration: float) -> void:
	var up := create_tween()
	up.tween_property(self, "position:y", target_position.y - height, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await up.finished

	var down := create_tween()
	down.tween_property(self, "position:y", target_position.y, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await down.finished


# Brief squash-and-stretch when the piece hits the board.
func _squash_on_impact() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 0.85), 0.06) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", POP_SCALE_NORM, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Infinite brightness pulse used to mark winning pieces.
func highlight() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "self_modulate", HIGHLIGHT_MODULATE, HIGHLIGHT_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "self_modulate", Color.WHITE, HIGHLIGHT_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# Spawns a one-shot AudioStreamPlayer and frees it when playback ends.
func _play_drop_sound() -> void:
	var player := AudioStreamPlayer.new()
	player.stream      = SOUNDS.pick_random()
	player.pitch_scale = randf_range(PITCH_MIN, PITCH_MAX)
	player.volume_db   = randf_range(DB_MIN, DB_MAX)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


# Scales the piece up briefly, then shrinks it to zero while fading out.
# Emits 'died' and frees the node when done.
func die() -> void:
	# Tiny pre-scale punch
	var punch := create_tween()
	punch.tween_property(self, "scale", Vector2(1.2, 1.2), 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await punch.finished

	# Shrink and fade out in parallel
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

	died.emit()
	queue_free()
