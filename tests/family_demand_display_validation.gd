extends SceneTree

const HouseholdScript = preload("res://scripts/domain/household.gd")
const HouseholdDemandDisplayHelperScript = preload("res://scripts/ui/household_demand_display_helper.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_housed_family_demand_lines()
	test_unsheltered_family_demand_lines()
	test_temporary_family_demand_lines()

	if failure_count > 0:
		push_error("Family demand display validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Family demand display validation passed.")
	quit()

func test_housed_family_demand_lines() -> void:
	var household = HouseholdScript.new(1, 2, HouseholdScript.WORK_PREF_NEUTRAL, 5, HouseholdScript.RESIDENCE_HOUSED)
	var lines: Array[String] = HouseholdDemandDisplayHelperScript.get_demand_lines(null, household)

	_check(lines.has("Food: 5 population"), "housed household should show population food pressure")
	_check(lines.has("Household goods: contributes 1 home-life demand"), "housed household should contribute household goods demand")
	_check(lines.has("Clothing: 5 population pressure, not supplied yet"), "housed household should show future-facing clothing pressure")
	_check(lines.has("Shelter: housed"), "housed household should show housed shelter status")

func test_unsheltered_family_demand_lines() -> void:
	var household = HouseholdScript.new(2, -1, HouseholdScript.WORK_PREF_NEUTRAL, 4, HouseholdScript.RESIDENCE_UNSHELTERED)
	var lines: Array[String] = HouseholdDemandDisplayHelperScript.get_demand_lines(null, household)

	_check(lines.has("Food: 4 population"), "unsheltered household should still show food pressure")
	_check(lines.has("Household goods: no full home-life demand while unsheltered"), "unsheltered household should not show full household goods demand")
	_check(lines.has("Clothing: 4 population pressure, not supplied yet"), "unsheltered household should show clothing pressure without penalty")
	_check(lines.has("Shelter: unsheltered"), "unsheltered household should show shelter status")

func test_temporary_family_demand_lines() -> void:
	var household = HouseholdScript.new(3, -1, HouseholdScript.WORK_PREF_NEUTRAL, 3, HouseholdScript.RESIDENCE_TEMPORARY)
	var lines: Array[String] = HouseholdDemandDisplayHelperScript.get_demand_lines(null, household)

	_check(lines.has("Food: 3 population"), "temporary household should show population food pressure")
	_check(lines.has("Household goods: no full home-life demand while temporary shelter"), "temporary household should not show full household goods demand")
	_check(lines.has("Clothing: 3 population pressure, not supplied yet"), "temporary household should show clothing pressure without penalty")
	_check(lines.has("Shelter: temporary shelter"), "temporary household should show temporary shelter status")

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
