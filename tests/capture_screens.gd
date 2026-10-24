extends SceneTree
## Run with a real display, not --headless; captures actual Godot framebuffers.
var app: Control

func _initialize() -> void:
	call_deferred("capture")

func snapshot(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null and image.get_width() >= 1280)
	var error := image.save_png("res://docs/screenshots/" + filename + ".png")
	assert(error == OK)
	print("FRAMEBUFFER: ", filename, " ", image.get_size())

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots")
	app = load("res://scenes/Main.tscn").instantiate()
	root.add_child(app)
	await create_timer(4.7).timeout
	assert(app.current_page == "menu")
	await snapshot("menu")
	app.show_collection(true)
	await create_timer(0.4).timeout
	await snapshot("collection")
	app.show_menu()
	app.start_game()
	await create_timer(1.8).timeout
	await snapshot("gameplay")
	app.game.kill_snake(app.game.player,null)
	await create_timer(1.6).timeout
	assert(app.current_page == "results")
	await snapshot("results")
	app.queue_free()
	await process_frame
	# Audio mixing runs on its own thread. Let the final stopped stream detach
	# before process shutdown, rather than ending in the same graphics frame.
	await create_timer(0.25).timeout
	quit(0)
