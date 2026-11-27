extends RefCounted
class_name SilentBladeCoverSystem

var zones: Array[SilentBladeStealthZone] = []

func register_zone(zone: SilentBladeStealthZone) -> void:
	if not zones.has(zone):
		zones.append(zone)

func get_concealment_multiplier(player: CharacterBody2D) -> float:
	var multiplier := 1.0
	for zone in zones:
		if is_instance_valid(zone) and zone.monitoring and zone.overlaps_body(player):
			if zone.zone_type == "GRASS" or zone.zone_type == "COVER":
				multiplier = minf(multiplier, zone.visibility_multiplier(player))
	return multiplier

func has_cover(player: CharacterBody2D) -> bool:
	return get_concealment_multiplier(player) < 0.80
