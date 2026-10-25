extends Control
## Original holographic podium: fourteen low-cost primitives at 24 Hz.
var phase := 0.0
var tick := 0.0
var accent := Color("45e9f5")
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	phase+=delta
	tick+=delta
	if tick>=1.0/24.0:
		tick=0.0
		queue_redraw()
func _draw() -> void:
	var center:=size*.5
	var radius:=size.x*.43
	draw_set_transform(center,0,Vector2(1,.24))
	draw_circle(Vector2.ZERO,radius,Color(.02,.11,.2,.45))
	draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(accent,.45),2.0)
	draw_arc(Vector2.ZERO,radius*.86,phase*.18,phase*.18+TAU*.72,48,Color(accent,.8),2.0)
	draw_arc(Vector2.ZERO,radius*.70,-phase*.12,-phase*.12+TAU*.36,32,Color("ffd369"),2.0)
	for i in range(8):
		var a:=float(i)*TAU/8.0+phase*.035
		draw_line(Vector2.from_angle(a)*radius*.93,Vector2.from_angle(a)*radius*.99,Color(accent,.7),3.0)
	draw_set_transform(Vector2.ZERO)
