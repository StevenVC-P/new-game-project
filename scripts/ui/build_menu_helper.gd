class_name BuildMenuHelper

static func get_building_catalog() -> Array[Dictionary]:
	return [
		{"id": "hut", "display_name": "Hut", "category": "Hand Work (Tier 0)"},
		{"id": "forager_garden", "display_name": "Forager's Garden", "category": "Hand Work (Tier 0)"},
		{"id": "gatherer_camp", "display_name": "Gatherer's Camp", "category": "Hand Work (Tier 0)"},
		{"id": "tool_mender", "display_name": "Tool Mender", "category": "Hand Work (Tier 0)"},
		{"id": "plot", "display_name": "Residential Plot", "category": "Town Planning"},
		{"id": "road", "display_name": "Road", "category": "Town Planning"},
		{"id": "storehouse", "display_name": "Storehouse", "category": "Town Planning"},
		{"id": "clear_woods", "display_name": "Clear Woods", "category": "Town Planning"},
		{
			"id": "house",
			"display_name": "House",
			"category": "Housing"
		},
		{
			"id": "farm",
			"display_name": "Farm",
			"category": "Food"
		},
		{
			"id": "woodcutter",
			"display_name": "Woodcutter",
			"category": "Wood/Tools"
		},
		{
			"id": "toolmaker",
			"display_name": "Toolmaker",
			"category": "Wood/Tools"
		},
		{
			"id": "quarry",
			"display_name": "Quarry",
			"category": "Stone/Construction"
		},
		{
			"id": "stonecutter",
			"display_name": "Stonecutter",
			"category": "Stone/Construction"
		},
		{
			"id": "brickworks",
			"display_name": "Brickworks",
			"category": "Stone/Construction"
		},
		{
			"id": "lime_kiln",
			"display_name": "Lime Kiln",
			"category": "Stone/Construction"
		},
		{
			"id": "mortar_yard",
			"display_name": "Mortar Yard",
			"category": "Stone/Construction"
		},
		{
			"id": "mason_yard",
			"display_name": "Mason Yard",
			"category": "Stone/Construction"
		},
		{
			"id": "sculptor",
			"display_name": "Sculptor",
			"category": "Craft"
		},
		{
			"id": "carver",
			"display_name": "Carver",
			"category": "Craft"
		},
		{
			"id": "tileworks",
			"display_name": "Tileworks",
			"category": "Craft"
		},
		{
			"id": "paver_yard",
			"display_name": "Paver Yard",
			"category": "Craft"
		}
	]

static func get_display_name(building_id: String) -> String:
	for building in get_building_catalog():
		if building["id"] == building_id:
			return building["display_name"]
	return "Unknown Building"

static func get_category(building_id: String) -> String:
	for building in get_building_catalog():
		if building["id"] == building_id:
			return building["category"]
	return "Unknown Category"
