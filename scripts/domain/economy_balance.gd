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
# The founders' stores carry them through their first lean spring (about 25 days of food for
# the founding families; was 60, about 5 days, before the farming year had seasons).
const STARTING_FOOD: int = 300
const STARTING_WOOD: int = 45
const STARTING_TOOLS: int = 14

# --- Daily output of a holding worked by a two-adult family, before values and upkeep ---
# Since 2026-10-20 a family runs one holding, so these are per family (double the earlier
# per-worker values: a family's total output is unchanged). A family with one working adult
# produces half; older children add the periodic family-support bonus on top.
const FARM_FOOD_PER_DAY: float = 4.0
# The farming year (docs/FIRST_STAGE_LOOP.md, decision 1): a field's daily food by season,
# spring, summer, autumn, winter, as a share of FARM_FOOD_PER_DAY. It averages 1, so a year's
# harvest is unchanged, but most of it comes in summer and autumn and winter lives on stores.
# Tried and measured (docs/FIRST_STAGE_LOOP.md, Milestone Log): 0.4/1.0/2.2/0.4 starved towns
# founded in spring (map luck 32/48); 0.7/1.0/1.6/0.7 with founding stores of 300 still lost 3 of 20
# sensible openings; 0.8/1.0/1.4/0.8 keeps the year's shape and the towns.
const FARM_SEASON_YIELD: Array[float] = [0.8, 1.0, 1.4, 0.8]
# Felling is winter work: woodcutters fell twice as fast in winter, marked woods or not.
const WINTER_FELLING_FACTOR: float = 2.0
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
	"paver_yard": {"output": "paving_stones", "inputs": {"stone_blocks": 1}},
	"fisher": {"output": "food", "inputs": {}},
	"hunter": {"output": "food", "inputs": {}},
	"herder": {"output": "wool", "inputs": {}}
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
# Each new or newly upgraded workplace needs no tools for this long. 60 days gives about 3
# minutes at 1x to get a toolmaker running (owner decision 2026-10-20). Counted per building
# since 2026-10-27 (docs/FIRST_STAGE_LOOP.md, decision 2): a town-wide grace from founding left
# workplaces built later with little or none, and towns fell off the tool cliff at random.
const MAINTENANCE_GRACE_DAYS: int = 60
const MAINTENANCE_TOOL_COST: int = 1
const MAINTENANCE_INTERVAL_DAYS: Dictionary = {
	"farm": 24,
	"woodcutter": 20,
	"toolmaker": 16
}
const MAINTENANCE_INTERVAL_DEFAULT_DAYS: int = 20

# --- Influence prototype (docs/FAMILY_INFLUENCE_PROTOTYPE.md) ---
# What the stores always keep back from families' own workplace projects: wood for homes and
# workshops (as FamilyDevelopment keeps for homes), and tools for every proper workplace's upkeep
# for about two intervals, so families investing on their own cannot empty the tool store.
const INFLUENCE_WOOD_RESERVE: int = 10
const INFLUENCE_TOOL_RESERVE_MIN: int = 4
const INFLUENCE_TOOL_RESERVE_PER_WORKPLACE: int = 2

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
	"storehouse": {"wood": 8, "tools": 0},
	"fisher": {"wood": 4, "tools": 0},
	"hunter": {"wood": 5, "tools": 1},
	"watch_post": {"wood": 6, "tools": 1},
	"herder": {"wood": 6, "tools": 0}
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
	"storehouse": 8.0,
	"fisher": 4.0,
	"hunter": 5.0,
	"watch_post": 5.0,
	"herder": 5.0
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
# Ground in woods (every tile beside it wooded) wears at this share of the rate, and never past a
# trail: wear never fells a tree. The strips between buildings never pass a trail either.
const FOREST_WEAR_FACTOR: float = 0.5

