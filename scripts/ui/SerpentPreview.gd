extends Control
class_name SerpentPreview

var skin_id := 0
var clock := 0.0
var heads: Array[Texture2D] = []
var bodies: Array[Texture2D] = []
var tails: Array[Texture2D] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(5):
		heads.append(load("res://assets/snakes/head_%d.png" % i))
		bodies.append(load("res://assets/snakes/body_%d.png" % i))
		tails.append(load("res://assets/snakes/tail_%d.png" % i))

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func point_at(t: float) -> Vector2:
	return Vector2(size.x * 0.15 + t * size.x * 0.7, size.y * 0.5 + sin(t * 6.0 + clock * 1.8) * size.y * 0.18)

func _draw() -> void:
	if heads.size() < 5:
		return
	var scale_factor := minf(size.y / 200.0, 1.6)
	for j in range(31):
		var t := float(j) / 30.0
		var p := point_at(t)
		var rot := (point_at(t + 0.01) - p).angle()
		draw_set_transform(p, rot, Vector2.ONE * scale_factor)
		var tex: Texture2D = bodies[skin_id]
		var dim := Vector2(38, 38)
		if j == 0:
			tex = tails[skin_id]
		elif j == 30:
			tex = heads[skin_id]
			dim = Vector2(67, 57)
		if tex:
			draw_texture_rect(tex, Rect2(-dim * 0.5, dim), false)
	draw_set_transform(Vector2.ZERO)
