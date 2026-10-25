extends Control

const ProfileScript = preload("res://scripts/core/Profile.gd")
const PreviewScript = preload("res://scripts/ui/SerpentPreview.gd")
const PlatformScript = preload("res://scripts/ui/LobbyPlatform.gd")
const AtmosphereScript = preload("res://scripts/ui/MenuAtmosphere.gd")
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
var page_animation_direction := 0
var atmosphere: Control
var selected_title: Label

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
	style.shadow_color=Color(0,0,0,.15)
	style.shadow_size=3
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

func game_button_style(asset: String, primary: bool) -> StyleBox:
	var path:="res://assets/ui/%s.png"%asset
	if ResourceLoader.exists(path):
		return button_art(asset)
	return box(Color("ffd259") if primary else Color(.035,.055,.08,.8),Color("ffda76") if primary else Color("3b5163"),2)

func animate_button(b: Button, target: Vector2) -> void:
	var old: Tween=b.get_meta("feedback_tween") if b.has_meta("feedback_tween") else null
	if old != null and old.is_valid():
		old.kill()
	var feedback := b.create_tween()
	b.set_meta("feedback_tween",feedback)
	feedback.tween_property(b,"scale",target,.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func button(parent: Node, caption: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text=caption
	b.add_theme_stylebox_override("normal",game_button_style("button_start" if primary else "button_alt",primary))
	b.add_theme_stylebox_override("hover",game_button_style("button_start_hover" if primary else "button_hover",primary))
	b.add_theme_stylebox_override("pressed",game_button_style("button_start_pressed" if primary else "button_pressed",primary))
	b.add_theme_stylebox_override("focus",box(Color(0,0,0,0),Color("ffce53"),2))
	b.add_theme_color_override("font_color",Color("231700") if primary else WHITE)
	b.add_theme_color_override("font_hover_color",Color("231700") if primary else WHITE)
	b.add_theme_color_override("font_pressed_color",Color("231700") if primary else WHITE)
	b.add_theme_font_size_override("font_size",25 if primary else 16)
	place(b,parent,rect)
	b.pivot_offset=rect.size*.5
	b.mouse_entered.connect(func():play_sound("hover");animate_button(b,Vector2.ONE*1.015))
	b.mouse_exited.connect(func():animate_button(b,Vector2.ONE))
	b.button_down.connect(func():animate_button(b,Vector2.ONE*.97))
	b.button_up.connect(func():animate_button(b,Vector2.ONE))
	b.pressed.connect(func():play_sound("tap");action.call())
	return b

func panel(parent: Node, rect: Rect2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel",button_art("lobby_panel") if ResourceLoader.exists("res://assets/ui/lobby_panel.png") else button_art("panel"))
	place(p,parent,rect)
	return p

func line_accent(parent: Node, rect: Rect2, color: Color = CYAN) -> ColorRect:
	var line := ColorRect.new()
	line.color=color
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	place(line,parent,rect)
	return line

func content_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var safe := Rect2(Vector2.ZERO,viewport_size)
	if OS.has_feature("mobile"):
		var physical := Vector2(DisplayServer.window_get_size())
		var device_safe := DisplayServer.get_display_safe_area()
		if physical.x>0 and physical.y>0 and device_safe.size.x>0 and device_safe.size.y>0:
			var ratio := viewport_size/physical
			safe=Rect2(Vector2(device_safe.position)*ratio,Vector2(device_safe.size)*ratio).intersection(safe)
	return safe

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
	screen.size=Vector2(1280,720)
	var safe := content_rect()
	var factor := minf(1.0,minf(safe.size.x/1280.0,safe.size.y/720.0))
	screen.scale=Vector2.ONE*factor
	screen.position=safe.position+(safe.size-screen.size*factor)*.5
	backdrop_shift = screen.position
	overlay = null
	toast_label = null
	background = picture(screen, "res://assets/backgrounds/menu.png", Rect2(-screen.position/screen.scale,get_viewport_rect().size/screen.scale))
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var shade := ColorRect.new()
	shade.color = Color(0.012,0.024,0.05,0.73)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(shade, screen, Rect2(-screen.position/screen.scale,get_viewport_rect().size/screen.scale))
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(screen,"modulate:a",1.0,0.22)

func show_boot() -> void:
	current_page = "boot"
	clear_screen()
	background.visible = false
	boot_elapsed = 0.0
	boot_done = 0
	var studio_path:="res://assets/branding/emnio_games.png" if ResourceLoader.exists("res://assets/branding/emnio_games.png") else "res://assets/branding/emnio_symbol.png"
	boot_logo=picture(screen,studio_path,Rect2(390,195,500,255))
	boot_wordmark = picture(screen,"res://assets/branding/emnio_wordmark.png",Rect2(470,424,340,65))
	boot_wordmark.modulate.a=0.0
	boot_wordmark.visible=studio_path.ends_with("emnio_symbol.png")
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
		menu_logo.position.y = 82.0 + sin(menu_clock*.9)*2.0
	if not boot_active:
		return
	boot_elapsed += delta
	if boot_elapsed > 1.15 and not boot_logo.texture.resource_path.ends_with("warserpent.png"):
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
	current_page="menu"
	clear_screen()
	set_music_track("menu")
	atmosphere=AtmosphereScript.new()
	atmosphere.name="Atmosphere"
	place(atmosphere,screen,Rect2(-screen.position/screen.scale,get_viewport_rect().size/screen.scale))
	# Compact original studio lobby header: identity, real balances, settings.
	var header:=ColorRect.new()
	header.color=Color(.02,.035,.055,.89)
	header.mouse_filter=Control.MOUSE_FILTER_IGNORE
	place(header,screen,Rect2(-screen.position.x/screen.scale.x,0,get_viewport_rect().size.x/screen.scale.x,73))
	button(screen,"%s  /  LV. %d"%[profile.data.name,profile.data.level],Rect2(28,14,278,46),show_profile)
	label_at(screen,"%d XP"%profile.data.xp,Rect2(322,21,120,28),14,MUTED)
	picture(screen,"res://assets/icons/coin.png",Rect2(468,24,26,26))
	label_at(screen,str(profile.data.coins),Rect2(507,16,135,38),22,Color("ffcf71"))
	picture(screen,"res://assets/icons/gem.png",Rect2(660,24,26,26))
	label_at(screen,str(profile.data.gems),Rect2(699,16,100,38),22,CYAN)
	label_at(screen,"EMNIO GAMES",Rect2(857,23,220,26),14,Color("c5d2df"))
	button(screen,"SETTINGS",Rect2(1094,14,154,46),show_settings)
	line_accent(screen,Rect2(0,72,1280,1),Color(.6,.7,.8,.24))
	# Real profile record, not an invented event or season.
	var record:=panel(screen,Rect2(27,103,204,97))
	label_at(record,"PERSONAL BEST",Rect2(15,11,180,24),11,Color("ffd259"))
	title(record,str(profile.data.best_score),Rect2(15,39,180,43),31)
	menu_logo=picture(screen,"res://assets/branding/warserpent.png",Rect2(270,82,360,150))
	var entries:=["SHOP","MISSIONS","REWARDS","RECORDS","ACHIEVEMENTS"]
	var icons:=["shop","mission","chest","record","achievement"]
	var actions:Array[Callable]=[func():show_collection(true),show_missions,show_rewards,show_ranking,show_achievements]
	var navigation_back:=picture(screen,"res://assets/ui/nav_strip.png",Rect2(15,212,228,335))
	navigation_back.stretch_mode=TextureRect.STRETCH_SCALE
	for i in range(entries.size()):
		var nav:=button(screen,entries[i],Rect2(27,231+i*59,204,45),actions[i])
		nav.add_theme_stylebox_override("normal",box(Color(.02,.03,.05,.22),Color(.3,.4,.5,.06),0))
		nav.alignment=HORIZONTAL_ALIGNMENT_LEFT
		nav.add_theme_font_size_override("font_size",14)
		var icon_path:="res://assets/icons/%s.png"%icons[i]
		if ResourceLoader.exists(icon_path):
			nav.icon=load(icon_path)
			nav.expand_icon=true
			nav.add_theme_constant_override("icon_max_width",23)
			nav.add_theme_constant_override("h_separation",13)
	# Animated upright serpent as the lobby character, on its own energy podium.
	var active:Dictionary=profile.catalog[int(profile.data.equipped)]
	var podium:=PlatformScript.new()
	podium.accent=Color(active.color)
	place(podium,screen,Rect2(289,494,610,146))
	preview=PreviewScript.new()
	preview.name="LobbyHero"
	preview.skin_id=int(profile.data.equipped)
	preview.hero_pose=true
	place(preview,screen,Rect2(252,138,660,440))
	selected_title=title(screen,str(active.name).to_upper(),Rect2(292,589,600,39),27)
	selected_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label_at(screen,str(active.ability)+"   /   "+str(active.rarity).to_upper(),Rect2(344,630,505,22),12,Color(active.color)).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	# Collection rail uses actual inventory. Every slot equips or opens its real page.
	label_at(screen,"COLLECTION",Rect2(1084,105,160,25),12,Color("ffd259"))
	for i in range(profile.catalog.size()):
		var skin:Dictionary=profile.catalog[i]
		var id:=int(skin.id)
		var owned:bool=profile.data.owned.has(id)
		var cell:=button(screen,"",Rect2(1113+(i%2)*67,145+(i/2)*66,57,57),func():
			if owned:
				profile.equip_skin(id)
				show_menu()
			else:
				collection_page=id/4
				show_collection(true))
		cell.tooltip_text=str(skin.name)
		picture(cell,"res://assets/snakes/head_%d.png"%id,Rect2(4,4,49,49))
		cell.modulate=Color.WHITE if owned else Color(.55,.62,.69,.8)
		if id==int(profile.data.equipped):
			cell.add_theme_stylebox_override("normal",box(Color("183744"),Color("ffce53"),2))
	var mode:=panel(screen,Rect2(942,446,304,143))
	button(mode,"OFFLINE" if not online_mode else "ONLINE",Rect2(13,11,278,35),func():online_mode=not online_mode;show_menu())
	title(mode,"NEON CITY",Rect2(15,56,277,35),23)
	if not online_mode:
		var modes:=OptionButton.new()
		for item in ["Rookie","Competitive","Veteran"]:
			modes.add_item(item)
		place(modes,mode,Rect2(13,99,278,32))
		modes.select(int(profile.data.settings.difficulty))
		modes.item_selected.connect(func(index):profile.set_setting("difficulty",index))
	else:
		label_at(mode,"DIRECT MULTIPLAYER",Rect2(15,103,277,24),11,MUTED)
	var start:=button(screen,"START ONLINE" if online_mode else "START",Rect2(942,608,304,78),show_online if online_mode else start_game,true)
	start.name="PrimaryPlay"
	start.add_theme_font_override("font",font_display)
	start.add_theme_font_size_override("font_size",31 if not online_mode else 23)
	var pulse:=start.create_tween().set_loops()
	pulse.tween_property(start,"modulate",Color("fff0b1"),1.4)
	pulse.tween_property(start,"modulate",Color.WHITE,1.4)
	# Cosmetic toolbar, every tab backed by a functioning collection/equip action.
	line_accent(screen,Rect2(27,658,870,1),Color(.7,.6,.3,.3))
	var serpents:=button(screen,"SERPENTS",Rect2(27,660,205,43),func():show_collection(false))
	serpents.icon=load("res://assets/icons/serpent.png")
	serpents.expand_icon=true
	serpents.add_theme_constant_override("icon_max_width",21)
	button(screen,"CHANGE SERPENT",Rect2(249,660,257,43),func():show_collection(false))
	label_at(screen,"%d / %d UNLOCKED"%[profile.data.owned.size(),profile.catalog.size()],Rect2(538,674,340,26),13,Color("d2bc7d"))

func open_page(caption: String, subtitle: String = "") -> Control:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = Control.new()
	place(overlay,screen,Rect2(0,0,1280,720))
	var dim := ColorRect.new()
	dim.color = Color(0.01,0.02,0.05,0.95)
	place(dim,overlay,Rect2(-screen.position/screen.scale,get_viewport_rect().size/screen.scale))
	line_accent(overlay,Rect2(42,24,42,3),Color("ffd259"))
	title(overlay,caption,Rect2(42,32,1000,55),35)
	label_at(overlay,subtitle,Rect2(44,90,1100,36),16,MUTED)
	button(overlay,"BACK",Rect2(1080,32,155,48),show_menu)
	return overlay

func change_collection_page(direction: int, maximum: int, shop: bool) -> void:
	collection_page=clampi(collection_page+direction,0,maximum-1)
	page_animation_direction=direction
	show_collection(shop)

func show_collection(shop: bool = false) -> void:
	current_page="shop" if shop else "collection"
	var page:=open_page("NEON MARKET" if shop else "SERPENT COLLECTION","Eight original serpents. Choose your own signature.")
	picture(page,"res://assets/icons/coin.png",Rect2(815,41,24,24))
	label_at(page,str(profile.data.coins),Rect2(851,35,180,38),23,Color("ffcf71"))
	var filters:=OptionButton.new()
	for text_value in ["All","Owned","Locked"]:
		filters.add_item(text_value)
	place(filters,page,Rect2(42,137,240,40))
	filters.select(filter_index)
	filters.item_selected.connect(func(value):filter_index=value;collection_page=0;show_collection(shop))
	var visible_entries:Array=[]
	for entry in profile.catalog:
		var owned:bool=profile.data.owned.has(int(entry.id))
		if (filter_index==1 and not owned) or (filter_index==2 and owned):
			continue
		visible_entries.append(entry)
	var page_count:=maxi(1,ceili(visible_entries.size()/4.0))
	collection_page=clampi(collection_page,0,page_count-1)
	button(page,"‹",Rect2(1000,137,68,40),func():change_collection_page(-1,page_count,shop))
	label_at(page,"%d / %d"%[collection_page+1,page_count],Rect2(1082,143,80,35),18,CYAN)
	button(page,"›",Rect2(1164,137,68,40),func():change_collection_page(1,page_count,shop))
	var cards:=Control.new()
	cards.name="CollectionCards"
	place(cards,page,Rect2(42,194,1190,452))
	if page_animation_direction!=0:
		cards.position.x+=float(page_animation_direction)*18.0
		cards.modulate.a=0.0
		var arrival:=cards.create_tween().set_parallel()
		arrival.tween_property(cards,"position:x",42.0,.21).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		arrival.tween_property(cards,"modulate:a",1.0,.21)
	page_animation_direction=0
	var x:=0
	for entry in visible_entries.slice(collection_page*4,collection_page*4+4):
		var id:=int(entry.id)
		var owned:bool=profile.data.owned.has(id)
		var tint:=Color(entry.color)
		var card:=panel(cards,Rect2(x,0,282,452))
		line_accent(card,Rect2(19,18,24,3),tint)
		label_at(card,str(entry.rarity).to_upper(),Rect2(54,8,210,24),11,tint)
		title(card,str(entry.name).replace(" ","\n"),Rect2(19,43,246,68),25)
		var serpent:=PreviewScript.new()
		serpent.skin_id=id
		place(serpent,card,Rect2(3,117,276,124))
		picture(card,"res://assets/icons/ability_%d.png"%id,Rect2(18,252,31,31))
		label_at(card,str(entry.ability),Rect2(60,250,205,40),16,CYAN).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var timing:=label_at(card,"ACTIVE %.1fs  /  READY %ds"%[float(entry.duration),int(entry.cooldown)],Rect2(19,294,249,28),11,MUTED)
		timing.name="PowerTiming"
		label_at(card,str(entry.description),Rect2(19,328,248,49),12,MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var caption:="EQUIPPED" if int(profile.data.equipped)==id else ("EQUIP" if owned else "%d COINS"%entry.price)
		button(card,caption,Rect2(17,395,248,41),func():
			if owned:
				profile.equip_skin(id)
				show_collection(shop)
			else:
				confirm_purchase(id,shop),int(profile.data.equipped)==id)
		x+=302
	label_at(page,"Unlocked serpents stay in your collection. No real-money purchases.",Rect2(42,669,1150,28),13,MUTED)

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
	var page := open_page("PILOT IDENTITY","Your local profile • Emnio Games")
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
	var page := open_page("EMNIO GAMES / CREDITS","War Serpent.io 1.2.0 • Emnio Games • MIT code • Original CC0 art • DejaVu fonts")
	var credits := RichTextLabel.new()
	credits.text = "DEVELOPED FOR EMNIO GAMES\nOriginal artwork, authored sprites and synthesized music. Background created with OpenAI image generation.\n\nGODOT ENGINE 4.6.3\nCopyright (c) 2014-present Godot Engine contributors.\nCopyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.\nhttps://godotengine.org/license/\n\n" + Engine.get_license_text() + "\n\nDejaVu fonts: copyright Bitstream, Inc. and DejaVu contributors. Full license below."
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
	current_page="results"
	clear_screen()
	label_at(screen,"RUN COMPLETE",Rect2(100,46,470,25),12,CYAN)
	title(screen,"ELIMINATED",Rect2(96,81,1060,68),45)
	var score_panel:=panel(screen,Rect2(98,182,414,348))
	label_at(score_panel,"FINAL SCORE",Rect2(28,26,360,28),14,CYAN)
	title(score_panel,str(last_result.get("score",0)),Rect2(23,82,368,108),80)
	line_accent(score_panel,Rect2(28,224,356,1),Color("294052"))
	label_at(score_panel,"PERSONAL BEST",Rect2(28,254,250,28),12,MUTED)
	title(score_panel,str(profile.data.best_score),Rect2(28,290,350,38),25)
	var stats:=panel(screen,Rect2(538,182,644,160))
	var stat_names:=["SURVIVED","ELIMINATIONS","ENERGY"]
	var values:=["%.1fs"%last_result.get("survived",0),str(last_result.get("kills",0)),str(last_result.get("energy",0))]
	for i in range(3):
		label_at(stats,stat_names[i],Rect2(27+i*208,26,192,27),11,MUTED)
		title(stats,values[i],Rect2(27+i*208,73,192,52),34)
	var earned:=panel(screen,Rect2(538,363,644,167))
	label_at(earned,"REWARDS EARNED",Rect2(27,23,590,26),12,CYAN)
	picture(earned,"res://assets/icons/coin.png",Rect2(27,81,35,35))
	title(earned,"+%d"%reward.get("coins",0),Rect2(81,72,214,52),32)
	line_accent(earned,Rect2(320,73,1,53),Color("294052"))
	label_at(earned,"XP",Rect2(353,84,50,32),18,CYAN)
	title(earned,"+%d"%reward.get("xp",0),Rect2(416,72,192,52),32)
	button(screen,"PLAY AGAIN",Rect2(98,579,414,68),start_game,true)
	button(screen,"CHANGE SERPENT",Rect2(538,579,358,68),func():show_menu();show_collection(false))
	button(screen,"MENU",Rect2(920,579,262,68),show_menu)

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