# --- Land (docs/FIRST_STAGE_LOOP.md, Geography Shapes The Town; TownLand) ---
# Food from the land rather than fields. A fisher's hut on a bank catches FISHER_FOOD_PER_DAY when
# FISHER_FULL_WATER_TILES of water lie within FISHER_REACH of it, all year; a hunter's lodge brings
# in HUNTER_FOOD_PER_DAY when HUNTER_FULL_WOODS_TILES of woods lie within HUNTER_REACH, more in
# autumn and winter, and less as the woods around it are felled. Less water or woods, less food,
# down to LAND_YIELD_FLOOR. A farm (FARM_FOOD_PER_DAY on average) yields more but needs farmland and
# follows the farming year.
const FISHER_FOOD_PER_DAY: float = 4.0
const FISHER_REACH: int = 3
const FISHER_FULL_WATER_TILES: int = 12
const HUNTER_FOOD_PER_DAY: float = 3.5
const HUNTER_REACH: int = 6
const HUNTER_FULL_WOODS_TILES: int = 40
const HUNT_SEASON_YIELD: Array[float] = [0.9, 0.8, 1.2, 1.1]
const LAND_YIELD_FLOOR: float = 0.25
# Hazards. Some springs (HIGH_WATER_CHANCE) bring high water: a field beside a river or lake yields
# HIGH_WATER_FIELD_YIELD of its spring harvest. In winter, an unfenced hunter's lodge or gatherer's
# camp within WOLF_WOODS_DISTANCE of woods works warily: WOLF_WINTER_YIELD of its output.
const HIGH_WATER_CHANCE: float = 0.33
const HIGH_WATER_FIELD_YIELD: float = 0.4
const WOLF_WINTER_YIELD: float = 0.75
const WOLF_WOODS_DISTANCE: int = 2
# A herder's fold grazes its flock on open land within HERDER_REACH: HERDER_WOOL_PER_DAY when
# HERDER_FULL_PASTURE_TILES of pasture lie in reach (hill tiles count double: the hill pasture of
# the land table). Wolves threaten an unfenced fold at the woods' edge in winter, as they do a lodge.
const HERDER_WOOL_PER_DAY: float = 1.0
const HERDER_REACH: int = 3
const HERDER_FULL_PASTURE_TILES: int = 90

# --- Clothing (docs/FIRST_STAGE_LOOP.md, milestone 6) ---
# A garment lasts CLOTHING_DAYS_PER_PERSON, so a town needs one for every that many people a day
# (at least one). Wool is spun and worn at home: it meets the clothing need as it is.
const CLOTHING_DAYS_PER_PERSON: float = 90.0

# --- Ambitions (docs/FIRST_STAGE_LOOP.md, milestone 3; FamilyAmbitions) ---
# A fulfilled ambition adds FULFILLED_CONTENTMENT to a family's contentment (at most
# MAX_CONTENTMENT), which fades by one every CONTENTMENT_FADE_MONTHS. Each point of contentment
# raises the hardship a family endures before leaving by one. Every content family adds
# CONTENT_ATTRACTION to the town's monthly arrival chance, at most CONTENT_ATTRACTION_MAX in all.
# An ambition waiting longer than AMBITION_PATIENCE_MONTHS lowers the hardship a family endures by
# AMBITION_WAITING_STRAIN.
# A family wants its field fenced once FENCE_WISH_TRIPS trips a day cross it.
const MAX_CONTENTMENT: int = 4
const FULFILLED_CONTENTMENT: int = 2
const CONTENTMENT_FADE_MONTHS: int = 12
const AMBITION_PATIENCE_MONTHS: int = 12
const AMBITION_WAITING_STRAIN: int = 1
const FENCE_WISH_TRIPS: float = 0.5
const CONTENT_ATTRACTION: int = 3
const CONTENT_ATTRACTION_MAX: int = 15

