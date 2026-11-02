extends Node

var fish: Node2D
var food_target: Node2D = null

func update_food_target() -> void:
	if not fish.is_hungry():
		release_target()
		return
	var best: Node2D = null
	var best_d := INF
	for f in get_tree().get_nodes_in_group("food"):
		if f.claimed_by != null and f.claimed_by != fish and is_instance_valid(f.claimed_by):
			continue
		var dd := fish.position.distance_to(f.position)
		if dd < best_d:
			best_d = dd
			best = f
	if best != food_target:
		release_target()
		food_target = best
		if best:
			best.claimed_by = fish

func release_target() -> void:
	if is_instance_valid(food_target) and food_target.claimed_by == fish:
		food_target.claimed_by = null
	food_target = null

func predicted_goal(speed: float) -> Vector2:
	var eta := fish.position.distance_to(food_target.position) / speed
	var goal: Vector2 = food_target.predict(eta)
	if fish.position.distance_to(goal) > 48.0:
		goal = fish.tank.navigator.open_point_near(goal)
	return goal

func _exit_tree() -> void:
	release_target()
