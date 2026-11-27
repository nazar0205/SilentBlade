extends Area2D
class_name SilentBladeStealthZone

@export_enum("GRASS", "COVER", "DARK", "LIGHT") var zone_type := "GRASS"
@export var zone_size := Vector2(180.0, 80.0)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	queue_redraw()

func visibility_multiplier(player: CharacterBody2D) -> float:
	var crouched := bool(player.get("crouching"))
	match zone_type:
		"GRASS":
			return 0.36 if crouched else 0.72
		"COVER":
			return 0.54 if crouched else 0.78
		"DARK":
			return 0.62
		"LIGHT":
			return 1.20
	return 1.0

func _draw() -> void:
	var rect := Rect2(-zone_size * 0.5, zone_size)
	match zone_type:
		"GRASS":
			draw_rect(rect, Color(0.17, 0.37, 0.24, 0.14), true)
			for x in range(-int(zone_size.x * 0.5), int(zone_size.x * 0.5), 12):
				draw_line(Vector2(x, 0), Vector2(x - 4, -18), Color(0.34, 0.56, 0.30, 0.75), 3.0)
				draw_line(Vector2(x, 0), Vector2(x + 5, -14), Color(0.45, 0.62, 0.34, 0.7), 2.0)
		"DARK":
			draw_rect(rect, Color(0.035, 0.05, 0.10, 0.28), true)
			draw_rect(rect, Color(0.32, 0.43, 0.62, 0.18), false, 2.0)
		"LIGHT":
			draw_arc(Vector2.ZERO, minf(zone_size.x, zone_size.y) * 0.38, 0.0, TAU, 36, Color(1.0, 0.72, 0.34, 0.34), 2.0)
		"COVER":
			draw_rect(rect, Color(0.42, 0.31, 0.22, 0.15), true)