# --- Trade (docs/FIRST_STAGE_LOOP.md, The Way To Trade; TownTrade) ---
# What goods are worth in grain at the neutral town. A trader wants TRADER_WANT_KINDS goods from
# TRADER_WANTS and offers TRADER_OFFER_KINDS from TRADER_OFFERS, about TRADER_GRAIN_PER_GOOD grain
# of each. It pays TRADER_BID_SHARE of a good's value and asks TRADER_ASK_SHARE, and each unit it
# takes or sells moves its price by up to TRADER_PRICE_SLOPE of that over the visit. Lots are worth
# about TRADER_LOT_GRAIN. Traders come in summer and autumn every TRADER_INTERVAL_DAYS by the
# town's link (plus up to TRADER_INTERVAL_JITTER_DAYS) and stay TRADER_STAY_DAYS.
const VALUE_IN_GRAIN: Dictionary = {
	"food": 1.0,
	"wool": 3.0,
	"wood": 1.5,
	"tools": 10.0,
	"stone_blocks": 3.0,
	"bricks": 4.0,
	"cut_stone": 5.0,
	"carved_goods": 8.0,
}
const TRADER_WANTS: Array[String] = ["food", "wood", "tools", "stone_blocks", "bricks", "carved_goods"]
const TRADER_OFFERS: Array[String] = ["food", "wood", "tools", "stone_blocks", "wool"]
const TRADER_WANT_KINDS: int = 3
const TRADER_OFFER_KINDS: int = 2
const TRADER_GRAIN_PER_GOOD: float = 80.0
const TRADER_LOT_GRAIN: float = 15.0
const TRADER_BID_SHARE: float = 0.85
const TRADER_ASK_SHARE: float = 1.15
const TRADER_PRICE_SLOPE: float = 0.5
const TRADER_STAY_DAYS: int = 10
const TRADER_INTERVAL_DAYS: Dictionary = {"crossroads": 20, "road": 30, "river": 45}
const TRADER_INTERVAL_JITTER_DAYS: int = 6

# --- Defense (docs/FIRST_STAGE_LOOP.md, milestone 5; TownDefense) ---
# From BANDITS_FROM_DAY, every BANDIT_ROLL_INTERVAL_DAYS outside winter, a band takes to the road
# toward a town with BANDIT_MONTHLY_CHANCE by how traders reach it, times the town's temptation
# (its stores' worth in grain against TEMPTING_STORE_GRAIN, between TEMPTATION_MIN and _MAX). It is
# seen BANDIT_WARNING_DAYS before it comes, with strength BANDIT_BASE_STRENGTH times temptation
# (plus 0-1, at most BANDIT_MAX_STRENGTH). A kept watch post guards with WATCH_POST_GUARD, each of
# up to MILITIA_FAMILIES called-up families with MILITIA_GUARD. A band meeting less guard takes
# RAID_TAKE_SHARE of the food, tools, and wood, less in proportion to the guard it met, leaving
# RAID_FOOD_KEPT_DAYS of food; every family loses RAID_CONTENTMENT_LOSS contentment.
const BANDITS_FROM_DAY: int = 360
const BANDIT_ROLL_INTERVAL_DAYS: int = 30
const BANDIT_MONTHLY_CHANCE: Dictionary = {"crossroads": 0.12, "road": 0.08, "river": 0.04}
const TEMPTING_STORE_GRAIN: float = 3000.0
const TEMPTATION_MIN: float = 0.5
const TEMPTATION_MAX: float = 2.0
const BANDIT_WARNING_DAYS: int = 10
const BANDIT_BASE_STRENGTH: float = 2.0
const BANDIT_MAX_STRENGTH: int = 5
const WATCH_POST_GUARD: int = 2
const MILITIA_GUARD: int = 1
const MILITIA_FAMILIES: int = 3
const RAID_TAKE_SHARE: float = 0.3
const RAID_FOOD_KEPT_DAYS: float = 30.0
const RAID_CONTENTMENT_LOSS: int = 1

# --- Errands (docs/TOWN_BUILDING_MODEL.md, Errands) ---
# Round trips a day each family makes from home besides work (TownErrands): to the store for
# food and goods every three days, to the nearest bank for water daily, to the woods' edge for
# firewood every four days, and to visit kin weekly. They wear paths and trample fields, and cost
# the family's workplace nothing. Cultural values will shape them per family later.
const ERRAND_ROUND_TRIPS_PER_DAY: Dictionary = {
	"store": 1.0 / 3.0,
	"water": 1.0,
	"firewood": 0.25,
	"kin": 1.0 / 7.0,
}

