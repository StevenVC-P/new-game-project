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
# Since sprint S2 a woodcutter's wood is the timber it fells, so winter's faster felling shows in its
# wood: twice the other seasons' pace in winter, the year's total unchanged (spring, summer, autumn,
# winter).
const WOOD_SEASON_YIELD: Array[float] = [0.8, 0.8, 0.8, 1.6]

# --- Winter fuel (TownFuel, sprint S3) ---
# A season's warmth is the site's climate temperature (0 to 1; temperate is about 0.55) plus
# SEASON_TEMPERATURE_OFFSET (spring, summer, autumn, winter). Below HEATING_BELOW_TEMPERATURE a
# hearth burns wood: FUEL_PER_PERSON_DAY at full cold (0 warmth), less the milder it is. So a
# temperate town heats in winter only, a cold one from autumn to spring, a tropical one never: a
# family of four burns about 0.4 wood a day in a temperate winter and 0.9 in a cold one. Families
# in temporary shelter or a hut burn ROUGH_SHELTER_FUEL_FACTOR as much. A family short of fuel
# loses one working day in COLD_SKIP_TICK_INTERVAL (on other days than hunger's), and
# HARDSHIP_COLD_DAYS cold days in a month are COLD_HARDSHIP_POINTS of hardship, half of hunger's.
const SEASON_TEMPERATURE_OFFSET: Array[float] = [0.0, 0.2, 0.0, -0.25]
const HEATING_BELOW_TEMPERATURE: float = 0.5
const FUEL_PER_PERSON_DAY: float = 0.25
const ROUGH_SHELTER_FUEL_FACTOR: float = 1.5
const COLD_SKIP_TICK_INTERVAL: int = 4
const HARDSHIP_COLD_DAYS: int = 10
const COLD_HARDSHIP_POINTS: int = 1
# While hearths burn, workshops and builders leave this many days of the hearths' wood in store.
const FUEL_RESERVE_DAYS: float = 5.0

# --- Fatal hardship (HouseholdMortality, sprint S3b) ---
# A month is severe when a family went hungry, or its hearth cold, on HARDSHIP_SEVERE_DAYS or more
# of its days. After HARDSHIP_SUSTAINED_MONTHS severe months running, each further month risks a
# death: HARDSHIP_DEATH_CHANCE_PER_MONTH for each month from then, for a family of
# STARTING_HOUSEHOLD_POPULATION_FOR_RISK (more for a larger one), up to HARDSHIP_DEATH_CHANCE_MAX;
# cold without a proper home is ROUGH_SHELTER_COLD_RISK as deadly. So a family of four starving
# two months running risks 6% that month, 12% the next, and so on.
const HARDSHIP_SEVERE_DAYS: int = 20
const HARDSHIP_SUSTAINED_MONTHS: int = 2
const HARDSHIP_DEATH_CHANCE_PER_MONTH: float = 0.06
const HARDSHIP_DEATH_CHANCE_MAX: float = 0.35
const STARTING_HOUSEHOLD_POPULATION_FOR_RISK: int = 4
const ROUGH_SHELTER_COLD_RISK: float = 1.5
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
	"stone_pit": {},
	"clay_pit": {},
	"tool_mender": {},
	"fish_weir": {},
	"snare_line": {},
	"grazing_pen": {},
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
	"stone_pit": 3.0,
	"clay_pit": 3.0,
	"tool_mender": 3.0,
	"fish_weir": 2.0,
	"snare_line": 2.0,
	"grazing_pen": 3.0,
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
# Household social model: a family working long days gives that share out of its rest instead,
# and a month with OVERWORK_WEEKS such weeks is a month's hardship of OVERWORK_HARDSHIP_POINTS.
const OVERWORK_WEEKS: int = 3
const OVERWORK_HARDSHIP_POINTS: int = 1

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
# A quarry stands on stone (TownDeposits, sprint S1b): it cuts its full rate with
# QUARRY_FULL_DEPOSIT_TILES of the best stone underfoot, less on fewer tiles or poorer stone. A
# deposit tile's grade runs from DEPOSIT_GRADE_FLOOR (a lone tile at an outcrop's edge) to 1 (stone
# all round it). Each tile holds STONE_DEPOSIT_UNITS_PER_TILE blocks: a quarry on four good tiles
# works for about three years at its full rate.
const QUARRY_FULL_DEPOSIT_TILES: int = 4
const DEPOSIT_GRADE_FLOOR: float = 0.4
const STONE_DEPOSIT_UNITS_PER_TILE: int = 600
# Clay (sprint S5) lies on open ground beside rivers and lakes, CLAY_DEPOSIT_UNITS_PER_TILE bricks'
# worth a tile; a brickworks stands on it as a quarry stands on stone. Some stone outcrops are
# limestone (LIMESTONE_SHARE of them, by place); a lime kiln must stand within
# LIME_KILN_LIMESTONE_REACH tiles of limestone.
const CLAY_DEPOSIT_UNITS_PER_TILE: int = 400
const LIMESTONE_SHARE: float = 0.45
const LIME_KILN_LIMESTONE_REACH: int = 4

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

