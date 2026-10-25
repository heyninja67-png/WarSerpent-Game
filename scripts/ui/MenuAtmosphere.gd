extends Control
## Ten cheap batched primitives, refreshed at 24Hz only while visible.
var phase := 0.0
var accumulated := 0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	phase+=delta
	accumulated+=delta
	if accumulated >= 1.0/24.0:
		accumulated=0.0
		queue_redraw()

func _draw() -> void:
	for i in range(6):
		var speed := 7.0+float(i%4)*3.0
		var x := fposmod(float(i*137)+sin(phase*.18+i)*18.0,size.x)
		var y := fposmod(float(i*83)-phase*speed,size.y)
		var alpha := .12+.13*(.5+.5*sin(phase*.7+i))
		draw_circle(Vector2(x,y),1.0+float(i%2),Color(.4,.9,1.0,alpha))
	for i in range(4):
		var x := fposmod(float(i*193)+phase*9.0,size.x)
		var y := 122.0+float(i)*69.0
		draw_line(Vector2(x,y),Vector2(x+11.0,y-4.0),Color(.5,.6,1.0,.1),1.0)
