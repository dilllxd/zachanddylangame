extends Control

func _ready() -> void:
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()

func set_paused(value: bool) -> void:
	get_tree().paused = value
	visible = value
	if value:
		$Center/Menu/Resume.grab_focus()
	else:
		$Center/Menu/Resume.release_focus()

func _on_resume_pressed() -> void:
	set_paused(false)

func _on_title_pressed() -> void:
	SaveManager.save_game()
	set_paused(false)
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")

func _on_quit_pressed() -> void:
	SaveManager.save_game()
	get_tree().paused = false
	get_tree().quit()
