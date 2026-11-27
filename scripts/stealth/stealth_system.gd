extends Node
class_name SilentBladeStealthSystem

const CoverSystemScript = preload("res://scripts/stealth/cover_system.gd")
var cover_system: SilentBladeCoverSystem = CoverSystemScript.new()
var zones: Array[SilentBladeStealthZone] = []

func register_zone(zone: SilentBladeStealthZone) -> void:
	if not zones.has(zone):
		zones.append(zone)
	if zone.zone_type == "GRASS" or zone.zone_type == "COVER":
		cover_system.register_zone(zone)

func get_visibility_multiplier(player: CharacterBody2D) -> float:
	var multiplier := 0.68 if bool(player.get("crouching")) else 1.0
	var speed := absf((player as CharacterBody2D).velocity.x)
	if speed > 240.0:
		multiplier *= 1.18
	elif speed < 55.0:
		multiplier *= 0.90
	multiplier *= cover_system.get_concealment_multiplier(player)
	for zone in zones:
		if not is_instance_valid(zone) or not zone.monitoring or not zone.overlaps_body(player):
			continue
		if zone.zone_type == "DARK" or zone.zone_type == "LIGHT":
			multiplier *= zone.visibility_multiplier(player)
	# Never make the character completely invisible; even ideal cover still leaves a small exposure.
	return clampf(multiplier, 0.18, 1.35)

func get_player_status(player: CharacterBody2D) -> String:
	var exposure := get_visibility_multiplier(player)
	if exposure < 0.55:
		return "В ТЕНИ / УКРЫТИИ"
	if exposure > 1.10:
		return "НА СВЕТУ"
	return "ЗАМЕТНОСТЬ: НОРМА"
