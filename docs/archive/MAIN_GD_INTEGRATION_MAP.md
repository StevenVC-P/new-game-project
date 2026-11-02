# main.gd Integration Map

This map is for local-agent tasks that need tiny, anchored integrations in `scripts/main.gd`. It records real symbols and safe patterns so agents do not invent variables or draw signatures.

`scripts/main.gd` is a high-risk integration surface. Prefer standalone helper scripts plus a small `insert_after` or `insert_before` edit at an exact anchor.

## View State

Real constants:

- `VIEW_REGION: String = "region"`
- `VIEW_CITY: String = "city"`

Real state variables:

- `current_view: String = VIEW_REGION`
- `selected_city_index: int = -1`
- `hovered_tile: Vector2i`
- `hovered_city_index: int`
- `city_hovered_tile: Vector2i`

Correct city-view check:

```gdscript
if current_view == VIEW_CITY:
```

Correct not-city-view guard:

```gdscript
if current_view != VIEW_CITY:
```

Do not use:

- `current_view == "city"`
- `current_city`
- `selected_object`

## City Access

Use `selected_city_index` and `cities`:

```gdscript
if selected_city_index >= 0 and selected_city_index < cities.size():
	var city: City = cities[selected_city_index]
```

Existing helpers:

- `get_city_pressure_debug_city() -> City`
- `get_household_debug_city()`

Inside `draw_city_sidebar(...)`, the selected city is already resolved:

```gdscript
var city: City = cities[selected_city_index]
var resources: Dictionary = city.resources
var pressure_summary: Dictionary = city.get_pressure_summary()
```

## Selected Building State

There is no `selected_building` object and no `selected_object`.

The selected/inspected building index is:

```gdscript
city_building_overlay.inspected_building_index
```

`draw_selected_object_summary(...)` resolves the selected building:

```gdscript
func draw_selected_object_summary(font: Font, font_size: int, city: City, x: float, y: float) -> float:
	var building_index: int = city_building_overlay.inspected_building_index
	if building_index < 0 or building_index >= city.buildings.size():
		return draw_sidebar_line(font, font_size, "None selected.", x, y, VisualStyle.COLOR_MUTED)

	var building: Building = city.buildings[building_index]
```

Inside this function, these names are in scope:

- `font`
- `font_size`
- `city`
- `x`
- `y`
- `building_index`
- `building`

Outside this function, do not assume `building_index` or `building` are available.

## Building Types And Links

Houses:

```gdscript
if building.is_house():
	var household: Household = city.get_household_for_building_id(building_index)
```

Production buildings:

```gdscript
if building.is_production_building():
	var household: Household = city.get_household_by_id(building.assigned_household_id)
```

Useful building fields:

- `building.type`
- `building.assigned_workers`
- `building.assigned_household_id`
- `building.assigned_preference`
- `building.receives_maintenance`
- `building.maintenance_level`

Useful city methods:

- `city.get_household_for_building_id(building_index)`
- `city.get_household_by_id(household_id)`
- `city.get_household_label(household_id)`
- `city.get_assigned_building_ids_for_house(house_index)`
- `city.get_assigned_house_building_id(building)`

## Drawing API

Prefer existing sidebar helpers over raw `draw_string(...)`.

Correct helper calls:

```gdscript
y = draw_sidebar_section_title(font, "Section Title", x, y)
y = draw_sidebar_line(font, font_size, "Text", x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
y = draw_sidebar_label_value(font, font_size, "Label", "Value", x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
```

Correct raw `draw_string(...)` shape:

```gdscript
draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)
```

Do not call:

```gdscript
draw_string(font, Vector2(x, y), text, Color.WHITE, font_size)
```

That is wrong because argument 4 is `HorizontalAlignment`, not `Color`.

## Existing Helper Patterns

City pressure action hints:

```gdscript
var action_hint_lines: Array[String] = CityPressureHintHelper.get_hints(pressure_summary, resources)
for action_hint: String in action_hint_lines:
	y = draw_sidebar_line(font, font_size, action_hint, text_x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
```

Selected building hints:

```gdscript
var selected_building_hint_lines := SelectedBuildingActionHintHelper.get_hints(building, city)
if selected_building_hint_lines.size() > 0:
	y = draw_sidebar_section_title(font, "Selected Building Hints", x, y)
	for hint_text in selected_building_hint_lines:
		y = draw_sidebar_line(font, font_size, hint_text, x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
```

Preferred pattern:

- helper returns `Array[String]`
- `main.gd` draws each line using sidebar helpers
- helper is read-only
- no raw dictionary dumps
- no simulation mutation

## Forbidden Guessed Names

Do not use:

- `selected_object`
- `selected_building`
- `current_city`
- `current_view == "city"`
- `summary_y`
- `household_id` unless it is a real local variable or field
- `building_id` unless it is a real local variable or field

## Local Variable Naming

Use specific local names to avoid scope collisions:

- `action_hint_lines`
- `selected_building_hint_lines`
- `household_link_lines`
- `city_status_lines`
- `production_breakdown_lines`

Avoid generic names in `main.gd` draw scopes:

- `hints`
- `lines`
- `items`
- `selected_object`

## Manual Test Expectations

For any `main.gd` sidebar integration:

1. Enter city view.
2. Confirm the sidebar still draws.
3. Select no building, a house, and a production building.
4. Confirm no runtime errors appear.
5. Confirm F3 and F4 debug panels still work.
6. Confirm no resources, assignments, maintenance, housing, or production formulas changed because of read-only UI.
