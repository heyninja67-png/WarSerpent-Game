extends RefCounted
class_name SnakeModel

## Fixed-capacity distance sampled history. No Array.push_front, body allocation,
## or per-frame history copying; sampling remains independent of FPS and speed.
const SPACING := 10.0
const BASE_SPEED := 162.0
const TURN_RATE := 3.8
const START_MASS := 36.0
const MIN_MASS := 12.0
const HISTORY_CAPACITY := 640
const SAMPLE_DISTANCE := 3.0
const COOLDOWNS := [12.0, 14.0, 15.0, 16.0, 17.0, 15.0, 11.0, 14.0]
const DURATIONS := [3.0, 3.0, 4.0, 4.0, 2.0, 4.0, 0.8, 3.0]
var id := 0
var skin := 0
var nickname := "Serpent"
var position := Vector2.ZERO
var heading := 0.0
var mass := START_MASS
var score := 0
var kills := 0
var collected := 0
var alive := true
var boosting := false
var cooldown := 0.0
var active_time := 0.0
var invulnerable := 2.0
var shield := false
var slow_time := 0.0
var slow_factor := 1.0
var segments := PackedVector2Array()
var respawn_time := 0.0
var boost_drop_time := 0.0
var _history := PackedVector2Array()
var _history_distances := PackedFloat64Array()
var _history_head := 0
var _travelled := 0.0
var _last_sample_distance := 0.0

func initialize(at: Vector2, angle: float, skin_index: int, snake_id: int, title: String) -> void:
	position = at
	heading = angle
	skin = clampi(skin_index, 0, 7)
	id = snake_id
	nickname = title
	_history.resize(HISTORY_CAPACITY)
	_history_distances.resize(HISTORY_CAPACITY)
	_history_head = 0
	_travelled = 0.0
	_last_sample_distance = 0.0
	var backwards := -Vector2.from_angle(heading)
	for i in range(HISTORY_CAPACITY):
		var index := (HISTORY_CAPACITY - i) % HISTORY_CAPACITY
		_history[index] = position + backwards * float(i) * SAMPLE_DISTANCE
		_history_distances[index] = -float(i) * SAMPLE_DISTANCE
	rebuild_body()

func segment_count() -> int:
	return clampi(7 + int(mass / 12.0), 8, 150)

func length_pixels() -> float:
	return float(segment_count() - 1) * SPACING

func rebuild_body() -> void:
	var count := segment_count()
	if segments.size() != count:
		segments.resize(count)
	segments[0] = position
	if _history.is_empty():
		for i in range(1, count):
			segments[i] = position - Vector2.from_angle(heading) * float(i) * SPACING
		return
	var cursor := 0
	var newer := position
	var newer_distance := _travelled
	for segment_index in range(1, count):
		var wanted := _travelled - float(segment_index) * SPACING
		while cursor < HISTORY_CAPACITY:
			var index := (_history_head - cursor + HISTORY_CAPACITY) % HISTORY_CAPACITY
			var older_distance := _history_distances[index]
			var older := _history[index]
			if older_distance <= wanted:
				var fraction := (newer_distance - wanted) / maxf(newer_distance - older_distance, 0.0001)
				segments[segment_index] = newer.lerp(older, clampf(fraction, 0.0, 1.0))
				break
			newer = older
			newer_distance = older_distance
			cursor += 1
		if cursor >= HISTORY_CAPACITY:
			segments[segment_index] = segments[segment_index - 1] - Vector2.from_angle(heading) * SPACING

func advance(delta: float, target_angle: float, request_boost: bool) -> void:
	if not alive:
		return
	cooldown = maxf(0.0, cooldown - delta)
	active_time = maxf(0.0, active_time - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	slow_time = maxf(0.0, slow_time - delta)
	if slow_time <= 0.0:
		slow_factor = 1.0
	if active_time <= 0.0:
		shield = false
	var turn := clampf(angle_difference(heading, target_angle), -TURN_RATE * delta, TURN_RATE * delta)
	heading += turn
	boosting = request_boost and mass > MIN_MASS
	var speed := BASE_SPEED * slow_factor
	if boosting:
		speed *= 1.7
		mass = maxf(MIN_MASS, mass - 19.0 * delta)
	if active_time > 0.0:
		if skin == 0:
			speed *= 1.55
		elif skin == 6:
			speed *= 1.9
	var previous := position
	position += Vector2.from_angle(heading) * speed * delta
	var distance := previous.distance_to(position)
	var previous_distance := _travelled
	_travelled += distance
	while _last_sample_distance + SAMPLE_DISTANCE <= _travelled:
		_last_sample_distance += SAMPLE_DISTANCE
		_history_head = (_history_head + 1) % HISTORY_CAPACITY
		var fraction := (_last_sample_distance - previous_distance) / maxf(distance, 0.0001)
		_history[_history_head] = previous.lerp(position, clampf(fraction, 0.0, 1.0))
		_history_distances[_history_head] = _last_sample_distance
	rebuild_body()

func collect(value: int) -> void:
	mass += float(value)
	score += value
	collected += value

func activate() -> bool:
	if not alive or cooldown > 0.0:
		return false
	cooldown = COOLDOWNS[skin]
	active_time = DURATIONS[skin]
	if skin == 3:
		shield = true
	elif skin == 4:
		invulnerable = DURATIONS[skin]
	return true

func collection_radius() -> float:
	return 150.0 if skin == 5 and active_time > 0.0 else 26.0

func slow(factor: float, duration: float) -> void:
	if skin == 4 and active_time > 0.0:
		return
	slow_time = maxf(slow_time, duration)
	slow_factor = minf(slow_factor, factor)

## Returns true if the snake can be killed by this collision.
func lethal_collision() -> bool:
	if invulnerable > 0.0:
		return false
	if shield and active_time > 0.0:
		shield = false
		active_time = 0.0
		invulnerable = 1.0
		return false
	return true
