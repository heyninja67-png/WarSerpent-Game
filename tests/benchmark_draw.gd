extends SceneTree

class TimedArena extends ArenaGame:
	var samples: Array[float] = []
	func _process(delta: float) -> void:
		clock += delta
		queue_redraw()
	func _draw() -> void:
		var start := Time.get_ticks_usec()
		super._draw()
		if samples.size() < 180:
			samples.append(float(Time.get_ticks_usec() - start))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(1047)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game := TimedArena.new()
	game.configure(0, 1)
	game.set_audio_enabled(false)
	game.set_quality("High")
	root.add_child(game)
	game.set_physics_process(false)
	for i in range(game.snakes.size()):
		var snake := game.snakes[i]
		snake.initialize(Vector2(-400 + (i % 5) * 190, -150 + (i / 5) * 270), 0, i % 5, i, "DRAW-%d" % i)
		snake.mass = 0
		while snake.segment_count() < 40:
			snake.mass += 1
		snake.rebuild_body()
	game.camera_position = Vector2.ZERO
	game.player.position = Vector2.ZERO
	while game.samples.size() < 180:
		await process_frame
	var sum := 0.0
	for sample in game.samples:
		sum += sample
	game.samples.sort()
	var result := {"draw_command_mean_us": sum / game.samples.size(), "draw_command_p95_us": game.samples[170], "frames": game.samples.size(), "snakes": game.snakes.size(), "segments_each": 40, "backend": DisplayServer.get_name(), "draw_calls_last_frame": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "rendered_objects_last_frame": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)}
	print("DRAW_BENCHMARK ", JSON.stringify(result))
	var path := "/tmp/warserpent-draw-benchmark.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			path = arg.trim_prefix("--output=")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	game.free()
	quit()
