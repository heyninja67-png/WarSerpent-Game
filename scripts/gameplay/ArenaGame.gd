extends Node2D
class_name ArenaGame

signal finished(result: Dictionary)

const BOUNDS := 1400.0
const SKIN_COLORS := [Color("48e8ff"), Color("ff8054"), Color("a9eeff"), Color("5dffbc"), Color("e988fa"), Color("ffd86a"), Color("ff5a9d"), Color("b5ff52")]
const SKIN_NAMES := ["VOLT SERPENT", "INFERNO VIPER", "FROST FANG", "CYBER REAPER", "SHADOW PHANTOM", "SOLAR WYRM", "NEON SAMURAI", "TOXIC FANG"]
const SKILL_NAMES := ["OVERDRIVE", "FLAME BURST", "FROZEN TRAIL", "CYBER SHIELD", "PHANTOM SHIFT", "SOLAR MAGNET", "SAMURAI DASH", "TOXIC CLOUD"]
const BOT_NAMES := ["NOVA-7", "AKIRA", "HEX", "KIRA.exe", "NEXUS", "SPECTRE", "BYTE", "ONYX", "ZERO"]
var snakes: Array[SnakeModel] = []
var brains: Array[ArenaBrain] = []
var player: SnakeModel
var foods: Array = []
var trails: Array = []
var sparks: Array = []
var body_grid := ArenaSpatialHash.new(65.0)
var food_grid := ArenaSpatialHash.new(100.0)
var textures: Dictionary = {}
var font: Font
var elapsed := 0.0
var clock := 0.0
var camera_position := Vector2.ZERO
var camera_zoom := 1.0
var paused := false
var ended := false
var death_delay := -1.0
# Networking can replace bot slots without changing model/physics rules.
var simulation_enabled := true
var local_player_control := true
var remote_controls: Dictionary = {}
var arena_label := "OFFLINE ARENA"
var skin_index := 0
var difficulty := 1
var quality := 1
var player_name := "PILOT"
var joystick_id := -1
var boost_id := -1
var skill_id := -1
var joystick_vector := Vector2.ZERO
var mouse_joystick := false
var mouse_boost := false
var boost_down := false
var shake := 0.0
var grid_timer := 0.0
var trail_timer := 0.0
var respawn_timer := 0.0
var audio_player: AudioStreamPlayer
var sfx_enabled := true
var previous_boost := false
var pickup_sound_delay := 0.0
var sound_streams: Dictionary = {}
var sfx_voices: Array[AudioStreamPlayer] = []
var food_multimesh: MultiMesh
var body_multimeshes: Array[MultiMesh] = []
var body_textures: Array[Texture2D] = []
var _body_counts := PackedInt32Array()
var _panel_styles: Dictionary = {}
var _ranking: Array[SnakeModel] = []
var _ranking_timer := 0.0
var _player_rank := 1
var _name_widths: Dictionary = {}
var _food_candidates: Array = []
var _collision_candidates: Array = []
var _world_offset := Vector2.ZERO
var _view_rect := Rect2()
const FOOD_COLORS := [Color("62eeff"), Color("e7a4ff"), Color("ffce7f"), Color("9cfcbd")]
const MAX_FOOD := 1500
const MAX_BODY_INSTANCES := 1500

func configure(selected_skin: int, bot_difficulty: int = 1) -> void:
	skin_index = clampi(selected_skin, 0, 7)
	difficulty = clampi(bot_difficulty, 0, 2)

func set_quality(value: String) -> void:
	# Mobile Auto starts conservatively. CPU core count is not a GPU benchmark.
	match value:
		"Low", "Baixo":
			quality = 0
		"High", "Alto":
			quality = 2
		"Auto":
			quality = 0 if OS.has_feature("mobile") or OS.get_processor_count() < 4 else 1
		_:
			quality = 1

func set_audio_enabled(value: bool) -> void:
	sfx_enabled = value

func set_player_name(value: String) -> void:
	player_name = value.left(16)
	if player != null:
		player.nickname = player_name

func toggle_pause() -> void:
	paused = not paused
	joystick_vector = Vector2.ZERO
	mouse_boost = false
	boost_id = -1

