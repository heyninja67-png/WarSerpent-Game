extends "res://scripts/gameplay/ArenaGame.gd"
class_name OnlineArena
## Direct-connect ENet rooms. The host simulates all movement, food and damage.
## Only steering/boost/skill requests travel from a client to the host.

signal network_status(message: String)
signal connection_ready()
signal connection_error(message: String)

const PROTOCOL := 1
const DEFAULT_PORT := 24680
const MAX_GUESTS := 3
const SNAPSHOT_INTERVAL := 1.0 / 12.0
const INPUT_INTERVAL := 1.0 / 20.0
var room_mode := ""
var room_ready := false
var room_port := DEFAULT_PORT
var assigned_slot := -1
var connection_timeout := 9.0
var received_snapshots := 0
var accepted_inputs := 0
var sent_inputs := 0
var last_network_error := ""
var peer: ENetMultiplayerPeer
var guest_slots: Dictionary = {}
var targets: Dictionary = {}
var previous_food: Array = []
var input_elapsed := 0.0
var snapshot_elapsed := 0.0
var connect_elapsed := 0.0
var pending_skill := false
var client_death_elapsed := 0.0
var input_times: Dictionary = {}
var sequence := 0
var last_sequence := -1
var pending_frames: Dictionary = {}
var client_started_at := 0.0
var host_lan_address := ""
var host_connection_hint := ""

func host(port: int = DEFAULT_PORT) -> Error:
	if port < 1024 or port > 65535:
		return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_GUESTS)
	if error != OK:
		peer = null
		return error
	room_mode = "host"
	room_port = port
	assigned_slot = 0
	name = "OnlineArena"
	return OK

func join(address: String, port: int = DEFAULT_PORT) -> Error:
	if address.strip_edges().is_empty() or address.length() > 253 or port < 1024 or port > 65535:
		return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error != OK:
		peer = null
		return error
	room_mode = "client"
	room_port = port
	name = "OnlineArena"
	return OK

func _ready() -> void:
	# Keep memory/traffic modest and host rules identical across quality profiles.
	quality = 0
	arena_label = "ONLINE ROOM"
	super._ready()
	if peer == null or room_mode.is_empty():
		fail_connection("Room was not configured.")
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(on_peer_disconnected)
	if room_mode == "host":
		cache_host_address()
		room_ready = true
		for food: Dictionary in foods:
			previous_food.append(food_signature(food))
		network_status.emit("Room open · UDP %d · up to 4 players" % room_port)
		connection_ready.emit()
	else:
		simulation_enabled = false
		local_player_control = false
		multiplayer.connected_to_server.connect(on_connected)
		multiplayer.connection_failed.connect(on_connection_failed)
		multiplayer.server_disconnected.connect(on_server_disconnected)
		network_status.emit("Connecting to room…")

func cache_host_address() -> void:
	# Cache once; never enumerate interfaces during drawing or per-frame simulation.
	var preferred: Array[String] = []
	var fallback: Array[String] = []
	for interface: Dictionary in IP.get_local_interfaces():
		var interface_name := str(interface.get("name", "")).to_lower()
		var primary := interface_name.begins_with("wl") or interface_name.begins_with("wifi") or interface_name.begins_with("en") or interface_name.begins_with("eth")
		for value in interface.get("addresses", []):
			var address := str(value)
			if not valid_lan_ipv4(address):
				continue
			if primary:
				preferred.append(address)
			else:
				fallback.append(address)
	if preferred.is_empty():
		for value in IP.get_local_addresses():
			var address := str(value)
			if valid_lan_ipv4(address) and not fallback.has(address):
				fallback.append(address)
	host_lan_address = preferred[0] if not preferred.is_empty() else (fallback[0] if not fallback.is_empty() else "")
	host_connection_hint = "LAN ROOM  %s:%d" % [host_lan_address,room_port] if not host_lan_address.is_empty() else "LAN IP unavailable · UDP %d" % room_port

