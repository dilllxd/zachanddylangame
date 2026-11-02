extends Node
# headless check: drop pellets all over the tank, make sure Goldy eats every one
var tank; var fish; var t := 0.0; var drops := 0; var eaten := 0; var wait := 0.0; var fails := 0
func _ready():
	SaveManager.enabled = false
	var main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	get_node("/root/Events").fish_fed.connect(func(_f, _p): eaten += 1)
func _process(delta):
	if tank == null:
		tank = get_tree().get_first_node_in_group("tank")
		return
	fish = tank.get_node("Fishes").get_child(0)
	fish.fullness = 0.0
	wait += delta
	if tank.get_node("Food").get_child_count() == 0:
		if drops >= 39:
			print("RESULT eaten=%d/%d fails=%d" % [eaten, drops, fails]); get_tree().quit()
		var px := 20.0 + drops * 20.0
		tank.drop_food(Vector2(px, 60))
		var pl = tank.get_node("Food").get_child(-1)
		var top = tank.navigator.decor_top(px)
		if top < 999 and abs(pl.floor_y - (top - 3.0)) > 1.0: print("FLOAT x=", px, " floor=", pl.floor_y, " top=", top)
		if false: tank.drop_food(Vector2(randf_range(40, 760), randf_range(40, 200)))
		drops += 1; wait = 0.0
	elif wait > 15.0:
		var p = tank.get_node("Food").get_child(0)
		print("STUCK fish=", fish.position, " pellet=", p.position, " open=", tank.navigator.is_open(p.position))
		fails += 1; p.queue_free(); wait = 0.0
	return
