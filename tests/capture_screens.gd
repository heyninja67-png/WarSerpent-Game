extends SceneTree
## Actual GL framebuffers; run with DISPLAY and --audio-driver Dummy, not --headless.
## Use XDG_DATA_HOME=/tmp/warserpent-flow-capture to isolate save data.
var app: Control
var captures := 0

func _initialize() -> void:
	call_deferred("capture")

func snapshot(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null and image.get_width() >= 1280 and image.get_height() >= 720)
	# Confirm actual rendered content; an all-black or empty framebuffer fails.
	var first := image.get_pixel(0,0)
	var varied := false
	for y in range(0,image.get_height(),60):
		for x in range(0,image.get_width(),60):
			var pixel := image.get_pixel(x,y)
			if absf(pixel.r-first.r)+absf(pixel.g-first.g)+absf(pixel.b-first.b) > 0.1:
				varied = true
	assert(varied,"Framebuffer must contain rendered artwork and interface")
	var error := image.save_png("res://docs/screenshots/" + filename + ".png")
	assert(error == OK)
	captures += 1
	print("FRAMEBUFFER: ",filename," ",image.get_size())

func capture() -> void:
	assert(OS.get_user_data_dir().begins_with("/tmp/warserpent-flow"),"Use isolated XDG_DATA_HOME=/tmp/warserpent-flow-capture")
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots")
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720)
	await process_frame
	app=load("res://scenes/Main.tscn").instantiate()
	root.add_child(app)
	await create_timer(2.8).timeout
	assert(app.current_page=="menu")
	await snapshot("menu")
	app.show_collection(true)
	await create_timer(0.4).timeout
	assert(app.profile.catalog.size()==8)
	await snapshot("collection")
	app.show_menu()
	app.start_game()
	await create_timer(1.4).timeout
	assert(app.game.player.alive)
	await snapshot("gameplay")
	app.game.kill_snake(app.game.player,null)
	await create_timer(1.3).timeout
	assert(app.current_page=="results")
	await snapshot("results")
	app.queue_free()
	await process_frame
	# The audio mixer detaches stopped streams asynchronously.
	await create_timer(0.25).timeout
	print("CAPTURE RESULT: %d actual framebuffers saved" % captures)
	quit(0)
