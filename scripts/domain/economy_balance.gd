class_name EconomyBalance
extends RefCounted

# Every tunable economy number in one place, so balance can be explored by editing this file.
# Check the effect of a change with: res://tests/sim/opening_check.gd (first two years of many towns)
# and res://tests/sim/settlement_growth_run.gd (ten years of one town).
#
# Outputs are per worked day and may be fractional; buildings carry the fraction between days.
#
# 2026-10-20 first balance pass (owner direction: tools are a valuable, slow craft; running short
# should be more common than having too many; every town must be able to get off the ground).
# Previous values: woodcutter 2.0, toolmaker 1.0/day, upkeep every 8-12 days, house 8 wood + 1 tool,
# toolmaker 10 wood + 3 tools, stone and craft buildings 2-3 tools. Results: docs/IMPLEMENTATION_ROADMAP.md.

# --- Founding ---
# Families that found a new town. With one holding per family, this is also the number of
# jobs a new town can fill (two farms, wood, and tools use four).
const FOUNDING_FAMILIES: int = 6
const STARTING_FOOD: int = 60
const STARTING_WOOD: int = 45
const STARTING_TOOLS: int = 14

# --- Daily output of a holding worked by a two-adult family, before values and upkeep ---
# Since 2026-10-20 a family runs one holding, so these are per family (double the earlier
# per-worker values: a family's total output is unchanged). A family with one working adult
# produces half; older children add the periodic family-support bonus on top.
const FARM_FOOD_PER_DAY: float = 4.0
const WOODCUTTER_WOOD_PER_DAY: float = 6.0
const TOOLMAKER_TOOLS_PER_DAY: float = 1.0
# Wood the toolmaker consumes for each tool it makes.
const TOOLMAKER_WOOD_PER_TOOL: int = 2
const EXPANDED_GOODS_PER_DAY: float = 2.0
# Working adults in the family the output values above assume.
const FULL_FAMILY_WORKING_ADULTS: float = 2.0

# --- Food ---
# One unit of food feeds this many people per day.
const PEOPLE_FED_PER_FOOD: int = 2

# --- Upkeep: every interval a workplace consumes tools, or loses condition without them ---
# New buildings need no tools for this long. 60 days gives about 3 minutes at 1x to get a
# toolmaker running (owner decision 2026-10-20; measured in docs/IMPLEMENTATION_ROADMAP.md).
const MAINTENANCE_GRACE_DAYS: int = 60
const MAINTENANCE_TOOL_COST: int = 1
const MAINTENANCE_INTERVAL_DAYS: Dictionary = {
	"farm": 24,
	"woodcutter": 20,
	"toolmaker": 16
}
const MAINTENANCE_INTERVAL_DEFAULT_DAYS: int = 20

# --- Construction costs ---
const BUILD_COSTS: Dictionary = {
	"house": {"wood": 6, "tools": 0},
	"farm": {"wood": 4, "tools": 1},
	"woodcutter": {"wood": 6, "tools": 1},
	"toolmaker": {"wood": 10, "tools": 0},
	"quarry": {"wood": 6, "tools": 1},
	"stonecutter": {"wood": 8, "tools": 1},
	"brickworks": {"wood": 8, "tools": 1},
	"lime_kiln": {"wood": 10, "tools": 1},
	"mortar_yard": {"wood": 8, "tools": 1},
	"mason_yard": {"wood": 10, "tools": 2},
	"sculptor": {"wood": 8, "tools": 2},
	"carver": {"wood": 8, "tools": 1},
	"tileworks": {"wood": 8, "tools": 1},
	"paver_yard": {"wood": 8, "tools": 1}
}

static func get_build_cost(building_type: String) -> Dictionary:
	return (BUILD_COSTS.get(building_type, {}) as Dictionary).duplicate()

static func get_maintenance_interval(building_type: String) -> int:
	return int(MAINTENANCE_INTERVAL_DAYS.get(building_type, MAINTENANCE_INTERVAL_DEFAULT_DAYS))
