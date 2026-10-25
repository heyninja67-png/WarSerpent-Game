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
var _steering_active := false
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
var _pickup_remaining := 0.0
var _pickup_total := 0
var _shield_feedback_remaining := 0.0
const MINIMAP_CENTER := Vector2(100, 98)
const MINIMAP_RADIUS := 72.0
const MINIMAP_REFRESH := 0.15
var _minimap_remaining := MINIMAP_REFRESH
var _minimap_refresh_count := 0
var _minimap_markers: Array = []
var _minimap_player := MINIMAP_CENTER
var _minimap_view_rect := Rect2()
const JOYSTICK_RADIUS := 70.0
const JOYSTICK_ENTER := 0.18
const JOYSTICK_EXIT := 0.12
const BODY_SHADES := [Color(1, 1, 1), Color(0.97, 0.97, 0.97), Color(0.92, 0.92, 0.92), Color(0.97, 0.97, 0.97)]
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

func reset_controls() -> void:
	joystick_id = -1
	boost_id = -1
	skill_id = -1
	mouse_joystick = false
	mouse_boost = false
	boost_down = false
	joystick_vector = Vector2.ZERO
	_steering_active = false

func toggle_pause() -> void:
	paused = not paused
	reset_controls()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_controls()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		reset_controls()
		if player != null and player.alive and not ended:
			paused = true

func update_joystick(point: Vector2, size: Vector2) -> void:
	var raw := (point - joystick_center(size)) / JOYSTICK_RADIUS
	var magnitude := minf(raw.length(), 1.0)
	if _steering_active:
		if magnitude <= JOYSTICK_EXIT:
			_steering_active = false
	elif magnitude >= JOYSTICK_ENTER:
		_steering_active = true
	if not _steering_active:
		joystick_vector = Vector2.ZERO
		return
	# Remap the active radius smoothly to 0..1. No separate offline-only deadzone.
	joystick_vector = raw.normalized() * clampf((magnitude - JOYSTICK_EXIT) / (1.0 - JOYSTICK_EXIT), 0.0, 1.0)

func register_pickup_feedback(value: int) -> void:
	if value <= 0:
		return
	_pickup_total += value
	_pickup_remaining = 0.65

func minimap_world_to_screen(world: Vector2) -> Vector2:
	var scale_factor := (MINIMAP_RADIUS - 6.0) / (BOUNDS * sqrt(2.0))
	return MINIMAP_CENTER + (world * scale_factor).limit_length(MINIMAP_RADIUS - 5.0)

func update_minimap() -> void:
	_minimap_markers.clear()
	for snake in snakes:
		if not snake.alive:
			continue
		var position_on_map := minimap_world_to_screen(snake.position)
		var is_player := player != null and snake.id == player.id
		_minimap_markers.append({"id": snake.id, "position": position_on_map, "player": is_player, "color": SKIN_COLORS[snake.skin]})
		if is_player:
			_minimap_player = position_on_map
	var half_view := get_viewport_rect().size / maxf(camera_zoom, 0.01) / 2.0
	var top_left := minimap_world_to_screen(camera_position - half_view)
	var bottom_right := minimap_world_to_screen(camera_position + half_view)
	_minimap_view_rect = Rect2(top_left, bottom_right - top_left)
	_minimap_refresh_count += 1

func minimap_state() -> Dictionary:
	return {"center": MINIMAP_CENTER, "radius": MINIMAP_RADIUS,
		"bounds": Rect2(MINIMAP_CENTER - Vector2.ONE * MINIMAP_RADIUS, Vector2.ONE * MINIMAP_RADIUS * 2),
		"markers": _minimap_markers, "player": _minimap_player,
		"view_rect": _minimap_view_rect, "refresh_count": _minimap_refresh_count, "refresh_interval": MINIMAP_REFRESH}

func boundary_danger() -> float:
	if player == null or not player.alive:
		return 0.0
	var clearance := BOUNDS - 14.0 - maxf(absf(player.position.x), absf(player.position.y))
	return clampf(1.0 - clearance / 220.0, 0.0, 1.0)

