extends RefCounted
class_name SilentBladeEnemyAI

const STATES := ["PATROL", "ALERT", "INVESTIGATE", "CHASE", "SEARCH", "RETURN", "ATTACK", "STAGGER", "KNOCKBACK"]
const TRANSITIONS := {
	"PATROL": ["ALERT", "CHASE", "KNOCKBACK", "STAGGER"],
	"ALERT": ["INVESTIGATE", "CHASE", "PATROL", "KNOCKBACK", "STAGGER"],
	"INVESTIGATE": ["ALERT", "CHASE", "SEARCH", "RETURN", "KNOCKBACK", "STAGGER"],
	"CHASE": ["ATTACK", "SEARCH", "ALERT", "KNOCKBACK", "STAGGER"],
	"SEARCH": ["ALERT", "CHASE", "RETURN", "KNOCKBACK", "STAGGER"],
	"RETURN": ["PATROL", "ALERT", "CHASE", "KNOCKBACK", "STAGGER"],
	"ATTACK": ["CHASE", "SEARCH", "KNOCKBACK", "STAGGER"],
	"STAGGER": ["CHASE", "SEARCH", "PATROL", "KNOCKBACK"],
	"KNOCKBACK": ["CHASE", "SEARCH", "PATROL", "STAGGER"]
}

func can_transition(current_state: String, next_state: String) -> bool:
	if current_state == next_state:
		return true
	if not TRANSITIONS.has(current_state) or not STATES.has(next_state):
		return false
	return next_state in TRANSITIONS[current_state]
