extends SceneTree
## Real scene integration. User data must be isolated with XDG_DATA_HOME.
## godot --headless --audio-driver Dummy --path . --script tests/test_flow.gd

var passed := 0
var failed := 0
var app: Control
var ui_stress_complete := false

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
		if child.is_queued_for_deletion():
			continue
		if child.is_class(type_name):
			result.append(child)
		result.append_array(descendants(child, type_name))
	return result

func find_button(caption: String, under: Node = null) -> Button:
	if under == null:
		under = app
	for item in descendants(under, "Button"):
		if item.text == caption:
			return item
	return null

func press(caption: String, under: Node = null) -> bool:
	var found := find_button(caption, under)
	check(found != null, "functional button exists: " + caption)
	if found:
		found.pressed.emit()
	return found != null

func has_label(text: String, node: Node = null) -> bool:
	if node == null:
		node = app
	for label in descendants(node,"Label"):
		if label.text == text:
			return true
	return false

func previews(node: Node) -> Array:
	var result: Array = []
	for control in descendants(node,"Control"):
		if control.get_script() == load("res://scripts/ui/SerpentPreview.gd"):
			result.append(control)
	return result

func controls_in_view() -> bool:
	var viewport_size: Vector2 = root.get_visible_rect().size
	for item in descendants(app.screen, "Button"):
		var rect: Rect2 = item.get_global_rect()
		if rect.position.x < -1 or rect.position.y < -1 or rect.end.x > viewport_size.x+1 or rect.end.y > viewport_size.y+1:
			print("OUTSIDE: ", item.text, " ", rect, " viewport ", viewport_size)
			return false
	return true

func english_page() -> bool:
	for label in descendants(app.screen,"Label") + descendants(app.screen,"Button"):
		var value: String = label.text.to_lower()
		for phrase in ["jogar", "moedas", "resgatar", "inicializando", "carregando", "conexão perdida", "sinal perdido", "recursos preparados", "eliminação", "configurações", "cobras"]:
			if value.contains(phrase):
				print("UNTRANSLATED: ",label.text)
				return false
	return true

func touch(index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	# Input.parse_input_event accepts physical coordinates, including on a
	#64px headless window. Apply the project's current stretch transform.
	event.position = root.get_final_transform() * at
	event.pressed = down
	Input.parse_input_event(event)

func mouse_button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	Input.parse_input_event(event)

func mouse_motion(at: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)

func tap_button(caption: String, use_mouse: bool = false) -> bool:
	var scope: Node = app.overlay if is_instance_valid(app.overlay) else app.screen
	var found := find_button(caption,scope)
	check(found != null and found.is_visible_in_tree(),"real pointer target is available: " + caption)
	if found == null:
		return false
	var point: Vector2 = found.get_global_rect().get_center()
	if use_mouse:
		mouse_button(point,true)
		mouse_button(point,false)
	else:
		touch(0,point,true)
		touch(0,point,false)
	await process_frame
	return true

func text_bounds(label: Label) -> Rect2:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var content := label.size
	var offset := Vector2.ZERO
	if label.has_theme_stylebox_override("normal"):
		var style: StyleBox = label.get_theme_stylebox("normal")
		offset = Vector2(style.get_content_margin(SIDE_LEFT),style.get_content_margin(SIDE_TOP))
		content -= offset+Vector2(style.get_content_margin(SIDE_RIGHT),style.get_content_margin(SIDE_BOTTOM))
	var wrap_width := content.x if label.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
	var measured: Vector2 = font.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,wrap_width,font_size)
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		offset.x += maxf(0.0,(content.x-measured.x)*0.5)
	elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		offset.x += maxf(0.0,content.x-measured.x)
	if label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		offset.y += maxf(0.0,(content.y-measured.y)*0.5)
	elif label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		offset.y += maxf(0.0,content.y-measured.y)
	return label.get_global_transform()*Rect2(offset,measured)

func geometry_valid(stage: String) -> bool:
	var valid := true
	var important: Array = []
	for control in descendants(app.screen,"Control"):
		if not control.is_visible_in_tree():
			continue
		if control is Label and not control.text.is_empty():
			var glyphs := text_bounds(control)
			var allocation: Rect2 = control.get_global_rect().grow(1.5)
			if not allocation.encloses(glyphs):
				print("CLIPPED TEXT ",stage,": ",control.text," glyphs=",glyphs," allocation=",allocation)
				valid = false
			important.append({"node":control,"rect":glyphs,"name":control.text})
		elif control is Button:
			important.append({"node":control,"rect":control.get_global_rect(),"name":control.text})
	for i in range(important.size()):
		for j in range(i+1,important.size()):
			var a: Dictionary = important[i]
			var b: Dictionary = important[j]
			if a.node.is_ancestor_of(b.node) or b.node.is_ancestor_of(a.node):
				continue
			if a.rect.intersection(b.rect).get_area() > 5.0:
				print("OVERLAP ",stage,": ",a.name," / ",b.name," ",a.rect.intersection(b.rect))
				valid = false
	return valid

func artwork_covers_viewport() -> bool:
	return app.background.get_global_rect().encloses(root.get_visible_rect())

