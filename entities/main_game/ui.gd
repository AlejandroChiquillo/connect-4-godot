extends Control

# ── Constants ─────────────────────────────────────────────────────────────────
const UPDATE_INTERVAL: float = 1.0

const ACTIVE_MODULATE: Color = Color.WHITE
const DIM_MODULATE:    Color = Color(0.4, 0.4, 0.4)
const TWEEN_DURATION:  float = 0.2

# Maps game_won player values to display strings (0 = draw)
const WIN_TEXTS: Dictionary = {
	0: "DRAW",
	1: "RED WINS",
	2: "YELLOW WINS",
}

# ── State ─────────────────────────────────────────────────────────────────────
var _elapsed_seconds: int = 0
var _timer: Timer


func _ready() -> void:
	Global.game_won.connect(_on_game_won)
	Global.turn_changed.connect(_on_turn_changed)
	Global.game_reset_done.connect(_on_reset_done)

	_build_timer()
	_update_display()
	_on_turn_changed(1)

	# Win panel starts hidden
	%WinLabel.modulate.a = 0.0
	%WinLabel.scale      = Vector2.ZERO
	%WinLabel.visible    = false

	%PlayAgainBtn.pressed.connect(_on_play_again_pressed)


# ── Game events ───────────────────────────────────────────────────────────────

func _on_game_won(player: int) -> void:
	stop()
	%WinLabel.text = WIN_TEXTS.get(player, "")
	_show_win_panel()


func _on_turn_changed(player: int) -> void:
	_animate_turn_indicator(%TurnRedTexture,    player == 1)
	_animate_turn_indicator(%TurnYellowTexture, player == 2)


func _on_reset_done() -> void:
	%PlayAgainBtn.disabled = false
	reset()


func _on_play_again_pressed() -> void:
	%PlayAgainBtn.disabled = true
	await _hide_win_panel()
	Global.game_reset.emit()


# ── Win panel animation ───────────────────────────────────────────────────────

func _show_win_panel() -> void:
	%WinLabel.visible = true
	%WinLabel.scale   = Vector2.ZERO

	var tween := create_tween().set_parallel(true)
	tween.tween_property(%WinLabel, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(%WinLabel, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_win_panel() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(%WinLabel, "scale", Vector2.ZERO, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(%WinLabel, "modulate:a", 0.0, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	%WinLabel.visible = false


# ── Turn indicator ────────────────────────────────────────────────────────────

# Brightens 'texture' when it belongs to the active player, dims it otherwise.
func _animate_turn_indicator(texture: TextureRect, is_active: bool) -> void:
	var tween := create_tween()
	tween.tween_property(
		texture, "self_modulate",
		ACTIVE_MODULATE if is_active else DIM_MODULATE,
		TWEEN_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ── Stopwatch ─────────────────────────────────────────────────────────────────

func _build_timer() -> void:
	_timer = Timer.new()
	_timer.wait_time = UPDATE_INTERVAL
	_timer.autostart = true
	_timer.timeout.connect(_on_tick)
	add_child(_timer)


func _on_tick() -> void:
	_elapsed_seconds += 1
	_update_display()


func _update_display() -> void:
	var minutes: int = _elapsed_seconds / 60
	var seconds: int = _elapsed_seconds % 60
	%Timer.text = "%02d:%02d" % [minutes, seconds]


# Stops the stopwatch (call when the game ends).
func stop() -> void:
	_timer.stop()


# Resets the stopwatch to zero and restarts it (call at the start of a new game).
func reset() -> void:
	_elapsed_seconds = 0
	_timer.stop()
	_timer.start()
	_update_display()