# --- The founding compact (sprint S7; TownCompact) ---
# The share of a holding's work each preset gives the community, in every category. A workshop's
# output is divided by worth in grain: its inputs' worth goes back to whoever owned them, and only
# the worth the work added is shared at the rate, so nothing is claimed twice along a chain.
# WORKED_VALUE_IN_GRAIN prices the goods the trader never deals in, for that division only (adding
# them to VALUE_IN_GRAIN would change the stores' temptation to bandits).
const COMPACT_PRESETS: Dictionary = {"communal": 1.0, "shared": 0.6, "private": 0.2}
const COMPACT_RATE_STEP: float = 0.1
const WORKED_VALUE_IN_GRAIN: Dictionary = {
	"lime": 6.0,
	"mortar": 10.0,
	"masonry": 18.0,
	"statues": 25.0,
	"tiles": 7.0,
	"paving_stones": 4.0,
}
# Giving more than the compact asks (monthly): a family whose values and trust lean toward the
# community gives GIVE_SHARE_PER_POINT of what it holds beyond its own needs per point of lean, at
# most GIVE_SHARE_MAX. Its needs: GIVE_KEEPS_FOOD_DAYS of food, GIVE_KEEPS_FUEL_DAYS of winter fuel,
# and whatever its own building projects still wait for. Trust counts TRUST_GIVING_WEIGHT a step.
const GIVE_SHARE_PER_POINT: float = 0.05
const GIVE_SHARE_MAX: float = 0.3
const GIVE_KEEPS_FOOD_DAYS: int = 90
const GIVE_KEEPS_FUEL_DAYS: int = 90
const TRUST_GIVING_WEIGHT: float = 0.5

# --- The commons' rules (sprint S8; TownCommons) ---
# The days of the town's food the common table may keep back from families not in danger, as the
# player chooses them. Monthly grants pass GRANT_SHARE of the community's food and wood beyond the
# reserve and GRANT_KEEPS_DAYS of the town's need into families' own goods. A family asked for help
# on a hungry day gives only from what it holds beyond HELP_KEEPS_FOOD_DAYS of its own eating.
const COMMONS_RESERVE_STEPS: Array[int] = [0, 30, 60, 90]
const GRANT_SHARE: float = 0.25
const GRANT_KEEPS_DAYS: int = 60
const HELP_KEEPS_FOOD_DAYS: int = 30
# A family short on this many days in a month is in danger (the reserve feeds it) before the month's
# hardship falls at HouseholdMigration.HARDSHIP_SHORTAGE_DAYS: survival first. Found by the S8 smoke
# run: reading danger only from hardship and severe months, families left without ever counting
# as in danger while the reserve held food.
const DANGER_SHORT_DAYS: int = 5

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
# With no woods marked, a woodcutter cuts the trees nearest it, slowly (owner, 2026-10-27: a tile
# about every 20 working days, some 16 a year). Since sprint S2 that pace follows from its wood: a
# woodcutter's wood comes out of the trees it fells, and a mature wooded tile holds TIMBER_PER_TILE
# wood, so a full woodcutter (WOODCUTTER_WOOD_PER_DAY) fells about 16 tiles a year, and with nothing
# left to fell it brings in nothing. Woods that
# spread grow in young, with YOUNG_WOODS_TIMBER, and gain TIMBER_GROWTH_PER_YEAR each spring until
# mature (about ten years). A woodcutter cuts its full rate from trees within
# WOODCUTTER_FULL_DISTANCE tiles of its middle (the reach it was placed by), and less the farther it
# must go, down to LAND_YIELD_FLOOR.
const TIMBER_PER_TILE: int = 135
const YOUNG_WOODS_TIMBER: int = 15
const TIMBER_GROWTH_PER_YEAR: int = 12
const WOODCUTTER_FULL_DISTANCE: float = 6.0
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

