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
	check(snake.segment_count() == 10 and snake.mass == 36, "starter snake has ten connected segments with boost mass")
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
	var responsive := make_snake()
	responsive.advance(0.2, PI / 2, false)
	var heavy := make_snake()
	heavy.mass = 1500
	heavy.advance(0.2, PI / 2, false)
	check(responsive.heading > 0.9 and responsive.heading > heavy.heading, "small snake turns responsively while large snake keeps readable radius")
	var settling := make_snake()
	settling.advance(0.1, 0.02, false)
	check(absf(settling.heading - 0.02) < 0.00001, "steering reaches nearby target without overshoot")
	settling.heading = PI - 0.01
	settling.advance(0.1, -PI + 0.01, false)
	check(absf(angle_difference(settling.heading, -PI + 0.01)) < 0.00001, "steering crosses angular wrap by shortest route")
	var steer30 := make_snake()
	var steer60 := make_snake()
	for i in range(60):
		steer60.advance(1.0 / 60, PI / 2, false)
	for i in range(30):
		steer30.advance(1.0 / 30, PI / 2, false)
	check(absf(steer30.heading - steer60.heading) < 0.0001 and steer30.position.distance_to(steer60.position) < 4.0, "30 and 60 Hz steering settle consistently")
	var rapid := make_snake(6)
	rapid.mass = 500
	rapid.activate()
	for i in range(360):
		rapid.advance(1.0 / 60, PI / 2 if i % 24 < 12 else -PI / 2, i % 3 != 0)
	var rapid_stable := rapid.position.is_finite()
	for i in range(1, rapid.segments.size()):
		rapid_stable = rapid_stable and rapid.segments[i].distance_to(rapid.segments[i - 1]) > 9.0 and rapid.segments[i].distance_to(rapid.segments[i - 1]) <= 10.01
	check(rapid_stable, "rapid boost and dash direction changes keep body connected")
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
	check(boosted.mass < normal.mass and boosted.mass >= Snake.MIN_MASS, "boost consumes mass with lower bound")
	boosted.mass = Snake.MIN_MASS
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
	var samurai := make_snake(6)
	samurai.activate()
	samurai.advance(0.25, 0, false)
	check(samurai.position.x > Snake.BASE_SPEED * 0.25 * 1.85, "samurai dash produces real speed increase")
	samurai.advance(1.0, 0, false)
	check(samurai.active_time == 0 and samurai.cooldown > 0, "samurai dash is brief and cooldown limited")
	var solar := make_snake(5)
	solar.activate()
	check(solar.collection_radius() == 150, "solar magnet expands actual collection radius")
	solar.advance(4.1, 0, false)
	check(solar.collection_radius() == 26, "solar magnet range returns to normal after duration")
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	var catalog_consistent := catalog.size() == Snake.COOLDOWNS.size()
	for item: Dictionary in catalog:
		catalog_consistent = catalog_consistent and float(item.cooldown) == Snake.COOLDOWNS[int(item.id)] and float(item.duration) == Snake.DURATIONS[int(item.id)]
	check(catalog_consistent, "all eight skill durations and cooldowns match catalog")
	var long_snake := make_snake()
	long_snake.mass = 1700
	for i in range(1200):
		long_snake.advance(1.0 / 60.0, float(i) * 0.014, i % 9 == 0)
	var stable := long_snake.segments.size() == long_snake.segment_count()
	for index in range(1, long_snake.segments.size()):
		stable = stable and long_snake.segments[index].distance_to(long_snake.segments[index - 1]) > 9.0 and long_snake.segments[index].distance_to(long_snake.segments[index - 1]) <= 10.01
	check(stable and long_snake._history.size() == Snake.HISTORY_CAPACITY, "fixed ring history wraps while long curved body keeps spacing")
	var hash_grid := Hash.new(50)
	hash_grid.insert(Vector2(49, -1), "boundary")
	check(hash_grid.query(Vector2(51, 1), 10).has("boundary"), "spatial query includes neighboring and negative cells")
	hash_grid.clear()
	check(hash_grid.query(Vector2.ZERO, 200).is_empty(), "spatial hash resets without stale collisions")
	var game := Arena.new()
	game.configure(0, 1)
	game.set_quality("Low")
	game.set_audio_enabled(false)
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	check(game.snakes.size() == 6 and game.foods.size() == 420, "low profile starts player, five bots and pooled energy")
	check(game.hud_state().protection_remaining > 0 and game.hud_state().danger == 0, "HUD exposes initial spawn protection and safe-center state")
	var center := game.joystick_center(game.get_viewport_rect().size)
	game.update_joystick(center + Vector2(11, 0), game.get_viewport_rect().size)
	check(game.joystick_vector == Vector2.ZERO, "joystick center noise below enter radius cannot drift")
	game.update_joystick(center + Vector2(15, 0), game.get_viewport_rect().size)
	game.update_joystick(center + Vector2(11, 0), game.get_viewport_rect().size)
	check(game.joystick_vector.x > 0 and game.joystick_vector.length() < 0.12, "hysteresis retains a deliberate small held direction")
	game.update_joystick(center + Vector2(7, 0), game.get_viewport_rect().size)
	game.update_joystick(center + Vector2(11, 0), game.get_viewport_rect().size)
	check(game.joystick_vector == Vector2.ZERO, "return to center releases steering until enter threshold crossed again")
	game.update_joystick(center + Vector2(1000, 1000), game.get_viewport_rect().size)
	check(game.joystick_vector.length() <= 1.00001, "joystick drag outside radius stays normalized")
	game.reset_controls()
	game.player.position = Vector2(1280, 0)
	check(game.boundary_danger() > 0.5, "boundary danger rises before reaching lethal arena edge")
	game.player.position = Vector2.ZERO
	check(game.boundary_danger() == 0, "boundary warning clears when returning toward center")
	var map_state: Dictionary = game.minimap_state()
	var live_player_markers := 0
	for marker: Dictionary in map_state.markers:
		if marker.player:
			live_player_markers += 1
	check(map_state.markers.size() == game.snakes.size() and live_player_markers == 1, "circular minimap contains actual live actors and one player marker")
	var map_inside := true
	for marker: Dictionary in map_state.markers:
		map_inside = map_inside and marker.position.is_finite() and marker.position.distance_to(map_state.center) <= map_state.radius
	check(map_inside and game.minimap_world_to_screen(Vector2(1400, 1400)).distance_to(map_state.center) <= map_state.radius, "minimap world mapping stays within circular boundary")
	var previous_refresh: int = map_state.refresh_count
	game.snakes[1].position = Vector2(600, 300)
	game._process(0.04)
	check(game.minimap_state().refresh_count == previous_refresh, "minimap cache does not rebuild on every render frame")
	game._process(0.12)
	var mapped_enemy := Vector2.ZERO
	for marker: Dictionary in game.minimap_state().markers:
		if marker.id == game.snakes[1].id:
			mapped_enemy = marker.position
	check(game.minimap_state().refresh_count == previous_refresh + 1 and mapped_enemy.distance_to(game.minimap_world_to_screen(Vector2(600, 300))) < 0.001, "minimap refreshes throttled cache from changed actor positions")
	var touch_joy := InputEventScreenTouch.new()
	touch_joy.index = 2
	touch_joy.position = game.joystick_center(game.get_viewport_rect().size) + Vector2(50, 0)
	touch_joy.pressed = true
	game._input(touch_joy)
	var touch_boost := InputEventScreenTouch.new()
	touch_boost.index = 5
	touch_boost.position = game.boost_center(game.get_viewport_rect().size)
	touch_boost.pressed = true
	game._input(touch_boost)
	var touch_skill := InputEventScreenTouch.new()
	touch_skill.index = 7
	touch_skill.position = game.skill_center(game.get_viewport_rect().size)
	touch_skill.pressed = true
	game._input(touch_skill)
	check(game.joystick_id == 2 and game.boost_id == 5 and game.skill_id == 7 and game.joystick_vector.x > 0.5, "three simultaneous touch identities steer, boost and use skill")
	check(game.player.cooldown > 0.0, "touch ability button changes actual ability state")
	touch_joy.pressed = false
	game._input(touch_joy)
	check(game.joystick_id == -1 and game.joystick_vector == Vector2.ZERO and game.boost_id == 5, "releasing joystick preserves held boost touch")
	touch_boost.pressed = false
	game._input(touch_boost)
	var center_boost_touch := InputEventScreenTouch.new()
	center_boost_touch.index = 8
	center_boost_touch.position = game.boost_secondary_center(game.get_viewport_rect().size)
	center_boost_touch.pressed = true
	game._input(center_boost_touch)
	check(game.boost_id == 8, "center boost widget is bound to the real held boost control")
	center_boost_touch.pressed = false
	game._input(center_boost_touch)
	game.player.cooldown = 0
	game.player.active_time = 0
	var pause_touch := InputEventScreenTouch.new()
	pause_touch.index = 3
	pause_touch.position = Vector2(game.get_viewport_rect().size.x - 45, 40)
	pause_touch.pressed = true
	game._input(pause_touch)
	var emulated_mouse := InputEventMouseButton.new()
	emulated_mouse.device = InputEvent.DEVICE_ID_EMULATION
	emulated_mouse.position = pause_touch.position
	emulated_mouse.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse.pressed = true
	game._input(emulated_mouse)
	check(game.paused, "touch pause ignores duplicate Android mouse emulation")
	check(game.joystick_id == -1 and game.boost_id == -1 and game.skill_id == -1 and not game._steering_active, "pause clears every held touch identity and steering latch")
	game.toggle_pause()
	game.joystick_id = 2
	game.boost_id = 4
	game.skill_id = 5
	game.mouse_boost = true
	game.joystick_vector = Vector2.RIGHT
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.joystick_id == -1 and game.boost_id == -1 and game.skill_id == -1 and game.joystick_vector == Vector2.ZERO and not game.mouse_boost, "application focus loss clears controls without stuck boost")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game.paused, "Android application pause suspends active local gameplay")
	game.toggle_pause()
	var before: int = game.player.score
	game.foods[0].p = game.player.position
	game.foods[0].active = true
	game.foods[0].v = 5
	game.rebuild_food_grid()
	game.collect_food(game.player)
	check(game.player.score >= before + 5 and not game.foods[0].active, "arena collection deactivates food and awards real mass")
	check(game.hud_state().pickup_total >= 5 and game.hud_state().pickup_remaining > 0, "pickup feedback aggregates actual collected energy")
	game.paused = true
	var feedback_left: float = game.hud_state().pickup_remaining
	game._process(0.2)
	check(game.hud_state().pickup_remaining == feedback_left, "pickup feedback freezes while paused")
	game.paused = false
	game._process(0.8)
	check(game.hud_state().pickup_total == 0 and game.hud_state().pickup_remaining == 0, "pickup feedback expires instead of accumulating UI objects")
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
	game.player.skin = 7
	game.player.cooldown = 0
	game.player.activate()
	enemy.position = game.player.position + Vector2(160, 0)
	enemy.slow_time = 0
	enemy.slow_factor = 1
	game.apply_abilities(0.1)
	check(enemy.slow_time > 0 and enemy.slow_factor == 0.60, "toxic cloud slows opponents inside its area")
	game.player.skin = 5
	game.player.cooldown = 0
	game.player.activate()
	game.foods[1].p = game.player.position + Vector2(110, 0)
	game.foods[1].active = true
	game.rebuild_food_grid()
	game.collect_food(game.player)
	check(not game.foods[1].active, "solar magnet actually collects energy beyond normal radius")
	enemy.heading = 0
	enemy.cooldown = 0
	enemy.active_time = 0
	enemy.slow_time = 0
	enemy.slow_factor = 1
	enemy.mass = 80
	game.remote_controls[enemy.id] = {"angle": PI / 2.0, "boost": true, "skill": true}
	game._physics_process(0.1)
	check(enemy.boosting and enemy.heading > 0 and enemy.cooldown > 0 and not game.remote_controls[enemy.id].skill, "remote control advances same model and consumes skill tap")
	game.simulation_enabled = false
	var paused_position := game.player.position
	game._physics_process(0.1)
	check(game.player.position == paused_position, "network clients can disable local authoritative simulation")
	game.simulation_enabled = true
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
	game.player.skin = 3
	game.player.cooldown = 0
	game.player.activate()
	game.check_collisions(game.player)
	check(game.player.alive and not game.player.shield and game._shield_feedback_remaining > 0, "actual body collision consumes shield and triggers bounded feedback")
	game.player.invulnerable = 0
	game.check_collisions(game.player)
	check(not game.player.alive and enemy.kills == 1, "head-body collision eliminates snake and credits killer")
	check(game.death_delay > 0, "player death begins defeat transition")
	game.player.alive = true
	enemy.alive = true
	game.player.invulnerable = 0
	enemy.invulnerable = 0
	enemy.shield = false
	game.player.position = Vector2.ZERO
	enemy.position = Vector2(10, 0)
	game.player.segments = PackedVector2Array([Vector2.ZERO, Vector2(-10, 0), Vector2(-20, 0)])
	enemy.segments = PackedVector2Array([Vector2(10, 0), Vector2(20, 0), Vector2(30, 0)])
	game.rebuild_body_grid()
	game.check_collisions(game.player)
	check(not game.player.alive and not enemy.alive, "unprotected head-to-head collision eliminates both consistently")
	game.player.alive = true
	enemy.alive = true
	game.player.invulnerable = 0
	enemy.invulnerable = 1
	game.rebuild_body_grid()
	game.check_collisions(game.player)
	check(not game.player.alive and enemy.alive, "protected head survives head-to-head without extending protection")
	var result: Dictionary = {}
	game.finished.connect(func(data: Dictionary): result.merge(data))
	game.end_game(false)
	check(result.has("score") and result.has("survived") and result.has("time") and not result.abandoned, "result signal supplies actual match statistics")
	game.free()
	print("GAMEPLAY TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

