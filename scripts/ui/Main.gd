extends Control

const ProfileScript = preload("res://scripts/core/Profile.gd")
const PreviewScript = preload("res://scripts/ui/SerpentPreview.gd")
const ArenaScript = preload("res://scripts/gameplay/ArenaGame.gd")
const CYAN := Color("55f5f0")
const INK := Color("091423")
const WHITE := Color("e8f6ff")
const MUTED := Color("95aec8")

var profile = ProfileScript.new()
var screen: Control
var overlay: Control
var background: TextureRect
var preview: Control
var toast_label: Label
var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var game: Node2D
var font_body: Font
var font_display: Font
var boot_elapsed := 0.0
var boot_paths: Array[String] = []
var boot_done := 0
var boot_active := false
var boot_bar: ProgressBar
var boot_status: Label
var boot_logo: TextureRect
var boot_studio: Label
var boot_wordmark: TextureRect
var last_result: Dictionary = {}
var reward: Dictionary = {}
var current_page := "menu"
var filter_index := 0
var collection_page := 0
var online_mode := false
var menu_clock := 0.0
var menu_logo: TextureRect
var audio_cache: Dictionary = {}
var backdrop_shift := Vector2.ZERO

func _ready() -> void:
	profile.load_profile()
	font_body = load("res://assets/fonts/Body.ttf")
	font_display = load("res://assets/fonts/Display.ttf")
	var theme_resource := Theme.new()
	theme_resource.default_font = font_body
	theme_resource.default_font_size = 18
	for control_type in ["OptionButton","LineEdit","SpinBox"]:
		theme_resource.set_stylebox("normal",control_type,box(Color("102338"),Color("3e6278"),10))
		theme_resource.set_stylebox("hover",control_type,box(Color("18344a"),CYAN,10))
		theme_resource.set_stylebox("focus",control_type,box(Color(0,0,0,0),CYAN,10))
		theme_resource.set_color("font_color",control_type,WHITE)
	theme_resource.set_stylebox("panel","PopupMenu",box(Color("102338"),Color("3e6278"),10))
	theme = theme_resource
	sfx = AudioStreamPlayer.new()
	add_child(sfx)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/music_menu.ogg") if ResourceLoader.exists("res://assets/audio/music_menu.ogg") else load("res://assets/audio/ambient.wav")
	if music.stream is AudioStreamOggVorbis:
		music.stream.loop = true
	music.volume_db = -14.0
	music.finished.connect(func(): music.play())
	add_child(music)
	apply_settings()
	show_boot()

func box(color: Color, edge: Color = Color("25445a"), radius: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style

func place(node: Control, parent: Node, rect: Rect2) -> Control:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node

func label_at(parent: Node, text_value: String, rect: Rect2, px: int = 20, color: Color = WHITE) -> Label:
	var label := Label.new()
	label.clip_text = true
	label.text = text_value
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", px)
	place(label, parent, rect)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func title(parent: Node, text_value: String, rect: Rect2, px: int = 32) -> Label:
	var label := label_at(parent, text_value, rect, px)
	label.add_theme_font_override("font", font_display)
	return label

func button_art(asset_name: String) -> StyleBoxTexture:
	var artwork := StyleBoxTexture.new()
	artwork.texture = load("res://assets/ui/%s.png" % asset_name)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		artwork.set_texture_margin(side,16)
	return artwork

func button(parent: Node, caption: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = caption
	b.add_theme_stylebox_override("normal", button_art("button" if primary else "button_alt"))
	b.add_theme_stylebox_override("hover", button_art("button_hover"))
	b.add_theme_stylebox_override("pressed", button_art("button_pressed"))
	b.add_theme_stylebox_override("focus", box(Color(0,0,0,0), CYAN, 14))
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_font_size_override("font_size", 23 if primary else 17)
	place(b,parent,rect)
	b.pivot_offset = rect.size * 0.5
	b.mouse_entered.connect(func():
		play_sound("hover")
		b.create_tween().tween_property(b,"scale",Vector2.ONE*1.025,0.14).set_trans(Tween.TRANS_QUAD))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b,"scale",Vector2.ONE,0.16))
	b.button_down.connect(func(): b.create_tween().tween_property(b,"scale",Vector2.ONE*0.965,0.08))
	b.button_up.connect(func(): b.create_tween().tween_property(b,"scale",Vector2.ONE,0.13))
	b.pressed.connect(func(): play_sound("tap"); action.call())
	return b

