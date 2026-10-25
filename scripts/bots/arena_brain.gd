extends RefCounted
class_name ArenaBrain

var decision_timer := 0.0
var target_angle := 0.0
var wants_boost := false
var wants_skill := false
var wander_phase := 0.0
var difficulty := 1
var _foods_nearby: Array = []
var _bodies_nearby: Array = []
var _food_scan_offset := 0

func decide(snake: SnakeModel, foods: Array, snakes: Array, bounds: float, delta: float, food_grid: ArenaSpatialHash = null, body_grid: ArenaSpatialHash = null) -> void:
	decision_timer -= delta
	if decision_timer > 0.0:
		return
	decision_timer = [0.32, 0.22, 0.16][clampi(difficulty, 0, 2)]
	wants_boost = false
	wants_skill = false
	var desired := Vector2.from_angle(snake.heading)
	var nearest := INF
	var food_position := snake.position + desired * 150.0
	if food_grid != null:
		food_grid.query_into(snake.position, 290.0, _foods_nearby)
		if _foods_nearby.is_empty():
			food_grid.query_into(snake.position, 550.0, _foods_nearby)
		for index: int in _foods_nearby:
			var food: Dictionary = foods[index]
			if not food.active:
				continue
			var distance := snake.position.distance_squared_to(food.p)
			if distance < nearest:
				nearest = distance
				food_position = food.p
	else:
		# Compatibility path for standalone simulations: bounded distributed sampling.
		var stride := maxi(1, foods.size() / 48)
		_food_scan_offset = (_food_scan_offset + 3) % stride
		for i in range(_food_scan_offset, foods.size(), stride):
			var food: Dictionary = foods[i]
			if not food.active:
				continue
			var distance := snake.position.distance_squared_to(food.p)
			if distance < nearest:
				nearest = distance
				food_position = food.p
	desired = (food_position - snake.position).normalized()
	var avoidance := Vector2.ZERO
	var threat := false
	var ahead := snake.position + Vector2.from_angle(snake.heading) * 75.0
	if body_grid != null:
		body_grid.query_into(ahead, 110.0, _bodies_nearby)
		for encoded: int in _bodies_nearby:
			var other_index := encoded >> 8
			var segment_index := encoded & 255
			if other_index >= snakes.size():
				continue
			var other: SnakeModel = snakes[other_index]
			if not other.alive or other.id == snake.id or segment_index >= other.segments.size():
				continue
			var away := ahead - other.segments[segment_index]
			var distance_squared := away.length_squared()
			if distance_squared < 110.0 * 110.0:
				var distance := sqrt(distance_squared)
				avoidance += away / maxf(distance, 0.001) * (1.0 - distance / 110.0) * 3.2
				threat = true
	else:
		for other: SnakeModel in snakes:
			if not other.alive or other.id == snake.id:
				continue
			if ahead.distance_squared_to(other.position) > pow(other.length_pixels() + 110, 2):
				continue
			for index in range(0, other.segments.size(), 4):
				var away := ahead - other.segments[index]
				var distance := away.length()
				if distance < 105.0:
					avoidance += away / maxf(distance, 0.001) * (1.0 - distance / 105.0) * 3.8
					threat = true
	if difficulty == 2 and not threat:
		for other: SnakeModel in snakes:
			if other.id == snake.id or not other.alive:
				continue
			if other.mass < snake.mass * 0.65 and other.position.distance_squared_to(snake.position) < 220.0 * 220.0 and snake.invulnerable <= 0.0:
				desired = (other.position + Vector2.from_angle(other.heading) * 70.0 - snake.position).normalized()
				wants_boost = snake.mass > 60.0
	var edge := bounds - 150.0
	if absf(ahead.x) > edge:
		avoidance.x -= signf(ahead.x) * 5.0
		threat = true
	if absf(ahead.y) > edge:
		avoidance.y -= signf(ahead.y) * 5.0
		threat = true
	var direction := desired + avoidance
	if direction.length_squared() > 0.01:
		target_angle = direction.angle()
	wants_skill = threat or (snake.skin in [0, 6] and nearest > 35000.0) or (snake.skin == 5 and nearest < 20000.0)
	if threat:
		wants_boost = false
