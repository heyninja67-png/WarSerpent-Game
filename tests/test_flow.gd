extends SceneTree
## Real SceneTree integration; isolated user data is enforced by the launcher.
## Run: XDG_DATA_HOME=/tmp/warserpent-flow godot --headless --path . --script tests/test_flow.gd

var passed := 0
var failed := 0
var app: Control
var restart_profile: RefCounted

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + description)
	else:
		failed += 1
		push_error("FAIL: " + description)

func descendants(node: Node, type_name: String) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child.is_class(type_name):
			result.append(child)
		result.append_array(descendants(child, type_name))
	return result

func find_button(caption: String, under: Node = null) -> Button:
	if under == null:
		under = app
	for item in descendants(under, "Button"):
		if item.text == caption and not item.is_queued_for_deletion():
			return item
	return null

func press(caption: String, under: Node = null) -> bool:
	var found := find_button(caption, under)
	check(found != null, "functional button exists: " + caption)
	if found:
		found.pressed.emit()
	return found != null

func all_buttons_in_canvas(canvas_size: Vector2 = Vector2(1280,720)) -> bool:
	for item in descendants(app.screen, "Button"):
		if item.is_queued_for_deletion():
			continue
		var rect: Rect2 = item.get_global_rect()
		if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > canvas_size.x + 1 or rect.end.y > canvas_size.y + 1:
			print("OUTSIDE: ", item.text, " ", rect)
			return false
	return true

