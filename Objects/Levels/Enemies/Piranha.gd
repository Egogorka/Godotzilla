extends "res://Scripts/Objects/Enemies/BaseEnemy.gd"

enum State {
	IDLE,
	STRUCK,
	MOVING_LEFT
}

const EXPLOSION := preload("res://Objects/Levels/Explosion.tscn")

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var state = State.IDLE
var velocity := Vector2()
var cooldown := 0

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	match state:
		State.IDLE:
			if (velocity.x == 0.0 and global_position.x < \
				camera.get_screen_center_position().x + Global.get_content_size().x / 2 + 20): 
					velocity = Vector2(-60, 0)
					animation_player.play("main")
					state = State.MOVING_LEFT
		State.STRUCK:
			if cooldown > 0:
				cooldown -= delta
			else:
				velocity = Vector2(-60, 0)
				animation_player.play("main")
				state = State.MOVING_LEFT
			
		State.MOVING_LEFT:
			if velocity.x > 0:
				state = State.STRUCK
				$Hurt.play()
				cooldown = 20;
				animation_player.play("RESET");

func _physics_process(delta: float) -> void:
	position += velocity * delta
	
func _on_health_component_damaged(_amount: float, _hurt_time: float) -> void:
	velocity.x = 60;
	
func _on_health_component_dead() -> void:
	var explosion := EXPLOSION.instantiate()
	explosion.global_position = global_position
	get_parent().add_child(explosion)
	start_destroy_sfx()
	queue_free()

#func _on_attack_component_attacked(_body: Node2D, _amount: float) -> void:
	
