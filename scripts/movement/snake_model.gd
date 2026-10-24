extends RefCounted
class_name SnakeModel

## Distance sampled path. Body spacing is independent of frame rate and speed.
const SPACING := 10.0
const BASE_SPEED := 162.0
const TURN_RATE := 3.8
const COOLDOWNS := [12.0, 14.0, 15.0, 16.0, 17.0]
const DURATIONS := [3.0, 3.0, 4.0, 4.0, 2.0]
var id := 0
var skin := 0
var nickname := "Serpent"
var position := Vector2.ZERO
var heading := 0.0
var mass := 180.0
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
var path: Array[Vector2] = []
var segments := PackedVector2Array()
var respawn_time := 0.0
var boost_drop_time := 0.0

func initialize(at: Vector2, angle: float, skin_index: int, snake_id: int, title: String) -> void:
	position = at
	heading = angle
	skin = clampi(skin_index, 0, 4)
	id = snake_id
	nickname = title
	path.clear()
	for i in range(200):
		path.append(position - Vector2.from_angle(heading) * float(i) * SPACING)
	rebuild_body()

func segment_count() -> int:
	return clampi(18 + int(mass / 12.0), 20, 150)

func length_pixels() -> float:
	return float(segment_count() - 1) * SPACING

func rebuild_body() -> void:
	segments.clear()
	segments.append(position)
	var wanted := SPACING
	var travelled := 0.0
	for i in range(1, path.size()):
		var distance := path[i - 1].distance_to(path[i])
		while wanted <= travelled + distance and segments.size() < segment_count():
			var fraction := (wanted - travelled) / maxf(distance, 0.0001)
			segments.append(path[i - 1].lerp(path[i], fraction))
			wanted += SPACING
		travelled += distance
		if segments.size() >= segment_count():
			# Retain a buffer to support immediate growth without teleporting tail.
			if i + 240 < path.size():
				path.resize(i + 240)
			break
	while segments.size() < segment_count():
		segments.append(segments[-1] - Vector2.from_angle(heading) * SPACING)

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
	boosting = request_boost and mass > 36.0
	var speed := BASE_SPEED * slow_factor
	if boosting:
		speed *= 1.7
		mass = maxf(36.0, mass - 19.0 * delta)
	if skin == 0 and active_time > 0.0:
		speed *= 1.55
	position += Vector2.from_angle(heading) * speed * delta
	path.push_front(position)
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