func hud_state() -> Dictionary:
	return {"protection_remaining": player.invulnerable if player != null else 0.0,
		"danger": boundary_danger(), "skill_remaining": player.active_time if player != null else 0.0,
		"pickup_total": _pickup_total, "pickup_remaining": _pickup_remaining}

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
	update_minimap()
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
	body_quad.size = Vector2(31, 31)
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
	_minimap_remaining -= delta
	if _minimap_remaining <= 0.0:
		_minimap_remaining = MINIMAP_REFRESH
		update_minimap()
	_ranking_timer -= delta
	if _ranking_timer <= 0.0:
		_ranking_timer = 0.3
		update_ranking()
	if not paused and player != null:
		_pickup_remaining = maxf(0.0, _pickup_remaining - delta)
		_shield_feedback_remaining = maxf(0.0, _shield_feedback_remaining - delta)
		if _pickup_remaining <= 0.0:
			_pickup_total = 0
		camera_position = camera_position.lerp(player.position, 1.0 - exp(-delta * 5.0))
		var desired_zoom := clampf(1.10 - player.mass / 6000.0, 0.66, 1.05)
		desired_zoom += _pickup_remaining * (0.003 if quality == 0 else 0.008)
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
	var target := direction.angle() if direction.length_squared() > 0.000001 else player.heading
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
			if snake.id == player.id:
				register_pickup_feedback(int(food.v))
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
			var had_shield := snake.shield
			var first_lethal := snake.lethal_collision()
			if had_shield and not snake.shield:
				shield_absorbed(snake)
			var second_lethal := other.lethal_collision()
			if first_lethal:
				kill_snake(snake, other)
			if second_lethal:
				kill_snake(other, snake)
			return
		var had_shield := snake.shield
		if snake.lethal_collision():
			kill_snake(snake, other)
		elif had_shield and not snake.shield:
			shield_absorbed(snake)
		return

func shield_absorbed(snake: SnakeModel) -> void:
	if snake.id == player.id:
		_shield_feedback_remaining = 0.45
		add_spark(snake.position, SKIN_COLORS[snake.skin], 5 if quality == 0 else 12)

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
			toggle_pause()
		elif event.keycode == KEY_E:
			use_skill()
	if event is InputEventScreenTouch:
		var point: Vector2 = event.position
		if event.pressed:
			if handle_interface_click(point, size):
				return
			if paused:
				return
			if point.x < size.x * 0.46 and point.y > size.y * 0.4 and joystick_id < 0 and point.distance_to(skill_center(size)) > 60.0:
				joystick_id = event.index
				update_joystick(point, size)
			elif boost_hit(point, size):
				boost_id = event.index
			elif point.distance_to(skill_center(size)) < 60.0:
				skill_id = event.index
				use_skill()
		else:
			if event.index == joystick_id:
				joystick_id = -1
				joystick_vector = Vector2.ZERO
				_steering_active = false
			if event.index == boost_id:
				boost_id = -1
			if event.index == skill_id:
				skill_id = -1
	elif event is InputEventScreenDrag and event.index == joystick_id:
		update_joystick(event.position, size)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if handle_interface_click(event.position, size):
				return
			if paused:
				return
			if boost_hit(event.position, size):
				mouse_boost = true
			elif event.position.distance_to(skill_center(size)) < 60.0:
				use_skill()
			elif event.position.x < size.x * 0.46 and event.position.y > size.y * 0.4:
				mouse_joystick = true
				update_joystick(event.position, size)
		else:
			mouse_joystick = false
			mouse_boost = false
			if joystick_id < 0:
				joystick_vector = Vector2.ZERO
				_steering_active = false
	elif event is InputEventMouseMotion and mouse_joystick:
		update_joystick(event.position, size)