func valid_lan_ipv4(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4 or address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0":
		return false
	for part in parts:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
			return false
	return true

func on_connected() -> void:
	_hello.rpc_id(1, PROTOCOL, skin_index, player_name)

func on_connection_failed() -> void:
	fail_connection("Cannot reach the room. Check the address, Wi-Fi and UDP port.")

func on_server_disconnected() -> void:
	fail_connection("The host closed the room.")

func fail_connection(message: String) -> void:
	if ended:
		return
	last_network_error = message
	room_ready = false
	network_status.emit(message)
	connection_error.emit(message)
	if player != null:
		ended = true
		finished.emit({"score":player.score,"kills":player.kills,"energy":player.collected,"time":elapsed,"survived":elapsed,"abandoned":true,"network_error":message})

@rpc("any_peer", "call_remote", "reliable", 0)
func _hello(version: int, selected_skin: int, nickname: String) -> void:
	if room_mode != "host" or not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or guest_slots.has(sender):
		return
	if version != PROTOCOL:
		peer.disconnect_peer(sender)
		return
	var slot := -1
	for candidate in range(1, MAX_GUESTS + 1):
		if not guest_slots.values().has(candidate):
			slot = candidate
			break
	if slot < 0 or slot >= snakes.size():
		peer.disconnect_peer(sender)
		return
	guest_slots[sender] = slot
	var snake: SnakeModel = snakes[slot]
	var clean_name := nickname.strip_edges().replace("\n", " ").replace("\r", " ").left(18)
	if clean_name.is_empty():
		clean_name = "Guest"
	snake.mass = 36.0
	snake.initialize(Vector2(slot * 140, 80), -PI / 2, clampi(selected_skin, 0, 7), slot, clean_name)
	snake.alive = true
	snake.score = 0
	snake.kills = 0
	snake.collected = 0
	snake.invulnerable = 3.0
	snake.cooldown = 0.0
	snake.active_time = 0.0
	snake.shield = false
	remote_controls[slot] = {"angle": snake.heading, "boost": false, "skill": false}
	input_times[sender] = 0
	_welcome.rpc_id(sender, slot, PROTOCOL, elapsed)
	var initial: Array = []
	for i in range(foods.size()):
		initial.append(pack_food(i, foods[i]))
	_food_updates.rpc_id(sender, initial, true)
	send_snapshot(sender)
	network_status.emit("%s joined · %d/4 players" % [clean_name, guest_slots.size() + 1])

@rpc("authority", "call_remote", "reliable", 0)
func _welcome(slot: int, version: int, started_at: float) -> void:
	if room_mode != "client" or version != PROTOCOL or slot < 1 or slot >= snakes.size():
		return
	assigned_slot = slot
	client_started_at = started_at
	player = snakes[slot]
	room_ready = true
	network_status.emit("Connected · authoritative online room")
	connection_ready.emit()

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _steer(angle: float, boost: bool, skill: bool) -> void:
	if room_mode != "host" or not multiplayer.is_server() or not is_finite(angle):
		return
	var sender := multiplayer.get_remote_sender_id()
	if not guest_slots.has(sender):
		return
	var now := Time.get_ticks_msec()
	# Normal clients send 20Hz; reject bursts beyond 50Hz. No client positions/rewards accepted.
	if now - int(input_times.get(sender, 0)) < 20:
		return
	input_times[sender] = now
	var slot: int = guest_slots[sender]
	remote_controls[slot] = {"angle": wrapf(angle, -PI, PI), "boost": boost, "skill": skill or bool(remote_controls[slot].get("skill", false))}
	accepted_inputs += 1

func on_peer_disconnected(id: int) -> void:
	if room_mode != "host" or not guest_slots.has(id):
		return
	var slot: int = guest_slots[id]
	remote_controls.erase(slot)
	guest_slots.erase(id)
	input_times.erase(id)
	# Existing bot slot resumes ordinary host AI, never a phantom player.
	snakes[slot].nickname = "NOVA-%d" % slot
	network_status.emit("Player left · %d/4 players" % (guest_slots.size() + 1))

func _physics_process(delta: float) -> void:
	if ended:
		return
	if room_mode == "host":
		# Opening a local pause overlay must not freeze the room for other players.
		var menu_open := paused
		paused = false
		local_player_control = not menu_open
		super._physics_process(delta)
		paused = menu_open
		if ended:
			return
		for id in guest_slots:
			if Time.get_ticks_msec() - int(input_times.get(id, 0)) > 1000:
				var slot: int = guest_slots[id]
				remote_controls[slot].boost = false
		snapshot_elapsed += delta
		if snapshot_elapsed >= SNAPSHOT_INTERVAL and not guest_slots.is_empty():
			snapshot_elapsed = 0.0
			send_snapshot()
			var updates: Array = []
			for i in range(foods.size()):
				var signature: Array = food_signature(foods[i])
				if i >= previous_food.size():
					previous_food.append(signature)
					updates.append(pack_food(i, foods[i]))
				elif signature != previous_food[i]:
					previous_food[i] = signature
					updates.append(pack_food(i, foods[i]))
			if not updates.is_empty():
				_food_updates.rpc(updates, false)
	else:
		pickup_sound_delay = maxf(0.0, pickup_sound_delay - delta)
		if not room_ready:
			connect_elapsed += delta
			if connect_elapsed > connection_timeout:
				fail_connection("Room connection timed out. Check Wi-Fi, address and UDP port.")
			return
		input_elapsed += delta
		if input_elapsed >= INPUT_INTERVAL:
			input_elapsed = 0.0
			var direction := joystick_vector
			var keyboard := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
			if keyboard.length_squared() > 0:
				direction = keyboard.normalized()
			var target_angle := direction.angle() if direction.length_squared() > 0.000001 else player.heading
			var request_boost := not paused and (boost_id >= 0 or mouse_boost or Input.is_physical_key_pressed(KEY_SPACE))
			_steer.rpc_id(1, target_angle, request_boost, pending_skill and not paused)
			pending_skill = false
			sent_inputs += 1
		if not player.alive:
			client_death_elapsed += delta
			if client_death_elapsed > 1.1:
				end_game(false)

func _process(delta: float) -> void:
	if room_mode == "client" and room_ready:
		var factor := 1.0 - exp(-delta * 18.0)
		for id in targets:
			var row: Array = targets[id]
			var snake: SnakeModel = snakes[int(id)]
			snake.position = snake.position.lerp(row[1], factor)
			snake.heading = lerp_angle(snake.heading, float(row[2]), factor)
			var remote_segments: PackedVector2Array = row[13]
			if snake.segments.size() != remote_segments.size():
				snake.segments = remote_segments
			else:
				for i in range(remote_segments.size()):
					snake.segments[i] = snake.segments[i].lerp(remote_segments[i], factor)
		super._process(delta)
	else:
		super._process(delta)

func use_skill() -> void:
	if room_mode == "client":
		if room_ready and not paused and not ended:
			pending_skill = true
	else:
		super.use_skill()

func end_game(abandoned: bool) -> void:
	if room_mode != "client":
		super.end_game(abandoned)
		return
	if ended:
		return
	ended = true
	var survived := maxf(0.0, elapsed - client_started_at)
	finished.emit({"score":player.score,"kills":player.kills,"energy":player.collected,"time":survived,"survived":survived,"abandoned":abandoned})

func pack_snapshot() -> Dictionary:
	var rows: Array = []
	for snake in snakes:
		rows.append([snake.id, snake.position, snake.heading, snake.skin, snake.nickname, snake.mass, snake.score, snake.kills, snake.collected, snake.alive, snake.cooldown, snake.active_time, snake.boosting, snake.segments, snake.shield, snake.invulnerable, snake.slow_time])
	return {"t": elapsed, "snakes": rows}

func send_snapshot(target_peer: int = 0) -> void:
	# Stay below ENet MTU, including RPC metadata; lost frames are replaced next tick.
	var bytes := var_to_bytes(pack_snapshot()).compress(FileAccess.COMPRESSION_DEFLATE)
	var count := ceili(float(bytes.size()) / 950.0)
	sequence += 1
	for index in range(count):
		var chunk := bytes.slice(index * 950, mini((index + 1) * 950, bytes.size()))
		if target_peer > 0:
			_snapshot_chunk.rpc_id(target_peer, sequence, index, count, chunk)
		else:
			_snapshot_chunk.rpc(sequence, index, count, chunk)

@rpc("authority", "call_remote", "unreliable", 2)
func _snapshot_chunk(frame: int, index: int, count: int, chunk: PackedByteArray) -> void:
	if room_mode != "client" or frame <= last_sequence or count < 1 or count > 64 or index < 0 or index >= count or chunk.size() > 950:
		return
	if not pending_frames.has(frame):
		if pending_frames.size() >= 3:
			pending_frames.erase(pending_frames.keys().min())
		pending_frames[frame] = {}
	var pieces: Dictionary = pending_frames[frame]
	pieces[index] = chunk
	if pieces.size() == count:
		var bytes := PackedByteArray()
		for part in range(count):
			if not pieces.has(part):
				return
			bytes.append_array(pieces[part])
		var decoded: Variant = bytes_to_var(bytes.decompress_dynamic(262144, FileAccess.COMPRESSION_DEFLATE))
		if decoded is Dictionary:
			_snapshot(decoded)
			last_sequence = frame
		for old in pending_frames.keys():
			if int(old) <= frame:
				pending_frames.erase(old)

func _snapshot(packet: Dictionary) -> void:
	if room_mode != "client" or not room_ready:
		return
	var rows: Array = packet.get("snakes", [])
	if rows.size() != snakes.size() or rows.size() > 16:
		return
	for row: Array in rows:
		if row.size() != 17 or int(row[0]) < 0 or int(row[0]) >= snakes.size() or not row[13] is PackedVector2Array or row[13].size() > 160:
			return
		var id := int(row[0])
		var snake: SnakeModel = snakes[id]
		if id == assigned_slot:
			if int(row[6]) > snake.score and pickup_sound_delay <= 0.0:
				play_effect("collect")
				pickup_sound_delay = 0.12
			if bool(row[12]) and not snake.boosting:
				play_effect("boost")
			if float(row[11]) > snake.active_time + 0.2:
				play_effect("ability")
		snake.skin = clampi(int(row[3]), 0, 7)
		snake.nickname = str(row[4]).left(18)
		snake.mass = float(row[5])
		snake.score = int(row[6])
		snake.kills = int(row[7])
		snake.collected = int(row[8])
		snake.alive = bool(row[9])
		snake.cooldown = float(row[10])
		snake.active_time = float(row[11])
		snake.boosting = bool(row[12])
		snake.shield = bool(row[14])
		snake.invulnerable = float(row[15])
		snake.slow_time = float(row[16])
		targets[id] = row
	elapsed = float(packet.get("t", elapsed))
	received_snapshots += 1

func food_signature(food: Dictionary) -> Array:
	return [food.p, food.v, food.active, food.kind]

func pack_food(index: int, food: Dictionary) -> Array:
	return [index, food.p, food.v, food.kind, food.active]

@rpc("authority", "call_remote", "reliable", 3)
func _food_updates(updates: Array, initial: bool) -> void:
	if room_mode != "client" or updates.size() > 1500:
		return
	if initial:
		foods.clear()
	for row: Array in updates:
		if row.size() != 5:
			continue
		var index := int(row[0])
		if index < 0 or index >= 1500:
			continue
		while foods.size() <= index:
			foods.append({"p": Vector2.ZERO, "v": 0, "kind": 0, "active": false, "respawn": 0.0})
		foods[index] = {"p": row[1], "v": int(row[2]), "kind": int(row[3]), "active": bool(row[4]), "respawn": 0.0}
		sync_food_visual(index)
	if initial:
		invalidate_food_visuals()

func draw_hud(size: Vector2) -> void:
	super.draw_hud(size)
	if not room_ready and not ended:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.06, 0.84))
		centered(size * 0.5, "CONNECTING TO ROOM…", 28, Color("8feaff"))
	else:
		if room_mode == "host":
			text(Vector2(22, 187), host_connection_hint, 13, Color("6df0be"))
			text(Vector2(22, 207), "HOST · %d/4 PLAYERS" % (guest_slots.size() + 1), 11, Color("92b9c9"))
		else:
			text(Vector2(22, 187), "ONLINE · CONNECTED", 13, Color("6df0be"))

func _exit_tree() -> void:
	if peer != null:
		peer.close()
	if is_inside_tree():
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	super._exit_tree()
