extends Node2D

# Isolated world map for visual evaluation: open scenes/world_map_demo.tscn and run it
# with F6. Entering a region only prints here; the real hand-off lives in main.gd.

var view: WorldMapView = null

func _ready() -> void:
	view = WorldMapView.new()
	add_child(view)
	view.setup(FixedWorldDefinition.build())
	view.region_entry_requested.connect(on_region_entry_requested)

func on_region_entry_requested(region_id: int) -> void:
	print("Enter region: ", view.data.get_region(region_id).name)
