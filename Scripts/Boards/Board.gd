class_name Board
extends Node2D

#region Variables

@export_category("General board settings")
@export var board_name: String = "Template"
@export var music: AudioStream
@export var tileset: Texture
## The scene the player will be sent to after completing this board
@export var next_scene: PackedScene
## If set, after the player makes their turn, one of the bosses
## will also have their turn
@export var allow_boss_movement := true

@export_category("Saves")
## If true, a player's current save will be changed when this
## scene starts
@export var use_in_saves := true
@export var board_id := "template"

## The array of levels
## Check out get_level_id(tile: Vector2i) -> int in Selector.gd
## to get the level ID for a cell in the tilemap
@export_category("Levels")
@export var levels: Array[PackedScene]

@onready var outline: TileMapLayer = $Board/Outline
@onready var tilemap: TileMapLayer = $"Board/Board Icons"
@onready var message_window: NinePatchRect = $Board/GUI/MessageWindow
@onready var selector: Sprite2D = $"Board/Board Icons/Selector"

# The actual playable board, the node that has this script
# also includes the board name.
@onready var board: Node2D = $Board

@onready var menubip: AudioStreamPlayer = $Board/GUI/MessageWindow/MenuBip

var selected_piece: Node = null
var board_data := {
	player_level = {}, # [PlayerCharacter.Type] -> int
}

#endregion

#region Main board code

func _ready() -> void:
	Global.board = self
	
	if use_in_saves:
		Global.save_data.board_id = board_id
		
		if not Global.save_data.has("board_data") or \
			Global.save_data.board_data.size() == 0:
				Global.save_data.board_data = board_data
				Global.store_save_data()
		else:
			board_data = Global.save_data.board_data
	
	RenderingServer.set_default_clear_color(Color.BLACK)
	tilemap.tile_set.get_source(0).texture = tileset
	tilemap.tile_set.get_source(1).texture = tileset
	build_outline()
	
	if board_name:
		# Show the board name and hide the actual board for now
		$BoardName.visible = true
		$BoardName.size = Global.get_default_resolution()
		$BoardName/Label.text = board_name
			
		board.visible = false
		board.process_mode = Node.PROCESS_MODE_DISABLED
		
		await Global.fade_in()
		# Show the board name for some time
		await get_tree().create_timer(2).timeout
		# ..and then fade out and show the board
		await Global.fade_out()
		
	Global.fade_in()
	$BoardName.visible = false
	board.visible = true
	board.process_mode = Node.PROCESS_MODE_INHERIT
	Global.play_music(music)
		
func _process(_delta: float) -> void:
	if not board.visible:
		return
		
	Global.accept_pause()
	
	if not selector.is_stopped() or selector.ignore_player_input:
		return
		
	if Input.is_action_just_pressed("A"):
		if not selected_piece:
			# If no board pieces are selected
			var piece := get_current_piece()
			if piece and piece.is_player():
				piece.select()
				selector.moved_at_all = false
				selected_piece = piece
				message_window.disappear()
			elif piece and not piece.is_player():
				show_boss_info(piece)
			else:
				message_window.appear("There is no monster here.")
			adjust_message_pos()
		elif not message_window.visible:
			if not selector.moved_at_all:
				var result: bool = await message_window.appear(
					"Not going\nto move?", true, true)
				if result:
					await not_going_to_move()
					return
				else:
					selected_piece.deselect()
					selected_piece = null
			# If a board piece is selected and A was pressed, start playing
			start_playing()
		
	# Cancel the player's current move
	if Input.is_action_just_pressed("B") and selected_piece:
		menubip.play()
		selected_piece.deselect()
		selected_piece = null
		message_window.disappear()
		
	# Mini board tutorial
	if Input.is_action_just_pressed("Start"):
		if not selected_piece and get_current_piece():
			# We don't check if it's a boss on purpose
			# (to be accurate to the original game)
			message_window.appear("Then press button A.")
		elif selected_piece:
			message_window.appear("If\nfinished movig, press button A.")
		else:
			message_window.appear("Select\na monster to move.")
		adjust_message_pos()
		
	if message_window.visible and Input.is_action_just_pressed("B"):
		message_window.disappear()
		