func popup_fits(dialog: Window) -> bool:
	var origin := Vector2(dialog.position)
	if not dialog.is_embedded():
		origin -= Vector2(root.position)
	var bounds := Rect2(origin,Vector2(dialog.size))
	return Rect2(Vector2.ZERO,Vector2(root.size)).grow(1.0).encloses(bounds)

func retired(node: Variant) -> bool:
	if not is_instance_valid(node) or node.get_parent() == null:
		return true
	# Safe retirement during a GUI callback hides and blocks a layer immediately,
	# then lets Godot finish the input dispatch before freeing it at frame end.
	return not node.is_visible_in_tree() and node.mouse_filter == Control.MOUSE_FILTER_IGNORE and node.process_mode == Node.PROCESS_MODE_DISABLED

func check_hud_regions(arena: Node2D) -> void:
	var size: Vector2 = arena.get_viewport_rect().size
	var regions := [
		arena.minimap_state().bounds,
		Rect2(arena.joystick_center(size)-Vector2.ONE*77,Vector2.ONE*154),
		Rect2(arena.boost_center(size)-Vector2.ONE*62,Vector2.ONE*124),
		Rect2(arena.skill_center(size)-Vector2.ONE*44,Vector2.ONE*88),
		Rect2(arena.boost_secondary_center(size)-Vector2.ONE*44,Vector2.ONE*88),
		Rect2(size.x-69,19,48,44)]
	var contained := true
	var separated := true
	for i in range(regions.size()):
		contained = contained and Rect2(Vector2.ZERO,size).encloses(regions[i])
		for j in range(i+1,regions.size()):
			separated = separated and regions[i].intersection(regions[j]).get_area() < 1.0
	check(contained,"important HUD interaction areas stay within the canvas")
	check(separated,"minimap joystick power boost and pause areas do not overlap")

func ui_stress() -> void:
	var stable_coins: int = app.profile.data.coins
	var stable_runs: int = app.profile.data.stats.runs
	var original_equipped: int = app.profile.data.equipped
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	await process_frame
	app.show_menu()
	await create_timer(0.45).timeout
	check(geometry_valid("lobby"),"lobby text and important controls are neither clipped nor overlapping")
	var mode_button := find_button("OFFLINE")
	var arena_title: Label = null
	for item in descendants(app.screen,"Label"):
		if item.is_visible_in_tree() and item.text == "NEON CITY":
			arena_title = item
	check(mode_button != null and arena_title != null and mode_button.get_global_rect().end.y <= arena_title.get_global_rect().position.y,"mode button's actual theme height does not overlap the arena title")
	var start := find_button("START")
	var start_point: Vector2 = start.get_global_rect().get_center()
	mouse_motion(start_point)
	await create_timer(0.17).timeout
	check(start.scale.x > 1.001 and controls_in_view(),"actual hover animates START without moving it out of bounds")
	mouse_button(start_point,true)
	await create_timer(0.06).timeout
	check(start.scale.x < 1.0,"press transition interrupts hover and visibly depresses START")
	mouse_motion(Vector2(900,110),true)
	mouse_button(Vector2(900,110),false)
	await create_timer(0.2).timeout
	check(app.current_page == "menu" and start.scale.is_equal_approx(Vector2.ONE),"dragging out and releasing restores START without starting a game")
	var same_hero: Control = app.preview
	for id in [0,1,0,1]:
		var cell: Button = app.collection_cells[id]
		var point := cell.get_global_rect().get_center()
		mouse_button(point,true)
		mouse_button(point,false)
	await create_timer(0.4).timeout
	check(app.preview == same_hero and app.preview.skin_id == 1 and app.profile.data.equipped == 1,"rapid owned-skin clicks reuse one hero and finish on the last actual selection")
	check(app.profile.data.coins == stable_coins and app.profile.data.stats.runs == stable_runs,"skin transition animations cannot grant or spend rewards")
	for caption in ["SHOP","MISSIONS","REWARDS","SETTINGS"]:
		await tap_button(caption,caption == "SETTINGS")
		var page: Control = app.overlay
		check(is_instance_valid(page) and not app.preview.is_visible_in_tree(),"modal " + caption + " hides and blocks the underlying lobby")
		check(geometry_valid("entrance " + caption),caption + " entrance keeps text and controls separate")
		await tap_button("BACK")
		check(retired(page),"BACK retires " + caption + " before another page can receive input")
	await tap_button("SHOP")
	await create_timer(0.4).timeout
	var equipped_button := find_button("EQUIPPED",app.overlay)
	check(equipped_button != null and equipped_button.get_parent().get_global_rect().encloses(equipped_button.get_global_rect()),"EQUIPPED button's actual theme height fits inside its skin card")
	var first_page: Control = app.overlay
	app.change_collection_page(1,2,true)
	var sliding_page: Control = app.overlay
	app.show_settings()
	check(retired(first_page) and retired(sliding_page),"interrupting pagination immediately hides and blocks both old modal layers")
	await create_timer(0.35).timeout
	check(app.current_page == "settings" and geometry_valid("interrupted page"),"interrupted page tweens cannot resurrect or overlap the current settings page")
	await tap_button("BACK")
	await tap_button("SHOP")
	await tap_button("›")
	var preserved_page: Control = app.overlay
	root.size = Vector2i(1600,720)
	await create_timer(0.15).timeout
	check(app.overlay == preserved_page and app.collection_page == 1,"live resize preserves the active collection page without rebuilding it")
	check(artwork_covers_viewport() and controls_in_view() and geometry_valid("wide active shop"),"live wide resize keeps artwork text and controls within the active viewport")
	await tap_button("BACK")
	await tap_button("%s  /  LV. %d" % [app.profile.data.name,app.profile.data.level])
	var edits := descendants(app.overlay,"LineEdit")
	var edit: LineEdit = edits[0]
	edit.text = "UNSAVED INPUT"
	var form: Control = app.overlay
	root.size = Vector2i(1280,900)
	await create_timer(0.15).timeout
	check(app.overlay == form and is_instance_valid(edit) and edit.text == "UNSAVED INPUT","live tall resize preserves unsaved form input and its existing control")
	check(artwork_covers_viewport() and controls_in_view() and geometry_valid("tall profile"),"live tall resize keeps the open form and its text fully visible")
	root.size = Vector2i(1280,720)
	await create_timer(0.15).timeout
	await tap_button("BACK")
	app.collection_page = 0
	await tap_button("SHOP")
	await tap_button("250 COINS")
	var dialog: ConfirmationDialog = app.purchase_dialog
	check(is_instance_valid(dialog) and popup_fits(dialog),"purchase confirmation fits within the current physical window")
	root.size = Vector2i(1600,720)
	await create_timer(0.15).timeout
	check(app.purchase_dialog == dialog and popup_fits(dialog),"live resize recenters the same purchase dialog inside the window")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	check(not is_instance_valid(app.purchase_dialog) and app.current_page == "shop","Android Back dismisses a purchase dialog before leaving its market page")
	await tap_button("250 COINS")
	var obsolete_dialog: ConfirmationDialog = app.purchase_dialog
	app.show_menu()
	if is_instance_valid(obsolete_dialog):
		obsolete_dialog.confirmed.emit()
	await process_frame
	check(not is_instance_valid(obsolete_dialog) and not app.profile.data.owned.has(2) and app.profile.data.coins == stable_coins,"navigation removes purchase popups and rejects a stale confirmation callback")
	app.toast("Interface check")
	check(not app.toast_label.get_global_rect().intersects(find_button("START").get_global_rect()),"lobby notice cannot cover START")
	await tap_button("SHOP")
	app.toast("Interface check")
	var notice_rect: Rect2 = app.toast_label.get_global_rect()
	var covers_purchase := false
	for item in descendants(app.overlay,"Button"):
		if item.text.ends_with("COINS"):
			covers_purchase = covers_purchase or notice_rect.intersects(item.get_global_rect())
	check(not covers_purchase and geometry_valid("shop notice"),"shop notice does not cover purchase controls or important text")
	await tap_button("BACK")
	var preserved_best: int = app.profile.data.best_score
	app.profile.data.coins = 2000000000
	app.profile.data.best_score = 12345678
	app.show_menu()
	await create_timer(0.5).timeout
	check(has_label("2000000000") and has_label("12345678") and geometry_valid("large exact values"),"large real menu values remain exact and fit their labels")
	app.profile.data.coins = stable_coins
	app.profile.data.best_score = preserved_best
	app.profile.equip_skin(original_equipped)
	app.show_menu()
	check(app.profile.data.stats.runs == stable_runs and app.profile.data.coins == stable_coins,"all UI navigation and display animations preserve real economy and completed runs")
	ui_stress_complete = true