func touch(index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	# Input.parse_input_event accepts physical window coordinates. Headless
	# windows are64x64, so include the project's stretch/letterbox transform.
	event.position = root.get_final_transform() * at
	event.pressed = down
	# Inject through Godot's input dispatcher, including the root full-screen
	# Control and GUI propagation; do not call the arena handler directly.
	Input.parse_input_event(event)

func run() -> void:
	var user_dir := OS.get_user_data_dir()
	if not user_dir.begins_with("/tmp/warserpent-flow"):
		push_error("Use isolated XDG_DATA_HOME=/tmp/warserpent-flow[-suffix] to protect developer data: " + user_dir)
		quit(2)
		return
	for path in ["user://profile.json", "user://profile.json.bak", "user://profile.json.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	seed(913)
	app = load("res://scenes/Main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(app.current_page == "boot", "startup begins with Emnio splash")
	check(app.boot_active, "resource loading is active")
	check(app.boot_done <= app.boot_paths.size(), "loading counters reflect actual resource jobs")
	await create_timer(4.6).timeout
	check(app.current_page == "menu", "splash/loading reaches menu")
	check(app.boot_done == app.boot_paths.size() and app.boot_done > 0, "all real resource jobs finish")
	check(app.profile.catalog.size() == 5, "five skin definitions loaded")
	check(all_buttons_in_canvas(), "menu controls fit1280x720 canvas")
	press("COBRAS")
	await process_frame
	check(app.current_page == "collection", "collection opens")
	check(descendants(app.overlay,"SerpentPreview").size() == 0 or descendants(app.overlay,"Control").size() >= 5, "collection populates skin card controls")
	check(all_buttons_in_canvas(), "collection controls fit canvas")
	press("150 COINS")
	await process_frame
	var dialogs := descendants(app,"ConfirmationDialog")
	check(dialogs.size() == 1, "buy action opens genuine purchase confirmation")
	if dialogs.size() == 1:
		dialogs[0].confirmed.emit()
	await process_frame
	check(app.profile.data.owned.has(1), "confirmed purchase grants Inferno skin")
	check(app.profile.data.coins == 350, "confirmed purchase deducts150 real coins")
	var equip_buttons: Array = []
	for item in descendants(app.overlay,"Button"):
		if item.text == "EQUIPAR":
			equip_buttons.append(item)
	check(equip_buttons.size() == 1, "only owned unequipped skin exposes equip action")
	if equip_buttons.size() == 1:
		equip_buttons[0].pressed.emit()
	await process_frame
	check(app.profile.data.equipped == 1, "equip button changes persisted selected skin")
	press("VOLTAR")
	await process_frame
	press("LOJA")
	await process_frame
	check(app.current_page == "shop", "shop navigation opens market")
	press("VOLTAR")
	await process_frame
	press("MISSÕES")
	await process_frame
	check(find_button("RESGATAR") != null, "missions expose real reward actions")
	var coins_before := int(app.profile.data.coins)
	press("RESGATAR")
	check(app.profile.data.coins == coins_before, "unfinished mission cannot pay reward")
	press("VOLTAR")
	await process_frame
	press("RECOMPENSAS")
	await process_frame
	coins_before = int(app.profile.data.coins)
	var gems_before := int(app.profile.data.gems)
	var fragments_before := int(app.profile.data.fragments)
	press("ABRIR CARGA")
	check(app.profile.data.coins == coins_before + 75 and app.profile.data.gems == gems_before + 3 and app.profile.data.fragments == fragments_before + 2, "daily reward pays documented75 coins3 gems2 fragments")
	press("ABRIR CARGA")
	check(app.profile.data.coins == coins_before + 75, "daily reward cannot be claimed twice")
	press("VOLTAR")
	await process_frame
	press("RANKING")
	await process_frame
	check(app.overlay != null, "local ranking opens")
	press("VOLTAR")
	await process_frame
	press("CONQUISTAS")
	await process_frame
	check(app.profile.achievements().size() == 4, "achievement screen uses four real progress objectives")
	press("VOLTAR")
	await process_frame
	press("AJUSTES")
	await process_frame
	var toggles := descendants(app.overlay,"CheckButton")
	check(toggles.size() == 1, "settings has sound toggle")
	if toggles.size() == 1:
		toggles[0].button_pressed = false
	check(not app.profile.data.settings.sound and not app.music.playing, "sound toggle stops music and persists preference")
	var qualities := descendants(app.overlay,"OptionButton")
	check(qualities.size() == 1,"graphics quality selector exists")
	if qualities.size() == 1:
		qualities[0].item_selected.emit(1)
	check(app.profile.data.settings.quality == "Baixo" and Engine.max_fps == 30,"low quality applies30 FPS target")
	press("CRÉDITOS E LICENÇAS")
	await process_frame
	var credits_text := descendants(app.overlay,"RichTextLabel")
	check(credits_text.size() == 1 and "Permission is hereby granted" in credits_text[0].text,"standalone app exposes Godot MIT license and attribution")
	press("VOLTAR")
	await process_frame
	press("PILOTO  /  NV. 1")
	await process_frame
	var names := descendants(app.overlay,"LineEdit")
	check(names.size() == 1, "profile name editor exists")
	if names.size() == 1:
		names[0].text = "NOVA TEST"
	press("SALVAR NOME")
	await process_frame
	check(app.profile.data.name == "NOVA TEST", "profile editor saves name")
	press("VOLTAR")
	await process_frame
	press("JOGAR   ›")
	await process_frame
	check(app.current_page == "game" and is_instance_valid(app.game),"play starts actual arena")
	var arena: Node2D = app.game
	check(arena.player.skin == 1,"equipped Inferno skin reaches gameplay")
	check(arena.player.nickname == "NOVA TEST","profile name reaches gameplay")
	check(arena.foods.size() >= 500 and arena.snakes.size() >= 7,"arena initializes real food and bots")
	var start_position: Vector2 = arena.player.position
	await create_timer(0.3).timeout
	check(arena.player.position.distance_to(start_position) > 30,"snake continuously moves through physics updates")
	var old_score: int = arena.player.score
	arena.foods[0].p = arena.player.position + Vector2.from_angle(arena.player.heading) * 8
	arena.foods[0].v = 8
	arena.foods[0].active = true
	arena.rebuild_food_grid()
	await create_timer(0.1).timeout
	check(arena.player.score >= old_score + 8,"arena collision with energy collects and grows score")
	var viewport_size: Vector2 = arena.get_viewport_rect().size
	touch(0,arena.joystick_center(viewport_size)+Vector2(40,-20),true)
	await process_frame
	touch(1,arena.boost_center(viewport_size),true)
	await create_timer(0.2).timeout
	check(arena.joystick_id == 0 and arena.boost_id == 1 and arena.player.boosting,"simultaneous Android joystick and boost remain active")
	touch(2,arena.skill_center(viewport_size),true)
	await process_frame
	check(arena.player.cooldown > 0 and arena.player.active_time > 0,"third simultaneous touch activates real ability cooldown")
	touch(0,Vector2.ZERO,false)
	touch(1,Vector2.ZERO,false)
	touch(2,Vector2.ZERO,false)
	await process_frame
	check(arena.joystick_id == -1 and arena.boost_id == -1,"touch release clears both control owners")
	arena.handle_interface_click(Vector2(viewport_size.x-45,40),viewport_size)
	check(arena.paused,"pause button pauses arena simulation")
	var paused_position: Vector2 = arena.player.position
	await create_timer(0.15).timeout
	check(arena.player.position == paused_position,"paused simulation stops movement")
	arena.handle_interface_click(viewport_size/2+Vector2(0,25),viewport_size)
	check(not arena.paused,"continue button resumes gameplay")
	# Hit the actual marked world boundary, bypassing spawn protection consistently.
	arena.player.position = Vector2(arena.BOUNDS+5,0)
	await create_timer(1.3).timeout
	check(app.current_page == "results","lethal arena boundary reaches results after defeat effect")
	check(app.profile.data.stats.runs == 1,"defeat commits exactly one completed run")
	check(float(app.profile.data.stats.survival) > 0.5,"survival time crosses gameplay/profile API")
	check(app.profile.data.best_score >= 8,"collected score updates persistent record")
	check(int(app.reward.coins) >= 10 and int(app.reward.xp) >= 15,"real results grant economy and XP rewards")
	check(all_buttons_in_canvas(),"results controls fit canvas")
	press("JOGAR NOVAMENTE")
	await process_frame
	check(app.current_page == "game" and app.game.player.alive,"restart starts fresh playable snake")
	app.game.end_game(true)
	await process_frame
	check(app.current_page == "menu","abandon returns to menu")
	check(app.profile.data.stats.runs == 1,"abandon cannot farm completed-run rewards")
	restart_profile = load("res://scripts/core/Profile.gd").new()
	check(restart_profile.load_profile(),"new profile object reloads saved state")
	check(restart_profile.data.name == "NOVA TEST" and restart_profile.data.equipped == 1 and restart_profile.data.owned.has(1),"name inventory and equipped skin persist after reopen")
	check(restart_profile.data.best_score == app.profile.data.best_score and restart_profile.data.coins == app.profile.data.coins,"economy and record persist after reopen")
	check(restart_profile.data.settings.quality == "Baixo" and not restart_profile.data.settings.sound,"graphics and audio preferences persist after reopen")
	# Keep-aspect project canvas remains1280x720 when physical window changes aspect.
	root.size = Vector2i(1600,720)
	await process_frame
	check(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep","wide phones retain complete canvas with aspect preservation")
	app.queue_free()
	await process_frame
	print("FLOW RESULT: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
