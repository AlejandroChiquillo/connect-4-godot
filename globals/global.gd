extends Node

# Emitted when the mouse enters a column — passes the column index
signal hover_column(column: int)

# Emitted when the mouse leaves a column — passes the column index
signal unhover_column(column: int)

# Emitted when the player clicks to drop a piece — passes the column index
signal place_piece(column: int)

# Emitted when the game ends — 0 = draw, 1 = player 1, 2 = player 2
signal game_won(player: int)

# Emitted to request a full board reset
signal game_reset

# Emitted once the reset animation finishes and the board is ready
signal game_reset_done

# Emitted whenever the active player changes — passes the new player index
signal turn_changed(player: int)