# --- Fields (docs/TOWN_BUILDING_MODEL.md, Fields and fences) ---
# People who walk through a field (not along its edge) trample it: each daily trip across a field
# costs it this share of its harvest, up to the max. A field's own family does not count.
const FIELD_TRAMPLE_LOSS_PER_TRIP: float = 0.02
const FIELD_TRAMPLE_MAX_LOSS: float = 0.4
# A fence keeps everyone else out of a field or a yard, and off its edges; it is built like
# anything else. Wood and work follow the fence's length: a 3x3 field takes 4 wood and 2
# family-days, a 2x2 house 3 wood and about 1.3.
const FENCE_EDGE_TILES_PER_WOOD: float = 3.0
const FENCE_WORK_DAYS_PER_EDGE_TILE: float = 1.0 / 6.0

# --- Woodland (docs/TOWN_BUILDING_MODEL.md, Woodland) ---
# A woodcutter's family fells the woods the player marked for clearing as the place it cuts its
# wood (its output is unchanged): a wooded tile takes this many full working days.
const CLEAR_DAYS_PER_TILE: float = 2.0
# With no woods marked, a woodcutter cuts the trees nearest it, slowly (owner, 2026-10-27): this
# share of its day goes into felling, so a tile falls every 20 working days, about 16 a year.
const UNMARKED_FELLING_SHARE: float = 0.1
# Clearing only clears; land marked to till becomes farmland after this many full working days
# of a field's family (TownFarmland), its harvest unchanged.
const TILL_DAYS_PER_TILE: float = 3.0
# Forest expansion (TownWoodland.spread_forest), once a year. Woods beyond the town map's edge
# count too: the woods at the edge are taken to go on past it. Every open tile that can grow woods
# and has woods on a side (not just a corner) may become woods. Woods within
# FOREST_INFLUENCE_RADIUS steps (|dx| + |dy|) push it: each wooded tile adds
# FOREST_INFLUENCE_DECAY ^ (steps - 1), so a side neighbour adds 1, a corner 0.5, three steps
# 0.25. The year's chance for a total influence I is
#   FOREST_SPREAD_MAX_CHANCE * (1 - (1 - FOREST_SPREAD_BASE_CHANCE / FOREST_SPREAD_MAX_CHANCE) ^ I),
# which is the base chance beside a lone wooded tile (I = 1), about 2.6% on a long straight edge
# (I = 3.75), 3.8% for a tile ringed by woods (I = 11), and never more than the max. A big forest
# spreads faster in all only because it has more edge; woods further away add nothing.
# Placeholders until tile size and the game's pace are calibrated: a town tile is a quarter of a
# regional tile, and a year is 360 days (6 minutes at 1x).
const FOREST_SPREAD_BASE_CHANCE: float = 0.01
const FOREST_SPREAD_MAX_CHANCE: float = 0.04
const FOREST_INFLUENCE_RADIUS: int = 3
const FOREST_INFLUENCE_DECAY: float = 0.5
# The year's spread is chosen at the start of spring and grows in a tile at a time, each on its
# own day between spring and the end of autumn (owner, 2026-10-27): the first three seasons.
const FOREST_GROWING_DAYS: int = 270

static func get_fence_cost(size: Vector2i) -> Dictionary:
	return {"wood": int(ceil(float(2 * (size.x + size.y)) / FENCE_EDGE_TILES_PER_WOOD))}

static func get_fence_work_days(size: Vector2i) -> float:
	return float(2 * (size.x + size.y)) * FENCE_WORK_DAYS_PER_EDGE_TILE

static func get_build_cost(building_type: String) -> Dictionary:
	return (BUILD_COSTS.get(building_type, {}) as Dictionary).duplicate()

static func get_build_work_days(building_type: String) -> float:
	return float(BUILD_WORK_DAYS.get(building_type, BUILD_WORK_DEFAULT_DAYS))

static func get_maintenance_interval(building_type: String) -> int:
	return int(MAINTENANCE_INTERVAL_DAYS.get(building_type, MAINTENANCE_INTERVAL_DEFAULT_DAYS))
