extends SceneTree
## Run with godot --headless --path . --script tests/test_profile.gd
const Profile = preload("res://scripts/core/Profile.gd")
var checks := 0
var failures := 0
var test_path := "user://test_profile_" + str(OS.get_process_id()) + ".json"

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var profile := Profile.new()
	check(not profile.load_profile(test_path), "New profile uses defaults")
	check(profile.data["coins"] == 500 and profile.data["gems"] == 25, "Starting economy")
	check(profile.catalog.size() == 8, "Eight complete skin definitions available")
	check(profile.data["name"] == "PILOT" and profile.data["version"] == 2, "New profiles use English name and current schema")
	check(profile.data["settings"]["sound"] and profile.data["settings"]["music"], "Music and effects enabled independently by default")
	check(profile.data["owned"] == [0] and profile.data["equipped"] == 0, "Starter inventory")
	check(not profile.equip_skin(1), "Cannot equip locked skin")
	check(not profile.buy_skin(99), "Unknown skin rejected")
	check(not profile.buy_skin(4), "Insufficient funds rejected")
	check(profile.data["coins"] == 500, "Rejected purchase leaves coins unchanged")
	check(profile.buy_skin(1), "Purchase writes real inventory")
	check(profile.data["coins"] == 350 and profile.data["owned"].has(1), "Purchase deducts exact price")
	check(not profile.buy_skin(1) and profile.data["coins"] == 350, "Duplicate purchase rejected")
	check(profile.equip_skin(1), "Owned skin equips")
	check(profile.set_player_name("  Blue Serpent  "), "Name edit persists")
	check(not profile.set_player_name("   "), "Empty names rejected")
	check(profile.set_setting("quality", "Low"), "English graphics setting changes")
	check(profile.set_setting("sound", false), "Sound setting changes")
	check(profile.data["settings"]["music"], "Disabling effects leaves music enabled")
	check(profile.set_setting("music", false), "Music can be disabled separately")
	check(profile.set_setting("sound", true) and not profile.data["settings"]["music"], "Enabling effects leaves music disabled")
	check(profile.set_setting("sound", false), "Effects preference restores independently")
	check(not profile.set_setting("music", "false"), "Music setting requires a boolean")
	check(profile.set_setting("difficulty", 2), "Difficulty setting changes")
	check(not profile.set_setting("quality", "UltraFake"), "Unknown graphics profile rejected")
	check(not profile.set_setting("difficulty", 9), "Invalid difficulty rejected")
	check(not profile.set_setting("not_a_setting", true), "Unknown setting rejected")
	var reload := Profile.new()
	check(reload.load_profile(test_path), "Saved profile reloads")
	check(reload.data["name"] == "Blue Serpent" and reload.data["equipped"] == 1, "Name and selected skin survive restart")
	check(reload.data["settings"]["quality"] == "Low" and not reload.data["settings"]["sound"] and not reload.data["settings"]["music"] and reload.data["settings"]["difficulty"] == 2, "All independent audio and graphics settings survive restart")
	check(not profile.claim_mission(0), "Incomplete mission cannot be claimed")
	var run_result := {"score": 2200, "time": 200.0, "kills": 4, "energy": 270}
	var reward := profile.record_run(run_result)
	check(reward["coins"] == 290 and reward["xp"] == 711, "Run rewards use score, survival, kills")
	check(profile.data["best_score"] == 2200 and reward["new_record"], "High score recorded")
	check(profile.data["level"] == 4, "XP advances level")
	check(profile.data["stats"]["runs"] == 1 and profile.data["stats"]["energy"] == 270, "Statistics accumulate")
	check(profile.data["achievements"].has("first_run") and profile.data["achievements"].has("collector") and profile.data["achievements"].has("survivor"), "Achievements unlock from actual stats")
	check(profile.mission_status(0)["ready"], "Mission becomes claimable after progress")
	var coins_before: int = profile.data["coins"]
	check(profile.claim_mission(0) and profile.data["coins"] == coins_before + 80, "Mission pays persistent rewards")
	check(not profile.claim_mission(0), "Mission cannot be claimed twice")
	check(not profile.claim_mission(-1) and not profile.claim_mission(99), "Invalid mission index rejected")
	check(profile.claim_daily(), "Daily chest pays once")
	coins_before = profile.data["coins"]
	check(not profile.claim_daily() and profile.data["coins"] == coins_before, "Daily cooldown prevents duplicate payout")
	check(profile.buy_skin(4) and profile.equip_skin(4), "Earned coins unlock legendary skin")
	var previous := profile.data.duplicate(true)
	var abandoned := profile.record_run({"score":999999, "abandoned":true})
	check(abandoned["coins"] == 0 and profile.data == previous, "Abandon does not grant fabricated rewards")
	# Saving twice establishes a known valid previous generation as backup.
	check(profile.save_profile() and profile.save_profile(), "Repeated save safely refreshes backup")
	var corrupt := FileAccess.open(test_path, FileAccess.WRITE)
	corrupt.store_string("{ interrupted write")
	corrupt.close()
	var recovered := Profile.new()
	check(recovered.load_profile(test_path) and recovered.recovered_backup, "Corrupted primary recovers valid backup")
	check(recovered.data["equipped"] == 4 and recovered.data["coins"] == previous["coins"], "Recovery preserves inventory and balance")
	check(recovered.save_profile(), "Recovered profile can be saved")
	var recovered_restart := Profile.new()
	check(recovered_restart.load_profile(test_path) and not recovered_restart.recovered_backup, "Recovered save becomes healthy primary")
	check(recovered_restart.data["missions_claimed"].has(0) and not recovered_restart.can_claim_daily(), "Mission claims and daily cooldown survive restart")
	# Migration keeps real v1 balances, names and inventory, translating only settings.
	var migration_path := test_path + ".v1"
	var quality_names := {"Baixo":"Low", "Médio":"Medium", "Alto":"High"}
	for old_quality in quality_names:
		var legacy: Dictionary = previous.duplicate(true)
		legacy["version"] = 1
		legacy["name"] = "PILOTO" if old_quality == "Baixo" else "RIVAL_42"
		legacy["settings"]["quality"] = old_quality
		legacy["settings"]["sound"] = old_quality != "Baixo"
		legacy["settings"].erase("music")
		var old_file := FileAccess.open(migration_path, FileAccess.WRITE)
		old_file.store_string(JSON.stringify(legacy))
		old_file.close()
		var migrated := Profile.new()
		check(migrated.load_profile(migration_path) and migrated.data["version"] == 2, "v1 profile migrates to current schema: " + old_quality)
		check(migrated.data["settings"]["quality"] == quality_names[old_quality], "Legacy graphics choice migrates to English: " + old_quality)
		check(migrated.data["settings"]["music"] == legacy["settings"]["sound"] and migrated.data["settings"]["sound"] == legacy["settings"]["sound"], "Migration preserves previous whole-audio preference: " + old_quality)
		check(migrated.data["coins"] == legacy["coins"] and migrated.data["gems"] == legacy["gems"] and migrated.data["fragments"] == legacy["fragments"] and migrated.data["owned"] == legacy["owned"] and migrated.data["equipped"] == legacy["equipped"] and migrated.data["name"] == legacy["name"], "Migration preserves balances inventory and player-chosen name: " + old_quality)
		check(migrated.save_profile(), "Migrated profile saves in current format: " + old_quality)
		var migrated_restart := Profile.new()
		check(migrated_restart.load_profile(migration_path) and migrated_restart.data["version"] == 2 and migrated_restart.data["settings"] == migrated.data["settings"], "Migrated settings survive restart: " + old_quality)
	var expanded_path := test_path + ".expanded"
	var expanded := Profile.new()
	expanded.load_profile(expanded_path)
	expanded.data["coins"] = 2000
	for id in [5, 6, 7]:
		check(expanded.buy_skin(id) and expanded.equip_skin(id), "New catalog skin can be purchased and equipped: " + str(id))
		check(not expanded.buy_skin(id), "New catalog skin cannot be purchased twice: " + str(id))
	check(expanded.data["coins"] == 600, "New skins deduct their exact combined price")
	var expanded_restart := Profile.new()
	check(expanded_restart.load_profile(expanded_path) and expanded_restart.data["owned"] == [0,5,6,7] and expanded_restart.data["equipped"] == 7, "Expanded inventory and selected skin persist")
	check(expanded.skin(5)["ability"] == "Solar Magnet" and expanded.skin(6)["duration"] == 0.8 and expanded.skin(7)["price"] == 200, "Expanded catalog contains power metadata and prices")
	# Protect a future-version save from downgrade overwrite.
	var future_file := FileAccess.open(test_path, FileAccess.WRITE)
	var future: Dictionary = previous.duplicate(true)
	future["version"] = 99
	future_file.store_string(JSON.stringify(future))
	future_file.close()
	var future_profile := Profile.new()
	future_profile.load_profile(test_path)
	check(not future_profile.save_profile(), "Future save version cannot be overwritten")
	var future_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(test_path))
	check(future_parsed["version"] == 99, "Future save remains intact")
	for path in [test_path, migration_path, expanded_path]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	print("PROFILE TESTS: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
