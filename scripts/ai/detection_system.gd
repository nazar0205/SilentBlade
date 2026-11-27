extends RefCounted
class_name SilentBladeDetectionSystem

var meter := 0.0
var stage := "HIDDEN"

func update(is_visible: bool, exposure: float, delta: float, detection_rate: float, decay_rate: float) -> Dictionary:
	var previous_stage := stage
	if is_visible:
		meter += maxf(0.0, delta) * maxf(0.0, detection_rate) * clampf(exposure, 0.18, 1.35)
	else:
		meter -= maxf(0.0, delta) * maxf(0.0, decay_rate)
	meter = clampf(meter, 0.0, 1.0)
	if meter >= 0.999:
		stage = "DETECTED"
	elif meter >= 0.10:
		stage = "SUSPICIOUS"
	else:
		stage = "HIDDEN"
	return {"meter": meter, "stage": stage, "changed": previous_stage != stage}

func add_suspicion(amount: float) -> void:
	meter = clampf(meter + amount, 0.0, 1.0)
	stage = "DETECTED" if meter >= 0.999 else ("SUSPICIOUS" if meter >= 0.10 else "HIDDEN")

func reset() -> void:
	meter = 0.0
	stage = "HIDDEN"
