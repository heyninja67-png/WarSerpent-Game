extends SceneTree

const Snake = preload("res://scripts/movement/snake_model.gd")
const Hash = preload("res://scripts/gameplay/spatial_hash.gd")
const Brain = preload("res://scripts/bots/arena_brain.gd")
const Arena = preload("res://scripts/gameplay/ArenaGame.gd")
var checks := 0
var failures := 0

func check(condition: bool, title: String) -> void:
	checks += 1
	if condition:
		print("PASS ", title)
	else:
		failures += 1
		push_error("FAIL " + title)

func make_snake(skin: int = 0) -> SnakeModel:
	var snake := Snake.new()
	snake.initialize(Vector2.ZERO, 0, skin, 0, "TEST")
	return snake

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(10301)
	var snake := make_snake()
	for i in range(120):
		snake.advance(1.0 / 60, 0, false)
	check(absf(snake.position.x - 324.0) < 0.01, "constant movement covers expected distance")
	check(absf(snake.position.y) < 0.01, "straight movement maintains axis")
	var spacing_ok := true
	for i in range(1, snake.segments.size()):
		spacing_ok = spacing_ok and absf(snake.segments[i].distance_to(snake.segments[i - 1]) - Snake.SPACING) < 0.02
	check(spacing_ok, "body is sampled by distance with consistent segment spacing")
	for i in range(100):
		snake.advance(1.0 / 60, float(i) * 0.035, false)
	spacing_ok = true
	for i in range(1, snake.segments.size()):
		spacing_ok = spacing_ok and snake.segments[i].distance_to(snake.segments[i - 1]) > 9.5 and snake.segments[i].distance_to(snake.segments[i - 1]) <= 10.01
	check(spacing_ok, "smooth curved path preserves spacing")
	var slow_frame := make_snake()
	for i in range(60):
		slow_frame.advance(1.0 / 30, 0, false)
	check(absf(slow_frame.position.x - 324.0) < 0.02, "movement is time based at 30 FPS")
	var count := snake.segment_count()
	snake.collect(120)
	snake.rebuild_body()
	check(snake.segment_count() == count + 10 and snake.score == 120, "energy grows snake and awards score")
	var normal := make_snake()
	var boosted := make_snake()
	for i in range(60):
		normal.advance(1.0 / 60, 0, false)
		boosted.advance(1.0 / 60, 0, true)
	check(boosted.position.x > normal.position.x * 1.6, "boost increases actual movement speed")
	check(boosted.mass < normal.mass and boosted.mass >= 36.0, "boost consumes mass with lower bound")
	boosted.mass = 36
	boosted.advance(0.1, 0, true)
	check(not boosted.boosting, "boost stops at minimum mass")
	var volt := make_snake(0)
	check(volt.activate(), "skill activates when ready")
	check(not volt.activate(), "cooldown blocks repeated activation")
	volt.advance(1, 0, false)
	check(volt.position.x > Snake.BASE_SPEED * 1.5, "electric overdrive changes speed")
	check(volt.cooldown > 0 and volt.active_time > 0, "skill tracks cooldown and duration independently")
	volt.advance(14, 0, false)
	check(volt.cooldown == 0 and volt.active_time == 0, "cooldown expires and permits reuse")
	check(volt.activate(), "skill can activate after cooldown")
	var shield := make_snake(3)
	shield.invulnerable = 0
	shield.activate()
	check(not shield.lethal_collision(), "cyber shield absorbs a collision")
	check(not shield.shield, "shield is consumed by collision")
	shield.advance(1.1, 0, false)
	check(shield.lethal_collision(), "consumed shield does not prevent later collision")
	var phantom := make_snake(4)
	phantom.invulnerable = 0
	phantom.activate()
	phantom.slow(0.2, 3)
	check(not phantom.lethal_collision() and phantom.slow_time == 0, "phantom avoids collision and negative slow while active")
	phantom.advance(2.5, 0, false)
	check(phantom.lethal_collision(), "phantom protection has finite duration")
	var hash_grid := Hash.new(50)
	hash_grid.insert(Vector2(49, -1), "boundary")
	check(hash_grid.query(Vector2(51, 1), 10).has("boundary"), "spatial query includes neighboring and negative cells")
	hash_grid.clear()
	check(hash_grid.query(Vector2.ZERO, 200).is_empty(), "spatial hash resets without stale collisions")
	var game := Arena.new()
	game.configure(0, 1)
	game.set_quality("Baixo")
	game.set_audio_enabled(false)
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	check(game.snakes.size() == 8 and game.foods.size() == 720, "low profile starts player, seven bots and pooled energy")
	var touch_joy := InputEventScreenTouch.new()
	touch_joy.index = 2
	touch_joy.position = Vector2(162, 600)
	touch_joy.pressed = true
	game._input(touch_joy)
	var touch_boost := InputEventScreenTouch.new()
	touch_boost.index = 5
	touch_boost.position = Vector2(1168, 604)
	touch_boost.pressed = true
	game._input(touch_boost)
	var touch_skill := InputEventScreenTouch.new()
	touch_skill.index = 7
	touch_skill.position = Vector2(1034, 573)
	touch_skill.pressed = true
	game._input(touch_skill)
	check(game.joystick_id == 2 and game.boost_id == 5 and game.skill_id == 7 and game.joystick_vector.x > 0.5, "three simultaneous touch identities steer, boost and use skill")
	check(game.player.cooldown > 0.0, "touch ability button changes actual ability state")
	touch_joy.pressed = false
	game._input(touch_joy)
	check(game.joystick_id == -1 and game.joystick_vector == Vector2.ZERO and game.boost_id == 5, "releasing joystick preserves held boost touch")
	touch_boost.pressed = false
	game._input(touch_boost)
	game.player.cooldown = 0
	game.player.active_time = 0
	var before: int = game.player.score
	game.foods[0].p = game.player.position
	game.foods[0].active = true
	game.foods[0].v = 5
	game.rebuild_food_grid()
	game.collect_food(game.player)
	check(game.player.score >= before + 5 and not game.foods[0].active, "arena collection deactivates food and awards real mass")
	var enemy: SnakeModel = game.snakes[1]
	game.player.skin = 1
	game.player.cooldown = 0
	game.player.activate()
	enemy.position = game.player.position + Vector2(60, 0)
	game.apply_abilities(0.1)
	check(enemy.slow_time > 0 and enemy.slow_factor < 0.5, "flame burst slows nearby opponents")
	game.player.skin = 2
	game.player.cooldown = 0
	game.player.activate()
	game.trail_timer = 0
	game.apply_abilities(0.1)
	check(not game.trails.is_empty(), "frost ability creates persistent slowing trail")
	enemy.slow_time = 0
	enemy.slow_factor = 1
	enemy.position = game.trails[0].p
	game.apply_abilities(0.1)
	check(enemy.slow_time > 0 and enemy.slow_factor < 0.6, "frozen trail slows other snakes")
	var brain := Brain.new()
	enemy.position = Vector2(1340, 0)
	enemy.heading = 0
	brain.decide(enemy, game.foods, game.snakes, 1400, 1)
	check(absf(brain.target_angle) > 1.0 and not brain.wants_boost, "bot steers away from lethal arena edge")
	# Isolate a body collision from random arena state.
	for rival in game.snakes:
		rival.alive = false
	game.player.alive = true
	game.player.invulnerable = 0
	game.player.shield = false
	game.player.position = Vector2.ZERO
	enemy.alive = true
	enemy.position = Vector2(200, 0)
	enemy.segments = PackedVector2Array([Vector2(200,0), Vector2(190,0), Vector2(180,0), Vector2(170,0), Vector2.ZERO])
	game.rebuild_body_grid()
	game.check_collisions(game.player)
	check(not game.player.alive and enemy.kills == 1, "head-body collision eliminates snake and credits killer")
	check(game.death_delay > 0, "player death begins defeat transition")
	var result: Dictionary = {}
	game.finished.connect(func(data: Dictionary): result.merge(data))
	game.end_game(false)
	check(result.has("score") and result.has("survived") and result.has("time") and not result.abandoned, "result signal supplies actual match statistics")
	game.free()
	print("GAMEPLAY TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

