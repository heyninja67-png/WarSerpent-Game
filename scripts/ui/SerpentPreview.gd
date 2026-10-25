extends Control
class_name SerpentPreview
## Shared assets, one instanced body draw, two cap draws; 24Hz animation budget.
static var texture_cache: Dictionary = {}
var skin_id := 0
var hero_pose := false
var segment_total := SEGMENTS
var clock := 0.0
var redraw_elapsed := 0.0
var head: Texture2D
var body: Texture2D
var tail: Texture2D
var body_instances: MultiMeshInstance2D
const SEGMENTS := 26

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for part in ["head","body","tail"]:
		var key := "%s_%d" % [part,skin_id]
		if not texture_cache.has(key):
			var path := "res://assets/snakes/%s.png" % key
			if not ResourceLoader.exists(path):
				path="res://assets/snakes/%s_0.png" % part
			texture_cache[key]=load(path)
		head=texture_cache[key] if part=="head" else head
		body=texture_cache[key] if part=="body" else body
		tail=texture_cache[key] if part=="tail" else tail
	var quad := QuadMesh.new()
	quad.size=Vector2(40,40)
	var mesh := MultiMesh.new()
	mesh.transform_format=MultiMesh.TRANSFORM_2D
	mesh.mesh=quad
	segment_total=48 if hero_pose else SEGMENTS
	mesh.instance_count=segment_total-2
	body_instances=MultiMeshInstance2D.new()
	body_instances.multimesh=mesh
	body_instances.texture=body
	body_instances.show_behind_parent=true
	add_child(body_instances)
	update_body()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	clock+=delta
	redraw_elapsed+=delta
	if redraw_elapsed >= 1.0/24.0:
		redraw_elapsed=0.0
		update_body()
		queue_redraw()

func point_at(t: float) -> Vector2:
	if hero_pose:
		var wave:=t*TAU*1.12+sin(clock*.65)*.15
		return Vector2(size.x*.5+sin(wave)*size.x*.255,size.y*.84-t*size.y*.65+cos(wave)*size.y*.09+sin(clock*1.3)*3.0)
	return Vector2(size.x*.12+t*size.x*.76,size.y*.49+sin(t*5.6+clock*1.25)*size.y*.18)

func update_body() -> void:
	if not is_instance_valid(body_instances):
		return
	var scale_factor := 1.65 if hero_pose else minf(size.y/200.0,1.55)
	for j in range(1,segment_total-1):
		var t := float(j)/(segment_total-1)
		var point := point_at(t)
		var angle := (point_at(t+.01)-point).angle()
		body_instances.multimesh.set_instance_transform_2d(j-1,Transform2D(angle,Vector2.ONE*scale_factor,0.0,point))

func _draw() -> void:
	if head == null:
		return
	var scale_factor := 1.65 if hero_pose else minf(size.y/200.0,1.55)
	for j in [0,segment_total-1]:
		var t := float(j)/(segment_total-1)
		var point := point_at(t)
		var angle := (point_at(t+.01)-point).angle()
		draw_set_transform(point,angle,Vector2.ONE*scale_factor)
		var texture := tail if j==0 else head
		var dimensions := Vector2(40,40) if j==0 else (Vector2(87,73) if hero_pose else Vector2(69,57))
		draw_texture_rect(texture,Rect2(-dimensions*.5,dimensions),false)
	draw_set_transform(Vector2.ZERO)