# --- Building materials (sprint S4) ---
# Homes and proper buildings may be built of timber (the costs above), of rough stone, or of dressed
# stone (masonry). Stone keeps a third of the wood (for roof and floors) and replaces the rest:
# STONE_PER_WOOD stone blocks, or MASONRY_PER_WOOD masonry, for each wood. Rough stone is slow to
# raise (STONE_WORK_FACTOR of the work); dressed stone, cut and mortared beforehand, less so. A
# stone building lasts longer between repairs (STONE_UPKEEP_FACTOR times the upkeep interval) and a
# stone home holds its warmth (STONE_HOME_FUEL_FACTOR of a timber home's firewood). Fields, hand work
# and anything costing under STONE_MIN_WOOD wood are timber or nothing.
const MATERIAL_TIMBER: String = "timber"
const MATERIAL_STONE: String = "stone"
const MATERIAL_DRESSED: String = "dressed_stone"
# Brick (sprint S5): fired clay, BRICKS_PER_WOOD for each wood replaced, raised at BRICK_WORK_FACTOR
# of timber's work; it lasts and keeps warm like stone.
const MATERIAL_BRICK: String = "brick"
const MATERIALS: Array[String] = [MATERIAL_TIMBER, MATERIAL_STONE, MATERIAL_DRESSED, MATERIAL_BRICK]
const STONE_PER_WOOD: float = 1.5
const MASONRY_PER_WOOD: float = 0.5
const BRICKS_PER_WOOD: float = 1.0
const BRICK_WORK_FACTOR: float = 1.3
const STONE_MIN_WOOD: int = 4
const STONE_WORK_FACTOR: float = 1.6
const DRESSED_WORK_FACTOR: float = 1.25
const STONE_UPKEEP_FACTOR: float = 1.5
const STONE_HOME_FUEL_FACTOR: float = 0.75

static func can_be_stone(building_type: String) -> bool:
	if building_type == "farm" or BuildingTiers.is_tier0(building_type):
		return false
	return int((BUILD_COSTS.get(building_type, {}) as Dictionary).get("wood", 0)) >= STONE_MIN_WOOD

# Built of stone or brick: lasting and warm.
static func is_stone_material(material: String) -> bool:
	return material == MATERIAL_STONE or material == MATERIAL_DRESSED or material == MATERIAL_BRICK

static func get_build_cost(building_type: String, material: String = MATERIAL_TIMBER) -> Dictionary:
	var cost: Dictionary = (BUILD_COSTS.get(building_type, {}) as Dictionary).duplicate()
	if not is_stone_material(material) or not can_be_stone(building_type):
		return cost
	var wood: int = int(cost.get("wood", 0))
	var kept: int = int(ceil(float(wood) / 3.0))
	cost["wood"] = kept
	match material:
		MATERIAL_STONE:
			cost["stone_blocks"] = int(ceil(float(wood - kept) * STONE_PER_WOOD))
		MATERIAL_BRICK:
			cost["bricks"] = int(ceil(float(wood - kept) * BRICKS_PER_WOOD))
		_:
			cost["masonry"] = int(ceil(float(wood - kept) * MASONRY_PER_WOOD))
	return cost

static func get_build_work_days(building_type: String, material: String = MATERIAL_TIMBER) -> float:
	var days: float = float(BUILD_WORK_DAYS.get(building_type, BUILD_WORK_DEFAULT_DAYS))
	if can_be_stone(building_type):
		match material:
			MATERIAL_STONE:
				days *= STONE_WORK_FACTOR
			MATERIAL_DRESSED:
				days *= DRESSED_WORK_FACTOR
			MATERIAL_BRICK:
				days *= BRICK_WORK_FACTOR
	return days

static func get_maintenance_interval(building_type: String) -> int:
	return int(MAINTENANCE_INTERVAL_DAYS.get(building_type, MAINTENANCE_INTERVAL_DEFAULT_DAYS))
