class_name Level
extends Node2D

@export var music: AudioStream = preload("res://Audio/Soundtrack/Earth.ogg")
@export var bg_color = Color(0, 0, 0)
@export var enable_level_end := true

@onready var camera: Camera2D = $Camera
@onready var player: GameCharacter = $Player

# These are set in Board.gd and in next_level()
var data = {
	current_character = GameCharacter.Type.GODZILLA,
	board_piece = null,
	boss_piece = null,
}

func _ready() -> void:
	RenderingServer.set_default_clear_color(bg_color)
	
	player.character = data.current_character
	player.health.dead.connect(func(): 
		Global.play_music(preload("res://Audio/Soundtrack/PlayerDeath.ogg"))
		)
	if data.board_piece:
		player.load_state(data.board_piece.character_data)
	
	player.intro_ended.connect(func():
		if not Global.music.playing:
			Global.play_music(music)
		)
		
	player.block_level_end = not enable_level_end
	
	Global.fade_in()
	
func _process(_delta: float) -> void:
	Global.accept_pause()
	
	if enable_level_end and player.position.x > camera.limit_right - 10:
		var board_piece = data.board_piece
		if board_piece:
			player.save_state(board_piece.character_data)
			board_piece.level = board_piece.character_data.level
			
			var board_data = Global.board.board_data
			board_data.player_level[board_piece.piece_character] = player.level
		
		next_level()
				
func get_HUD():
	return $HUD
	
func next_level() -> void:
	if OS.is_debug_build() and not Global.board:
		get_tree().paused = true
		Global.fade_out()
		return
		
	assert(is_instance_valid(Global.board))
	
	var level_scene := Global.get_next_level()
	if level_scene:
		var level := level_scene.instantiate()
		if level.music != music:
			Global.music_fade_out()
			
		await Global.fade_out(true)
		level.data = data
		Global.change_scene_node(level)
	else:
		if Global.board.music != music:
			Global.music_fade_out()
			
		await Global.fade_out(true)
		Global.change_scene_node(Global.board)
		Global.board.returned()