func adjust_message_pos() -> void:
	if selector.position.y > 120:
		message_window.position.y = 16
	else:
		message_window.position.y = 144

func build_outline() -> void:
	for cell in outline.get_used_cells():
		var cell_id := outline.get_cell_atlas_coords(cell)
		if cell_id != Vector2i(0, 0) and cell_id != Vector2i(-1, -1):
			print("Warning: Icon moved from outline layer to board icons layer")
			tilemap.set_cell(cell, 0, cell_id)
			
	outline.clear()
			
	for cell in tilemap.get_used_cells():
		outline.set_cell(cell, 0, Vector2i(0, 0))
		
func not_going_to_move() -> void:
	await fade_out_selected()
	returned()
	
func start_playing(boss_piece: Node2D = null) -> void:
	Global.playing_levels.assign(
		selector.playing_levels.map(func(x: int) -> PackedScene:
			if x >= levels.size():
				print("Level with id " + str(x) + " is out of bounds")
				return null
			return levels[x]
			))
	if boss_piece != null:
		Global.playing_levels.append(boss_piece.boss_scene)
		
	if Global.playing_levels.find(null) >= 0:
		Global.playing_levels.clear()
				
	if Global.playing_levels.size() == 0:
		not_going_to_move()
		return
	
	if boss_piece == null:
		menubip.play()
	await fade_out_selected()
	
	var level := Global.get_next_level().instantiate()
	if level is Level:
		level.data = {
			current_character = selected_piece.piece_character,
			board_piece = selected_piece,
			boss_piece = boss_piece,
		}
	# We don't free the board scene so we can later return to it,
	# hence the second false argument.
	Global.change_scene_node(level, false)
	
func fade_out_selected() -> void:
	selected_piece.prepare_start()
	get_tree().paused = true
	
	await get_tree().create_timer(0.5).timeout
	
	Global.music_fade_out()
	await Global.fade_out()
	
	await get_tree().create_timer(0.5).timeout
	
	get_tree().paused = false
	
func returned(ignore_boss_moves := false) -> void:
	await get_tree().create_timer(0.5).timeout
	
	message_window.make_hide()
	Global.fade_in()
	if not Global.music.playing or Global.music.stream != music:
		Global.play_music(music)
	if selected_piece:
		selected_piece.deselect()
		selected_piece = null
		
	if ignore_boss_moves:
		selector.set_process(true)
		selector.visible = true
		selector.moved.emit()
		return

	if allow_boss_movement and get_boss_pieces().size() > 0:
		selector.hide()
		selector.ignore_player_input = true
		var selector_pos_saved := Vector2(selector.position)

		await Global.fade_end
		await move_boss()
		# See the explanation for that if statement in move_boss()
		# in if selector.visible
		if not selector.visible:
			Global.fade_in()
		
		selector.position = selector_pos_saved
		selector.show()
		selector.ignore_player_input = false
		
#endregion

#region Bosses
		
func show_boss_info(piece: Node2D) -> void:
	var text := PlayerCharacter.CHARACTER_NAMES[piece.piece_character] + " - "
	var size := Vector2i(message_window.default_window_size)
	var hp_text := boss_hp_str(piece.character_data.hp / 8)
	
	if text.length() >= (size.x - 16) / 8:
		size.x = (text.length() + 1) * 8
		
	var space_count := (size.x - 16) / 8 - hp_text.length()
	text += "life\n" + " ".repeat(space_count) + hp_text
	message_window.appear(text, true, false, size)
		
func boss_hp_str(hp: float) -> String:
	var s := str(snappedf(hp, 0.1))
	if fmod(hp, 1) < 0.1:
		s += ".0"
	return s
	
