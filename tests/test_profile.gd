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
	check(profile.catalog.size() == 5, "Five complete skins available")
	check(profile.data["owned"] == [0] and profile.data["equipped"] == 0, "Starter inventory")
	check(not profile.equip_skin(1), "Cannot equip locked skin")
	check(not profile.buy_skin(99), "Unknown skin rejected")
	check(not profile.buy_skin(4), "Insufficient funds rejected")
	check(profile.data["coins"] == 500, "Rejected purchase leaves coins unchanged")
	check(profile.buy_skin(1), "Purchase writes real inventory")
	check(profile.data["coins"] == 350 and profile.data["owned"].has(1), "Purchase deducts exact price")
	check(not profile.buy_skin(1) and profile.data["coins"] == 350, "Duplicate purchase rejected")
	check(profile.equip_skin(1), "Owned skin equips")
	check(profile.set_player_name("  Cobra Azul  "), "Name edit persists")
	check(not profile.set_player_name("   "), "Empty names rejected")
	check(profile.set_setting("quality", "Baixo"), "Graphics setting changes")
	check(profile.set_setting("sound", false), "Sound setting changes")
	check(profile.set_setting("difficulty", 2), "Difficulty setting changes")
	check(not profile.set_setting("quality", "UltraFake"), "Unknown graphics profile rejected")
	check(not profile.set_setting("difficulty", 9), "Invalid difficulty rejected")
	check(not profile.set_setting("not_a_setting", true), "Unknown setting rejected")
	var reload := Profile.new()
	check(reload.load_profile(test_path), "Saved profile reloads")
	check(reload.data["name"] == "Cobra Azul" and reload.data["equipped"] == 1, "Name and selected skin survive restart")
	check(reload.data["settings"]["quality"] == "Baixo" and not reload.data["settings"]["sound"] and reload.data["settings"]["difficulty"] == 2, "All settings survive restart")
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
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(test_path + suffix)
	print("PROFILE TESTS: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
