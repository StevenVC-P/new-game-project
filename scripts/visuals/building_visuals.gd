class_name BuildingVisuals
extends RefCounted

# What each building type looks like, as semantic profiles kept apart from simulation data:
# which drawing it uses and its materials. TownBuildingPainter draws the profiles today; a
# later sprite or texture renderer can take the same keys.
#
# Tier 0 hand work (hut, forager's garden, gatherer's camp, tool mender) has drawings of its
# own, rougher than its tier 1 counterpart, and its materials are washed toward bare earth.

const ROOF_THATCH: Color = RegionMapStyle.COLOR_ROOF_THATCH
const ROOF_TIMBER: Color = RegionMapStyle.COLOR_ROOF_TIMBER
const ROOF_TILE: Color = RegionMapStyle.COLOR_ROOF_TILE
const ROOF_SLATE: Color = RegionMapStyle.COLOR_ROOF_SLATE
const WALL_TIMBER: Color = RegionMapStyle.COLOR_WALL_TIMBER
const WALL_STONE: Color = RegionMapStyle.COLOR_TOWN_WALL

const TIER0_EARTH_COLOR: Color = Color(0.55, 0.5, 0.4)
const TIER0_WASH: float = 0.3

# Base type -> drawing and materials. Drawings are named after what stands on the plot.
const PROFILES: Dictionary = {
	"house": {"drawing": "house", "roof": ROOF_THATCH, "wall": WALL_TIMBER},
	"farm": {"drawing": "field", "roof": ROOF_THATCH, "wall": WALL_TIMBER},
	"woodcutter": {"drawing": "woodshed", "roof": ROOF_TIMBER, "wall": WALL_TIMBER},
	"toolmaker": {"drawing": "forge", "roof": ROOF_TIMBER, "wall": WALL_STONE},
	"quarry": {"drawing": "quarry", "roof": ROOF_TIMBER, "wall": WALL_STONE},
	"stonecutter": {"drawing": "stone_shed", "roof": ROOF_SLATE, "wall": WALL_STONE},
	"brickworks": {"drawing": "brick_clamp", "roof": ROOF_TILE, "wall": WALL_TIMBER},
	"lime_kiln": {"drawing": "lime_kiln", "roof": ROOF_TIMBER, "wall": WALL_STONE},
	"mortar_yard": {"drawing": "mortar_yard", "roof": ROOF_TIMBER, "wall": WALL_TIMBER},
	"mason_yard": {"drawing": "mason_yard", "roof": ROOF_SLATE, "wall": WALL_STONE},
	"sculptor": {"drawing": "sculptor", "roof": ROOF_SLATE, "wall": WALL_STONE},
	"carver": {"drawing": "carver", "roof": ROOF_TIMBER, "wall": WALL_TIMBER},
	"tileworks": {"drawing": "tileworks", "roof": ROOF_TILE, "wall": WALL_TIMBER},
	"paver_yard": {"drawing": "paver_yard", "roof": ROOF_SLATE, "wall": WALL_STONE},
	"storehouse": {"drawing": "storehouse", "roof": ROOF_TIMBER, "wall": WALL_TIMBER},
	"fisher": {"drawing": "fisher", "roof": ROOF_THATCH, "wall": WALL_TIMBER},
	"hunter": {"drawing": "lodge", "roof": ROOF_TIMBER, "wall": WALL_TIMBER},
}

const TIER0_DRAWINGS: Dictionary = {
	"hut": "hut",
	"forager_garden": "garden",
	"gatherer_camp": "camp",
	"tool_mender": "mender",
}

static func get_profile(building_type: String) -> Dictionary:
	var base_type: String = BuildingTiers.get_base_type(building_type)
	var profile: Dictionary = (PROFILES.get(base_type, PROFILES["house"]) as Dictionary).duplicate()
	profile["type"] = building_type
	profile["rough"] = BuildingTiers.is_tier0(building_type)
	if profile["rough"]:
		profile["drawing"] = TIER0_DRAWINGS.get(building_type, profile["drawing"])
		profile["roof"] = (profile["roof"] as Color).lerp(TIER0_EARTH_COLOR, TIER0_WASH)
		profile["wall"] = (profile["wall"] as Color).lerp(TIER0_EARTH_COLOR, TIER0_WASH)
	return profile