func move_boss() -> void:
	var boss_piece: Node2D = get_boss_pieces().pick_random()
	
	# Don't include other boss pieces in the navigation path
	# (by usign an alternative tile without navigation region)
	for p: Node2D in get_boss_pieces():
		if p != boss_piece:
			outline.set_cell(p.get_cell_pos(), 0, Vector2i(0, 0), 1)
		
	var player_piece: Node2D = get_closest_player(boss_piece)
	await get_tree().create_timer(0.5).timeout
	boss_piece.select()
	selected_piece = boss_piece
	
	var nav_agent: NavigationAgent2D = boss_piece.get_nav_agent()
	nav_agent.set_navigation_map(outline.get_navigation_map())
	nav_agent.target_position = player_piece.global_position
	nav_agent.get_next_path_position() # Build the navigation path
	var path := convert_navigation_path(nav_agent.get_current_navigation_path())
	
	for p: Node2D in get_boss_pieces():
		if p != boss_piece:
			outline.set_cell(p.get_cell_pos(), 0, Vector2i(0, 0))
	
	selector.playing_levels.clear()
	
	for i in mini(boss_piece.steps, path.size()):
		await get_tree().create_timer(0.5).timeout
		# Direction of movement
		var direction := path[i] - boss_piece.position
		# Request movement
		selector.move(direction.x, direction.y)
		await selector.moved
		selector.move(0, 0)
		
		# Basically, the boss might have already collided with a player piece,
		# started the boss battle and it would've been finished at this point
		# (due to the piece collision signal),
		# calling returned() again and setting selector.visible to true,
		# and since returned() got called again we don't want to proceed with
		# the move_boss() function anymore
		if selector.visible:
			return
			
		# Wait until we get onto the next hex
		await selector.stopped
	
	await get_tree().create_timer(0.5).timeout
	boss_piece.prepare_start()
	await get_tree().create_timer(0.5).timeout
	
	selector.playing_levels.clear()
	selected_piece = null
	
	await Global.fade_out()
	
func get_closest_player(boss_piece: Node2D) -> Node2D:
	var array := get_player_pieces()
	if array.size() == 0:
		return null
	array.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var distance_a := a.position.distance_to(boss_piece.position)
		var distance_b := b.position.distance_to(boss_piece.position)
		return distance_a < distance_b
		)
	return array[0]
	
# Convert navigation path of global positions to
# path of positions snapped to tilemap cells
func convert_navigation_path(path: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in path:
		var pos: Vector2 = selector.map_to_tilemap(tilemap.to_local(point))
		if (result.size() > 0 and result[-1] != pos or result.size() == 0) \
			and selector.cell_exists(selector.get_cell_pos(pos)):
				result.append(pos)
	# We don't want the boss to try to move to its current position
	result.remove_at(0)
	return result
	
#endregion

#region Board-specific piece-related code

func get_board_pieces() -> Array[Node2D]:
	var board_pieces: Array[Node2D] = []
	board_pieces.assign(
		%"Board Pieces".get_children().filter(func(x: Node2D) -> bool:
			return not x.is_queued_for_deletion()
			))
	return board_pieces

func get_current_piece() -> Node2D:
	for p in get_board_pieces():
		if p.get_cell_pos() == selector.get_cell_pos(selector.old_pos):
			return p
	return null
	
func get_player_pieces() -> Array[Node2D]:
	return get_board_pieces().filter(func(p: Node2D) -> bool: return p.is_player())
	
func get_boss_pieces() -> Array[Node2D]:
	return get_board_pieces().filter(func(p: Node2D) -> bool: return not p.is_player())

func _on_selector_piece_collision(piece: Node2D, boss_collision: bool) -> void:
	if not selected_piece.is_player():
		var boss := selected_piece
		selected_piece = piece
		
		boss.prepare_start()
		selector.playing_levels.clear()
		start_playing(boss)
		return
		
	if not boss_collision and not message_window.visible:
		message_window.appear("Unable to advance because a "
			+ "monster is blocking the way.", false)
		adjust_message_pos()
	elif boss_collision:
		adjust_message_pos()
		var result: bool = await message_window.appear(
			"Will you\nfight\n" + piece.get_character_name() + "?",
			false, true)
		start_playing(piece if result else null)
		
#endregion
