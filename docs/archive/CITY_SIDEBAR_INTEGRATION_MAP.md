# City Sidebar Integration Map

This map documents safe insertion points and in-scope variables for City Overview sidebar tasks. It is intended for local-agent prompts and Codex review.

## Sidebar Entry Point

Main function:

```gdscript
func draw_city_sidebar(font: Font, font_size: int):
```

The sidebar clears click options, computes its rectangle, draws the `City Overview` title, validates `selected_city_index`, and then draws sections in order.

After this guard:

```gdscript
if selected_city_index < 0 or selected_city_index >= cities.size():
	return
```

these variables are in scope:

- `font`
- `font_size`
- `sidebar_x`
- `sidebar_pos`
- `sidebar_size`
- `sidebar_rect`
- `text_x`
- `y`
- `city`
- `resources`
- `placement_status`
- `pressure_summary`
- `placement_color`

## Current Sidebar Order

Current high-level order:

1. `City Overview` title
2. `City Health`
3. `Action Hints`
4. `Resources`
5. `Population`
6. `Selected Object`
7. `Build Controls`
8. placement status line

Existing anchors:

```gdscript
y = draw_sidebar_section_title(font, "City Health", text_x, y)
y = draw_sidebar_section_title(font, "Action Hints", text_x, y)
y = draw_sidebar_section_title(font, "Resources", text_x, y)
y = draw_sidebar_section_title(font, "Population", text_x, y)
y = draw_sidebar_section_title(font, "Selected Object", text_x, y)
y = draw_selected_object_summary(font, font_size, city, text_x, y)
y = draw_sidebar_section_title(font, "Build Controls", text_x, y)
```

Use exact anchors. Do not invent section names.

## Safe Insertion Patterns

### Add A City-Level Section

Good location: after City Health or Action Hints.

Example:

```gdscript
y = draw_sidebar_section_title(font, "New Section", text_x, y)
var new_section_lines: Array[String] = NewHelper.get_lines(city, resources, pressure_summary)
for new_section_text: String in new_section_lines:
	y = draw_sidebar_line(font, font_size, new_section_text, text_x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
y += 4.0
```

Use when the section is about the whole city.

### Add A Selected-Building Section

Prefer editing inside:

```gdscript
func draw_selected_object_summary(font: Font, font_size: int, city: City, x: float, y: float) -> float:
```

Use this when the section needs `building_index` or `building`.

Safe in-scope variables inside that function:

- `font`
- `font_size`
- `city`
- `x`
- `y`
- `building_index`
- `building`

Example:

```gdscript
var household_link_lines: Array[String] = HouseholdHomeWorkLinkHelper.get_links(city, building_index)
if household_link_lines.size() > 0:
	y = draw_sidebar_section_title(font, "Household Links", x, y)
	for household_link_text: String in household_link_lines:
		y = draw_sidebar_line(font, font_size, household_link_text, x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
```

Do not add selected-building logic in `draw_city_sidebar(...)` after the call to `draw_selected_object_summary(...)`; the local `building` variable is not available there.

## Correct Drawing Helpers

Use:

```gdscript
y = draw_sidebar_section_title(font, "Section", x, y)
y = draw_sidebar_line(font, font_size, "Text", x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
y = draw_sidebar_label_value(font, font_size, "Label", "Value", x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
```

Do not pass `city` to these helpers.

Do not use wrong raw `draw_string(...)` argument order. The correct order is:

```gdscript
draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)
```

## Existing Sidebar Helpers

`CityPressureHintHelper`:

- file: `scripts/ui/city_pressure_hint_helper.gd`
- called from `draw_city_sidebar(...)`
- city-level, pressure/resource based
- read-only

`SelectedBuildingActionHintHelper`:

- file: `scripts/ui/selected_building_action_hint_helper.gd`
- called from `draw_selected_object_summary(...)`
- selected-building based
- read-only

Future helpers should follow this pattern:

- standalone script in `scripts/ui/`
- `class_name`
- preferably `extends RefCounted`
- static read-only function returning `Array[String]`
- tiny anchored draw integration in `main.gd`

## Selected Object Reality

There is no generic selected object model.

Actual selected building source:

```gdscript
city_building_overlay.inspected_building_index
```

Actual selected building resolution:

```gdscript
var building_index: int = city_building_overlay.inspected_building_index
var building: Building = city.buildings[building_index]
```

Actual house resident lookup:

```gdscript
var household: Household = city.get_household_for_building_id(building_index)
```

Actual production assigned household lookup:

```gdscript
var household: Household = city.get_household_by_id(building.assigned_household_id)
```

Actual assigned production buildings for a house:

```gdscript
var assigned_building_ids: Array[int] = city.get_assigned_building_ids_for_house(house_index)
```

## Forbidden Guesses

Do not use:

- `selected_object`
- `selected_object.has(...)`
- `selected_object.household_id`
- `selected_object.building_id`
- `summary_y`
- `current_city`
- `current_view == "city"`
- raw `draw_string(...)` with `Color` as argument 4

## Safe Task Requirements

For local-agent sidebar tasks:

- Require `scripts/main.gd` path only when integration is truly needed.
- Prefer `insert_after` / `insert_before`; never allow `replace_entire_file`.
- Preserve:
  - `func _ready():`
  - `func _input(event: InputEvent):`
  - `func _draw():`
  - `draw_city_sidebar`
  - `draw_selected_object_summary`
  - existing helper names
- Block:
  - `replace_entire_file`
  - `.tscn`
  - mutation methods such as `assign_`, `unassign_`, `toggle_maintenance`, `add_resource`, `remove_resource`, `pay_cost`

## Manual Test Expectations

For sidebar changes:

1. Run the game.
2. Enter city view.
3. Confirm City Overview appears.
4. Select no building, a house, and a production building.
5. Confirm the new section appears only where it makes sense.
6. Confirm lines are short and readable.
7. Confirm F3/F4 still work.
8. Confirm build controls and selected object controls still work.
9. Confirm no runtime errors appear.
10. Confirm no simulation state changes from read-only display.