func handle_interface_click(point: Vector2, size: Vector2) -> bool:
	if Rect2(size.x - 69, 19, 48, 44).has_point(point):
		toggle_pause()
		return true
	if paused:
		if Rect2(size.x / 2 - 160, size.y / 2 + 2, 320, 56).has_point(point):
			toggle_pause()
		elif Rect2(size.x / 2 - 160, size.y / 2 + 76, 320, 56).has_point(point):
			end_game(true)
		return true
	return false

func joystick_center(size: Vector2) -> Vector2:
	return Vector2(112, size.y - 120)

func boost_center(size: Vector2) -> Vector2:
	return Vector2(size.x - 112, size.y - 116)

func skill_center(size: Vector2) -> Vector2:
	return Vector2(size.x / 2.0 - 52, size.y - 106)

func boost_secondary_center(size: Vector2) -> Vector2:
	return Vector2(size.x / 2.0 + 52, size.y - 106)

func boost_hit(point: Vector2, size: Vector2) -> bool:
	return point.distance_to(boost_center(size)) < 68.0 or point.distance_to(boost_secondary_center(size)) < 45.0

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
			var shade: Color = BODY_SHADES[index & 3]
			shade.a = tint.a
			multimesh.set_instance_color(instance, shade)
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
		draw_texture_rect(textures["arenas/neon_city"], Rect2(-BOUNDS, -BOUNDS, BOUNDS * 2, BOUNDS * 2), true, Color.WHITE)
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
	if quality > 0 and snake.boosting and textures.has("effects/energy"):
		draw_sprite("effects/energy", snake.position, 0, Vector2(68, 68), Color(color, 0.18))
	draw_sprite("head%d" % snake.skin, snake.position, snake.heading, Vector2(46, 40), tint)
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

func draw_minimap() -> void:
	draw_circle(MINIMAP_CENTER, MINIMAP_RADIUS + 4, Color(0.035, 0.04, 0.11, 0.85))
	draw_circle(MINIMAP_CENTER, MINIMAP_RADIUS, Color(0.07, 0.08, 0.17, 0.73))
	draw_arc(MINIMAP_CENTER, MINIMAP_RADIUS + 1, 0, TAU, 56, Color("6adeee"), 2)
	var arena_half := (MINIMAP_RADIUS - 6) / sqrt(2.0)
	draw_rect(Rect2(MINIMAP_CENTER - Vector2.ONE * arena_half, Vector2.ONE * arena_half * 2), Color(0.46, 0.5, 0.79, 0.35), false, 1)
	draw_line(MINIMAP_CENTER - Vector2(arena_half, 0), MINIMAP_CENTER + Vector2(arena_half, 0), Color(0.4, 0.5, 0.8, 0.1), 1)
	draw_line(MINIMAP_CENTER - Vector2(0, arena_half), MINIMAP_CENTER + Vector2(0, arena_half), Color(0.4, 0.5, 0.8, 0.1), 1)
	draw_rect(_minimap_view_rect, Color(0.45, 0.9, 1, 0.32), false, 1)
	for marker: Dictionary in _minimap_markers:
		if marker.player:
			continue
		draw_circle(marker.position, 2.7, Color(marker.color, 0.95))
	draw_circle(_minimap_player, 6.0, Color(0.5, 0.95, 1, 0.2))
	draw_circle(_minimap_player, 3.8, Color("f5feff"))
	draw_arc(_minimap_player, 7.5, 0, TAU, 16, Color("78f7ff"), 1)
	centered(Vector2(MINIMAP_CENTER.x, 16), "NEON CITY", 10, Color("b8cee9"))

func draw_power_button(at: Vector2, icon: Texture2D, caption: String, ready_fraction: float, color: Color, hint: String = "") -> void:
	draw_circle(at, 44, Color(0.035, 0.045, 0.095, 0.86))
	draw_arc(at, 43, 0, TAU, 36, Color(color, 0.18), 4)
	draw_arc(at, 43, -PI / 2, -PI / 2 + TAU * clampf(ready_fraction, 0.001, 1.0), 36, color, 3)
	if icon != null:
		draw_texture_rect(icon, Rect2(at - Vector2.ONE * 26, Vector2.ONE * 52), false, Color.WHITE if ready_fraction >= 0.99 or caption.begins_with("BOOST") else Color(0.6, 0.63, 0.8, 0.5))
	if not hint.is_empty():
		centered(at + Vector2(0, 8), hint, 25, Color.WHITE)
	centered(at + Vector2(0, 62), caption, 10, Color("d1e4f4"))

