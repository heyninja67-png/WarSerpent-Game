class_name PlayerProfile
extends RefCounted
## Versioned local progression. No network, real currency, or secret data.

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://profile.json"
const MISSION_DEFS := [
	{"title":"Coletor de energia", "description":"Colete 100 energias", "stat":"energy", "target":100, "coins":80, "gems":2, "fragments":3},
	{"title":"Primeira caçada", "description":"Elimine 3 adversários", "stat":"kills", "target":3, "coins":120, "gems":3, "fragments":5},
	{"title":"Resistência neon", "description":"Sobreviva 120 s no total", "stat":"survival", "target":120, "coins":100, "gems":2, "fragments":3},
	{"title":"Ascensão de Emnio", "description":"Acumule 2.000 pontos", "stat":"score", "target":2000, "coins":200, "gems":5, "fragments":8}
]
const ACHIEVEMENT_DEFS := [
	{"id":"first_run", "title":"Primeira órbita", "description":"Conclua uma partida", "stat":"runs", "target":1},
	{"id":"collector", "title":"Reator vivo", "description":"Colete 250 energias", "stat":"energy", "target":250},
	{"id":"hunter", "title":"Predador neon", "description":"Elimine 10 adversários", "stat":"kills", "target":10},
	{"id":"survivor", "title":"Além do limite", "description":"Sobreviva 180 s em uma partida", "stat":"best_survival", "target":180}
]

var data: Dictionary = {}
var catalog: Array = []
var save_path := DEFAULT_PATH
var last_error := ""
var recovered_backup := false

func _init() -> void:
	data = _defaults()
	if FileAccess.file_exists("res://data/catalog.json"):
		var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
		if decoded is Array:
			catalog = decoded

func _defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION, "name": "PILOTO", "coins": 500, "gems": 25,
		"fragments": 0, "xp": 0, "level": 1, "owned": [0], "equipped": 0,
		"best_score": 0, "settings": {"sound": true, "quality": "Auto", "difficulty": 1},
		"stats": {"runs": 0, "score": 0, "energy": 0, "kills": 0, "survival": 0.0, "best_survival": 0.0},
		"missions_claimed": [], "achievements": [], "daily_claim_day": ""
	}

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {}
	var candidate: Dictionary = parsed
	# Reject future schema versions instead of overwriting them with an older client.
	if int(candidate.get("version", 0)) > SAVE_VERSION:
		last_error = "Save de uma versão mais recente; arquivo preservado."
		return {}
	if not candidate.has("name") or not candidate.get("owned") is Array or not candidate.get("settings") is Dictionary:
		return {}
	return candidate

func load_profile(path: String = DEFAULT_PATH) -> bool:
	save_path = path
	last_error = ""
	recovered_backup = false
	var loaded := _read_save(save_path)
	if loaded.is_empty():
		loaded = _read_save(save_path + ".bak")
		recovered_backup = not loaded.is_empty()
	if loaded.is_empty():
		data = _defaults()
		if FileAccess.file_exists(save_path) and last_error.is_empty():
			last_error = "Save inválido; perfil local padrão carregado."
		return false
	data = _normalize(loaded)
	return true

func _normalize(loaded: Dictionary) -> Dictionary:
	var clean := _defaults()
	for key in clean:
		if loaded.has(key):
			clean[key] = loaded[key]
	clean["version"] = SAVE_VERSION
	clean["name"] = str(clean["name"]).strip_edges().left(18)
	if clean["name"].is_empty():
		clean["name"] = "PILOTO"
	for key in ["coins", "gems", "fragments", "xp", "best_score"]:
		clean[key] = clampi(int(clean[key]), 0, 2000000000)
	clean["level"] = 1 + int(clean["xp"]) / 200
	var owned: Array = [0]
	if clean["owned"] is Array:
		for skin in clean["owned"]:
			var id := int(skin)
			if _skin_exists(id) and not owned.has(id):
				owned.append(id)
	clean["owned"] = owned
	clean["equipped"] = int(clean["equipped"])
	if not owned.has(clean["equipped"]):
		clean["equipped"] = 0
	var settings: Dictionary = _defaults()["settings"]
	if clean["settings"] is Dictionary:
		for key in settings:
			if clean["settings"].has(key):
				settings[key] = clean["settings"][key]
	settings["sound"] = bool(settings["sound"])
	if not ["Auto", "Baixo", "Médio", "Alto"].has(settings["quality"]):
		settings["quality"] = "Auto"
	settings["difficulty"] = clampi(int(settings["difficulty"]), 0, 2)
	clean["settings"] = settings
	var stats: Dictionary = _defaults()["stats"]
	if clean["stats"] is Dictionary:
		for key in stats:
			stats[key] = maxf(0.0, float(clean["stats"].get(key, 0)))
	clean["stats"] = stats
	for key in ["missions_claimed", "achievements"]:
		if not clean[key] is Array:
			clean[key] = []
	var claimed: Array = []
	for mission in clean["missions_claimed"]:
		var index := int(mission)
		if index >= 0 and index < MISSION_DEFS.size() and not claimed.has(index):
			claimed.append(index)
	clean["missions_claimed"] = claimed
	clean["daily_claim_day"] = str(clean["daily_claim_day"])
	return clean