func _ready() -> void:
	font = ThemeDB.fallback_font
	for candidate in ["res://assets/fonts/Body.ttf", "res://assets/fonts/DejaVuSans.ttf"]:
		if ResourceLoader.exists(candidate):
			font = load(candidate)
			break
	for i in range(8):
		for part in ["head", "body", "tail"]:
			var path := "res://assets/snakes/%s_%d.png" % [part, i]
			if ResourceLoader.exists(path):
				textures["%s%d" % [part, i]] = load(path)
	for item in ["arenas/neon_city", "hud/joystick", "icons/energy", "effects/glow", "hud/boost", "hud/ability", "icons/ability_0", "icons/ability_1", "icons/ability_2", "icons/ability_3", "icons/ability_4", "icons/ability_5", "icons/ability_6", "icons/ability_7", "effects/energy"]:
		var path := "res://assets/%s.png" % item
		if ResourceLoader.exists(path):
			textures[item] = load(path)
	for effect in ["collect", "boost", "ability", "death"]:
		var path := "res://assets/audio/%s.wav" % effect
		if ResourceLoader.exists(path):
			sound_streams[effect] = load(path)
	for i in range(3):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -12.0
		add_child(voice)
		sfx_voices.append(voice)
	audio_player = sfx_voices[0]
	initialize_multimeshes()
	player = SnakeModel.new()
	player.initialize(Vector2.ZERO, -PI / 2.0, skin_index, 0, player_name)
	snakes.append(player)
	var bot_count: int = [5, 7, 9][quality]
	for i in range(bot_count):
		spawn_bot(i + 1)
	for i in range([420, 650, 1000][quality]):
		foods.append({"p": random_point(), "v": randi_range(2, 5), "kind": randi_range(0, 3), "active": true, "respawn": 0.0})
	rebuild_food_grid()
	rebuild_body_grid()
	invalidate_food_visuals()
	update_ranking()
	set_process_input(true)

func _exit_tree() -> void:
	for voice in sfx_voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null

func initialize_multimeshes() -> void:
	var food_quad := QuadMesh.new()
	food_quad.size = Vector2.ONE * 16.0
	food_multimesh = MultiMesh.new()
	food_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	food_multimesh.use_colors = true
	food_multimesh.mesh = food_quad
	food_multimesh.instance_count = MAX_FOOD
	food_multimesh.visible_instance_count = 0
	var body_quad := QuadMesh.new()
	body_quad.size = Vector2(29, 29)
	_body_counts.resize(8)
	for skin in range(8):
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.use_colors = true
		multimesh.mesh = body_quad
		multimesh.instance_count = MAX_BODY_INSTANCES
		multimesh.visible_instance_count = 0
		body_multimeshes.append(multimesh)
		body_textures.append(textures.get("body%d" % skin))

## Network snapshots call this after replacing food dictionaries.
func invalidate_food_visuals() -> void:
	if food_multimesh == null:
		return
	food_multimesh.visible_instance_count = mini(foods.size(), MAX_FOOD)
	for index in range(mini(foods.size(), MAX_FOOD)):
		sync_food_visual(index)

func sync_food_visual(index: int) -> void:
	if food_multimesh == null or index >= MAX_FOOD:
		return
	var food: Dictionary = foods[index]
	var scale_factor := (13.0 + float(food.v) * 1.2) / 16.0 if food.active else 0.0
	food_multimesh.set_instance_transform_2d(index, Transform2D(0.0, Vector2.ONE * scale_factor, 0.0, food.p))
	food_multimesh.set_instance_color(index, FOOD_COLORS[int(food.kind) % FOOD_COLORS.size()])

func update_ranking() -> void:
	_ranking.assign(snakes)
	_ranking.sort_custom(func(a: SnakeModel, b: SnakeModel) -> bool: return a.score > b.score)
	_player_rank = _ranking.find(player) + 1

func random_point(margin: float = 55.0) -> Vector2:
	return Vector2(randf_range(-BOUNDS + margin, BOUNDS - margin), randf_range(-BOUNDS + margin, BOUNDS - margin))

func spawn_bot(id: int) -> void:
	var snake := SnakeModel.new()
	var angle := float(id) * TAU / 9.0
	var position := Vector2.from_angle(angle) * randf_range(650.0, 1100.0)
	snake.initialize(position, angle + PI / 2.0, (id - 1) % 8, id, BOT_NAMES[(id - 1) % BOT_NAMES.size()])
	snake.mass = randf_range(24.0, 120.0)
	snake.rebuild_body()
	snakes.append(snake)
	var brain := ArenaBrain.new()
	brain.difficulty = difficulty
	brain.target_angle = snake.heading
	brains.append(brain)

