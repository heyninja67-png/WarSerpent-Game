extends SceneTree

const Arena = preload("res://scripts/gameplay/ArenaGame.gd")
const Brain = preload("res://scripts/bots/arena_brain.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(4432)
	var start := Time.get_ticks_usec()
	var frames := 0
	for skin in range(5):
		var game := Arena.new()
		game.configure(skin, 2)
		game.set_audio_enabled(false)
		root.add_child(game)
		game.set_physics_process(false)
		game.set_process(false)
		var pilot := Brain.new()
		pilot.difficulty = 2
		for frame in range(1800):
			if game.ended:
				break
			pilot.decide(game.player, game.foods, game.snakes, game.BOUNDS, 1.0 / 60)
			game.joystick_vector = Vector2.from_angle(pilot.target_angle)
			game.boost_id = 12 if pilot.wants_boost else -1
			if frame % 120 == 0:
				game.use_skill()
			game._physics_process(1.0 / 60)
			game._process(1.0 / 60)
			frames += 1
			if not game.player.position.is_finite() or game.foods.size() > 1500:
				failures += 1
				break
		print("SIM skin=%d time=%.2f score=%d alive=%s foods=%d snakes=%d" % [skin, game.elapsed, game.player.score, game.player.alive, game.foods.size(), game.snakes.size()])
		if game.elapsed < 1.0:
			failures += 1
		game.free()
	var duration := (Time.get_ticks_usec() - start) / 1000000.0
	print("SIMULATION: %d physics steps, %.3fs wall time, %.3fms/step, %d failures (headless CPU only, not Android FPS)" % [frames, duration, duration * 1000 / maxf(frames, 1), failures])
	quit(1 if failures else 0)
