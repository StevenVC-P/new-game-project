extends Node2D

# Isolated regional map demo (scenes/region_map_demo.tscn): the showcase regions without the
# rest of the game. Keys 1-6 switch region, G toggles a grown player town, F and L toggle
# founding sites and labels; drag or WASD pans and the wheel zooms.

var world: WorldMapData = null
var view: RegionMapView = null
var showcase_index: int = 0
var grown: bool = false

func _ready() -> void:
	world = FixedWorldDefinition.build()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	view = RegionMapView.new()
	layer.add_child(view)
	view.map_clicked.connect(func(position: Vector2) -> void: print("Clicked tile ", view.screen_to_tile(position)))
	get_viewport().size_changed.connect(fit_view)
	fit_view()
	show_showcase(0)

func fit_view() -> void:
	view.set_screen_rect(Rect2(Vector2.ZERO, get_viewport_rect().size))

func show_showcase(index: int) -> void:
	showcase_index = index
	var showcase: Dictionary = RegionShowcase.SHOWCASES[index]
	var region: Dictionary = RegionShowcase.build(world, showcase["region"], grown)
	view.set_region(region["tiles"], region["cities"], region["roads"], region["geography"])
	var sites: Array[Vector2i] = []
	var cities: Array[City] = region["cities"]
	var has_player: bool = cities.any(func(city: City) -> bool: return city.is_player_city())
	if not has_player:
		for y in range(RegionShowcase.MAP_SIZE.y):
			for x in range(RegionShowcase.MAP_SIZE.x):
				if FoundingSiteHelper.is_valid_founding_tile(region["tiles"], cities, Vector2i(x, y), RegionShowcase.MIN_CITY_DISTANCE):
					sites.append(Vector2i(x, y))
	view.set_founding_state(not has_player, sites, Vector2i(-1, -1), RegionShowcase.MIN_CITY_DISTANCE, RegionShowcase.CITY_RESOURCE_RANGE)
	print("Showcase: ", showcase["label"], " (", showcase["region"], ") ", (region["geography"] as RegionGeography).get_debug_summary())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if view.handle_mouse_event(event):
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion:
			var tile: Vector2i = view.screen_to_tile((event as InputEventMouseMotion).position)
			view.set_hover(tile, view.founding_sites.has(tile), -1)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event as InputEventKey
		if view.handle_key(key):
			return
		if key.keycode >= KEY_1 and key.keycode < KEY_1 + RegionShowcase.SHOWCASES.size():
			show_showcase(key.keycode - KEY_1)
		elif key.keycode == KEY_G:
			grown = not grown
			show_showcase(showcase_index)
