class_name BuildingTiers
extends RefCounted

# Building tiers (owner decision 2026-10-20).
# Tier 0 is hand work a family can always do: almost free to build, no tool upkeep, about a third
# of tier 1 output. It is a floor so a town that runs out of wood or tools can always restart.
# Tier 1 is the proper holding. A tier 0 building upgrades in place into its tier 1 counterpart
# and shares its footprint and terrain rules, so the upgrade always fits.

const TIER0_TO_TIER1: Dictionary = {
	"hut": "house",
	"forager_garden": "farm",
	"gatherer_camp": "woodcutter",
	"tool_mender": "toolmaker"
}

const DISPLAY_NAMES: Dictionary = {
	"hut": "Hut",
	"forager_garden": "Forager's Garden",
	"gatherer_camp": "Gatherer's Camp",
	"tool_mender": "Tool Mender",
	"fisher": "Fisher's Hut",
	"hunter": "Hunter's Lodge",
	"watch_post": "Watch Post"
}

static func is_tier0(building_type: String) -> bool:
	return TIER0_TO_TIER1.has(building_type)

# The tier 1 building a type behaves like (itself for anything that is not tier 0).
static func get_base_type(building_type: String) -> String:
	return str(TIER0_TO_TIER1.get(building_type, building_type))

static func get_upgrade_type(building_type: String) -> String:
	return str(TIER0_TO_TIER1.get(building_type, ""))

static func get_display_name(building_type: String) -> String:
	return str(DISPLAY_NAMES.get(building_type, building_type.capitalize()))
