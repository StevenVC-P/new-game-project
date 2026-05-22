class_name TradeRoute
extends RefCounted

var id: int = -1
var source_city_id: int = -1
var destination_city_id: int = -1
var resource_type: String = "food"
var amount_per_tick: int = 1
var active: bool = true

func _init(route_id: int = -1, source_id: int = -1, destination_id: int = -1, resource_name: String = "food", amount: int = 1):
	id = route_id
	source_city_id = source_id
	destination_city_id = destination_id
	resource_type = resource_name
	amount_per_tick = amount

func can_transfer(source_city: City) -> bool:
	if not active:
		return false
	if amount_per_tick <= 0:
		return false

	return source_city.can_transfer(resource_type, amount_per_tick)

func transfer_tick(source_city: City, destination_city: City):
	if not can_transfer(source_city):
		return

	source_city.remove_resource(resource_type, amount_per_tick)
	destination_city.add_resource(resource_type, amount_per_tick)

func get_summary(source_label: String, destination_label: String) -> String:
	return source_label + " -> " + destination_label + " " + resource_type + " " + str(amount_per_tick) + "/tick"
