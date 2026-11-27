extends RefCounted
class_name SilentBladeMissionResults

# Transparent medal times for the full 6.2 km mission, excluding the briefing screen.
const S_TIME_LIMIT := 420.0
const A_TIME_LIMIT := 660.0
const B_TIME_LIMIT := 960.0

static func evaluate(stats: Dictionary) -> String:
	if not bool(stats.get("success", false)):
		return "D"
	var elapsed := maxf(0.0, float(stats.get("elapsed_time", 0.0)))
	var detections := int(stats.get("detections", 0))
	var alarms := int(stats.get("alarms", 0))
	var secrets_found := int(stats.get("secrets_found", 0))
	var secrets_total := int(stats.get("secrets_total", 0))
	var neutralized := int(stats.get("neutralized", 0))
	if elapsed <= S_TIME_LIMIT and detections == 0 and alarms == 0 and secrets_found >= secrets_total and neutralized == 0:
		return "S"
	if elapsed <= A_TIME_LIMIT and detections == 0 and alarms <= 1 and secrets_found >= 1:
		return "A"
	if elapsed <= B_TIME_LIMIT and detections <= 2 and alarms <= 2:
		return "B"
	return "C"

static func optional_objectives(stats: Dictionary) -> Array[Dictionary]:
	var detection_free := int(stats.get("detections", 0)) == 0
	var no_kills := int(stats.get("neutralized", 0)) == 0
	var all_secrets := int(stats.get("secrets_found", 0)) >= int(stats.get("secrets_total", 0))
	var all_documents := int(stats.get("documents_collected", 0)) >= int(stats.get("documents_total", 2))
	return [
		{"id": "ghost_run", "title": "Призрак: пройти без обнаружения", "completed": detection_free},
		{"id": "no_kills", "title": "Без кровопролития: не устранять противников", "completed": no_kills},
		{"id": "all_secrets", "title": "Собиратель: найти все секреты", "completed": all_secrets},
		{"id": "all_documents", "title": "Архивариус: собрать оба документа", "completed": all_documents}
	]
