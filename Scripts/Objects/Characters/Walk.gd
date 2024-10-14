extends State

# Move state is used for characters that walk on the ground.
# This state consists of not only walking but also crouching and jumping.
# This state also includes the movement for flying characters.

var walk_frame := 0.0
var walk_frames := 0
var walk_frame_speed := 0

var jumping := false
var jump_speed := -2 * 60

func state_init() -> void:
	if not parent.is_flying():
		walk_frames = parent.body.sprite_frames.get_frame_count("Walk")
	
	match parent.character:
		PlayerCharacter.Type.GODZILLA:
			walk_frame_speed = 9
			# # You can change the jumping speed for your character like this
			# jump_speed = -1 * 60
		PlayerCharacter.Type.NOTBARAGON:
			walk_frame_speed = 6

func _process(delta: float) -> void:
	move(delta)
	
	# Attacks
	match parent.character:
		PlayerCharacter.Type.GODZILLA:
			common_ground_attacks()
			if parent.animation_player.current_animation == "Crouch" \
				and parent.inputs_pressed[PlayerCharacter.Inputs.B]:
					parent.use_attack(PlayerCharacter.Attack.TAIL_WHIP)
			if parent.inputs_pressed[PlayerCharacter.Inputs.START] \
				and parent.power.value >= 6 * 8:
				parent.use_attack(PlayerCharacter.Attack.HEAT_BEAM)
		PlayerCharacter.Type.NOTBARAGON:
			common_ground_attacks()
	
func common_ground_attacks() -> void:
	if parent.inputs_pressed[PlayerCharacter.Inputs.A]:
		parent.use_attack(PlayerCharacter.Attack.PUNCH)
	if parent.animation_player.current_animation != "Crouch" \
		and parent.inputs_pressed[PlayerCharacter.Inputs.B]:
			parent.use_attack(PlayerCharacter.Attack.KICK)

func move(delta: float) -> void:
	var dirx: float = signf(parent.inputs[PlayerCharacter.Inputs.XINPUT])
	if dirx:
		parent.velocity.x = parent.move_speed * dirx
		
		if parent.allow_direction_changing:
			parent.direction = int(signf(dirx))
			
		walk_frame = wrapf(
			walk_frame + walk_frame_speed * delta * dirx * parent.direction,
			0, walk_frames)
			
		if parent.body.animation == "Walk":
			parent.body.frame = int(walk_frame)
	else:
		parent.velocity.x = 0
		
	var diry: float = parent.inputs[PlayerCharacter.Inputs.YINPUT]
	
	# Jump!
	if parent.is_on_floor() and diry < -0.4:
		parent.velocity.y = jump_speed
		jumping = true
	
	# Variable jump height
	if not parent.is_on_floor() and jumping:
		if diry < -0.4 and parent.velocity.y < -1.95 * 60:
			parent.velocity.y -= 216 * delta
		if parent.velocity.y < 0 and diry >= -0.4:
			jumping = false
			parent.velocity.y = 0
	
	# Crouch
	if diry > 0.4 and parent.body.sprite_frames.has_animation("Crouch"):
		if parent.animation_player.current_animation == "Walk"\
			or parent.animation_player.current_animation == "":
			parent.animation_player.play("Crouch")

	if diry <= 0.4 and parent.animation_player.current_animation == "Crouch":
		parent.animation_player.play("RESET")

func reset() -> void:
	walk_frame = 0
