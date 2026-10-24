extends RefCounted
class_name ArenaBrain

var decision_timer := 0.0
var target_angle := 0.0
var wants_boost := false
var wants_skill := false
var wander_phase := 0.0
var difficulty := 1

func decide(snake: SnakeModel, foods: Array, snakes: Array, bounds: float, delta: float) -> void:
	decision_timer -= delta
	if decision_timer > 0.0:
		return
	decision_timer = [0.26, 0.15, 0.09][clampi(difficulty, 0, 2)]
	wants_boost = false
	wants_skill = false
	var desired := Vector2.from_angle(snake.heading)
	var nearest := INF
	var food_position := snake.position + desired * 100.0
	# Sample distributed food indices so all bots do not chase the first pellet.
	for i in range(snake.id % 5, foods.size(), 5):
		var food: Dictionary = foods[i]
		if not food.get("active", true):
			continue
		var distance: float = snake.position.distance_squared_to(food.p)
		if distance < nearest:
			nearest = distance
			food_position = food.p
	desired = (food_position - snake.position).normalized()
	var avoidance := Vector2.ZERO
	var threat := false
	var forward := Vector2.from_angle(snake.heading)
	var ahead := snake.position + forward * 75.0
	for other: SnakeModel in snakes:
		if not other.alive or other.id == snake.id:
			continue
		for index in range(0, other.segments.size(), 4):
			var away := ahead - other.segments[index]
			var distance := away.length()
			if distance < 105.0:
				avoidance += away.normalized() * (1.0 - distance / 105.0) * 3.8
				threat = true
		if difficulty == 2 and other.mass < snake.mass * 0.65 and other.position.distance_to(snake.position) < 220.0 and snake.invulnerable <= 0.0:
			desired = (other.position + Vector2.from_angle(other.heading) * 70.0 - snake.position).normalized()
			wants_boost = snake.mass > 90.0
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
	wants_skill = threat or (snake.skin == 0 and nearest > 35000.0)
	if threat:
		wants_boost = false