func panel(parent: Node, rect: Rect2) -> Panel:
	var p := Panel.new()
	var artwork := StyleBoxTexture.new()
	artwork.texture = load("res://assets/ui/panel.png")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		artwork.set_texture_margin(side,16)
	p.add_theme_stylebox_override("panel", artwork)
	place(p, parent, rect)
	return p

func picture(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var pic := TextureRect.new()
	pic.texture = load(path)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(pic, parent, rect)
	return pic

func clear_screen() -> void:
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	add_child(screen)
	screen.size = Vector2(1280,720)
	screen.position = (get_viewport_rect().size - screen.size) * 0.5
	backdrop_shift = screen.position
	overlay = null
	toast_label = null
	background = picture(screen, "res://assets/backgrounds/menu.png", Rect2(-screen.position,get_viewport_rect().size))
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var shade := ColorRect.new()
	shade.color = Color(0.015,0.025,0.06,0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(shade, screen, Rect2(-screen.position,get_viewport_rect().size))
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(screen,"modulate:a",1.0,0.22)

func show_boot() -> void:
	current_page = "boot"
	clear_screen()
	background.visible = false
	boot_elapsed = 0.0
	boot_done = 0
	boot_logo = picture(screen,"res://assets/branding/emnio_symbol.png",Rect2(535,190,210,210))
	boot_wordmark = picture(screen,"res://assets/branding/emnio_wordmark.png",Rect2(470,424,340,65))
	boot_wordmark.modulate.a=0.0
	var letters := boot_wordmark.create_tween()
	letters.tween_interval(0.35)
	letters.tween_property(boot_wordmark,"modulate:a",1.0,0.4)
	boot_logo.pivot_offset = boot_logo.size * 0.5
	boot_logo.scale = Vector2.ONE * 0.76
	boot_logo.rotation=-0.12
	boot_logo.modulate.a = 0.0
	var reveal := boot_logo.create_tween().set_parallel()
	reveal.tween_property(boot_logo,"modulate:a",1.0,0.55)
	reveal.tween_property(boot_logo,"rotation",0.0,0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(boot_logo,"scale",Vector2.ONE,0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	boot_bar = ProgressBar.new()
	boot_bar.show_percentage = false
	boot_bar.add_theme_stylebox_override("background",box(Color("111a2a"),Color("111a2a"),2))
	boot_bar.add_theme_stylebox_override("fill",box(CYAN,CYAN,2))
	place(boot_bar,screen,Rect2(500,531,280,3))
	boot_status = Label.new()
	boot_status.visible = false
	screen.add_child(boot_status)
	boot_studio = Label.new()
	boot_studio.visible = false
	screen.add_child(boot_studio)
	boot_paths.clear()
	for i in range(profile.catalog.size()):
		for part in ["head","body","tail"]:
			boot_paths.append("res://assets/snakes/%s_%d.png" % [part,i])
	for path in ["res://assets/arenas/neon_city.png","res://assets/branding/warserpent.png","res://assets/audio/collect.wav","res://assets/audio/ability.wav"]:
		boot_paths.append(path)
	boot_active = true
	ResourceLoader.load_threaded_request(boot_paths[0])

func _process(delta: float) -> void:
	menu_clock += delta
	if current_page == "menu" and is_instance_valid(menu_logo) and not is_instance_valid(overlay):
		menu_logo.position.y = 124.0 + sin(menu_clock*1.2)*4.0
	if not boot_active:
		return
	boot_elapsed += delta
	if boot_elapsed > 1.15 and boot_logo.texture.resource_path.ends_with("emnio_symbol.png"):
		boot_wordmark.visible=false
		boot_logo.texture = load("res://assets/branding/warserpent.png")
		boot_logo.position = Vector2(350,225)
		boot_logo.size = Vector2(580,200)
		boot_logo.modulate.a = 0.0
		boot_logo.create_tween().tween_property(boot_logo,"modulate:a",1.0,0.3)
	if boot_done < boot_paths.size():
		var status := ResourceLoader.load_threaded_get_status(boot_paths[boot_done])
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(boot_paths[boot_done])
			boot_done += 1
			boot_bar.value = 100.0*boot_done/boot_paths.size()
			if boot_done < boot_paths.size():
				ResourceLoader.load_threaded_request(boot_paths[boot_done])
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			boot_active=false
			push_error("Missing resource: "+boot_paths[boot_done])
	if boot_done == boot_paths.size() and boot_elapsed >= 2.0:
		boot_active = false
		show_menu()

func show_menu() -> void:
	current_page = "menu"
	clear_screen()
	set_music_track("menu")
	button(screen,"%s  /  LV. %d" % [profile.data.name,profile.data.level],Rect2(42,28,290,52),show_profile)
	label_at(screen,"%d XP" % profile.data.xp,Rect2(354,38,170,32),16,MUTED)
	picture(screen,"res://assets/icons/coin.png",Rect2(765,40,28,28))
	label_at(screen,str(profile.data.coins),Rect2(805,35,120,38),23,Color("ffcf71"))
	picture(screen,"res://assets/icons/gem.png",Rect2(940,40,28,28))
	label_at(screen,str(profile.data.gems),Rect2(979,35,100,38),23,CYAN)
	button(screen,"SETTINGS",Rect2(1090,28,150,52),show_settings)
	label_at(screen,"EMNIO  /  NEON CITY",Rect2(54,105,420,25),13,CYAN)
	menu_logo = picture(screen,"res://assets/branding/warserpent.png",Rect2(36,124,668,170))
	var active: Dictionary = profile.catalog[int(profile.data.equipped)]
	preview = PreviewScript.new()
	preview.skin_id = int(profile.data.equipped)
	place(preview,screen,Rect2(30,280,720,280))
	var identity := title(screen,str(active.name).to_upper(),Rect2(56,551,650,42),28)
	identity.modulate = Color(active.color)
	label_at(screen,str(active.ability)+"  /  "+str(active.rarity).to_upper(),Rect2(58,600,650,26),14,MUTED)
	var play_panel := panel(screen,Rect2(814,142,426,470))
	label_at(play_panel,"CHOOSE YOUR ARENA",Rect2(28,24,370,25),13,CYAN)
	button(play_panel,"OFFLINE" if not online_mode else "ONLINE",Rect2(27,65,372,52),func(): online_mode=not online_mode; show_menu())
	title(play_panel,"NEON CITY",Rect2(28,139,370,54),34)
	label_at(play_panel,"Real players • Direct connection" if online_mode else "Solo arena • Smart rivals",Rect2(30,193,365,30),17,MUTED)
	if not online_mode:
		var modes := OptionButton.new()
		for item in ["Rookie","Competitive","Veteran"]:
			modes.add_item(item)
		place(modes,play_panel,Rect2(28,248,370,46))
		modes.select(int(profile.data.settings.difficulty))
		modes.item_selected.connect(func(index): profile.set_setting("difficulty",index))
	else:
		label_at(play_panel,"Host a room or join an address.",Rect2(30,250,365,40),16,MUTED)
	var play := button(play_panel,"PLAY ONLINE  ›" if online_mode else "PLAY  ›",Rect2(28,328,370,78),show_online if online_mode else start_game,true)
	play.add_theme_font_override("font",font_display)
	var pulse := play.create_tween().set_loops()
	pulse.tween_property(play,"modulate",Color("a9ffef"),1.1)
	pulse.tween_property(play,"modulate",Color.WHITE,1.1)
	label_at(play_panel,"BEST  %d" % profile.data.best_score,Rect2(30,425,365,24),14,MUTED)
	var names := ["SERPENTS","SHOP","MISSIONS","REWARDS","RECORDS","ACHIEVEMENTS"]
	var actions: Array[Callable] = [func(): show_collection(false),func(): show_collection(true),show_missions,show_rewards,show_ranking,show_achievements]
	for i in range(6):
		button(screen,names[i],Rect2(42+i*202,659,186,43),actions[i])

func open_page(caption: String, subtitle: String = "") -> Control:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = Control.new()
	place(overlay,screen,Rect2(0,0,1280,720))
	var dim := ColorRect.new()
	dim.color = Color(0.01,0.02,0.05,0.95)
	place(dim,overlay,Rect2(-screen.position,get_viewport_rect().size))
	title(overlay,caption,Rect2(42,30,1000,55),35)
	label_at(overlay,subtitle,Rect2(44,90,1100,36),16,MUTED)
	button(overlay,"BACK",Rect2(1080,32,155,48),show_menu)
	return overlay

func show_collection(shop: bool = false) -> void:
	current_page = "shop" if shop else "collection"
	var page := open_page("NEON MARKET" if shop else "SERPENT COLLECTION", "%d coins • Eight original serpents • Eight powers" % profile.data.coins)
	var filters := OptionButton.new()
	for text_value in ["All", "Owned", "Locked"]:
		filters.add_item(text_value)
	place(filters,page,Rect2(42,137,240,40))
	filters.select(filter_index)
	filters.item_selected.connect(func(value): filter_index=value; collection_page=0; show_collection(shop))
	var x := 42
	var visible_entries: Array = []
	for entry in profile.catalog:
		var owned: bool = profile.data.owned.has(int(entry.id))
		if (filter_index == 1 and not owned) or (filter_index == 2 and owned):
			continue
		visible_entries.append(entry)
	var page_count := maxi(1,ceili(visible_entries.size()/4.0))
	collection_page = clampi(collection_page,0,page_count-1)
	button(page,"‹",Rect2(1000,137,68,40),func(): collection_page=maxi(0,collection_page-1); show_collection(shop))
	label_at(page,"%d / %d" % [collection_page+1,page_count],Rect2(1082,143,80,35),18,CYAN)
	button(page,"›",Rect2(1164,137,68,40),func(): collection_page=mini(page_count-1,collection_page+1); show_collection(shop))
	for entry in visible_entries.slice(collection_page*4,collection_page*4+4):
		var id := int(entry.id)
		var owned: bool = profile.data.owned.has(id)
		if (filter_index == 1 and not owned) or (filter_index == 2 and owned):
			continue
		var card := panel(page,Rect2(x,195,282,448))
		label_at(card,str(entry.rarity).to_upper(),Rect2(16,16,208,25),13,Color(entry.color))
		title(card,str(entry.name).replace(" ","\n"),Rect2(16,50,212,68),24)
		var serpent := PreviewScript.new()
		serpent.skin_id=id
		place(serpent,card,Rect2(5,115,272,125))
		label_at(card,str(entry.ability),Rect2(16,250,205,45),17,CYAN).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_at(card,str(entry.description),Rect2(16,302,250,70),14,MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var caption := "EQUIPPED" if int(profile.data.equipped)==id else ("EQUIP" if owned else "%d COINS" % entry.price)
		button(card,caption,Rect2(14,390,254,43),func():
			if owned:
				profile.equip_skin(id)
				show_collection(shop)
			else:
				confirm_purchase(id,shop), int(profile.data.equipped)==id)
		x += 302
	label_at(page,"Earn coins in the arena. Every unlock stays in your collection.",Rect2(42,669,1150,28),15,MUTED)

func confirm_purchase(id: int, shop: bool) -> void:
	var entry: Dictionary = profile.catalog[id]
	var dialog := ConfirmationDialog.new()
	dialog.title = "Unlock serpent"
	dialog.dialog_text = "Unlock %s for %d coins?\nYour balance: %d" % [entry.name,entry.price,profile.data.coins]
	dialog.ok_button_text = "UNLOCK"
	dialog.cancel_button_text = "CANCEL"
	add_child(dialog)
	dialog.confirmed.connect(func():
		var success: bool = profile.buy_skin(id)
		show_collection(shop)
		if success:
			play_sound("purchase")
			toast("Serpent unlocked. Equip it to use its power!")
		else:
			play_sound("error")
			toast("Not enough coins. Earn more in the arena or complete missions.")
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2i(550,220))

func show_profile() -> void:
	var page := open_page("PILOT IDENTITY","Your local profile • Emnio")
	panel(page,Rect2(90,175,1100,425))
	label_at(page,"ARENA NAME",Rect2(125,207,500,35),17,CYAN)
	var name_edit := LineEdit.new()
	name_edit.text = profile.data.name
	name_edit.max_length = 18
	place(name_edit,page,Rect2(125,253,540,58))
	button(page,"SAVE NAME",Rect2(705,253,270,58),func(): profile.set_player_name(name_edit.text); show_profile(); toast("Identity saved"),true)
	title(page,"LEVEL %d" % profile.data.level,Rect2(125,349,400,55),32)
	label_at(page,"%d XP  •  %d matches  •  %d eliminations" % [profile.data.xp,profile.data.stats.runs,profile.data.stats.kills],Rect2(125,423,970,38),23)
	label_at(page,"FRAGMENTS: %d    |    BEST SCORE: %d" % [profile.data.fragments,profile.data.best_score],Rect2(125,485,950,35),20,MUTED)

func show_settings() -> void:
	var page := open_page("SETTINGS","Tune performance, music and effects to your device.")
	panel(page,Rect2(160,160,960,465))
	label_at(page,"SOUND EFFECTS",Rect2(200,215,400,40),22)
	var sound := CheckButton.new()
	sound.text = "Enabled"
	sound.button_pressed = bool(profile.data.settings.sound)
	place(sound,page,Rect2(700,215,300,45))
	sound.toggled.connect(func(value): profile.set_setting("sound",value); apply_settings())
	label_at(page,"MUSIC",Rect2(200,285,400,40),22)
	var music_toggle := CheckButton.new()
	music_toggle.text = "Enabled"
	music_toggle.button_pressed = bool(profile.data.settings.get("music",true))
	place(music_toggle,page,Rect2(700,285,300,45))
	music_toggle.toggled.connect(func(value): profile.set_setting("music",value); apply_settings())
	label_at(page,"GRAPHICS",Rect2(200,355,400,40),22)
	var quality := OptionButton.new()
	var options := ["Auto", "Low", "Medium", "High"]
	for item in options:
		quality.add_item(item)
	quality.select(maxi(0,options.find(str(profile.data.settings.quality))))
	place(quality,page,Rect2(700,355,300,45))
	quality.item_selected.connect(func(index): profile.set_setting("quality",options[index]); apply_settings())
	label_at(page,"Low: 30 FPS target • fewer effects\nMedium / High: 60 FPS target\nActual performance depends on your device.",Rect2(200,420,800,95),20,MUTED)
	label_at(page,"Joystick + BOOST + power • Keyboard: WASD / Space / E",Rect2(200,548,850,35),15,CYAN)
	button(page,"CREDITS & LICENSES",Rect2(395,628,490,48),show_credits)

func show_credits() -> void:
	var page := open_page("EMNIO / CREDITS","War Serpent.io 1.1.0 • MIT code • Original CC0 art • DejaVu fonts")
	var credits := RichTextLabel.new()
	credits.text = "DEVELOPED FOR EMNIO\nOriginal artwork, authored sprites and synthesized music. Background created with OpenAI image generation.\n\nGODOT ENGINE 4.6.3\nCopyright (c) 2014-present Godot Engine contributors.\nCopyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.\nhttps://godotengine.org/license/\n\n" + Engine.get_license_text() + "\n\nDejaVu fonts: copyright Bitstream, Inc. and DejaVu contributors. Full license below."
	credits.scroll_active = true
	credits.text += "\n\n" + FileAccess.get_file_as_string("res://assets/fonts/LICENSE-DejaVu.txt")
	place(credits,page,Rect2(75,155,1130,490))

func apply_settings() -> void:
	var quality_setting := str(profile.data.settings.quality)
	var low_budget := quality_setting == "Low" or (quality_setting == "Auto" and OS.has_feature("mobile"))
	Engine.max_fps = 30 if low_budget else 60
	if is_instance_valid(music):
		if bool(profile.data.settings.get("music",true)):
			if not music.playing:
				music.play()
		else:
			music.stop()

func show_missions() -> void:
	var page := open_page("CITY CONTRACTS","Lifetime objectives • Claim each reward once")
	var entries: Array = profile.missions()
	for i in range(entries.size()):
		var status: Dictionary = profile.mission_status(i)
		var entry: Dictionary = entries[i]
		var y := 161 + i*92
		panel(page,Rect2(50,y,1180,80))
		label_at(page,str(entry.get("name",entry.get("title","Mission"))),Rect2(75,y+8,560,30),20)
		label_at(page,"%d / %d  •  %d coins" % [status.get("progress",0),entry.get("target",0),entry.get("coins",entry.get("reward",0))],Rect2(75,y+42,700,25),15,MUTED)
		var claimed: bool = bool(status.get("claimed",false))
		var claim := button(page,"CLAIMED" if claimed else "CLAIM",Rect2(980,y+17,220,45),func():
			if profile.claim_mission(i):
				play_sound("purchase")
				show_missions()
			else:
				toast("Complete the objective to claim this reward."))
		claim.disabled = claimed

func show_rewards() -> void:
	var page := open_page("DAILY DROP","One crate each UTC day • No ads")
	picture(page,"res://assets/icons/chest.png",Rect2(480,170,320,250))
	title(page,"+75 COINS   +3 GEMS",Rect2(390,435,600,60),30)
	label_at(page,"+2 fragments for your collection",Rect2(460,493,450,30),17,CYAN)
	button(page,"OPEN CRATE",Rect2(460,540,360,65),func():
		if profile.claim_daily():
			play_sound("purchase")
			toast("Crate opened! Your rewards are saved.")
		else:
			toast("Already claimed today. Come back tomorrow."),true)

func show_ranking() -> void:
	var page := open_page("LOCAL RECORD","Your personal record • Live arena standings appear during a match")
	panel(page,Rect2(120,190,1040,360))
	title(page,"01   " + str(profile.data.name),Rect2(170,220,850,65),35)
	label_at(page,"BEST SCORE",Rect2(170,310,500,30),16,CYAN)
	title(page,str(profile.data.best_score),Rect2(170,355,600,75),57)
	label_at(page,"%d matches  /  %d eliminations  /  %.0f seconds survived" % [profile.data.stats.runs,profile.data.stats.kills,profile.data.stats.survival],Rect2(170,465,900,35),20,MUTED)

func show_achievements() -> void:
	var page := open_page("ACHIEVEMENTS","Milestones earned in the arena")
	var all_entries: Array = profile.achievements()
	for i in range(all_entries.size()):
		var entry: Dictionary = all_entries[i]
		var y := 155+i*88
		panel(page,Rect2(70,y,1140,75))
		label_at(page,str(entry.get("name",entry.get("title","Achievement"))),Rect2(95,y+7,770,32),23)
		label_at(page,str(entry.get("description","")),Rect2(95,y+40,830,25),15,MUTED)
		label_at(page,"UNLOCKED" if entry.get("unlocked",false) else "LOCKED",Rect2(970,y+22,240,35),17,CYAN if entry.get("unlocked",false) else MUTED)

func start_game() -> void:
	current_page = "game"
	play_sound("start")
	set_music_track("arena")
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	game = ArenaScript.new()
	game.configure(int(profile.data.equipped),int(profile.data.settings.difficulty))
	game.finished.connect(on_finished)
	if game.has_method("set_quality"):
		game.set_quality(str(profile.data.settings.quality))
	if game.has_method("set_audio_enabled"):
		game.set_audio_enabled(bool(profile.data.settings.sound))
	if game.has_method("set_player_name"):
		game.set_player_name(str(profile.data.name))
	add_child(game)

func on_finished(result: Dictionary) -> void:
	last_result = result
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
	if bool(result.get("abandoned",false)):
		show_menu()
		if result.has("network_error"):
			toast(str(result.network_error))
		return
	reward = profile.record_run(result)
	show_results()

func show_results() -> void:
	current_page = "results"
	clear_screen()
	title(screen,"ELIMINATED",Rect2(380,50,700,80),48)
	label_at(screen,"Your next run starts stronger.",Rect2(390,135,720,40),20,MUTED)
	panel(screen,Rect2(225,205,830,340))
	title(screen,str(last_result.get("score",0)),Rect2(265,235,480,85),65)
	label_at(screen,"FINAL SCORE   /   BEST %d" % profile.data.best_score,Rect2(270,328,700,35),19,CYAN)
	label_at(screen,"SURVIVED  %.1fs       ELIMINATIONS  %d       ENERGY  %d" % [last_result.get("survived",0),last_result.get("kills",0),last_result.get("energy",0)],Rect2(270,392,740,40),18)
	label_at(screen,"EARNED     +%d COINS    +%d XP" % [reward.get("coins",0),reward.get("xp",0)],Rect2(270,461,720,40),23,Color("ffd36b"))
	button(screen,"PLAY AGAIN",Rect2(225,585,355,66),start_game,true)
	button(screen,"CHANGE SERPENT",Rect2(600,585,250,66),func(): show_menu(); show_collection(false))
	button(screen,"MENU",Rect2(870,585,185,66),show_menu)

func toast(message: String) -> void:
	if is_instance_valid(toast_label):
		toast_label.queue_free()
	toast_label = label_at(screen,message,Rect2(150,618,980,38),18,CYAN)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.z_index = 40
	# A node-bound tween dies with its toast when navigation frees the screen.
	var lifetime := toast_label.create_tween()
	lifetime.tween_interval(3.3)
	lifetime.tween_callback(toast_label.queue_free)

func play_sound(sound_name: String) -> void:
	if not bool(profile.data.settings.sound):
		return
	if not audio_cache.has(sound_name):
		var path := "res://assets/audio/%s.wav" % sound_name
		if not ResourceLoader.exists(path):
			return
		audio_cache[sound_name] = load(path)
	sfx.stream = audio_cache[sound_name]
	sfx.volume_db = -17.0 if sound_name == "hover" else -8.0
	sfx.play()

func _exit_tree() -> void:
	for player in [music,sfx]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and is_instance_valid(game):
		game.paused = true
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if current_page == "game" and is_instance_valid(game) and game.has_method("toggle_pause"):
			game.toggle_pause()
		elif current_page != "boot":
			show_menu()

func set_music_track(track: String) -> void:
	if not is_instance_valid(music):
		return
	var path := "res://assets/audio/music_%s.ogg" % track
	if ResourceLoader.exists(path) and (music.stream == null or music.stream.resource_path != path):
		music.stop()
		music.stream = load(path)
		if music.stream is AudioStreamOggVorbis:
			music.stream.loop = true
		music.volume_db = -14.0 if track == "menu" else -17.0
	apply_settings()

func show_online() -> void:
	current_page = "online"
	var page := open_page("ONLINE ARENA","Host a room or connect directly to another player's address.")
	panel(page,Rect2(110,170,1060,440))
	label_at(page,"SERVER ADDRESS",Rect2(150,210,600,35),18,CYAN)
	var address := LineEdit.new()
	address.placeholder_text = "192.168.1.10 or public server address"
	place(address,page,Rect2(150,256,680,60))
	var port := SpinBox.new()
	port.min_value=1024
	port.max_value=65535
	port.value=24680
	place(port,page,Rect2(860,256,250,60))
	label_at(page,"Same Wi-Fi: enter the host's local IP. Internet play requires a reachable UDP port.",Rect2(150,344,950,65),17,MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button(page,"HOST ROOM",Rect2(150,470,440,70),func(): begin_online(true,"",int(port.value)),true)
	button(page,"JOIN ROOM",Rect2(620,470,490,70),func():
		if address.text.strip_edges().is_empty():
			toast("Enter the host's IP address first.")
		else:
			begin_online(false,address.text.strip_edges(),int(port.value)),true)

func begin_online(host: bool, address: String, port: int) -> void:
	# The networking implementation is loaded only when selected.
	var path := "res://scripts/network/OnlineArena.gd"
	if not ResourceLoader.exists(path):
		toast("Online components are unavailable.")
		return
	var arena_script = load(path)
	var arena = arena_script.new()
	arena.configure(int(profile.data.equipped),int(profile.data.settings.difficulty))
	arena.set_player_name(str(profile.data.name))
	arena.set_quality(str(profile.data.settings.quality))
	arena.set_audio_enabled(bool(profile.data.settings.sound))
	arena.finished.connect(on_finished)
	arena.name="OnlineArena"
	var error: int = arena.host(port) if host else arena.join(address,port)
	if error != OK:
		arena.free()
		toast("Unable to open this connection. Check the address and port.")
		return
	current_page="game"
	remove_child(screen)
	screen.queue_free()
	game=arena
	add_child(game)
	set_music_track("arena")
	play_sound("start")
