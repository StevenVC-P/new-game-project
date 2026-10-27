class_name SaveCodec
extends RefCounted

# Copies an object's state to and from plain data for saved games. It takes every script
# variable, so a field added to a domain class is saved without anyone remembering to add it;
# what must not be saved (caches, links to other objects) is named where the object is saved
# (GameState). Object-valued variables are always left out: the owner saves its children itself.

static func capture(object: Object, skip: Array[String] = []) -> Dictionary:
	var data: Dictionary = {}
	for property: Dictionary in object.get_property_list():
		if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var property_name: String = property["name"]
		if property_name.begins_with("_") or skip.has(property_name):
			continue
		var value: Variant = object.get(property_name)
		if value is Object or contains_objects(value):
			continue
		# Deep copy: the save must not change when the game plays on after it is captured.
		data[property_name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return data

# Restores what capture() took. Variables the object no longer has (a save from an older
# build) are ignored; ones the save lacks keep the object's defaults.
static func restore(object: Object, data: Dictionary) -> void:
	for property_name: String in data:
		if property_name in object:
			var value: Variant = data[property_name]
			object.set(property_name, value.duplicate(true) if value is Array or value is Dictionary else value)

static func contains_objects(value: Variant) -> bool:
	if value is Array:
		if (value as Array).get_typed_builtin() == TYPE_OBJECT:
			return true
		for item: Variant in value:
			if item is Object:
				return true
	return false
