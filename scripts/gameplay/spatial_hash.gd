extends RefCounted
class_name ArenaSpatialHash

var cell_size := 80.0
var cells: Dictionary = {}

func _init(size: float = 80.0) -> void:
	cell_size = size

func clear() -> void:
	cells.clear()

func key(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / cell_size), floori(at.y / cell_size))

func insert(at: Vector2, data: Variant) -> void:
	var cell := key(at)
	if not cells.has(cell):
		cells[cell] = []
	cells[cell].append(data)

func query(at: Vector2, radius: float) -> Array:
	var output: Array = []
	var low := key(at - Vector2.ONE * radius)
	var high := key(at + Vector2.ONE * radius)
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var cell := Vector2i(x, y)
			if cells.has(cell):
				output.append_array(cells[cell])
	return output
