extends TextureRect

@export var speed_x = -10
var dist_travelled = 0;

@onready var area2D = $Area2D
@onready var shape = $Area2D/CollisionShape2D

const SPLASH = preload("res://Objects/Levels/WaterSplash.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area2D.monitoring = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_position.x += speed_x * delta
	dist_travelled += speed_x * delta
	if abs(dist_travelled) > 117:
		global_position.x -= dist_travelled
		dist_travelled = 0
	pass

func _on_body_shape_entered(_body_rid: RID, body: Node2D, _body_shape_index: int, _local_shape_index: int) -> void:
	var enter_pos = Vector2(body.global_position.x, shape.global_position.y - 10)
	var splash = SPLASH.instantiate()
	splash.global_position = enter_pos
	get_parent().get_parent().add_child(splash)
	splash.splash()
	pass
