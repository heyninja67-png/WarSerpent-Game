extends SceneTree

const Arena = preload("res://scripts/gameplay/ArenaGame.gd")
const Snake = preload("res://scripts/movement/snake_model.gd")
var benchmark_result: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(928341)
	var game := Arena.new()
	game.configure(0, 1)
	game.set_audio_enabled(false)
	game.set_quality("High")
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	for snake in game.snakes:
		snake.mass = 0
		while snake.segment_count() < 40:
			snake.mass += 1
		snake.rebuild_body()
	game.rebuild_body_grid()
	# A fixed 40-segment body makes the model timing comparable despite starter-size changes.
	var model := Snake.new()
	model.initialize(Vector2.ZERO, 0, 0, 0, "BENCH")
	model.mass = 0
	while model.segment_count() < 40:
		model.mass += 1
	var start := Time.get_ticks_usec()
	for i in range(12000):
		model.advance(1.0 / 60.0, float(i) * 0.01, false)
	benchmark_result["model_40_segments_us"] = (Time.get_ticks_usec() - start) / 12000.0
	start = Time.get_ticks_usec()
	for i in range(1200):
		game.rebuild_body_grid()
	benchmark_result["body_grid_us"] = (Time.get_ticks_usec() - start) / 1200.0
	start = Time.get_ticks_usec()
	for i in range(1200):
		game.brains[i % game.brains.size()].decide(game.snakes[1 + i % game.brains.size()], game.foods, game.snakes, game.BOUNDS, 1.0)
	benchmark_result["ai_decision_us"] = (Time.get_ticks_usec() - start) / 1200.0
	start = Time.get_ticks_usec()
	for frame in range(3600):
		for snake in game.snakes:
			snake.invulnerable = 1000
		game.joystick_vector = Vector2.from_angle(float(frame) * 0.012)
		game._physics_process(1.0 / 60)
		if game.ended:
			push_error("Benchmark unexpectedly ended")
			quit(1)
			return
	benchmark_result["arena_step_us"] = (Time.get_ticks_usec() - start) / 3600.0
	benchmark_result["food_count"] = game.foods.size()
	benchmark_result["snake_count"] = game.snakes.size()
	benchmark_result["starter_segments"] = Snake.new().segment_count()
	print("BENCHMARK ", JSON.stringify(benchmark_result))
	var path := "/tmp/warserpent-benchmark.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			path = arg.trim_prefix("--output=")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(benchmark_result, "  "))
	game.free()
	quit()
