extends SceneTree

const BuildingScript = preload("res://scripts/domain/building.gd")
const CityScript = preload("res://scripts/domain/city.gd")
const HouseholdScript = preload("res://scripts/domain/household.gd")
const ProductionRequirementHelperScript = preload("res://scripts/ui/production_requirement_helper.gd")
const SelectedBuildingActionHintHelperScript = preload("res://scripts/ui/selected_building_action_hint_helper.gd")
const WorkplaceStabilityDisplayHelperScript = preload("res://scripts/ui/workplace_stability_display_helper.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_housed_household_has_no_workplace_warning()
	test_temporary_household_has_workplace_warning()
	test_unsheltered_household_has_workplace_warning()

	if failure_count > 0:
		push_error("Unsheltered workplace warning validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Unsheltered workplace warning validation passed.")
	quit()

func test_housed_household_has_no_workplace_warning() -> void:
	var setup: Dictionary = _make_assigned_workplace(HouseholdScript.RESIDENCE_HOUSED)
	var warning_lines: Array[String] = WorkplaceStabilityDisplayHelperScript.get_warning_lines(setup["city"], setup["building"])
	var requirement_lines: Array[String] = ProductionRequirementHelperScript.get_requirement_lines(setup["city"], setup["building"])
	var hints: Array[String] = SelectedBuildingActionHintHelperScript.get_hints(setup["building"], setup["city"])

	_check(warning_lines.is_empty(), "housed assigned household should not create workplace stability warning")
	_check(not _has_line_starting_with(requirement_lines, "Workplace stability:"), "housed household should not add requirement warning")
	_check(not hints.has("House the assigned household to stabilize this workplace."), "housed household should not add stability action hint")

func test_temporary_household_has_workplace_warning() -> void:
	var setup: Dictionary = _make_assigned_workplace(HouseholdScript.RESIDENCE_TEMPORARY)
	var warning_lines: Array[String] = WorkplaceStabilityDisplayHelperScript.get_warning_lines(setup["city"], setup["building"])
	var requirement_lines: Array[String] = ProductionRequirementHelperScript.get_requirement_lines(setup["city"], setup["building"])
	var hints: Array[String] = SelectedBuildingActionHintHelperScript.get_hints(setup["building"], setup["city"])

	_check(warning_lines.has("Workplace stability: assigned household is temporarily sheltered"), "temporary assigned household should create workplace stability warning")
	_check(warning_lines.has("Housing instability may reduce reliability later"), "temporary warning should remain future-facing")
	_check(requirement_lines.has("Workplace stability: assigned household is temporarily sheltered"), "temporary warning should appear in production requirements")
	_check(hints.has("House the assigned household to stabilize this workplace."), "temporary warning should add selected building action hint")

func test_unsheltered_household_has_workplace_warning() -> void:
	var setup: Dictionary = _make_assigned_workplace(HouseholdScript.RESIDENCE_UNSHELTERED)
	var warning_lines: Array[String] = WorkplaceStabilityDisplayHelperScript.get_warning_lines(setup["city"], setup["building"])
	var requirement_lines: Array[String] = ProductionRequirementHelperScript.get_requirement_lines(setup["city"], setup["building"])
	var hints: Array[String] = SelectedBuildingActionHintHelperScript.get_hints(setup["building"], setup["city"])

	_check(warning_lines.has("Workplace stability: assigned household is unsheltered"), "unsheltered assigned household should create workplace stability warning")
	_check(warning_lines.has("Housing instability may reduce reliability later"), "unsheltered warning should remain future-facing")
	_check(requirement_lines.has("Workplace stability: assigned household is unsheltered"), "unsheltered warning should appear in production requirements")
	_check(hints.has("House the assigned household to stabilize this workplace."), "unsheltered warning should add selected building action hint")

func _make_assigned_workplace(housing_status: String) -> Dictionary:
	var city = CityScript.new("Workplace Stability Test City")
	var household = city.households[0]
	household.housing_status = housing_status

	var building = BuildingScript.new(100, BuildingScript.BUILDING_FARM, Vector2i.ZERO, Vector2i(2, 2))
	building.assign_household(household)

	return {
		"city": city,
		"building": building,
	}

func _has_line_starting_with(lines: Array[String], prefix: String) -> bool:
	for line: String in lines:
		if line.begins_with(prefix):
			return true

	return false

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
