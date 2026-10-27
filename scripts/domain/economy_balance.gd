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
# What each workplace makes and the inputs it uses per unit made (tier 0 uses its tier 1 type's).
const PRODUCTION: Dictionary = {
	"farm": {"output": "food", "inputs": {}},
	"woodcutter": {"output": "wood", "inputs": {}},
	"toolmaker": {"output": "tools", "inputs": {"wood": TOOLMAKER_WOOD_PER_TOOL}},
	"quarry": {"output": "stone_blocks", "inputs": {}},
	"stonecutter": {"output": "cut_stone", "inputs": {"stone_blocks": 1}},
	"brickworks": {"output": "bricks", "inputs": {"wood": 1}},
	"lime_kiln": {"output": "lime", "inputs": {"stone_blocks": 1, "wood": 1}},
	"mortar_yard": {"output": "mortar", "inputs": {"lime": 1, "stone_blocks": 1}},
	"mason_yard": {"output": "masonry", "inputs": {"cut_stone": 1, "mortar": 1}},
	"sculptor": {"output": "statues", "inputs": {"cut_stone": 1, "tools": 1}},
	"carver": {"output": "carved_goods", "inputs": {"wood": 1, "tools": 1}},
	"tileworks": {"output": "tiles", "inputs": {"bricks": 1, "wood": 1}},
	"paver_yard": {"output": "paving_stones", "inputs": {"stone_blocks": 1}}
}
# Working adults in the family the output values above assume.
const FULL_FAMILY_WORKING_ADULTS: float = 2.0

# --- Building tiers (scripts/domain/building_tiers.gd) ---
# Tier 0 hand work produces this fraction of its tier 1 counterpart and needs no tool upkeep.
const TIER0_OUTPUT_FRACTION: float = 1.0 / 3.0
# Families living in tier 0 housing (huts, temporary shelter) for longer than this start to
# accumulate hardship, scaled by their Home and Place values.
const ROUGH_HOUSING_GRACE_MONTHS: int = 6

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
	"hut": {},
	"forager_garden": {},
	"gatherer_camp": {},
	"tool_mender": {},
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
	"paver_yard": {"wood": 8, "tools": 1},
	"storehouse": {"wood": 8, "tools": 0}
}

# --- Construction (docs/TOWN_BUILDING_MODEL.md) ---
# Work to raise a building, in family-days: one two-adult family working a whole day. Builders
# first carry the materials from a store to the site, then build; carrying is extra work that
# grows with distance (see Logistics below).
const BUILD_WORK_DAYS: Dictionary = {
	"hut": 3.0,
	"forager_garden": 2.0,
	"gatherer_camp": 2.0,
	"tool_mender": 3.0,
	"house": 8.0,
	"farm": 6.0,
	"woodcutter": 6.0,
	"toolmaker": 10.0,
	"storehouse": 8.0
}
const BUILD_WORK_DEFAULT_DAYS: float = 12.0
# An upgrade in place reuses the site, so it takes this share of building the tier 1 type new.
const UPGRADE_WORK_FRACTION: float = 0.75
const ROAD_WORK_DAYS_PER_TILE: float = 0.25
# Families that can work one site at once.
const MAX_CREW_TIER0: int = 2
const MAX_CREW: int = 3
# A family that works a holding can still give this share of its day to its own home or to tier 0
# hand work, at the same cost to its holding's output that day.
const SPARE_TIME_SHARE: float = 0.2

# --- Logistics (docs/TOWN_BUILDING_MODEL.md) ---
# Goods move between workplaces and stores on foot. Distances are in effort-tiles: a tile of open
# ground is 1, a road tile ROAD_EFFORT, yards and fields BUILT_EFFORT, and water cannot be
# crossed. Other ground is its terrain times its cover: rock (ROUGH_EFFORT) or sloping hill land
# (HILL_EFFORT), times WOODS_EFFORT under trees, so a wooded hillside costs 2.8. A family covers
# DAY_EFFORT_TILES in a working day and carries CARRY_LOAD units a trip.
const DAY_EFFORT_TILES: float = 500.0
const CARRY_LOAD: float = 5.0
const ROAD_EFFORT: float = 0.5
const BUILT_EFFORT: float = 2.0
const ROUGH_EFFORT: float = 3.0
const HILL_EFFORT: float = 1.4
const WOODS_EFFORT: float = 2.0
# Travel (hauling plus walking to work) never takes more than this share of a family's day.
const MAX_TRAVEL_SHARE: float = 0.6
# Each unit carried also takes a moment to load and stack, however short the trip.
const HANDLING_DAYS_PER_UNIT: float = 0.01

# --- Paths (docs/TOWN_BUILDING_MODEL.md, Paths) ---
# Nobody builds paths: ground people walk often wears into a trail, then a path, and both make
# that ground quicker to cross. Every trip a family makes over a tile adds 1 wear; wear fades by
# PATH_WEAR_DECAY a day (grass grows back over about two months untrodden), so a tile settles at
# about 60 times its daily trips. A tile becomes a trail at TRAIL_WEAR and a path at PATH_WEAR,
# and falls back a level only below half of that, so a path does not flicker at the threshold.
# A family walking to work and back (2 trips a day) wears a trail in about a month; a path needs
# more than 2.5 trips a day, so it forms where routes share ground or goods are carried.
const PATH_WEAR_DECAY: float = 1.0 / 60.0
const TRAIL_WEAR: float = 40.0
const PATH_WEAR: float = 150.0
# Share of the ground's effort left on a trail and on a path (open ground 1.0 becomes 0.85 and
# 0.65; woods and rock keep their extra cost in proportion). Built roads stay quickest.
const TRAIL_EFFORT_FACTOR: float = 0.85
const PATH_EFFORT_FACTOR: float = 0.65

# --- Woodland (docs/TOWN_BUILDING_MODEL.md, Woodland) ---
# A woodcutter's family fells the woods the player marked for clearing as the place it cuts its
# wood (its output is unchanged): a wooded tile takes this many full working days.
const CLEAR_DAYS_PER_TILE: float = 2.0
# Felled land grows back from the woods around it: each day it gains its share of wooded
# neighbours (out of 8) divided by REGROWTH_DAYS, and is woods again at 1. Ringed by woods that
# is a year; on a straight edge (3 wooded neighbours) about three; with no woods beside it,
# never, until the tiles between have grown back.
const REGROWTH_DAYS: float = 360.0
# Foot traffic fights it: wear (TownLogistics) of TRAMPLE_WEAR cancels the growth of a tile
# ringed by woods, and more pushes it back. A trail (wear 40) always holds the land open; once
# nobody walks it, its wear fades below this in three to five months and the woods come back.
const TRAMPLE_WEAR: float = 10.0
# Growth at which young trees show on the ground.
const SAPLING_GROWTH: float = 0.5

static func get_build_cost(building_type: String) -> Dictionary:
	return (BUILD_COSTS.get(building_type, {}) as Dictionary).duplicate()

static func get_build_work_days(building_type: String) -> float:
	return float(BUILD_WORK_DAYS.get(building_type, BUILD_WORK_DEFAULT_DAYS))

static func get_maintenance_interval(building_type: String) -> int:
	return int(MAINTENANCE_INTERVAL_DAYS.get(building_type, MAINTENANCE_INTERVAL_DEFAULT_DAYS))