func draw_hud(size: Vector2) -> void:
	var accent: Color = SKIN_COLORS[player.skin]
	draw_minimap()
	# Compact headers leave the arena and characters exposed.
	panel(Rect2(size.x / 2 - 82, 12, 164, 66), Color(0.045, 0.055, 0.12, 0.62), Color("3f4974"))
	centered(Vector2(size.x / 2, 31), "TIME", 11, Color("c9cde9"))
	centered(Vector2(size.x / 2, 63), "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60], 28, Color("78f3ff"))
	centered(Vector2(size.x / 2, 94), arena_label, 10, Color("9baccd"))
	var score_center := Vector2(size.x - 326, 0)
	panel(Rect2(score_center.x - 59, 12, 118, 66), Color(0.045, 0.055, 0.12, 0.62), Color("3f4974"))
	centered(Vector2(score_center.x, 31), "SCORE", 11, Color("c9cde9"))
	centered(Vector2(score_center.x, 63), str(player.score), 28, accent)
	# Ten real competitors; no opaque leaderboard card over the action.
	var board_x := size.x - 218
	text(Vector2(board_x, 98), "TOP SERPENTS", 12, Color("d2e6fa"))
	draw_line(Vector2(board_x, 108), Vector2(size.x - 24, 108), Color(0.45, 0.65, 0.9, 0.35), 1)
	for i in range(mini(10, _ranking.size())):
		var snake := _ranking[i]
		var color := accent if snake.id == player.id else Color("c3cadf")
		var y := 128 + i * 21
		if snake.id == player.id:
			draw_rect(Rect2(board_x - 5, y - 14, 199, 19), Color(accent, 0.1))
		text(Vector2(board_x, y), str(i + 1), 12, color)
		text(Vector2(board_x + 24, y), snake.nickname.left(11), 12, color)
		text(Vector2(size.x - 65, y), str(snake.score), 12, color)
	text(Vector2(board_x, 143 + mini(10, _ranking.size()) * 21), "YOU  #%d / %d" % [_player_rank, snakes.size()], 11, accent)
	panel(Rect2(size.x - 69, 19, 48, 44), Color("142036"), Color("52648a"))
	centered(Vector2(size.x - 45, 48), "Ⅱ", 22, Color("bbe3f5"))
	var joy := joystick_center(size)
	if textures.has("hud/joystick"):
		draw_texture_rect(textures["hud/joystick"], Rect2(joy - Vector2.ONE * 76, Vector2.ONE * 152), false, Color(1, 1, 1, 0.60))
	else:
		draw_circle(joy, 72, Color(0.05, 0.09, 0.16, 0.7))
		draw_arc(joy, 72, 0, TAU, 40, Color(0.4, 0.8, 1, 0.4), 2)
	var knob := joy + joystick_vector * 47
	draw_circle(knob, 27, Color("213950"))
	draw_arc(knob, 26, 0, TAU, 28, Color("80dbea"), 2)
	centered(joy + Vector2(0, 99), "MOVE", 11, Color("9bb1cc"))
	var boost := boost_center(size)
	draw_circle(boost, 60, Color(0.045, 0.055, 0.12, 0.78))
	draw_arc(boost, 58, -PI / 2, TAU - PI / 2, 44, Color(accent, 0.85 if boost_down else 0.45), 4)
	if textures.has("hud/boost"):
		draw_texture_rect(textures["hud/boost"], Rect2(boost - Vector2(34, 44), Vector2(68, 68)), false, accent)
	centered(boost + Vector2(0, 29), "BOOST", 13, Color.WHITE)
	centered(boost + Vector2(0, 82), "HOLD", 10, Color("9eafd0"))
	var skill := skill_center(size)
	var ready_fraction: float = 1.0 - player.cooldown / SnakeModel.COOLDOWNS[player.skin]
	var ability_icon: Texture2D = textures.get("icons/ability_%d" % player.skin)
	draw_power_button(skill, ability_icon, SKILL_NAMES[player.skin], ready_fraction, accent, "" if player.cooldown <= 0 else str(ceili(player.cooldown)))
	# The second center widget is another real hold area for boost, not an invented power.
	var mass_fraction := clampf((player.mass - SnakeModel.MIN_MASS) / 80.0, 0, 1)
	draw_power_button(boost_secondary_center(size), textures.get("hud/boost"), "BOOST · HOLD", mass_fraction, Color("ffcf79"))
	centered(Vector2(size.x / 2, size.y - 177), "%s  ·  LENGTH %d  ·  KILLS %d" % [player.nickname, player.segment_count(), player.kills], 11, Color("c4cce2"))
	if _pickup_remaining > 0.0:
		centered(Vector2(size.x / 2, size.y - 201), "+%d ENERGY" % _pickup_total, 15, Color(accent, minf(1.0, _pickup_remaining * 3.0)))
	if player.invulnerable > 0.0 and not (player.skin == 4 and player.active_time > 0.0):
		centered(Vector2(size.x / 2, 115), "PROTECTED · %.1fs" % player.invulnerable, 12, Color("a9edff"))
	if _shield_feedback_remaining > 0.0:
		centered(Vector2(size.x / 2, size.y / 2 - 90), "SHIELD ABSORBED", 19, Color("b4eaff"))
	var danger := boundary_danger()
	if danger > 0.0:
		draw_boundary_warning(size, danger)
	if player.active_time > 0.0:
		centered(Vector2(size.x / 2, size.y - 156), "%s · %.1fs" % [SKILL_NAMES[player.skin], player.active_time], 12, accent)
		draw_rect(Rect2(size.x / 2 - 90, size.y - 149, 180, 3), Color("28324a"))
		draw_rect(Rect2(size.x / 2 - 90, size.y - 149, 180 * clampf(player.active_time / SnakeModel.DURATIONS[player.skin], 0, 1), 3), accent)
	elif player.slow_time > 0.0:
		centered(Vector2(size.x / 2, size.y - 156), "SLOWED", 13, Color("9fdfff"))
	if elapsed < 7.0:
		centered(Vector2(size.x / 2, size.y - 13), "COLLECT ENERGY · AVOID SNAKES AND THE EDGE · E: ABILITY", 10, Color("a5b8d4"))
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

func draw_boundary_warning(size: Vector2, danger: float) -> void:
	var edge_color := Color(1.0, 0.28, 0.42, 0.15 + danger * 0.45)
	var direction := Vector2(-signf(player.position.x), 0) if absf(player.position.x) > absf(player.position.y) else Vector2(0, -signf(player.position.y))
	if direction.x != 0:
		var x := 0.0 if player.position.x < 0 else size.x - 9.0
		draw_rect(Rect2(x, 0, 9, size.y), edge_color)
	else:
		var y := 0.0 if player.position.y < 0 else size.y - 9.0
		draw_rect(Rect2(0, y, size.x, 9), edge_color)
	var at := Vector2(size.x / 2 - 115, 157)
	panel(Rect2(size.x / 2 - 145, 137, 290, 44), Color("351b2d"), Color("e76489"))
	var tip := at + direction * 12
	draw_line(at - direction * 8, tip, Color("ff9db5"), 3, true)
	draw_line(tip, tip - direction.rotated(0.65) * 9, Color("ff9db5"), 3, true)
	draw_line(tip, tip - direction.rotated(-0.65) * 9, Color("ff9db5"), 3, true)
	centered(Vector2(size.x / 2 + 12, 166), "ARENA EDGE · TURN INWARD", 13, Color("ffc4cf"))
