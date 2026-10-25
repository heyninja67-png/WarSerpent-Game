extends Control
class_name SerpentPreview
## A shared texture cache and 24Hz redraw budget keep collection previews cheap.
static var texture_cache: Dictionary = {}
var skin_id := 0
var clock := 0.0
var redraw_elapsed := 0.0
var head: Texture2D
var body: Texture2D
var tail: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part in ["head","body","tail"]:
		var key := "%s_%d" % [part,skin_id]
		if not texture_cache.has(key):
			var path := "res://assets/snakes/%s.png" % key
			if not ResourceLoader.exists(path):
				path = "res://assets/snakes/%s_0.png" % part
			texture_cache[key]=load(path)
		head=texture_cache[key] if part=="head" else head
		body=texture_cache[key] if part=="body" else body
		tail=texture_cache[key] if part=="tail" else tail

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	clock += delta
	redraw_elapsed += delta
	if redraw_elapsed >= 1.0/24.0:
		redraw_elapsed=0.0
		queue_redraw()

func point_at(t: float) -> Vector2:
	return Vector2(size.x*0.12+t*size.x*0.76,size.y*0.48+sin(t*6.0+clock*1.45)*size.y*0.2)

func _draw() -> void:
	if head == null:
		return
	var scale_factor := minf(size.y/200.0,1.55)
	var segment_total := 26
	for j in range(segment_total):
		var t := float(j)/(segment_total-1)
		var point := point_at(t)
		var angle := (point_at(t+0.01)-point).angle()
		draw_set_transform(point,angle,Vector2.ONE*scale_factor)
		var texture := body
		var dimensions := Vector2(40,40)
		if j == 0:
			texture=tail
		elif j == segment_total-1:
			texture=head
			dimensions=Vector2(69,57)
		if texture:
			draw_texture_rect(texture,Rect2(-dimensions*0.5,dimensions),false)
	draw_set_transform(Vector2.ZERO)
