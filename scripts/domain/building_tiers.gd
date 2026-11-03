class_name BuildingTiers
extends RefCounted

# Building tiers (owner decision 2026-10-20).
# Tier 0 is hand work a family can always do: almost free to build, no tool upkeep, about a third
# of tier 1 output. It is a floor so a town that runs out of wood or tools can always restart.
# Tier 1 is the proper holding. A tier 0 building upgrades in place into its tier 1 counterpart
# and shares its footprint and terrain rules, so the upgrade always fits.
#
# Every workplace here with a hand-work stage is work families can choose for themselves
# (FamilyInitiative.get_occupations): a new trade becomes a family's choice by adding its stage here.

const TIER0_TO_TIER1: Dictionary = {
	"hut": "house",
	"forager_garden": "farm",
	"gatherer_camp": "woodcutter",
	"tool_mender": "toolmaker",
	"fish_weir": "fisher",
	"snare_line": "hunter",
	"grazing_pen": "herder",
	# Sprint S4c (owner D6): families take up stone work themselves, prising stone from a deposit by
	# hand before any quarry is built.
	"stone_pit": "quarry"
}

const DISPLAY_NAMES: Dictionary = {
	"hut": "Hut",
	"forager_garden": "Forager's Garden",
	"gatherer_camp": "Gatherer's Camp",
	"tool_mender": "Tool Mender",
	"fish_weir": "Fish Weir",
	"snare_line": "Snare Line",
	"grazing_pen": "Grazing Pen",
	"stone_pit": "Stone Pit",
	"fisher": "Fisher's Hut",
	"hunter": "Hunter's Lodge",
	"watch_post": "Watch Post",
	"herder": "Herder's Fold"
}

static func is_tier0(building_type: String) -> bool:
	return TIER0_TO_TIER1.has(building_type)

# The tier 1 building a type behaves like (itself for anything that is not tier 0).
static func get_base_type(building_type: String) -> String:
	return str(TIER0_TO_TIER1.get(building_type, building_type))

static func get_upgrade_type(building_type: String) -> String:
	return str(TIER0_TO_TIER1.get(building_type, ""))

# The hand work a tier 1 type starts as ("" when it has none).
static func get_hand_work_type(building_type: String) -> String:
	for tier0: String in TIER0_TO_TIER1.keys():
		if TIER0_TO_TIER1[tier0] == building_type:
			return tier0
	return ""

static func get_display_name(building_type: String) -> String:
	return str(DISPLAY_NAMES.get(building_type, building_type.capitalize()))
