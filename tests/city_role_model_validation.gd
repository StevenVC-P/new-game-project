extends SceneTree

const CityScript = preload("res://scripts/domain/city.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_default_city_role_is_player()
	test_player_city_helpers()
	test_neutral_city_helpers()
	test_debug_city_helpers()
	test_invalid_role_falls_back_to_player()
	test_set_role_normalizes_values()
	test_neutral_city_tick_guard_keeps_resources_stable()

	if failure_count > 0:
		push_error("City role model validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("City role model validation passed.")
	quit()

func test_default_city_role_is_player() -> void:
	var city = CityScript.new("Default Role City")

	_check(city.role == CityScript.ROLE_PLAYER, "default city role should be player")
	_check(city.is_player_city(), "default city should report player role")
	_check(city.is_controllable_city(), "default player city should be controllable")
	_check(city.should_tick_simulation(), "default player city should tick simulation")

func test_player_city_helpers() -> void:
	var city = CityScript.new("Player City", Vector2.ZERO, CityScript.ROLE_PLAYER)

	_check(city.is_player_city(), "player city should report player")
	_check(not city.is_neutral_city(), "player city should not report neutral")
	_check(not city.is_debug_city(), "player city should not report debug")
	_check(city.is_controllable_city(), "player city should be controllable")
	_check(city.should_tick_simulation(), "player city should tick simulation")

func test_neutral_city_helpers() -> void:
	var city = CityScript.new("Neutral Town", Vector2.ZERO, CityScript.ROLE_NEUTRAL)

	_check(city.is_neutral_city(), "neutral city should report neutral")
	_check(not city.is_player_city(), "neutral city should not report player")
	_check(not city.is_debug_city(), "neutral city should not report debug")
	_check(not city.is_controllable_city(), "neutral city should not be controllable")
	_check(not city.should_tick_simulation(), "neutral city should not tick simulation by default")

func test_debug_city_helpers() -> void:
	var city = CityScript.new("Debug City", Vector2.ZERO, CityScript.ROLE_DEBUG)

	_check(city.is_debug_city(), "debug city should report debug")
	_check(not city.is_player_city(), "debug city should not report player")
	_check(not city.is_neutral_city(), "debug city should not report neutral")
	_check(city.is_controllable_city(), "debug city should be controllable for compatibility")
	_check(city.should_tick_simulation(), "debug city should tick simulation for compatibility")

func test_invalid_role_falls_back_to_player() -> void:
	var city = CityScript.new("Invalid Role City", Vector2.ZERO, "observer")

	_check(city.role == CityScript.ROLE_PLAYER, "invalid constructor role should fall back to player")
	_check(city.is_player_city(), "invalid constructor role fallback should be player")

func test_set_role_normalizes_values() -> void:
	var city = CityScript.new("Mutable Role City")

	city.set_role(CityScript.ROLE_NEUTRAL)
	_check(city.role == CityScript.ROLE_NEUTRAL, "set_role should accept neutral")
	_check(city.is_neutral_city(), "set_role neutral should update helper state")

	city.set_role("unknown")
	_check(city.role == CityScript.ROLE_PLAYER, "set_role should normalize unknown values to player")
	_check(city.is_player_city(), "set_role unknown fallback should be player")

func test_neutral_city_tick_guard_keeps_resources_stable() -> void:
	var city = CityScript.new("Neutral Town", Vector2.ZERO, CityScript.ROLE_NEUTRAL)
	var starting_food: int = int(city.resources["food"])

	if city.should_tick_simulation():
		city.tick()

	_check(int(city.resources["food"]) == starting_food, "neutral city should not tick through role-gated simulation paths")

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
