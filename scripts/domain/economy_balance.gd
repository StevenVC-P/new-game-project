class_name EconomyBalance
extends RefCounted

# Every tunable economy number in one place, so balance can be explored by editing this file.
# Check the effect of a change with: res://tests/sim/opening_check.gd (first two years of many towns)
# and res://tests/sim/settlement_growth_run.gd (ten years of one town).
#
# Outputs are per worked day and may be fractional; buildings carry the fraction between days.

# --- Founding stock ---
const STARTING_FOOD: int = 60
const STARTING_WOOD: int = 45
const STARTING_TOOLS: int = 14

# --- Daily output of a worked building, before family values and upkeep ---
const FARM_FOOD_PER_DAY: float = 2.0
const WOODCUTTER_WOOD_PER_DAY: float = 2.0
const TOOLMAKER_TOOLS_PER_DAY: float = 1.0
# Wood the toolmaker consumes for each tool it makes.
const TOOLMAKER_WOOD_PER_TOOL: int = 2
const EXPANDED_GOODS_PER_DAY: float = 1.0

# --- Food ---
# One unit of food feeds this many people per day.
const PEOPLE_FED_PER_FOOD: int = 2

# --- Upkeep: every interval a workplace consumes tools, or loses condition without them ---
const MAINTENANCE_GRACE_DAYS: int = 20
const MAINTENANCE_TOOL_COST: int = 1
const MAINTENANCE_INTERVAL_DAYS: Dictionary = {
	"farm": 12,
	"woodcutter": 10,
	"toolmaker": 8
}
const MAINTENANCE_INTERVAL_DEFAULT_DAYS: int = 10

# --- Construction costs ---
const BUILD_COSTS: Dictionary = {
	"house": {"wood": 8, "tools": 1},
	"farm": {"wood": 4, "tools": 1},
	"woodcutter": {"wood": 6, "tools": 1},
	"toolmaker": {"wood": 10, "tools": 3},
	"quarry": {"wood": 6, "tools": 2},
	"stonecutter": {"wood": 8, "tools": 2},
	"brickworks": {"wood": 8, "tools": 2},
	"lime_kiln": {"wood": 10, "tools": 2},
	"mortar_yard": {"wood": 8, "tools": 2},
	"mason_yard": {"wood": 10, "tools": 3},
	"sculptor": {"wood": 8, "tools": 3},
	"carver": {"wood": 8, "tools": 2},
	"tileworks": {"wood": 8, "tools": 2},
	"paver_yard": {"wood": 8, "tools": 2}
}

static func get_build_cost(building_type: String) -> Dictionary:
	return (BUILD_COSTS.get(building_type, {}) as Dictionary).duplicate()

static func get_maintenance_interval(building_type: String) -> int:
	return int(MAINTENANCE_INTERVAL_DAYS.get(building_type, MAINTENANCE_INTERVAL_DEFAULT_DAYS))
