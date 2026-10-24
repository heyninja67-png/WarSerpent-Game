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
var last_result: Dictionary = {}
var reward: Dictionary = {}
var current_page := "menu"
var filter_index := 0

func _ready() -> void:
	profile.load_profile()
	font_body = load("res://assets/fonts/Body.ttf")
	font_display = load("res://assets/fonts/Display.ttf")
	var theme_resource := Theme.new()
	theme_resource.default_font = font_body
	theme_resource.default_font_size = 18
	theme = theme_resource
	sfx = AudioStreamPlayer.new()
	add_child(sfx)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/ambient.wav")
	music.volume_db = -22.0
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

func button(parent: Node, caption: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = caption
	var artwork := StyleBoxTexture.new()
	artwork.texture = load("res://assets/ui/button.png" if primary else "res://assets/ui/button_alt.png")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		artwork.set_texture_margin(side,18)
	b.add_theme_stylebox_override("normal", artwork)
	b.add_theme_stylebox_override("hover", box(Color("22516c"), CYAN))
	b.add_theme_stylebox_override("pressed", box(Color("316177"), Color("eab5ff")))
	b.add_theme_stylebox_override("focus", box(Color(0,0,0,0), CYAN))
	b.add_theme_font_size_override("font_size", 23 if primary else 17)
	b.add_theme_color_override("font_color", WHITE)
	place(b, parent, rect)
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
	overlay = null
	toast_label = null
	background = picture(screen, "res://assets/backgrounds/menu.png", Rect2(0,0,1280,720))
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var shade := ColorRect.new()
	shade.color = Color(0.015,0.025,0.06,0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(shade, screen, Rect2(0,0,1280,720))
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(screen,"modulate:a",1.0,0.22)

func show_boot() -> void:
	current_page = "boot"
	clear_screen()
	background.visible = false
	boot_logo = picture(screen, "res://assets/branding/emnio.png", Rect2(440,150,400,200))
	boot_studio = title(screen, "EMNIO", Rect2(400,350,480,70), 48)
	boot_studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_at(screen, "ENERGIA SEM LIMITES", Rect2(510,425,300,30), 16, CYAN)
	var energy_serpent := PreviewScript.new()
	place(energy_serpent,screen,Rect2(-500,430,400,100))
	energy_serpent.modulate = Color(0.8,0.5,1.0,0.7)
	var crossing := energy_serpent.create_tween()
	crossing.tween_interval(1.4)
	crossing.tween_property(energy_serpent,"position:x",1400.0,1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	boot_bar = ProgressBar.new()
	boot_bar.show_percentage = false
	boot_bar.add_theme_stylebox_override("background", box(INK))
	boot_bar.add_theme_stylebox_override("fill", box(CYAN,CYAN))
	place(boot_bar, screen, Rect2(430,535,420,7))
	boot_status = label_at(screen,"Inicializando recursos…",Rect2(430,556,500,40),16,MUTED)
	for i in range(5):
		for part in ["head", "body", "tail"]:
			boot_paths.append("res://assets/snakes/%s_%d.png" % [part,i])
	for path in ["res://assets/arenas/neon_city.png", "res://assets/branding/warserpent.png", "res://data/catalog.json", "res://assets/audio/collect.wav", "res://assets/audio/ability.wav"]:
		# JSON is loaded by profile; the visible progress measures texture/audio jobs.
		if not path.ends_with(".json"):
			boot_paths.append(path)
	boot_active = true
	ResourceLoader.load_threaded_request(boot_paths[0])

func _process(delta: float) -> void:
	if not boot_active:
		return
	boot_elapsed += delta
	boot_logo.modulate.a = clampf(boot_elapsed * 1.8,0.0,1.0) * (0.88 + 0.12 * sin(boot_elapsed * 4.0))
	if boot_elapsed > 2.0 and boot_studio.text == "EMNIO":
		boot_logo.texture = load("res://assets/branding/warserpent.png")
		boot_logo.position = Vector2(320,180)
		boot_logo.size = Vector2(640,220)
		boot_studio.text = "WAR SERPENT.IO"
		boot_studio.add_theme_font_size_override("font_size", 30)
	if boot_done < boot_paths.size():
		var status := ResourceLoader.load_threaded_get_status(boot_paths[boot_done])
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(boot_paths[boot_done])
			boot_done += 1
			boot_bar.value = 100.0 * boot_done / boot_paths.size()
			boot_status.text = "Recursos preparados · %d/%d" % [boot_done, boot_paths.size()]
			if boot_done < boot_paths.size():
				ResourceLoader.load_threaded_request(boot_paths[boot_done])
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			boot_status.text = "Falha no recurso: " + boot_paths[boot_done]
			boot_active = false
	if boot_done == boot_paths.size() and boot_elapsed >= 4.0:
		boot_active = false
		show_menu()

func show_menu() -> void:
	current_page = "menu"
	clear_screen()
	panel(screen,Rect2(30,22,1220,70))
	button(screen,"%s  /  NV. %d" % [profile.data.name,profile.data.level],Rect2(44,33,310,48),show_profile)
	label_at(screen,"XP  %d" % profile.data.xp,Rect2(375,42,160,32),17,MUTED)
	label_at(screen,"●  %d COINS" % profile.data.coins,Rect2(620,40,220,36),20,Color("ffd36b"))
	label_at(screen,"◆  %d GEMS" % profile.data.gems,Rect2(850,40,185,36),20,CYAN)
	button(screen,"AJUSTES",Rect2(1080,33,154,48),show_settings)
	picture(screen,"res://assets/branding/warserpent.png",Rect2(325,108,630,160))
	label_at(screen,"NEON CITY    /    ARENA OFFLINE",Rect2(40,129,300,30),14,CYAN)
	var side := panel(screen,Rect2(40,290,244,225))
	label_at(side,"SEU PRÓXIMO RECORDE",Rect2(18,20,220,28),14,MUTED)
	title(side,str(profile.data.best_score),Rect2(18,53,220,55),43)
	label_at(side,"Colete energia. Corte caminhos.\nSobreviva à cidade neon.",Rect2(18,120,215,60),15)
	label_at(side,"WASD / joystick   •   E poder",Rect2(18,187,225,24),12,CYAN)
	preview = PreviewScript.new()
	preview.skin_id = int(profile.data.equipped)
	place(preview,screen,Rect2(288,260,680,265))
	var active: Dictionary = profile.catalog[int(profile.data.equipped)]
	var skin_panel := panel(screen,Rect2(995,290,245,225))
	label_at(skin_panel,str(active.rarity).to_upper(),Rect2(18,14,220,25),13,Color(active.color))
	title(skin_panel,str(active.name).replace(" ","\n"),Rect2(18,42,210,80),24)
	label_at(skin_panel,str(active.ability),Rect2(18,133,210,45),16,CYAN).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(skin_panel,"TROCAR COBRA",Rect2(18,176,210,35),func(): show_collection(false))
	var play := button(screen,"JOGAR   ›",Rect2(436,533,408,80),start_game,true)
	play.add_theme_font_override("font",font_display)
	var tween := play.create_tween().set_loops()
	tween.tween_property(play,"modulate",Color("b9ffff"),1.2)
	tween.tween_property(play,"modulate",Color.WHITE,1.2)
	label_at(screen,"DIFICULDADE",Rect2(888,539,145,23),12,MUTED)
	var modes := OptionButton.new()
	for item in ["Iniciante", "Competitivo", "Veterano"]:
		modes.add_item(item)
	place(modes,screen,Rect2(888,565,225,45))
	modes.select(int(profile.data.settings.difficulty))
	modes.item_selected.connect(func(index): profile.set_setting("difficulty",index))
	label_at(screen,"Sem conexão • Sem anúncios • Sem compras reais",Rect2(435,616,500,23),13,MUTED)
	var names := ["COBRAS", "LOJA", "MISSÕES", "RECOMPENSAS", "RANKING", "CONQUISTAS"]
	var actions: Array[Callable] = [func(): show_collection(false),func(): show_collection(true),show_missions,show_rewards,show_ranking,show_achievements]
	for i in range(6):
		button(screen,names[i],Rect2(32+i*205,660,190,44),actions[i])

func open_page(caption: String, subtitle: String = "") -> Control:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = Control.new()
	place(overlay,screen,Rect2(0,0,1280,720))
	var dim := ColorRect.new()
	dim.color = Color(0.01,0.02,0.05,0.95)
	place(dim,overlay,Rect2(0,0,1280,720))
	title(overlay,caption,Rect2(42,30,1000,55),35)
	label_at(overlay,subtitle,Rect2(44,90,1100,36),16,MUTED)
	button(overlay,"VOLTAR",Rect2(1080,32,155,48),show_menu)
	return overlay

func show_collection(shop: bool = false) -> void:
	current_page = "shop" if shop else "collection"
	var page := open_page("MERCADO NEON" if shop else "SUAS SERPENTES", "5 identidades • 5 habilidades reais   |   Saldo: %d coins" % profile.data.coins)
	var filters := OptionButton.new()
	for text_value in ["Todas", "Desbloqueadas", "Bloqueadas"]:
		filters.add_item(text_value)
	place(filters,page,Rect2(42,137,240,40))
	filters.select(filter_index)
	filters.item_selected.connect(func(value): filter_index=value; show_collection(shop))
	var x := 42
	for entry in profile.catalog:
		var id := int(entry.id)
		var owned: bool = profile.data.owned.has(id)
		if (filter_index == 1 and not owned) or (filter_index == 2 and owned):
			continue
		var card := panel(page,Rect2(x,195,230,448))
		label_at(card,str(entry.rarity).to_upper(),Rect2(16,16,208,25),13,Color(entry.color))
		title(card,str(entry.name).replace(" ","\n"),Rect2(16,50,212,68),24)
		var serpent := PreviewScript.new()
		serpent.skin_id=id
		place(serpent,card,Rect2(2,115,226,125))
		label_at(card,str(entry.ability),Rect2(16,250,205,45),17,CYAN).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_at(card,str(entry.description),Rect2(16,302,202,70),14,MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var caption := "EQUIPADA" if int(profile.data.equipped)==id else ("EQUIPAR" if owned else "%d COINS" % entry.price)
		button(card,caption,Rect2(14,390,202,43),func():
			if owned:
				profile.equip_skin(id)
				show_collection(shop)
			else:
				confirm_purchase(id,shop), int(profile.data.equipped)==id)
		x += 241
	label_at(page,"Jogue para ganhar moedas. Cada compra é salva no inventário local.",Rect2(42,669,1150,28),15,MUTED)

func confirm_purchase(id: int, shop: bool) -> void:
	var entry: Dictionary = profile.catalog[id]
	var dialog := ConfirmationDialog.new()
	dialog.title = "Desbloquear serpente"
	dialog.dialog_text = "Comprar %s por %d coins?\nSaldo atual: %d" % [entry.name,entry.price,profile.data.coins]
	dialog.ok_button_text = "COMPRAR"
	dialog.cancel_button_text = "CANCELAR"
	add_child(dialog)
	dialog.confirmed.connect(func():
		var success: bool = profile.buy_skin(id)
		show_collection(shop)
		if success:
			play_sound("unlock")
			toast("Serpente desbloqueada. Equipe para usar sua habilidade!")
		else:
			toast("Moedas insuficientes. Ganhe mais na arena ou nas missões.")
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2i(550,220))

func show_profile() -> void:
	var page := open_page("IDENTIDADE DO PILOTO","Perfil salvo no dispositivo • Emnio")
	panel(page,Rect2(90,175,1100,425))
	label_at(page,"NOME NA ARENA",Rect2(125,207,500,35),17,CYAN)
	var name_edit := LineEdit.new()
	name_edit.text = profile.data.name
	name_edit.max_length = 18
	place(name_edit,page,Rect2(125,253,540,58))
	button(page,"SALVAR NOME",Rect2(705,253,270,58),func(): profile.set_player_name(name_edit.text); show_profile(); toast("Identidade salva"),true)
	title(page,"NÍVEL %d" % profile.data.level,Rect2(125,349,400,55),32)
	label_at(page,"%d XP  •  %d partidas  •  %d eliminações" % [profile.data.xp,profile.data.stats.runs,profile.data.stats.kills],Rect2(125,423,970,38),23)
	label_at(page,"FRAGMENTS: %d    |    RECORDE: %d" % [profile.data.fragments,profile.data.best_score],Rect2(125,485,950,35),20,MUTED)

func show_settings() -> void:
	var page := open_page("CONFIGURAÇÕES","A qualidade controla o orçamento visual e a meta de quadros; não altera as regras.")
	panel(page,Rect2(160,180,960,430))
	label_at(page,"ÁUDIO",Rect2(200,215,400,40),22)
	var sound := CheckButton.new()
	sound.text = "Ativado"
	sound.button_pressed = bool(profile.data.settings.sound)
	place(sound,page,Rect2(700,215,300,45))
	sound.toggled.connect(func(value): profile.set_setting("sound",value); apply_settings())
	label_at(page,"GRÁFICOS",Rect2(200,307,400,40),22)
	var quality := OptionButton.new()
	var options := ["Auto", "Baixo", "Médio", "Alto"]
	for item in options:
		quality.add_item(item)
	quality.select(maxi(0,options.find(str(profile.data.settings.quality))))
	place(quality,page,Rect2(700,307,300,45))
	quality.item_selected.connect(func(index): profile.set_setting("quality",options[index]); apply_settings())
	label_at(page,"Baixo: 30 FPS / efeitos reduzidos\nMédio, Alto e Auto: limite de 60 FPS\nDesempenho real depende do aparelho.",Rect2(200,405,800,105),20,MUTED)
	label_at(page,"Controle: joystick + BOOST + habilidade; teclado: WASD / Espaço / E.",Rect2(200,548,850,35),15,CYAN)
	button(page,"CRÉDITOS E LICENÇAS",Rect2(395,628,490,48),show_credits)

func show_credits() -> void:
	var page := open_page("EMNIO / CRÉDITOS","War Serpent.io 1.0.0 • Código MIT • Arte original CC0 • Fontes DejaVu")
	var credits := RichTextLabel.new()
	credits.text = "DESENVOLVIDO PARA EMNIO\nArte original, sprites autorais e áudio sintetizado. Fundo criado com geração de imagens OpenAI.\n\nGODOT ENGINE 4.6.3\nCopyright (c) 2014-present Godot Engine contributors.\nCopyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.\nhttps://godotengine.org/license/\n\n" + Engine.get_license_text() + "\n\nFontes DejaVu: copyright Bitstream, Inc. e contribuidores DejaVu. Licença completa incluída no código-fonte em assets/fonts/LICENSE-DejaVu.txt."
	credits.scroll_active = true
	credits.text += "\n\n" + FileAccess.get_file_as_string("res://assets/fonts/LICENSE-DejaVu.txt")
	place(credits,page,Rect2(75,155,1130,490))

func apply_settings() -> void:
	var quality_setting := str(profile.data.settings.quality)
	var low_budget := quality_setting == "Baixo" or (quality_setting == "Auto" and OS.get_processor_count() < 4)
	Engine.max_fps = 30 if low_budget else 60
	if is_instance_valid(music):
		if bool(profile.data.settings.sound):
			if not music.playing:
				music.play()
		else:
			music.stop()

func show_missions() -> void:
	var page := open_page("CONTRATOS DA CIDADE","Objetivos permanentes • Recompensas resgatáveis uma única vez")
	var entries: Array = profile.missions()
	for i in range(entries.size()):
		var status: Dictionary = profile.mission_status(i)
		var entry: Dictionary = entries[i]
		var y := 161 + i*92
		panel(page,Rect2(50,y,1180,80))
		label_at(page,str(entry.get("name",entry.get("title","Missão"))),Rect2(75,y+8,560,30),20)
		label_at(page,"%d / %d  •  %d coins" % [status.get("progress",0),entry.get("target",0),entry.get("coins",entry.get("reward",0))],Rect2(75,y+42,700,25),15,MUTED)
		var claimed: bool = bool(status.get("claimed",false))
		var claim := button(page,"RESGATADA" if claimed else "RESGATAR",Rect2(980,y+17,220,45),func():
			if profile.claim_mission(i):
				play_sound("unlock")
				show_missions()
			else:
				toast("Complete o objetivo para resgatar."))
		claim.disabled = claimed

func show_rewards() -> void:
	var page := open_page("CARGA DIÁRIA","Uma caixa por dia UTC • Recompensa local, sem anúncios")
	picture(page,"res://assets/icons/chest.png",Rect2(480,170,320,250))
	title(page,"+75 COINS   +3 GEMS",Rect2(390,435,600,60),30)
	label_at(page,"+2 fragments para sua coleção",Rect2(460,493,450,30),17,CYAN)
	button(page,"ABRIR CARGA",Rect2(460,540,360,65),func():
		if profile.claim_daily():
			play_sound("unlock")
			toast("Carga recebida! Saldo atualizado e salvo.")
		else:
			toast("Carga já recebida hoje. Volte amanhã."),true)

func show_ranking() -> void:
	var page := open_page("REGISTRO LOCAL","Ranking desta instalação • A classificação contra bots aparece durante a partida")
	panel(page,Rect2(120,190,1040,360))
	title(page,"01   " + str(profile.data.name),Rect2(170,220,850,65),35)
	label_at(page,"RECORDE",Rect2(170,310,500,30),16,CYAN)
	title(page,str(profile.data.best_score),Rect2(170,355,600,75),57)
	label_at(page,"%d partidas  /  %d eliminações  /  %.0f s sobrevividos" % [profile.data.stats.runs,profile.data.stats.kills,profile.data.stats.survival],Rect2(170,465,900,35),20,MUTED)

func show_achievements() -> void:
	var page := open_page("CONQUISTAS","Seu histórico de domínio da arena")
	var all_entries: Array = profile.achievements()
	for i in range(all_entries.size()):
		var entry: Dictionary = all_entries[i]
		var y := 155+i*88
		panel(page,Rect2(70,y,1140,75))
		label_at(page,str(entry.get("name",entry.get("title","Conquista"))),Rect2(95,y+7,770,32),23)
		label_at(page,str(entry.get("description","")),Rect2(95,y+40,830,25),15,MUTED)
		label_at(page,"CONQUISTADA" if entry.get("unlocked",false) else "BLOQUEADA",Rect2(970,y+22,240,35),17,CYAN if entry.get("unlocked",false) else MUTED)

func start_game() -> void:
	current_page = "game"
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
		return
	reward = profile.record_run(result)
	show_results()

func show_results() -> void:
	current_page = "results"
	clear_screen()
	title(screen,"SINAL PERDIDO",Rect2(380,50,700,80),48)
	label_at(screen,"A cidade lembra da sua energia. Volte mais forte.",Rect2(390,135,720,40),20,MUTED)
	panel(screen,Rect2(225,205,830,340))
	title(screen,str(last_result.get("score",0)),Rect2(265,235,480,85),65)
	label_at(screen,"PONTUAÇÃO   /   RECORDE %d" % profile.data.best_score,Rect2(270,328,700,35),19,CYAN)
	label_at(screen,"TEMPO  %.1fs       ELIMINAÇÕES  %d       ENERGIA  %d" % [last_result.get("survived",0),last_result.get("kills",0),last_result.get("energy",0)],Rect2(270,392,740,40),18)
	label_at(screen,"RECOMPENSA     +%d COINS    +%d XP" % [reward.get("coins",0),reward.get("xp",0)],Rect2(270,461,720,40),23,Color("ffd36b"))
	button(screen,"JOGAR NOVAMENTE",Rect2(225,585,355,66),start_game,true)
	button(screen,"TROCAR COBRA",Rect2(600,585,250,66),func(): show_menu(); show_collection(false))
	button(screen,"MENU",Rect2(870,585,185,66),show_menu)

func toast(message: String) -> void:
	if is_instance_valid(toast_label):
		toast_label.queue_free()
	toast_label = label_at(screen,message,Rect2(150,618,980,38),18,CYAN)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.z_index = 40
	var current := toast_label
	get_tree().create_timer(3.3).timeout.connect(func():
		if is_instance_valid(current):
			current.queue_free())

func play_sound(sound_name: String) -> void:
	if bool(profile.data.settings.sound):
		sfx.stream = load("res://assets/audio/%s.wav" % sound_name)
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
