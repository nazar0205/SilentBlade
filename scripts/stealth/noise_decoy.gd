extends CharacterBody2D
class_name SilentBladeNoiseDecoy

var noise_system: SilentBladeNoiseSystem
var lifetime := 1.6
var emitted := false
const GRAVITY := 980.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	if emitted:
		return
	lifetime -= delta
	velocity.y += GRAVITY * delta
	move_and_slide()
	if is_on_floor() or get_slide_collision_count() > 0 or lifetime <= 0.0:
		_emits_landing_noise()

func _emits_landing_noise() -> void:
	if emitted:
		return
	emitted = true
	if is_instance_valid(noise_system):
		noise_system.emit_noise(global_position, 480.0, 0.95, "DECOY", get_instance_id())
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color("c5a27a"))
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 18, Color("f2d5a8"), 2.0)
