extends SceneTree
## Integration worker: run host/client as separate OS processes (real ENet UDP).
const Online = preload("res://scripts/network/OnlineArena.gd")
var arena: Node2D
var mode := ""
var elapsed := 0.0
var assertions := 0
var failures := 0
var sent_skill := false
var observed_movement := false
var previous_position := Vector2.ZERO
var saw_peer := false
var done := false
var app: Node
var joined_at := -1.0
var tiny_direction_observed := false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if not args.is_empty() else "host"
	arena = Online.new()
	arena.configure(6 if mode == "client" else 0,0)
	arena.set_audio_enabled(false)
	arena.set_player_name("Remote pilot" if mode == "client" else "Host pilot")
	var error: Error = arena.host(24689) if mode == "host" else arena.join("127.0.0.1",24699 if mode == "unreachable" else 24689)
	check(error == OK,"ENet peer created")
	arena.finished.connect(func(result):
		if mode == "unreachable" or mode == "disconnect":
			var expected := "timed out" if mode == "unreachable" else "host closed"
			check(result.abandoned and result.get("network_error","").contains(expected),"connection failure returns honest network error without match rewards")
			finish()
		else:
			check(false,"match unexpectedly ended: " + str(result))
			finish())
	if mode == "unreachable":
		arena.connection_timeout = 1.0
	if mode == "host":
		app = Node.new()
		app.name = "WarSerpentIO"
		root.add_child(app)
	else:
		# Real application root: catches RPC path mismatches with headless hosts.
		app = load("res://scenes/Main.tscn").instantiate()
		root.add_child(app)
		while app.boot_active:
			await process_frame
		if is_instance_valid(app.screen):
			app.screen.queue_free()
	app.add_child(arena)
	if mode == "host":
		check(arena.host_connection_hint.contains(str(arena.room_port)) and arena.room_port == 24689,"host HUD caches the actual room port and LAN connection hint")

func _process(delta: float) -> bool:
	if arena == null or done or not arena.is_inside_tree():
		return false
	elapsed += delta
	if mode == "unreachable":
		if elapsed > 3.0:
			check(false,"connection timeout must complete")
			finish()
		return false
	if mode == "host":
		arena.player.invulnerable = 100.0
		# Keep host alive and near the origin; test that client controls steer only its slot.
		arena.joystick_vector = Vector2.from_angle(elapsed * 1.0)
		if not arena.guest_slots.is_empty():
			if joined_at < 0:
				joined_at = elapsed
			saw_peer = true
			var slot: int = arena.guest_slots.values()[0]
			arena.snakes[slot].invulnerable = 100.0
			if elapsed - joined_at < 0.7:
				arena.snakes[slot].mass = 120.0
				arena.foods[0].p = arena.snakes[slot].position
				arena.foods[0].active = true
				arena.foods[0].v = 9
				arena.rebuild_food_grid()
		if elapsed >= 7.5:
			check(saw_peer,"server accepted real remote human")
			check(arena.accepted_inputs >= 20,"server accepted rate-limited input packets")
			var slot: int = arena.guest_slots.values()[0] if not arena.guest_slots.is_empty() else 1
			check(arena.snakes[slot].score >= 9,"server awarded food to remote player")
			check(arena.snakes[slot].cooldown > 0,"server applied remote skill request and cooldown")
			finish()
	else:
		if arena.room_ready:
			if not sent_skill:
				previous_position = arena.player.position
				arena.use_skill()
				sent_skill = true
			if mode == "client" and elapsed < 1.1:
				# Enter the shared radial gate, then remain just above its exit radius.
				# The filtered amplitude is ~0.011: a second 12% client gate would drop it.
				var center: Vector2 = arena.joystick_center(arena.get_viewport_rect().size)
				arena.update_joystick(center + Vector2.RIGHT * arena.JOYSTICK_RADIUS * 0.20, arena.get_viewport_rect().size)
				arena.update_joystick(center + Vector2.RIGHT * arena.JOYSTICK_RADIUS * 0.13, arena.get_viewport_rect().size)
				if elapsed > 0.85 and absf(angle_difference(arena.player.heading, 0.0)) < 0.3:
					tiny_direction_observed = true
			else:
				arena.joystick_vector = Vector2.from_angle(elapsed * -1.0)
			arena.mouse_boost = elapsed < 3.0
			if arena.player.position.distance_to(previous_position) > 40:
				observed_movement = true
		if mode == "disconnect" and elapsed > 7.0:
			check(false,"host closure must complete guest disconnect")
			finish()
		if mode == "client" and elapsed >= 3.8:
			check(arena.room_ready and arena.assigned_slot > 0,"client handshake assigns distinct authoritative snake")
			check(arena.received_snapshots >= 20,"client receives ongoing authoritative snapshots")
			check(arena.sent_inputs >= 30,"client sends steering inputs")
			check(observed_movement,"remote steering produces visible synchronized motion")
			check(tiny_direction_observed,"tiny active joystick direction reaches host without a second deadzone")
			check(arena.player.skin == 6 and arena.player.nickname == "Remote pilot","server preserves selected skin and nickname")
			check(arena.player.score >= 9 and arena.player.cooldown > 0,"food growth and ability cooldown synchronize from host")
			check(arena.foods.size() >= 400,"real initial food data synchronized")
			finish()
	return false

func finish() -> void:
	done = true
	print("NETWORK ", mode, ": ", assertions, " checks, ", failures, " failures")
	if is_instance_valid(app):
		app.queue_free()
	await process_frame
	await create_timer(0.6).timeout
	quit(0 if failures == 0 else 1)
