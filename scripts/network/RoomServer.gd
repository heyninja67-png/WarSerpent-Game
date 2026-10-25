extends SceneTree
## Optional direct room host. A headless pilot circles safely; guests use ordinary slots.
var arena: OnlineArena
var time := 0.0

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	var args := OS.get_cmdline_user_args()
	var port := int(args[0]) if not args.is_empty() else 24680
	arena = OnlineArena.new()
	arena.configure(0,0)
	arena.set_player_name("Room host")
	arena.set_audio_enabled(false)
	if arena.host(port) != OK:
		push_error("Cannot host UDP room on port %d" % port)
		quit(1)
		return
	var wrapper := Node.new()
	wrapper.name = "WarSerpentIO"
	root.add_child(wrapper)
	wrapper.add_child(arena)
	arena.finished.connect(func(_result): quit(0))
	print("Direct room listening on UDP ",port,". Public access requires your own reachable host/forwarding.")

func _process(delta: float) -> bool:
	time += delta
	if is_instance_valid(arena) and arena.player != null:
		arena.joystick_vector = Vector2.from_angle(time)
		arena.player.invulnerable = 10.0
	return false
