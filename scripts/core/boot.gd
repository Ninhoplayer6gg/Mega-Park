extends Node
## Entry point: applies the UI theme, loads (or creates) the save and opens the title screen.

func _ready() -> void:
	get_tree().root.theme = UITheme.get_theme()
	get_tree().set_auto_accept_quit(true)
	if not SaveManager.load_game():
		SaveManager.new_game()
	# Let tests or tools jump straight into a scene: --scene=park|battle
	var target := SceneRouter.TITLE
	for arg in OS.get_cmdline_user_args():
		if arg == "--tour" and ResourceLoader.exists("res://tests/tour_driver.gd"):
			var driver: Node = load("res://tests/tour_driver.gd").new()
			driver.name = "TourDriver"
			get_tree().root.add_child.call_deferred(driver)
		if arg == "--gtour" and ResourceLoader.exists("res://tests/genetics_tour.gd"):
			var gdriver: Node = load("res://tests/genetics_tour.gd").new()
			gdriver.name = "GeneticsTour"
			get_tree().root.add_child.call_deferred(gdriver)
		if arg == "--scene=park":
			target = SceneRouter.PARK
		elif arg == "--scene=battle":
			target = SceneRouter.BATTLE
	get_tree().change_scene_to_file.call_deferred(target)