func check_power_timings() -> void:
	var timings: Array = []
	for label in descendants(app.overlay,"Label"):
		if label.name == "PowerTiming":
			timings.append(label)
	check(timings.size() == 4,"collection page exposes four readable power timing labels")
	for label in timings:
		var card_previews := previews(label.get_parent())
		if card_previews.is_empty():
			check(false,"power timing belongs to a skin card")
			continue
		var entry: Dictionary = app.profile.catalog[card_previews[0].skin_id]
		check(label.text.contains("%.1fs" % entry.duration) and label.text.contains("%ds" % entry.cooldown),"%s card reports real duration and cooldown" % entry.name)

func check_minimap(arena: Node2D, state: Dictionary) -> void:
	var center: Vector2 = state.center
	var radius: float = state.radius
	check(radius > 30.0 and center.x-radius >= 0.0 and center.y-radius >= 0.0 and center.x < 220.0 and center.y < 200.0,"circular minimap fits the upper left of the arena")
	var player_position: Vector2 = state.player
	check(player_position.is_finite() and player_position.distance_to(center) <= radius,"minimap exposes a finite player position inside its circle")
	var valid_markers := true
	var correct_directions := true
	var player_markers := 0
	for marker in state.markers:
		var marker_position: Vector2 = marker.position
		if not marker_position.is_finite() or marker_position.distance_to(center) > radius+0.01:
			valid_markers = false
		var world_snake: RefCounted = null
		for candidate in arena.snakes:
			if int(candidate.id) == int(marker.id):
				world_snake = candidate
				break
		if world_snake == null:
			valid_markers = false
			continue
		if bool(marker.player):
			player_markers += 1
			if int(marker.id) != int(arena.player.id) or marker_position.distance_to(player_position) > 0.01:
				valid_markers = false
		var direction: Vector2 = marker_position-center
		if world_snake.position.length() > 50.0 and direction.length() > 1.0:
			if direction.normalized().dot(world_snake.position.normalized()) < 0.98:
				correct_directions = false
	check(player_markers == 1 and state.markers.size() == arena.snakes.size(),"minimap identifies the actual player and all initial opponents")
	check(valid_markers,"minimap markers use actual snake IDs and stay inside the circle")
	check(correct_directions,"minimap marker directions agree with opponents' real world positions")
	var transforms_valid: bool = arena.minimap_world_to_screen(Vector2.ZERO).is_equal_approx(center)
	for corner in [Vector2(-arena.BOUNDS,-arena.BOUNDS),Vector2(arena.BOUNDS,-arena.BOUNDS),Vector2(arena.BOUNDS,arena.BOUNDS),Vector2(-arena.BOUNDS,arena.BOUNDS)]:
		var mapped: Vector2 = arena.minimap_world_to_screen(corner)
		transforms_valid = transforms_valid and mapped.is_finite() and mapped.distance_to(center) <= radius
	check(transforms_valid,"actual minimap transform centers the world and keeps all arena corners visible")