func save_profile() -> bool:
	last_error = ""
	var parent := ProjectSettings.globalize_path(save_path).get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(parent)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		last_error = "Não foi possível criar diretório do save."
		return false
	# Write and flush first, then atomically rename. Last valid primary becomes backup.
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Não foi possível abrir o save temporário."
		return false
	data["version"] = SAVE_VERSION
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	var valid_existing := _read_save(save_path)
	if not valid_existing.is_empty():
		var copy_error := DirAccess.copy_absolute(save_path, save_path + ".bak")
		if copy_error != OK:
			last_error = "Não foi possível preservar o backup do save."
			return false
	elif not last_error.is_empty():
		# Never clobber a save from a future version.
		DirAccess.remove_absolute(temporary)
		return false
	var error := DirAccess.rename_absolute(temporary, save_path)
	if error != OK:
		last_error = "Não foi possível confirmar o save: " + str(error)
		return false
	return true

func _skin_exists(id: int) -> bool:
	for item in catalog:
		if int(item.get("id", -1)) == id:
			return true
	return id == 0

func skin(id: int) -> Dictionary:
	for item in catalog:
		if int(item.get("id", -1)) == id:
			return item
	return {}

func buy_skin(id: int) -> bool:
	var item := skin(id)
	if item.is_empty() or data["owned"].has(id):
		return false
	var price := int(item.get("price", 0))
	if int(data["coins"]) < price:
		return false
	var previous := data.duplicate(true)
	data["coins"] -= price
	data["owned"].append(id)
	if not save_profile():
		data = previous
		return false
	return true

func equip_skin(id: int) -> bool:
	if not data["owned"].has(id) or not _skin_exists(id):
		return false
	var previous: int = data["equipped"]
	data["equipped"] = id
	if not save_profile():
		data["equipped"] = previous
		return false
	return true

func record_run(result: Dictionary) -> Dictionary:
	var reward := {"coins": 0, "xp": 0, "gems": 0, "fragments": 0, "new_record": false}
	if result.get("abandoned", false):
		return reward
	var score := clampi(int(result.get("score", 0)), 0, 10000000)
	var elapsed := clampf(float(result.get("time", result.get("survival_time", 0.0))), 0.0, 86400.0)
	var kills := clampi(int(result.get("kills", 0)), 0, 10000)
	var energy := clampi(int(result.get("energy", 0)), 0, 1000000)
	reward["coins"] = 10 + score / 10 + kills * 15
	reward["xp"] = 15 + score / 4 + int(elapsed / 3.0) + kills * 20
	reward["fragments"] = kills
	reward["new_record"] = score > int(data["best_score"])
	var previous := data.duplicate(true)
	data["best_score"] = maxi(score, int(data["best_score"]))
	for currency in ["coins", "xp", "gems", "fragments"]:
		data[currency] += int(reward[currency])
	data["level"] = 1 + int(data["xp"]) / 200
	data["stats"]["runs"] += 1
	data["stats"]["score"] += score
	data["stats"]["energy"] += energy
	data["stats"]["kills"] += kills
	data["stats"]["survival"] += elapsed
	data["stats"]["best_survival"] = maxf(elapsed, float(data["stats"]["best_survival"]))
	for achievement in ACHIEVEMENT_DEFS:
		if float(data["stats"][achievement["stat"]]) >= float(achievement["target"]) and not data["achievements"].has(achievement["id"]):
			data["achievements"].append(achievement["id"])
	if not save_profile():
		data = previous
		reward = {"coins": 0, "xp": 0, "gems": 0, "fragments": 0, "new_record": false}
	return reward

func missions() -> Array:
	return MISSION_DEFS.duplicate(true)

func mission_status(index: int) -> Dictionary:
	if index < 0 or index >= MISSION_DEFS.size():
		return {}
	var mission: Dictionary = MISSION_DEFS[index].duplicate(true)
	mission["progress"] = minf(float(data["stats"][mission["stat"]]), float(mission["target"]))
	mission["claimed"] = data["missions_claimed"].has(index)
	mission["ready"] = mission["progress"] >= float(mission["target"]) and not mission["claimed"]
	return mission

func claim_mission(index: int) -> bool:
	var mission := mission_status(index)
	if mission.is_empty() or not mission["ready"]:
		return false
	var previous := data.duplicate(true)
	for currency in ["coins", "gems", "fragments"]:
		data[currency] += int(mission[currency])
	data["missions_claimed"].append(index)
	if not save_profile():
		data = previous
		return false
	return true

func can_claim_daily() -> bool:
	return data["daily_claim_day"] != Time.get_date_string_from_system(true)

func claim_daily() -> bool:
	if not can_claim_daily():
		return false
	var previous := data.duplicate(true)
	data["daily_claim_day"] = Time.get_date_string_from_system(true)
	data["coins"] += 75
	data["gems"] += 3
	data["fragments"] += 2
	if not save_profile():
		data = previous
		return false
	return true

func achievements() -> Array:
	var all: Array = []
	for definition in ACHIEVEMENT_DEFS:
		var item: Dictionary = definition.duplicate(true)
		item["unlocked"] = data["achievements"].has(item["id"])
		item["progress"] = minf(float(data["stats"][item["stat"]]), float(item["target"]))
		all.append(item)
	return all

func set_setting(key: String, value: Variant) -> bool:
	if not data["settings"].has(key):
		return false
	if key == "sound" and not value is bool:
		return false
	if key == "quality" and not ["Auto", "Baixo", "Médio", "Alto"].has(value):
		return false
	if key == "difficulty" and (not (value is int or value is float) or int(value) < 0 or int(value) > 2):
		return false
	var previous: Variant = data["settings"][key]
	data["settings"][key] = value
	if not save_profile():
		data["settings"][key] = previous
		return false
	return true

func set_player_name(player_name: String) -> bool:
	var cleaned := player_name.strip_edges().left(18).replace("\n", " ").replace("\t", " ")
	if cleaned.is_empty():
		return false
	var previous: String = data["name"]
	data["name"] = cleaned
	if not save_profile():
		data["name"] = previous
		return false
	return true
