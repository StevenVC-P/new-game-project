class_name GoodsNeedBucketHelper

const BUCKET_FOOD: String = "food"
const BUCKET_TOOLS: String = "tools"
const BUCKET_CONSTRUCTION_MATERIALS: String = "construction_materials"
const BUCKET_MAINTENANCE_MATERIALS: String = "maintenance_materials"
const BUCKET_HOUSEHOLD_GOODS: String = "household_goods"
const BUCKET_CIVIC_GOODS: String = "civic_goods"

const CURRENT_GOOD_IDS: Array[String] = [
	"food",
	"wood",
	"tools",
	"stone_blocks",
	"cut_stone",
	"bricks",
	"masonry",
	"lime",
	"mortar",
	"statues",
	"carved_goods",
	"tiles",
	"paving_stones",
]

const GOOD_TO_NEED_BUCKETS: Dictionary = {
	"food": [BUCKET_FOOD],
	"wood": [BUCKET_CONSTRUCTION_MATERIALS, BUCKET_MAINTENANCE_MATERIALS],
	"tools": [BUCKET_TOOLS, BUCKET_MAINTENANCE_MATERIALS],
	"stone_blocks": [BUCKET_CONSTRUCTION_MATERIALS, BUCKET_MAINTENANCE_MATERIALS],
	"cut_stone": [BUCKET_CONSTRUCTION_MATERIALS],
	"bricks": [BUCKET_CONSTRUCTION_MATERIALS, BUCKET_MAINTENANCE_MATERIALS],
	"masonry": [BUCKET_CONSTRUCTION_MATERIALS, BUCKET_MAINTENANCE_MATERIALS],
	"lime": [BUCKET_CONSTRUCTION_MATERIALS, BUCKET_MAINTENANCE_MATERIALS],
	"mortar": [BUCKET_CONSTRUCTION_MATERIALS, BUCKET_MAINTENANCE_MATERIALS],
	"tiles": [BUCKET_CONSTRUCTION_MATERIALS, BUCKET_MAINTENANCE_MATERIALS, BUCKET_HOUSEHOLD_GOODS],
	"paving_stones": [BUCKET_CONSTRUCTION_MATERIALS, BUCKET_CIVIC_GOODS],
	"carved_goods": [BUCKET_HOUSEHOLD_GOODS, BUCKET_CIVIC_GOODS],
	"statues": [BUCKET_HOUSEHOLD_GOODS, BUCKET_CIVIC_GOODS],
}

const BUCKET_DISPLAY_NAMES: Dictionary = {
	BUCKET_FOOD: "Food",
	BUCKET_TOOLS: "Tools",
	BUCKET_CONSTRUCTION_MATERIALS: "Construction Materials",
	BUCKET_MAINTENANCE_MATERIALS: "Maintenance Materials",
	BUCKET_HOUSEHOLD_GOODS: "Household Goods",
	BUCKET_CIVIC_GOODS: "Civic Goods",
}

const GOOD_DISPLAY_NAMES: Dictionary = {
	"food": "Food",
	"wood": "Wood",
	"tools": "Tools",
	"stone_blocks": "Stone Blocks",
	"cut_stone": "Cut Stone",
	"bricks": "Bricks",
	"masonry": "Masonry",
	"lime": "Lime",
	"mortar": "Mortar",
	"statues": "Statues",
	"carved_goods": "Carved Goods",
	"tiles": "Tiles",
	"paving_stones": "Paving Stones",
}

# Future goods planned in the demand model include wheat, bread, fish, planks,
# clay, pottery, wool, clothing, and wooden_tools. They are intentionally not
# mapped until they exist in the current city resource dictionary.

static func get_need_buckets_for_good(good_id: String) -> Array[String]:
	if not GOOD_TO_NEED_BUCKETS.has(good_id):
		return []

	return _copy_string_array(GOOD_TO_NEED_BUCKETS[good_id])


static func get_goods_for_need_bucket(bucket_id: String) -> Array[String]:
	var goods: Array[String] = []
	for good_id in GOOD_TO_NEED_BUCKETS.keys():
		if is_good_in_need_bucket(str(good_id), bucket_id):
			goods.append(str(good_id))

	return goods


static func is_good_in_need_bucket(good_id: String, bucket_id: String) -> bool:
	if not GOOD_TO_NEED_BUCKETS.has(good_id):
		return false

	var buckets: Array[String] = _copy_string_array(GOOD_TO_NEED_BUCKETS[good_id])
	return buckets.has(bucket_id)


static func get_current_goods_for_need_bucket(bucket_id: String) -> Array[String]:
	var goods: Array[String] = []
	for good_id in CURRENT_GOOD_IDS:
		if is_good_in_need_bucket(good_id, bucket_id):
			goods.append(good_id)

	return goods


static func get_bucket_display_name(bucket_id: String) -> String:
	if BUCKET_DISPLAY_NAMES.has(bucket_id):
		return str(BUCKET_DISPLAY_NAMES[bucket_id])

	return _format_id_as_label(bucket_id)


static func get_good_display_name(good_id: String) -> String:
	if GOOD_DISPLAY_NAMES.has(good_id):
		return str(GOOD_DISPLAY_NAMES[good_id])

	return _format_id_as_label(good_id)


static func _copy_string_array(values) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values:
			result.append(str(value))

	return result


static func _format_id_as_label(value: String) -> String:
	var words: PackedStringArray = value.replace("_", " ").split(" ")
	for index in range(words.size()):
		if words[index].length() > 0:
			words[index] = words[index].substr(0, 1).to_upper() + words[index].substr(1).to_lower()

	return " ".join(words)