func _process(delta: float) -> void:
	clock += delta
	_ranking_timer -= delta
	if _ranking_timer <= 0.0:
		_ranking_timer = 0.3
		update_ranking()
	if not paused and player != null:
		camera_position = camera_position.lerp(player.position, 1.0 - exp(-delta * 5.0))
		var desired_zoom := clampf(1.02 - player.mass / 4500.0, 0.63, 0.98)
		if player.boosting:
			desired_zoom -= 0.08
		camera_zoom = lerpf(camera_zoom, desired_zoom, 1.0 - exp(-delta * 2.0))
		shake = maxf(0.0, shake - delta * 18.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if paused or ended or player == null or not simulation_enabled:
		return
	if death_delay >= 0.0:
		death_delay -= delta
		update_sparks(delta)
		if death_delay <= 0.0:
			end_game(false)
		return
	elapsed += delta
	pickup_sound_delay = maxf(0.0, pickup_sound_delay - delta)
	var direction := joystick_vector
	var keyboard := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if keyboard.length_squared() > 0.0:
		direction = keyboard.normalized()
	var target := direction.angle() if direction.length() > 0.12 else player.heading
	boost_down = boost_id >= 0 or mouse_boost or Input.is_physical_key_pressed(KEY_SPACE)
	if not local_player_control:
		var controls: Dictionary = remote_controls.get(player.id, {})
		target = float(controls.get("angle", player.heading))
		boost_down = bool(controls.get("boost", false))
		if bool(controls.get("skill", false)):
			player.activate()
			controls["skill"] = false
	player.advance(delta, target, boost_down)
	if player.boosting and not previous_boost:
		play_effect("boost")
	previous_boost = player.boosting
	for i in range(1, snakes.size()):
		var snake := snakes[i]
		if not snake.alive:
			snake.respawn_time -= delta
			if snake.respawn_time <= 0.0:
				respawn_bot(snake)
			continue
		if remote_controls.has(snake.id):
			var controls: Dictionary = remote_controls[snake.id]
			if bool(controls.get("skill", false)):
				snake.activate()
				controls["skill"] = false
			snake.advance(delta, float(controls.get("angle", snake.heading)), bool(controls.get("boost", false)))
		else:
			var brain := brains[i - 1]
			brain.decide(snake, foods, snakes, BOUNDS, delta, food_grid, body_grid)
			if brain.wants_skill:
				snake.activate()
			snake.advance(delta, brain.target_angle, brain.wants_boost)
	apply_abilities(delta)
	rebuild_body_grid()
	for snake in snakes:
		if not snake.alive:
			continue
		collect_food(snake)
		if maxf(absf(snake.position.x), absf(snake.position.y)) > BOUNDS - 14.0:
			# Arena edge always kills, including protected snakes; it is visibly marked.
			kill_snake(snake, null)
			continue
		check_collisions(snake)
		if snake.boosting:
			snake.boost_drop_time -= delta
			if snake.boost_drop_time <= 0.0:
				snake.boost_drop_time = 0.22
				drop_energy(snake.segments[-1], 2)
	grid_timer -= delta
	if grid_timer <= 0.0:
		grid_timer = 0.3
		for index in range(foods.size()):
			var food: Dictionary = foods[index]
			if not food.active and food.respawn <= elapsed:
				food.p = random_point()
				food.active = true
				sync_food_visual(index)
		rebuild_food_grid()
	update_sparks(delta)

func respawn_bot(snake: SnakeModel) -> void:
	var spawn := random_point(160.0)
	if spawn.distance_to(player.position) < 500.0:
		spawn = -player.position.normalized() * 1100.0
		if spawn.length() < 500.0:
			spawn = Vector2(900, 900)
	snake.initialize(spawn, randf() * TAU, snake.skin, snake.id, snake.nickname)
	snake.alive = true
	snake.mass = randf_range(24.0, 120.0)
	snake.rebuild_body()
	snake.invulnerable = 2.0
	snake.cooldown = 0.0
	snake.active_time = 0.0
	snake.shield = false
	snake.slow_time = 0.0
	snake.slow_factor = 1.0

func rebuild_food_grid() -> void:
	food_grid.clear()
	for i in range(foods.size()):
		if foods[i].active:
			food_grid.insert(foods[i].p, i)

func rebuild_body_grid() -> void:
	body_grid.clear()
	for snake_index in range(snakes.size()):
		var snake := snakes[snake_index]
		if snake.alive:
			for index in range(0, snake.segments.size(), 2):
				# A native integer replaces a newly allocated Dictionary per segment.
				body_grid.insert(snake.segments[index], (snake_index << 8) | index)

func collect_food(snake: SnakeModel) -> void:
	var radius := snake.collection_radius()
	food_grid.query_into(snake.position, radius, _food_candidates)
	for index: int in _food_candidates:
		var food: Dictionary = foods[index]
		if food.active and snake.position.distance_squared_to(food.p) < radius * radius:
			snake.collect(int(food.v))
			food.active = false
			food.respawn = elapsed + randf_range(1.0, 3.0)
			sync_food_visual(index)
			if snake.id == player.id and pickup_sound_delay <= 0.0:
				pickup_sound_delay = 0.12
				play_effect("collect")
			if snake.id == player.id and quality > 0:
				add_spark(food.p, SKIN_COLORS[snake.skin], 2)

func check_collisions(snake: SnakeModel) -> void:
	if not snake.alive or snake.invulnerable > 0.0:
		return
	body_grid.query_into(snake.position, 24.0, _collision_candidates)
	for encoded: int in _collision_candidates:
		var other_index := encoded >> 8
		var segment_index := encoded & 255
		if other_index >= snakes.size():
			continue
		var other := snakes[other_index]
		if not other.alive or other.id == snake.id or segment_index >= other.segments.size():
			continue
		if snake.position.distance_squared_to(other.segments[segment_index]) > 18.0 * 18.0:
			continue
		if segment_index <= 2 and snake.position.distance_squared_to(other.position) < 22.0 * 22.0:
			var first_lethal := snake.lethal_collision()
			var second_lethal := other.lethal_collision()
			if first_lethal:
				kill_snake(snake, other)
			if second_lethal:
				kill_snake(other, snake)
			return
		if snake.lethal_collision():
			kill_snake(snake, other)
		return

func apply_abilities(delta: float) -> void:
	trail_timer -= delta
	var make_trail := trail_timer <= 0.0
	if make_trail:
		trail_timer = 0.16
	for snake in snakes:
		if not snake.alive or snake.active_time <= 0.0:
			continue
		if snake.skin == 1:
			for other in snakes:
				if other.id != snake.id and other.alive and other.position.distance_to(snake.position) < 160.0:
					other.slow(0.45, 0.65)
		elif snake.skin == 7:
			for other in snakes:
				if other.id != snake.id and other.alive and other.position.distance_squared_to(snake.position) < 185.0 * 185.0:
					other.slow(0.60, 0.7)
		elif snake.skin == 2 and make_trail:
			trails.append({"p": snake.segments[mini(6, snake.segments.size() - 1)], "owner": snake.id, "life": 3.0})
	for i in range(trails.size() - 1, -1, -1):
		var trail: Dictionary = trails[i]
		trail.life -= delta
		if trail.life <= 0.0:
			trails.remove_at(i)
			continue
		for snake in snakes:
			if snake.alive and snake.id != trail.owner and snake.position.distance_squared_to(trail.p) < 43.0 * 43.0:
				snake.slow(0.52, 0.8)

func use_skill() -> void:
	if paused or ended or player == null:
		return
	if player.activate():
		add_spark(player.position, SKIN_COLORS[player.skin], 28)
		play_effect("ability")

func play_effect(effect: String) -> void:
	if not sfx_enabled or not sound_streams.has(effect):
		return
	var selected: AudioStreamPlayer = null
	for voice in sfx_voices:
		if not voice.playing:
			selected = voice
			break
	if selected == null:
		if effect == "collect":
			return # Never steal an ability/death voice for a pellet.
		selected = sfx_voices[0]
	selected.stream = sound_streams[effect]
	selected.play()

func drop_energy(at: Vector2, value: int) -> void:
	for index in range(foods.size()):
		var food: Dictionary = foods[index]
		if not food.active:
			food.p = at
			food.v = value
			food.active = true
			sync_food_visual(index)
			return
	if foods.size() < MAX_FOOD:
		foods.append({"p": at, "v": value, "kind": 1, "active": true, "respawn": 0.0})
		food_multimesh.visible_instance_count = foods.size()
		sync_food_visual(foods.size() - 1)

func kill_snake(snake: SnakeModel, killer: SnakeModel) -> void:
	if not snake.alive:
		return
	snake.alive = false
	snake.respawn_time = 4.0
	if killer != null and killer.id != snake.id:
		killer.kills += 1
		killer.score += 35
	for i in range(0, snake.segments.size(), 2):
		drop_energy(snake.segments[i] + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 8)
	add_spark(snake.position, SKIN_COLORS[snake.skin], 36)
	rebuild_food_grid()
	if snake.id == player.id:
		shake = 12.0
		death_delay = 1.1
		play_effect("death")

func add_spark(at: Vector2, color: Color, count: int) -> void:
	if quality == 0:
		count = mini(count, 7)
	for i in range(count):
		if sparks.size() >= 240:
			break
		sparks.append({"p": at, "v": Vector2.from_angle(randf() * TAU) * randf_range(35, 180), "life": randf_range(0.25, 0.7), "c": color})

func update_sparks(delta: float) -> void:
	for i in range(sparks.size() - 1, -1, -1):
		var spark: Dictionary = sparks[i]
		spark.life -= delta
		spark.p += spark.v * delta
		if spark.life <= 0.0:
			sparks.remove_at(i)

func end_game(abandoned: bool) -> void:
	if ended:
		return
	ended = true
	finished.emit({"score": player.score, "kills": player.kills, "survived": elapsed, "time": elapsed, "energy": player.collected, "abandoned": abandoned})

func _input(event: InputEvent) -> void:
	# Android sends touch plus an emulated mouse event for UI compatibility.
	# Gameplay already processes the touch; applying both toggles pause twice.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if ended:
		return
	var size := get_viewport_rect().size
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			paused = not paused
		elif event.keycode == KEY_E:
			use_skill()
	if event is InputEventScreenTouch:
		var point: Vector2 = event.position
		if event.pressed:
			if handle_interface_click(point, size):
				return
			if paused:
				return
			if point.x < size.x * 0.46 and point.y > size.y * 0.4 and joystick_id < 0:
				joystick_id = event.index
				joystick_vector = (point - joystick_center(size)).limit_length(70.0) / 70.0
			elif point.distance_to(boost_center(size)) < 68.0:
				boost_id = event.index
			elif point.distance_to(skill_center(size)) < 60.0:
				skill_id = event.index
				use_skill()
		else:
			if event.index == joystick_id:
				joystick_id = -1
				joystick_vector = Vector2.ZERO
			if event.index == boost_id:
				boost_id = -1
			if event.index == skill_id:
				skill_id = -1
	elif event is InputEventScreenDrag and event.index == joystick_id:
		joystick_vector = (event.position - joystick_center(size)).limit_length(70.0) / 70.0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if handle_interface_click(event.position, size):
				return
			if paused:
				return
			if event.position.distance_to(boost_center(size)) < 70.0:
				mouse_boost = true
			elif event.position.distance_to(skill_center(size)) < 60.0:
				use_skill()
			elif event.position.x < size.x * 0.46 and event.position.y > size.y * 0.4:
				mouse_joystick = true
				joystick_vector = (event.position - joystick_center(size)).limit_length(70.0) / 70.0
		else:
			mouse_joystick = false
			mouse_boost = false
			if joystick_id < 0:
				joystick_vector = Vector2.ZERO
	elif event is InputEventMouseMotion and mouse_joystick:
		joystick_vector = (event.position - joystick_center(size)).limit_length(70.0) / 70.0

func handle_interface_click(point: Vector2, size: Vector2) -> bool:
	if Rect2(size.x - 69, 19, 48, 44).has_point(point):
		paused = not paused
		joystick_vector = Vector2.ZERO
		mouse_boost = false
		boost_id = -1
		return true
	if paused:
		if Rect2(size.x / 2 - 160, size.y / 2 + 2, 320, 56).has_point(point):
			paused = false
		elif Rect2(size.x / 2 - 160, size.y / 2 + 76, 320, 56).has_point(point):
			end_game(true)
		return true
	return false

func joystick_center(size: Vector2) -> Vector2:
	return Vector2(112, size.y - 120)

func boost_center(size: Vector2) -> Vector2:
	return Vector2(size.x - 112, size.y - 116)

func skill_center(size: Vector2) -> Vector2:
	return Vector2(size.x - 246, size.y - 147)

func visible(at: Vector2, margin: float = 80.0) -> bool:
	return _view_rect.grow(margin).has_point(at)

func _draw() -> void:
	if player == null:
		return
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("050b18"))
	_world_offset = size / 2.0 - camera_position * camera_zoom
	if shake > 0.0:
		_world_offset += Vector2(sin(clock * 94), cos(clock * 71)) * shake
	_view_rect = Rect2(camera_position - size / camera_zoom / 2.0, size / camera_zoom)
	draw_set_transform(_world_offset, 0.0, Vector2.ONE * camera_zoom)
	draw_arena()
	for trail: Dictionary in trails:
		if visible(trail.p):
			draw_circle(trail.p, 42.0, Color(0.4, 0.9, 1.0, 0.1 * minf(trail.life, 1.0)))
			draw_arc(trail.p, 32, 0, TAU, 16, Color(0.5, 0.9, 1, 0.32 * minf(trail.life, 1.0)), 1.5)
	# One GPU instanced draw for the entire pellet pool, without per-frame food loops.
	if food_multimesh != null and textures.has("icons/energy"):
		draw_multimesh(food_multimesh, textures.get("effects/energy", textures["icons/energy"]))
	draw_body_batches()
	for snake in snakes:
		if snake.alive:
			draw_snake(snake)
	for spark: Dictionary in sparks:
		if visible(spark.p):
			draw_line(spark.p, spark.p - spark.v.normalized() * 6.0, Color(spark.c, minf(spark.life * 2.0, 1.0)), 2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_hud(size)

func snake_tint(snake: SnakeModel) -> Color:
	if snake.skin == 4 and snake.active_time > 0.0:
		return Color(1, 1, 1, 0.38)
	return Color(1, 1, 1, 0.62 + 0.18 * sin(clock * 14)) if snake.invulnerable > 0.0 else Color.WHITE

func draw_body_batches() -> void:
	_body_counts.fill(0)
	for snake in snakes:
		if not snake.alive:
			continue
		var multimesh := body_multimeshes[snake.skin]
		var tint := snake_tint(snake)
		for index in range(1, snake.segments.size() - 1):
			var at := snake.segments[index]
			if not visible(at, 30):
				continue
			var instance := _body_counts[snake.skin]
			if instance >= MAX_BODY_INSTANCES:
				break
			var angle := (snake.segments[index - 1] - at).angle()
			multimesh.set_instance_transform_2d(instance, Transform2D(angle, at))
			multimesh.set_instance_color(instance, tint)
			_body_counts[snake.skin] += 1
	for skin in range(8):
		body_multimeshes[skin].visible_instance_count = _body_counts[skin]
		if _body_counts[skin] > 0 and body_textures[skin] != null:
			draw_multimesh(body_multimeshes[skin], body_textures[skin])

func draw_arena() -> void:
	var left := maxf(-BOUNDS, camera_position.x - get_viewport_rect().size.x / camera_zoom / 2 - 100)
	var right := minf(BOUNDS, camera_position.x + get_viewport_rect().size.x / camera_zoom / 2 + 100)
	var top := maxf(-BOUNDS, camera_position.y - get_viewport_rect().size.y / camera_zoom / 2 - 100)
	var bottom := minf(BOUNDS, camera_position.y + get_viewport_rect().size.y / camera_zoom / 2 + 100)
	if textures.has("arenas/neon_city"):
		draw_texture_rect(textures["arenas/neon_city"], Rect2(-BOUNDS, -BOUNDS, BOUNDS * 2, BOUNDS * 2), true, Color(0.6, 0.65, 0.8, 0.45))
	else:
		draw_rect(Rect2(-BOUNDS, -BOUNDS, BOUNDS * 2, BOUNDS * 2), Color("081323"))
	for x in range(floori(left / 180.0), ceili(right / 180.0)) if quality == 2 else []:
		draw_line(Vector2(x * 180, top), Vector2(x * 180, bottom), Color(0.1, 0.55, 0.8, 0.085), 1)
	for y in range(floori(top / 180.0), ceili(bottom / 180.0)) if quality == 2 else []:
		draw_line(Vector2(left, y * 180), Vector2(right, y * 180), Color(0.1, 0.55, 0.8, 0.085), 1)
	# Distinct, bright arena boundary and repeating hazard markers.
	draw_rect(Rect2(-BOUNDS, -BOUNDS, BOUNDS * 2, BOUNDS * 2), Color("e75b9e"), false, 8)
	draw_rect(Rect2(-BOUNDS + 12, -BOUNDS + 12, BOUNDS * 2 - 24, BOUNDS * 2 - 24), Color(0.85, 0.25, 0.6, 0.24), false, 2)
	for i in range(-13, 14):
		for point in [Vector2(i * 100, -BOUNDS + 22), Vector2(i * 100, BOUNDS - 22), Vector2(-BOUNDS + 22, i * 100), Vector2(BOUNDS - 22, i * 100)]:
			if visible(point):
				draw_circle(point, 4, Color("ff5c9a"))

func draw_sprite(key: String, at: Vector2, angle: float, dimensions: Vector2, tint: Color = Color.WHITE) -> bool:
	if not textures.has(key):
		return false
	draw_set_transform(_world_offset + at * camera_zoom, angle, Vector2.ONE * camera_zoom)
	draw_texture_rect(textures[key], Rect2(-dimensions / 2, dimensions), false, tint)
	draw_set_transform(_world_offset, 0.0, Vector2.ONE * camera_zoom)
	return true

func draw_snake(snake: SnakeModel) -> void:
	var color: Color = SKIN_COLORS[snake.skin]
	var tint := snake_tint(snake)
	var points := snake.segments
	if points.size() > 1 and visible(points[-1], 35):
		draw_sprite("tail%d" % snake.skin, points[-1], (points[-2] - points[-1]).angle(), Vector2(35, 25), tint)
	if not visible(snake.position):
		return
	draw_sprite("head%d" % snake.skin, snake.position, snake.heading, Vector2(42, 37), tint)
	if quality == 2 and (snake.boosting or snake.active_time > 0.0):
		draw_circle(snake.position, 40, Color(color, 0.055))
		draw_arc(snake.position, 35, clock * 1.5, clock * 1.5 + PI * 1.4, 24, Color(color, 0.25), 2)
	if snake.shield or snake.invulnerable > 0.0:
		draw_arc(snake.position, 27, clock, clock + TAU * 0.85, 28, Color(color, 0.7), 2.5)
	if snake.active_time > 0.0:
		if snake.skin in [1, 7]:
			var radius := 100.0 + fmod(clock * 110, 65.0)
			draw_arc(snake.position, radius, 0, TAU, 32, Color(color, 0.26), 4)
		elif snake.skin == 5:
			draw_arc(snake.position, 150, clock, clock + TAU * 0.8, 36, Color(color, 0.4), 2)
	if not _name_widths.has(snake.nickname):
		_name_widths[snake.nickname] = font.get_string_size(snake.nickname, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, snake.position + Vector2(-float(_name_widths[snake.nickname]) / 2, -35), snake.nickname, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(color, 0.9))

func panel(rect: Rect2, color: Color = Color("101c31"), border: Color = Color("2b4260")) -> void:
	var key := Vector2i(color.to_rgba32(), border.to_rgba32())
	if not _panel_styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = Color(color, 0.91)
		style.border_color = border
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		_panel_styles[key] = style
	draw_style_box(_panel_styles[key], rect)

func text(at: Vector2, content: String, size: int = 18, color: Color = Color.WHITE) -> void:
	draw_string(font, at, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(at: Vector2, content: String, size: int, color: Color) -> void:
	var width := font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(at - Vector2(width / 2, 0), content, size, color)

func draw_hud(size: Vector2) -> void:
	var accent: Color = SKIN_COLORS[player.skin]
	panel(Rect2(22, 20, 256, 88))
	text(Vector2(40, 44), "NEON CITY   /   " + player.nickname, 13, Color("9bb3d1"))
	text(Vector2(40, 82), "%05d" % player.score, 30, accent)
	text(Vector2(151, 79), "POINTS", 12, Color("8dacc8"))
	panel(Rect2(22, 118, 256, 43))
	text(Vector2(37, 145), "LENGTH %d   /   KILLS %d" % [player.segment_count(), player.kills], 14, Color("b7cee4"))
	panel(Rect2(size.x - 256, 78, 234, 224))
	text(Vector2(size.x - 237, 105), "TOP SERPENTS", 16, Color("80e7ff"))
	var ranking := _ranking
	var rank := _player_rank
	for i in range(mini(5, ranking.size())):
		var snake := ranking[i]
		var color := accent if snake.id == 0 else Color("a4bbd1")
		text(Vector2(size.x - 237, 136 + i * 27), "%d  %s" % [i + 1, snake.nickname.left(10)], 13, color)
		text(Vector2(size.x - 77, 136 + i * 27), str(snake.score), 13, color)
	text(Vector2(size.x - 237, 283), "YOUR RANK  #%d / %d" % [rank, snakes.size()], 12, accent)
	panel(Rect2(size.x - 69, 19, 48, 44))
	centered(Vector2(size.x - 45, 48), "Ⅱ", 22, Color("bbe3f5"))
	centered(Vector2(size.x / 2, 33), "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60], 17, Color("b3ccdf"))
	centered(Vector2(size.x / 2, 54), arena_label, 11, Color("637f9a"))
	var joy := joystick_center(size)
	draw_circle(joy, 77, Color(0.03, 0.09, 0.17, 0.67))
	draw_arc(joy, 72, 0, TAU, 48, Color(0.3, 0.7, 0.9, 0.35), 2)
	draw_arc(joy, 58, 0, TAU, 48, Color(0.4, 0.8, 1.0, 0.09), 10)
	var knob := joy + joystick_vector * 47
	if textures.has("hud/joystick"):
		draw_texture_rect(textures["hud/joystick"], Rect2(joy - Vector2.ONE * 74, Vector2.ONE * 148), false, Color(1, 1, 1, 0.45))
	draw_circle(knob, 29, Color("19354b"))
	draw_arc(knob, 28, 0, TAU, 32, Color(0.38, 0.85, 1.0, 0.7), 2)
	draw_circle(knob, 8, Color(0.4, 0.86, 1.0, 0.28))
	centered(joy + Vector2(0, 103), "MOVE", 12, Color("688ca7"))
	var boost := boost_center(size)
	draw_circle(boost, 62, Color("10263a"))
	draw_arc(boost, 60, 0, TAU, 48, Color(accent, 0.95 if boost_down else 0.4), 3)
	if textures.has("hud/boost"):
		draw_texture_rect(textures["hud/boost"], Rect2(boost - Vector2(31, 45), Vector2(62, 62)), false, accent)
	else:
		centered(boost + Vector2(0, -5), "»", 47, accent)
	centered(boost + Vector2(0, 23), "BOOST", 13, Color.WHITE)
	centered(boost + Vector2(0, 84), "HOLD", 10, Color("7c9cb7"))
	var skill := skill_center(size)
	draw_circle(skill, 46, Color("172139"))
	var ready := player.cooldown <= 0.0
	draw_arc(skill, 44, -PI / 2, -PI / 2 + TAU * clampf(1.0 - player.cooldown / SnakeModel.COOLDOWNS[player.skin], 0.001, 1.0), 48, accent, 3)
	if ready and textures.has("icons/ability_%d" % player.skin):
		draw_texture_rect(textures["icons/ability_%d" % player.skin], Rect2(skill - Vector2.ONE * 28, Vector2.ONE * 56), false)
	else:
		centered(skill + Vector2(0, 8), str(ceili(player.cooldown)), 27, Color("8599b0"))
	centered(skill + Vector2(0, 67), SKILL_NAMES[player.skin], 10, Color("c1d5e6"))
	if player.active_time > 0.0:
		panel(Rect2(size.x / 2 - 140, size.y - 86, 280, 38), Color("152d3c"), accent)
		centered(Vector2(size.x / 2, size.y - 61), SKILL_NAMES[player.skin] + " ACTIVE", 14, accent)
	elif player.slow_time > 0.0:
		centered(Vector2(size.x / 2, size.y - 67), "SLOWED", 14, Color("9fdfff"))
	if elapsed < 7.0:
		centered(Vector2(size.x / 2, size.y - 31), "COLLECT ENERGY  ·  AVOID OTHER SNAKES AND THE EDGE  ·  E: ABILITY", 12, Color("88a9c4"))
	if death_delay >= 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.01, 0.1, 0.35))
		centered(size / 2, "ELIMINATED", 36, Color("ff8fb9"))
	if paused:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.06, 0.85))
		panel(Rect2(size.x / 2 - 210, size.y / 2 - 130, 420, 300), Color("0e1b30"), Color("4f8cae"))
		centered(Vector2(size.x / 2, size.y / 2 - 69), "PAUSED", 32, Color.WHITE)
		centered(Vector2(size.x / 2, size.y / 2 - 37), "Your arena is waiting.", 15, Color("94b0cb"))
		panel(Rect2(size.x / 2 - 160, size.y / 2 + 2, 320, 56), Color("123c4d"), accent)
		centered(Vector2(size.x / 2, size.y / 2 + 37), "RESUME", 18, accent)
		panel(Rect2(size.x / 2 - 160, size.y / 2 + 76, 320, 56))
		centered(Vector2(size.x / 2, size.y / 2 + 111), "BACK TO MENU", 17, Color("aec3d9"))
