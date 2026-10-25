extends RefCounted
class_name ArenaSpatialHash

## Buckets are retained and emptied, rather than recreated every physics frame.
var cell_size := 80.0
var cells: Dictionary = {}
var active_cells: Array[Vector2i] = []

func _init(size: float = 80.0) -> void:
	cell_size = size

func clear() -> void:
	for cell in active_cells:
		cells[cell].clear()
	active_cells.clear()

func key(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / cell_size), floori(at.y / cell_size))

func insert(at: Vector2, data: Variant) -> void:
	var cell := key(at)
	if not cells.has(cell):
		cells[cell] = []
	var bucket: Array = cells[cell]
	if bucket.is_empty():
		active_cells.append(cell)
	bucket.append(data)

func query_into(at: Vector2, radius: float, output: Array) -> void:
	output.clear()
	var low := key(at - Vector2.ONE * radius)
	var high := key(at + Vector2.ONE * radius)
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var cell := Vector2i(x, y)
			if cells.has(cell):
				output.append_array(cells[cell])

func query(at: Vector2, radius: float) -> Array:
	var output: Array = []
	query_into(at, radius, output)
	return output
