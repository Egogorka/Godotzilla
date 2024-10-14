extends Sprite2D

@onready var player: AnimationPlayer = $AnimationPlayer

func splash() -> void:
	player.play("main")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_animation_changed(old_name: StringName, new_name: StringName) -> void:
	if old_name == "main" and new_name == "[stop]":
		queue_free()

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "main":
		queue_free()