func run() -> void:
	if not OS.get_user_data_dir().begins_with("/tmp/warserpent-flow"):
		push_error("Protect developer saves: set XDG_DATA_HOME=/tmp/warserpent-flow[-suffix]")
		quit(2)
		return
	for path in ["user://profile.json","user://profile.json.bak","user://profile.json.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	seed(913)
	app = load("res://scenes/Main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(app.current_page == "boot", "startup begins with custom Emnio splash")
	check(not ProjectSettings.get_setting("application/boot_splash/show_image"), "engine boot logo is disabled")
	check(ProjectSettings.get_setting("application/config/version") == "1.2.1","project reports version1.2.1")
	check(app.boot_logo.texture.resource_path.ends_with("emnio_games.png"), "first animated splash uses the new Emnio Games studio artwork")
	check(app.boot_active and app.boot_done <= app.boot_paths.size(), "loading counter measures actual resource jobs")
	check(app.boot_status.text.is_empty() and not app.boot_status.visible, "splash contains no loading status phrases")
	await create_timer(2.8).timeout
	check(app.current_page == "menu", "short splash reaches menu")
	check(app.boot_done == app.boot_paths.size() and app.boot_done == 28, "all24 snake sprite jobs and4 shared resources finish")
	check(app.profile.catalog.size() == 8, "eight distinct serpent definitions load")
	check(previews(app.screen).size() == 1,"menu has one animated equipped serpent")
	check(app.music.stream is AudioStreamOggVorbis and app.music.stream.loop,"menu uses actual looping Ogg music")
	check(app.music.playing,"menu music plays by default")
	check(controls_in_view(), "menu controls fit current viewport")
	check(english_page(),"menu presents English text")
	press("CHANGE SERPENT")
	await process_frame
	check(app.current_page == "collection","CHANGE SERPENT toolbar opens the real collection")
	press("BACK")
	await process_frame
	var skin_cells: Array = []
	for candidate in descendants(app.screen,"Button"):
		if candidate.tooltip_text in ["Volt Serpent","Inferno Viper","Frost Fang","Cyber Reaper","Shadow Phantom","Solar Wyrm","Neon Samurai","Toxic Fang"]:
			skin_cells.append(candidate)
	check(skin_cells.size() == 8,"lobby collection rail exposes all eight actual skins")
	for candidate in skin_cells:
		if candidate.tooltip_text == "Toxic Fang":
			candidate.pressed.emit()
	await process_frame
	check(app.current_page == "shop" and app.collection_page == 1 and previews(app.overlay)[3].skin_id == 7,"locked rail skin opens its actual market page")
	press("‹",app.overlay)
	await process_frame
	press("BACK")
	await process_frame
	var animated_preview: Control = previews(app.screen)[0]
	var preview_clock: float = animated_preview.clock
	var preview_pose: Vector2 = animated_preview.point_at(0.6)
	check(animated_preview.hero_pose,"lobby presents the equipped serpent in its animated hero pose")
	var hero_center: Vector2 = animated_preview.get_global_rect().get_center()-app.screen.global_position
	check(hero_center.x > app.screen.size.x*0.4 and hero_center.x < app.screen.size.x*0.7,"selected serpent occupies the center of the lobby")
	var feature_columns: Array[float] = []
	for feature in ["SHOP","MISSIONS","REWARDS","RECORDS","ACHIEVEMENTS"]:
		var feature_button := find_button(feature)
		if feature_button != null:
			feature_columns.append(feature_button.get_global_rect().get_center().x-app.screen.global_position.x)
	check(feature_columns.size() == 5 and feature_columns.max() < app.screen.size.x*0.3,"all five functional features occupy the lobby's left column")
	var start_button := find_button("START")
	check(start_button != null,"lobby exposes the real START action")
	if start_button != null:
		var start_center: Vector2 = start_button.get_global_rect().get_center()-app.screen.global_position
		check(start_center.x > app.screen.size.x*0.65 and start_center.y > app.screen.size.y*0.65,"START action occupies the lobby's lower right")
	var atmosphere: Node = app.screen.get_node_or_null("Atmosphere")
	check(atmosphere != null,"menu has an animated atmospheric layer")
	var atmosphere_phase: float = float(atmosphere.phase) if atmosphere != null else -1.0
	await create_timer(0.35).timeout
	check(animated_preview.clock > preview_clock and animated_preview.point_at(0.6).distance_to(preview_pose) > 0.05,"equipped lobby serpent visibly changes pose over time")
	if atmosphere != null:
		check(float(atmosphere.phase) > atmosphere_phase,"ambient animation advances while menu is visible")
	var collection_button := find_button("SERPENTS")
	check(collection_button != null,"functional button exists: SERPENTS")
	if collection_button != null:
		var point: Vector2 = collection_button.get_global_rect().get_center()
		mouse_button(point,true)
		await create_timer(0.12).timeout
		check(collection_button.scale.x < 0.995,"dispatched pointer press produces visible button feedback")
		check(controls_in_view(),"button feedback keeps controls inside viewport")
		mouse_button(point,false)
	await process_frame
	check(app.current_page == "collection", "collection opens")
	check(previews(app.overlay).size() == 4,"collection renders four previews per page")
	check(previews(app.overlay)[0].skin_id == 0 and previews(app.overlay)[3].skin_id == 3,"first collection page contains skins0 through3")
	check(controls_in_view(),"first collection page stays inside screen")
	check(geometry_valid("collection first page"),"first collection page text and controls neither clip nor overlap")
	check_power_timings()
	press("›",app.overlay)
	await process_frame
	check(app.collection_page == 1,"next button changes collection page")
	check(previews(app.overlay).size() == 4 and previews(app.overlay)[0].skin_id == 4 and previews(app.overlay)[3].skin_id == 7,"second page exposes all four additional skins")
	check(controls_in_view() and english_page(),"second page fits screen and uses English descriptions")
	check(geometry_valid("collection second page"),"all additional skin cards keep text and controls separate")
	check_power_timings()
	press("‹",app.overlay)
	await process_frame
	press("150 COINS",app.overlay)
	await process_frame
	var dialogs := descendants(app,"ConfirmationDialog")
	check(dialogs.size() == 1,"purchase opens genuine confirmation dialog")
	if dialogs.size() == 1:
		check(dialogs[0].ok_button_text == "UNLOCK" and dialogs[0].cancel_button_text == "CANCEL","purchase confirmation is English")
		dialogs[0].confirmed.emit()
	await process_frame
	check(app.profile.data.owned.has(1) and app.profile.data.coins == 350,"confirmed purchase grants skin and deducts150 coins")
	press("EQUIP",app.overlay)
	await process_frame
	check(app.profile.data.equipped == 1,"equip changes persisted selected skin")
	var filters := descendants(app.overlay,"OptionButton")
	if not filters.is_empty():
		filters[0].item_selected.emit(1)
	await process_frame
	check(previews(app.overlay).size() == 2,"Owned filter displays purchased skins only")
	filters = descendants(app.overlay,"OptionButton")
	if not filters.is_empty():
		filters[0].item_selected.emit(2)
	await process_frame
	check(previews(app.overlay).size() == 4 and previews(app.overlay)[0].skin_id == 2,"Locked filter excludes owned skins and paginates remainder")
	filters = descendants(app.overlay,"OptionButton")
	if not filters.is_empty():
		filters[0].item_selected.emit(0)
	await process_frame
	press("BACK")
	await process_frame
	press("SHOP")
	await process_frame
	check(app.current_page == "shop" and english_page(),"shop opens functional English market")
	press("BACK")
	await process_frame
	press("MISSIONS")
	await process_frame
	check(find_button("CLAIM") != null and english_page(),"English missions expose real reward actions")
	var coins_before := int(app.profile.data.coins)
	press("CLAIM")
	check(app.profile.data.coins == coins_before,"unfinished mission cannot pay reward")
	press("BACK")
	await process_frame
	press("REWARDS")
	await process_frame
	coins_before = int(app.profile.data.coins)
	var gems_before := int(app.profile.data.gems)
	var fragments_before := int(app.profile.data.fragments)
	press("OPEN CRATE")
	check(app.profile.data.coins == coins_before+75 and app.profile.data.gems == gems_before+3 and app.profile.data.fragments == fragments_before+2,"daily crate pays75 coins3 gems2 fragments")
	press("OPEN CRATE")
	check(app.profile.data.coins == coins_before+75,"daily reward cannot be claimed twice")
	press("BACK")
	await process_frame
	press("RECORDS")
	await process_frame
	check(has_label("LOCAL RECORD") and english_page(),"records screen identifies itself as local")
	check(geometry_valid("records"),"local record text and controls fit without overlap")
	press("BACK")
	await process_frame
	press("ACHIEVEMENTS")
	await process_frame
	check(app.profile.achievements().size() == 4 and english_page(),"achievement page shows real English milestones")
	check(geometry_valid("achievements"),"achievement rows and status labels neither clip nor overlap")
	press("BACK")
	await process_frame
	press("SETTINGS")
	await process_frame
	var toggles := descendants(app.overlay,"CheckButton")
	check(toggles.size() == 2,"settings exposes independent SFX and music switches")
	if toggles.size() == 2:
		toggles[0].button_pressed = false
	check(not app.profile.data.settings.sound and app.profile.data.settings.music and app.music.playing,"SFX mute leaves music playing")
	if toggles.size() == 2:
		toggles[1].button_pressed = false
	check(not app.profile.data.settings.music and not app.music.playing,"music switch independently stops music")
	if toggles.size() == 2:
		toggles[0].button_pressed = true
	check(app.profile.data.settings.sound and not app.music.playing,"SFX can be re-enabled while music remains muted")
	if toggles.size() == 2:
		toggles[0].button_pressed = false
	var qualities := descendants(app.overlay,"OptionButton")
	check(qualities.size() == 1,"quality selector exists")
	if qualities.size() == 1:
		qualities[0].item_selected.emit(1)
	check(app.profile.data.settings.quality == "Low" and Engine.max_fps == 30,"Low quality applies30 FPS target")
	check(controls_in_view() and english_page(),"settings controls fit screen and use English")
	press("CREDITS & LICENSES")
	await process_frame
	var credits := descendants(app.overlay,"RichTextLabel")
	check(credits.size() == 1,"credits opens scrollable license text")
	check(geometry_valid("credits"),"credits heading and navigation do not overlap the scrollable license body")
	if credits.size() == 1:
		check(credits[0].text.contains("Godot Engine") and credits[0].text.contains("Permission is hereby granted") and credits[0].text.contains("Bitstream"),"credits include Godot and font attribution/license")
	press("BACK")
	await process_frame
	press("PILOT  /  LV. 1")
	await process_frame
	var names := descendants(app.overlay,"LineEdit")
	check(names.size() == 1,"profile editor exposes name input")
	if names.size() == 1:
		names[0].text = "NOVA TEST"
	press("SAVE NAME")
	await process_frame
	check(app.profile.data.name == "NOVA TEST","profile editor saves name")
	press("BACK")
	await process_frame
	press("OFFLINE")
	await process_frame
	check(app.online_mode and find_button("START ONLINE") != null,"mode selector exposes actual online workflow")
	press("START ONLINE")
	await process_frame
	check(app.current_page == "online" and find_button("HOST ROOM") != null and find_button("JOIN ROOM") != null,"online page exposes host and join actions")
	check(english_page() and controls_in_view(),"online connection page is English and fits viewport")
	check(geometry_valid("online"),"online address labels and connection controls neither clip nor overlap")
	press("JOIN ROOM")
	await process_frame
	check(app.current_page == "online" and is_instance_valid(app.toast_label) and app.toast_label.text.contains("IP address"),"empty join address reports validation without fake connected state")
	# Network transport and room authentication have separate multiprocess tests.
	# These UI checks prove both buttons invoke the actual OnlineArena workflow.
	press("HOST ROOM")
	await process_frame
	check(app.current_page == "game" and is_instance_valid(app.game) and app.game.name == "OnlineArena","host button starts actual networking arena")
	if is_instance_valid(app.game):
		check(app.game.room_mode == "host" and app.game.room_ready,"host arena reports an open ENet room")
		app.game.end_game(true)
	await process_frame
	check(app.current_page == "menu","leaving hosted room returns to menu")
	check(app.profile.data.stats.runs == 0,"leaving room cannot grant farming rewards")
	app.show_online()
	await process_frame
	var addresses := descendants(app.overlay,"LineEdit")
	if not addresses.is_empty():
		addresses[0].text = "127.0.0.1"
	press("JOIN ROOM")
	await process_frame
	check(app.current_page == "game" and is_instance_valid(app.game) and app.game.room_mode == "client","join button starts actual client connection attempt")
	if is_instance_valid(app.game):
		check(not app.game.room_ready,"unreachable client does not pretend to be connected")
		app.game.end_game(true)
	await process_frame
	app.online_mode = false
	app.show_menu()
	await process_frame
	# Expand fills both wide and tall landscape displays with complete controls.
	root.mode = Window.MODE_WINDOWED
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,900)]:
		root.size = dimensions
		await process_frame
		app.show_menu()
		await process_frame
		check(controls_in_view(),"menu controls visible at physical%s" % dimensions)
		check(artwork_covers_viewport(),"animated artwork covers viewport without black bars at%s" % dimensions)
		app.show_collection(false)
		await process_frame
		check(controls_in_view(),"collection controls visible at physical%s" % dimensions)
	root.size = Vector2i(1280,720)
	await process_frame
	app.show_menu()
	await process_frame
	press("START")
	await process_frame
	check(app.current_page == "game" and is_instance_valid(app.game),"play starts actual offline arena")
	var arena: Node2D = app.game
	check(arena.player.skin == 1 and arena.player.nickname == "NOVA TEST","equipped skin and saved name reach gameplay")
	check(arena.player.segment_count() <= 16,"player starts as a short serpent rather than large adult")
	check(arena.foods.size() >= 200 and arena.snakes.size() >= 5,"arena creates real energy and bot competitors")
	check(app.music.stream.resource_path.ends_with("music_arena.ogg") and not app.music.playing,"arena music track changes while preserving independent mute")
	var initial_hud: Dictionary = arena.hud_state()
	check(initial_hud.protection_remaining > 0.0 and initial_hud.protection_remaining <= 2.0,"spawn HUD reflects actual temporary protection")
	check(initial_hud.danger == 0.0,"central spawn has no false boundary danger")
	await process_frame
	var initial_map: Dictionary = arena.minimap_state()
	check_minimap(arena,initial_map)
	check_hud_regions(arena)
	var minimap_started: float = arena.elapsed
	var start_position: Vector2 = arena.player.position
	await create_timer(0.3).timeout
	check(arena.player.position.distance_to(start_position) > 30,"snake continuously moves through physics updates")
	check(arena.hud_state().protection_remaining < initial_hud.protection_remaining,"protection indicator counts down with simulation time")
	var updated_map: Dictionary = arena.minimap_state()
	var refreshes: int = int(updated_map.refresh_count)-int(initial_map.refresh_count)
	var refresh_limit := ceili((arena.elapsed-minimap_started)/float(updated_map.refresh_interval))+1
	check(float(updated_map.refresh_interval) >= 0.1 and refreshes >= 1 and refreshes <= refresh_limit,"actual minimap refresh count respects its capped update budget")
	var updated_player_marker: Vector2 = updated_map.player
	check(updated_player_marker.distance_to(initial_map.player) > 0.1 and (updated_player_marker-Vector2(updated_map.center)).normalized().dot(arena.player.position.normalized()) > 0.98,"minimap player indicator updates with real movement in the correct direction")
	var rows: Array = arena.leaderboard_state()
	var ranks_valid := not rows.is_empty()
	var text_fits := true
	var player_rows := 0
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		ranks_valid = ranks_valid and int(row.rank) == i+1 and str(row.rank_text) == str(i+1)
		if i > 0:
			ranks_valid = ranks_valid and int(rows[i-1].score) >= int(row.score)
		if bool(row.player):
			player_rows += 1
		text_fits = text_fits and arena.font.get_string_size(str(row.name),HORIZONTAL_ALIGNMENT_LEFT,-1,12).x <= 111.0
		text_fits = text_fits and arena.font.get_string_size(str(row.score_text),HORIZONTAL_ALIGNMENT_LEFT,-1,12).x <= 44.0
	check(ranks_valid and player_rows == 1,"leaderboard renders one coherent sorted score and rank snapshot with the actual player")
	check(text_fits,"leaderboard displayed names and scores fit their assigned pixel widths")
	var old_score: int = arena.player.score
	arena.foods[0].p = arena.player.position+Vector2.from_angle(arena.player.heading)*8
	arena.foods[0].v = 8
	arena.foods[0].active = true
	arena.rebuild_food_grid()
	await create_timer(0.1).timeout
	check(arena.player.score >= old_score+8,"food collision increases real score")
	check(arena.hud_state().pickup_total >= 8 and arena.hud_state().pickup_remaining > 0.0,"real energy collection activates pickup feedback")
	var viewport_size: Vector2 = arena.get_viewport_rect().size
	touch(0,arena.joystick_center(viewport_size)+Vector2(40,-20),true)
	await process_frame
	touch(1,arena.boost_center(viewport_size),true)
	await create_timer(0.2).timeout
	check(arena.joystick_id == 0 and arena.boost_id == 1 and arena.player.boosting,"dispatcher delivers simultaneous joystick and boost touches")
	touch(2,arena.skill_center(viewport_size),true)
	await process_frame
	check(arena.player.cooldown > 0 and arena.player.active_time > 0 and arena.joystick_id == 0 and arena.boost_id == 1 and arena.skill_id == 2,"third touch activates power without dropping joystick or boost")
	check(arena.hud_state().skill_remaining > 0.0,"active ability has a live HUD duration indicator")
	touch(1,Vector2.ZERO,false)
	await process_frame
	check(arena.boost_id == -1 and arena.joystick_id == 0 and arena.skill_id == 2,"releasing boost preserves steering and ability fingers")
	touch(3,arena.boost_center(viewport_size),true)
	await process_frame
	touch(0,Vector2.ZERO,false)
	await process_frame
	check(arena.joystick_id == -1 and arena.boost_id == 3 and arena.skill_id == 2,"releasing steering preserves independent boost and ability fingers")
	touch(2,Vector2.ZERO,false)
	await process_frame
	check(arena.skill_id == -1 and arena.boost_id == 3,"releasing ability preserves held boost")
	touch(3,Vector2.ZERO,false)
	await process_frame
	check(arena.joystick_id == -1 and arena.boost_id == -1,"touch release clears control owners")
	touch(3,arena.boost_center(viewport_size),true)
	touch(4,arena.boost_secondary_center(viewport_size),true)
	await create_timer(0.06).timeout
	touch(4,Vector2.ZERO,false)
	await create_timer(0.06).timeout
	check(arena.boost_id == 3 and arena.player.boosting,"releasing center boost preserves the simultaneously held primary boost")
	touch(3,Vector2.ZERO,false)
	touch(3,arena.boost_center(viewport_size),true)
	touch(4,arena.boost_secondary_center(viewport_size),true)
	touch(3,Vector2.ZERO,false)
	await create_timer(0.06).timeout
	check(arena.boost_id == 4 and arena.player.boosting,"releasing primary boost preserves the simultaneously held center boost")
	touch(4,Vector2.ZERO,false)
	await process_frame
	touch(4,arena.boost_secondary_center(viewport_size),true)
	await physics_frame
	await process_frame
	check(arena.boost_id == 4 and arena.player.boosting,"secondary center BOOST control drives actual acceleration")
	touch(4,Vector2.ZERO,false)
	touch(0,arena.joystick_center(viewport_size)+Vector2(40,0),true)
	touch(1,arena.boost_center(viewport_size),true)
	touch(2,Vector2(viewport_size.x-45,40),true)
	touch(2,Vector2(viewport_size.x-45,40),false)
	await process_frame
	check(arena.paused,"dispatched pause touch pauses simulation")
	check(arena.joystick_id == -1 and arena.boost_id == -1 and arena.skill_id == -1,"pause clears every held touch owner")
	touch(0,Vector2.ZERO,false)
	touch(1,Vector2.ZERO,false)
	var paused_position: Vector2 = arena.player.position
	await create_timer(0.15).timeout
	check(arena.player.position == paused_position,"paused simulation stops movement")
	arena.player.position = Vector2(arena.BOUNDS-180,0)
	var outer_warning: float = arena.boundary_danger()
	check(outer_warning > 0.0 and outer_warning < 1.0,"approaching real arena boundary triggers a graduated warning")
	arena.player.position = Vector2(arena.BOUNDS-40,0)
	check(arena.boundary_danger() > outer_warning and arena.hud_state().danger == arena.boundary_danger(),"boundary HUD intensifies as lethal edge approaches")
	arena.player.position = Vector2.ZERO
	check(arena.boundary_danger() == 0.0,"boundary warning clears when returning to safe center")
	arena.player.position = paused_position
	touch(0,viewport_size/2+Vector2(0,25),true)
	touch(0,viewport_size/2+Vector2(0,25),false)
	await process_frame
	check(not arena.paused,"continue touch resumes gameplay")
	arena.player.position = Vector2(arena.BOUNDS+5,0)
	await create_timer(1.3).timeout
	check(app.current_page == "results" and has_label("ELIMINATED"),"lethal world boundary reaches clear ELIMINATED result")
	check(not has_label("CONNECTION LOST") and not has_label("SINAL PERDIDO"),"ordinary defeat never claims network connection loss")
	check(app.profile.data.stats.runs == 1 and float(app.profile.data.stats.survival) > 0.5,"defeat saves exactly one run with survival time")
	check(app.profile.data.best_score >= 8 and int(app.reward.coins) >= 10 and int(app.reward.xp) >= 15,"collected score updates record and real rewards")
	check(controls_in_view() and english_page(),"results are English and controls fit screen")
	var score_counter: Label = app.screen.find_child("AnimatedFinalScore",true,false)
	check(score_counter != null and int(score_counter.get_meta("target_value")) == int(app.last_result.score),"result animation targets the actual completed-run score")
	var score_before: int = int(score_counter.get_meta("displayed_value"))
	await create_timer(0.7).timeout
	check(int(score_counter.get_meta("displayed_value")) == int(app.last_result.score) and score_counter.text == str(app.last_result.score) and int(score_counter.get_meta("displayed_value")) >= score_before,"animated score reaches its exact real final value")
	var earned_coins: Label = app.screen.find_child("AnimatedCoins",true,false)
	var earned_xp: Label = app.screen.find_child("AnimatedXP",true,false)
	check(earned_coins.text == "+%d" % app.reward.coins and earned_xp.text == "+%d" % app.reward.xp,"reward animations finish on the exact coins and XP actually granted")
	check(geometry_valid("settled results"),"settled result numbers and controls neither clip nor overlap")
	var rewarded_coins: int = app.profile.data.coins
	var rewarded_runs: int = app.profile.data.stats.runs
	app.show_results()
	app.show_results()
	var replay_score: Label = app.screen.find_child("AnimatedFinalScore",true,false)
	var replay_initial: int = int(replay_score.get_meta("displayed_value"))
	await create_timer(0.2).timeout
	check(replay_initial == 0 and int(replay_score.get_meta("displayed_value")) > 0 and int(replay_score.get_meta("displayed_value")) < int(app.last_result.score),"result score visibly progresses through real intermediate numbers")
	await create_timer(0.6).timeout
	check(app.profile.data.coins == rewarded_coins and app.profile.data.stats.runs == rewarded_runs,"replaying and interrupting result animations cannot farm a second reward")
	press("PLAY AGAIN")
	await process_frame
	check(app.current_page == "game" and app.game.player.alive,"restart begins fresh playable serpent")
	touch(2,app.game.skill_center(app.game.get_viewport_rect().size),true)
	await process_frame
	check(app.game.skill_id == 2 and app.game.joystick_id == -1 and app.game.player.cooldown > 0.0,"standalone ability touch is not intercepted by the steering region")
	touch(2,Vector2.ZERO,false)
	app.game.end_game(true)
	await process_frame
	check(app.current_page == "menu" and app.profile.data.stats.runs == 1,"abandon returns to menu without farming rewards")
	var reopened = load("res://scripts/core/Profile.gd").new()
	check(reopened.load_profile(),"new profile instance reloads saved state")
	check(reopened.data.name == "NOVA TEST" and reopened.data.equipped == 1 and reopened.data.owned.has(1),"name inventory and equipped skin survive reopen")
	check(reopened.data.best_score == app.profile.data.best_score and reopened.data.coins == app.profile.data.coins,"economy and record survive reopen")
	check(reopened.data.settings.quality == "Low" and not reopened.data.settings.sound and not reopened.data.settings.music,"graphics and independent audio preferences survive reopen")
	await ui_stress()
	check(ui_stress_complete,"the complete UI stress workflow executed without aborting a coroutine")
	app.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("FLOW RESULT: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
