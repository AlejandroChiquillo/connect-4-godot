extends Node2D

const SLOT_SCENE  = preload("uid://bkq8na2xn6vp5")
const PIECE_SCENE = preload("uid://bsxqg6rk8ulkq")

# ── Board dimensions ──────────────────────────────────────────────────────────
const COLS:      int   = 7
const ROWS:      int   = 6
const SLOT_SIZE: float = 64.0

# All four directions to check for a Connect Four line
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1,  0),  # Horizontal →
	Vector2i(0,  1),  # Vertical ↓
	Vector2i(1,  1),  # Diagonal ↘
	Vector2i(1, -1),  # Diagonal ↗
]

@export_range(0, 64, 1.0) var slot_gap: float = 42.0

# ── State ─────────────────────────────────────────────────────────────────────
var slots:        Dictionary[Vector2i, Slot]
var current_turn: int  = 1
var board_locked: bool = false


func _ready() -> void:
	Global.hover_column.connect(_on_hover_column)
	Global.unhover_column.connect(_on_unhover_column)
	Global.place_piece.connect(_on_place_piece)
	Global.game_reset.connect(_on_game_reset)
	_center_board()
	_build_grid()


# Offsets the board node so the grid is centred in the viewport.
func _center_board() -> void:
	var vp   := get_viewport_rect().size
	var step := SLOT_SIZE + slot_gap
	var w    := COLS * SLOT_SIZE + (COLS - 1) * slot_gap
	var h    := ROWS * SLOT_SIZE + (ROWS - 1) * slot_gap
	position = Vector2((vp.x - w) * 0.5, (vp.y - h + 64.0) * 0.5)


# Instantiates and positions all slot nodes, storing them in 'slots'.
func _build_grid() -> void:
	var step := SLOT_SIZE + slot_gap
	for row in ROWS:
		for col in COLS:
			var coord := Vector2i(col, row)
			var slot: Slot = SLOT_SCENE.instantiate()
			slot.grid_position = coord
			slot.position      = Vector2(col * step, row * step)
			slots[coord]       = slot
			add_child(slot)


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_hover_column(col: int) -> void:
	for row in ROWS:
		slots[Vector2i(col, row)].set_hover(true)


func _on_unhover_column(col: int) -> void:
	for row in ROWS:
		slots[Vector2i(col, row)].set_hover(false)


# Main game logic: validates the move, drops the piece, then checks end conditions.
func _on_place_piece(col: int) -> void:
	if board_locked:
		return

	var target_row := _find_lowest_free_row(col)
	if target_row == -1:
		return  # Column is full

	board_locked = true

	var coord := Vector2i(col, target_row)
	var slot: Slot = slots[coord]
	slot.filled = current_turn

	_spawn_piece(slot, current_turn)

	# Check for a win before handing the turn over
	var winning_cells := _check_winner(coord, current_turn)
	if winning_cells.size() > 0:
		_on_game_won(current_turn, winning_cells)
		return

	if _is_board_full():
		_on_draw()
		return

	current_turn = 2 if current_turn == 1 else 1
	Global.turn_changed.emit(current_turn)

	# Wait for the fall animation to finish before accepting new input
	await get_tree().create_timer(0.5).timeout
	board_locked = false


# ── Board helpers ─────────────────────────────────────────────────────────────

# Returns the lowest empty row in 'col', or -1 if the column is full.
func _find_lowest_free_row(col: int) -> int:
	for row in range(ROWS - 1, -1, -1):
		if slots[Vector2i(col, row)].filled == 0:
			return row
	return -1


# Returns true when every top-row slot is occupied.
func _is_board_full() -> bool:
	for col in COLS:
		if slots[Vector2i(col, 0)].filled == 0:
			return false
	return true


# Instances a Piece above the board and sends it falling to the slot's position.
func _spawn_piece(slot: Slot, turn: int) -> void:
	var piece: Piece = PIECE_SCENE.instantiate()
	piece.piece_type      = turn
	piece.target_position = slot.position
	piece.position        = Vector2(slot.position.x, -SLOT_SIZE - slot_gap)
	add_child(piece)


# ── Win detection ─────────────────────────────────────────────────────────────

# Checks all four directions from 'origin'. Returns the winning cells, or [].
func _check_winner(origin: Vector2i, player: int) -> Array[Vector2i]:
	for dir in DIRECTIONS:
		var line := _get_winning_line(origin, dir, player)
		if line.size() >= 4:
			return line
	return []


# Combines the two rays in opposite directions into a single de-duplicated line.
func _get_winning_line(origin: Vector2i, dir: Vector2i, player: int) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	var ray_pos := _ray_cells(origin, dir,                       player)
	var ray_neg := _ray_cells(origin, Vector2i(-dir.x, -dir.y),  player)

	# ray_neg is in reverse order and shares the origin; reverse before merging
	ray_neg.reverse()
	for cell in ray_neg:
		if not line.has(cell):
			line.append(cell)
	for cell in ray_pos:
		if not line.has(cell):
			line.append(cell)
	return line


# Walks from 'origin' in 'dir' while cells belong to 'player', collecting coords.
func _ray_cells(origin: Vector2i, dir: Vector2i, player: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var pos := origin
	while slots.has(pos) and slots[pos].filled == player:
		cells.append(pos)
		pos += dir
	return cells


# ── End-game ──────────────────────────────────────────────────────────────────

func _on_game_won(player: int, winning_cells: Array[Vector2i]) -> void:
	_highlight_winning_pieces(winning_cells)
	Global.game_won.emit(player)
	# board_locked stays true — no more moves allowed


func _highlight_winning_pieces(cells: Array[Vector2i]) -> void:
	var target_positions: Array[Vector2] = []
	for coord in cells:
		target_positions.append(slots[coord].position)

	for child in get_children():
		if child is Piece and child.target_position in target_positions:
			child.highlight()


func _on_draw() -> void:
	Global.game_won.emit(0)  # 0 signals a draw to any listener


# ── Reset ─────────────────────────────────────────────────────────────────────

func _on_game_reset() -> void:
	board_locked = true

	# Stagger the death animations slightly for a nicer effect
	var pieces := get_children().filter(func(c): return c is Piece)
	for piece in pieces:
		await get_tree().create_timer(0.15).timeout
		piece.die()

	# Wait for the last piece to fully disappear before clearing state
	if pieces.size() > 0:
		await pieces[-1].died

	for slot in slots.values():
		slot.filled = 0

	current_turn = 1
	board_locked = false
	Global.turn_changed.emit(current_turn)
	Global.game_reset_done.emit()
