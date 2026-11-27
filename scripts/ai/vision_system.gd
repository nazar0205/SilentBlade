extends RefCounted
class_name SilentBladeVisionSystem

func evaluate(observer: CharacterBody2D, target: CharacterBody2D, facing: int, vision_range: float, vision_angle: float, collision_mask: int = 1) -> Dictionary:
	if not is_instance_valid(observer) or not is_instance_valid(target):
		return {"visible": false, "blocked": true, "distance": INF}
	var origin := observer.global_position + Vector2(0.0, -47.0)
	var destination := target.global_position + Vector2(0.0, -30.0)
	var to_target := destination - origin
	var distance := to_target.length()
	if distance > vision_range or distance < 0.001:
		return {"visible": false, "blocked": false, "distance": distance}
	var forward := Vector2.RIGHT * (1.0 if facing >= 0 else -1.0)
	var half_angle_cos := cos(deg_to_rad(vision_angle * 0.5))
	if forward.dot(to_target / distance) < half_angle_cos:
		return {"visible": false, "blocked": false, "distance": distance}
	var query := PhysicsRayQueryParameters2D.create(origin, destination, collision_mask)
	query.exclude = [observer.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = observer.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"visible": false, "blocked": true, "distance": distance}
	var collider: Object = hit.get("collider")
	var clear := collider == target
	return {"visible": clear, "blocked": not clear, "distance": distance}
