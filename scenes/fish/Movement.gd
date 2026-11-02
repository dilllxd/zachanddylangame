extends Node

var fish: Node2D
var tank: Node2D
var velocity := Vector2.ZERO
var wander_target: Vector2
var path := PackedVector2Array()
var path_goal := Vector2.INF

func next_waypoint(goal: Vector2, replan: bool) -> Vector2:
	if tank.navigator.line_clear(fish.position, goal) or (is_instance_valid(fish.seeker.food_target) and fish.position.distance_to(goal) < 48.0):
		path.clear()
		path_goal = goal
		return goal
	if path.is_empty() or (replan and goal.distance_to(path_goal) > tank.navigator.CELL):
		replan_path(goal)
	while path.size() > 1 and (fish.position.distance_to(path[0]) < 8 or tank.navigator.line_clear(fish.position, path[1])):
		path.remove_at(0)  # skip waypoints we can already see past
	return path[0] if not path.is_empty() else goal

func replan_path(goal: Vector2) -> void:
	path = tank.navigator.find_path(fish.position, goal)
	path_goal = goal

func pick_wander_target() -> void:
	wander_target = tank.navigator.random_open_point()
	path.clear()
	path_goal = wander_target


func steer(steer_to: Vector2, target_speed: float, goal: Vector2, delta: float) -> void:
	# smooth steering instead of instant direction changes
	var desired := (steer_to - fish.position).normalized() * target_speed
	velocity = velocity.lerp(desired, clamp(fish.turn_rate * delta, 0.0, 1.0))
	var next := fish.position + velocity * delta
	# close to food we drop the padding and only avoid real rock pixels, so pellets
	# tucked against a rock or on a slope are still reachable
	var near_food := is_instance_valid(fish.seeker.food_target) and fish.position.distance_to(fish.seeker.food_target.position) < 48.0
	if near_food and tank.navigator.is_open_raw(next):
		fish.position = next
	elif tank.navigator.is_open(next) or not tank.navigator.is_open(fish.position):
		fish.position = next  # also let him swim out if he ever ends up inside decor
	elif tank.navigator.is_open(Vector2(next.x, fish.position.y)):
		fish.position.x = next.x  # slide along the rock instead of freezing
	elif tank.navigator.is_open(Vector2(fish.position.x, next.y)):
		fish.position.y = next.y
	else:
		velocity *= 0.5  # bumped decor, slow down and let the path pull us out
		path_goal = Vector2.INF
		replan_path(goal)
	if abs(velocity.x) > 2:
		fish.get_node("Sprite2D").flip_h = velocity.x < 0
