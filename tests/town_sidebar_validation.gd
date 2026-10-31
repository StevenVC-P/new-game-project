extends SceneTree

# The town sidebar in the real game (TownSidebar, docs/TOWN_UI.md): it docks beside the map at a
# fifth of the window; every page builds from a new and a grown town without changing the town;
# Needs attention shows only what the town's state holds; tabs, the wheel, and buttons answer real
# clicks; a family card and the map's selection follow each other; the tool footer and the ground
# readout appear when they should; and every shortcut the Planning page lists selects that tool.

const MainScript = preload("res://scripts/main.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")
const KNOWN_KINDS: Array[String] = ["heading", "status", "card", "row", "text", "buttons", "expander", "gap"]

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	root.size = Vector2i(1920, 1080)
	var main: Node2D = MainScript.new()
	main.use_authored_world = true
	root.add_child(main)
	await _settle()
	var region: WorldMapData.Region = main.world_map_data.find_region_by_name("Meander Plains")
	main.world_map_view.request_region_entry(region.id)
	main.wait_for_neighbourhood_job()
	await _settle()
	var middle: Vector2 = Vector2(main.region_map_size) * 0.5
	var site: Vector2i = main.region_founding_sites[0]
	for tile: Vector2i in main.region_founding_sites:
		if Vector2(tile).distance_to(middle) < Vector2(site).distance_to(middle):
			site = tile
	main.set_pending_founding_tile(site)
	_check(main.found_player_city_at_pending_site(), "founding should open the town")
	main.simulation_clock.is_paused = true
	await _settle()
	var city: City = main.cities[main.selected_city_index]
	_check(city.influence.enabled and city.construction.starting_land_given and HomeSites.count_room(city) >= EconomyBalance.FOUNDING_FAMILIES, "a town founded with families leading has its starting residential land (%d spots)" % HomeSites.count_room(city))

	test_layout(main)
	test_pages_build(main, city, "a new town")
	test_shortcuts(main)
	StandInPlayerScript.new().play(city, {}, 360)
	await _settle()
	test_pages_build(main, city, "a grown town")
	test_pages_change_nothing(main, city)
	test_attention_follows_state(city)
	await test_tabs_and_keys(main)
	await test_clicks(main, city)
	await test_residential_land(main, city)
	await test_family_focus(main, city)
	await test_footer(main, city)
	await test_scrolling(main)

	main.regional_terrain.wait_for_tasks()
	main.queue_free()
	await _settle()
	if failure_count > 0:
		push_error("Town sidebar validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Town sidebar validation passed.")
	quit()

func test_layout(main: Node2D) -> void:
	var sidebar: TownSidebar = main.town_sidebar
	var rect: Rect2 = main.get_city_sidebar_rect()
	_check(sidebar.visible, "the sidebar shows in the town view")
	_check(is_equal_approx(rect.size.x, 384.0), "a fifth of a 1920 window is 384, got %.0f" % rect.size.x)
	_check(is_equal_approx(rect.end.x, 1920.0) and is_equal_approx(rect.end.y, 1080.0), "the sidebar runs to the window's edges, got " + str(rect))
	_check(sidebar.position == rect.position and sidebar.size == rect.size, "the panel sits where main.gd says the sidebar is")
	_check(main.get_town_map_screen_rect().end.x <= rect.position.x, "the map ends where the sidebar begins")

func test_pages_build(main: Node2D, city: City, label: String) -> void:
	for tab: Dictionary in TownSidebar.TABS:
		var blocks: Array = (tab["page"] as Script).call("build", {"city": city, "focused_household_id": city.households[0].id, "tool": "farm", "placing": true})
		_check(not blocks.is_empty(), "%s: the %s page shows something" % [label, tab["id"]])
		_check_kinds(blocks, "%s, %s page" % [label, tab["id"]])
	var overview: Array = SidebarOverviewPage.build({"city": city})
	_check(str(overview[0]["title"]) == city.settlement.get_title(), "%s: the overview opens on the settlement's stage" % label)
	var attention: Array[Dictionary] = SidebarOverviewPage.get_attention(city)
	for index in range(1, attention.size()):
		_check(int(attention[index - 1]["priority"]) >= int(attention[index]["priority"]), "%s: attention is ordered most pressing first" % label)

func _check_kinds(blocks: Array, where: String) -> void:
	for block: Dictionary in blocks:
		_check(KNOWN_KINDS.has(str(block.get("kind", ""))), "%s: unknown block kind %s" % [where, str(block.get("kind"))])
		if str(block.get("kind")) == "expander":
			_check_kinds(block["blocks"], where)

# Reading the town for the pages must not change it (predictions toggle an ask and put it back).
func test_pages_change_nothing(main: Node2D, city: City) -> void:
	city.influence.set_encouraged(TownInfluence.ACTIVITY_WOOD, true)
	var resources: Dictionary = city.resources.duplicate(true)
	var encouraged: Array[String] = city.influence.encouraged.duplicate()
	city.influence.set_priority(CommunityPriority.HOUSING)
	var backing_week: int = city.influence.backing_week
	var notes: Array = city.households.map(func(h: Household) -> String: return h.initiative_note + h.social_note)
	for tab: Dictionary in TownSidebar.TABS:
		(tab["page"] as Script).call("build", {"city": city, "focused_household_id": city.households[0].id})
	_check(city.resources == resources, "building pages leaves the stores as they were")
	_check(city.influence.backing_week == backing_week, "building pages leaves the backing families act on as it was")
	city.influence.set_priority(CommunityPriority.NONE)
	city.influence.set_encouraged(TownInfluence.ACTIVITY_WOOD, true)
	_check(city.influence.encouraged == encouraged, "building pages leaves the community's asks as they were")
	_check(city.households.map(func(h: Household) -> String: return h.initiative_note + h.social_note) == notes, "building pages leaves families' notes as they were")
	city.influence.set_encouraged(TownInfluence.ACTIVITY_WOOD, false)

func test_attention_follows_state(city: City) -> void:
	var titles: Callable = func() -> Array: return SidebarOverviewPage.get_attention(city).map(func(card: Dictionary) -> String: return str(card["title"]))
	_check(not titles.call().has("Food has run out"), "no hunger card while there is food")
	_check(not titles.call().has("Bandits on the road"), "no bandit card while no band is coming")
	var shortage: bool = city.resources["food_shortage"]
	city.resources["food_shortage"] = true
	_check(titles.call().has("Food has run out"), "a shortage shows the hunger card")
	city.resources["food_shortage"] = shortage
	city.defense.raid_day = city.construction.day + 10
	city.defense.raid_strength = 3
	var cards: Array[Dictionary] = SidebarOverviewPage.get_attention(city)
	_check(str(cards[0]["title"]) == "Bandits on the road", "bandits on the road come first")
	_check((cards[0]["buttons"] as Array).any(func(b: Dictionary) -> bool: return b["action"]["action"] == "call_militia"), "the bandit card offers the militia")
	city.defense.raid_day = -1
	city.trade.arrive(city.construction.day, TownTrade.LINK_ROAD)
	var trader: Array = SidebarOverviewPage.get_attention(city).filter(func(card: Dictionary) -> bool: return card["title"] == "A trader is in town")
	_check(trader.size() == 1 and (trader[0]["buttons"] as Array).size() == city.trade.get_lots().size(), "a trader's card offers each of its lots")
	city.trade.trader_until_day = -1

func test_tabs_and_keys(main: Node2D) -> void:
	var sidebar: TownSidebar = main.town_sidebar
	sidebar.show_tab(TownSidebar.TAB_OVERVIEW)
	_key(main, KEY_L)
	_check(sidebar.tab == TownSidebar.TAB_FAMILIES, "L opens the families page")
	_key(main, KEY_L)
	_check(sidebar.tab == TownSidebar.TAB_OVERVIEW, "L again goes back to the overview")
	_key(main, KEY_TAB)
	_check(sidebar.tab == TownSidebar.TAB_FAMILIES, "Tab moves to the next page")
	_key(main, KEY_TAB, true)
	_check(sidebar.tab == TownSidebar.TAB_OVERVIEW, "Shift+Tab moves back")
	for index in range(TownSidebar.TABS.size()):
		_click(sidebar.position + sidebar.get_tab_rect(index).get_center())
		await _settle()
		_check(sidebar.tab == TownSidebar.TABS[index]["id"], "clicking the %s tab shows it" % TownSidebar.TABS[index]["id"])

func test_clicks(main: Node2D, city: City) -> void:
	var sidebar: TownSidebar = main.town_sidebar
	main.show_sidebar_tab(TownSidebar.TAB_COMMUNITY)
	await _settle()
	sidebar.rebuild()
	for priority: String in [CommunityPriority.NONE] + CommunityPriority.ALL:
		_check(sidebar.prims.any(func(p: Dictionary) -> bool: return str(p["p"]) == "hit" and p["action"].get("action") == "set_priority" and p["action"].get("priority") == priority), "the community page offers %s" % CommunityPriority.get_display_name(priority))
	_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "set_priority" and a.get("priority") == CommunityPriority.FOOD), "the community page has food security")
	_check(city.influence.priority == CommunityPriority.FOOD and city.influence.is_encouraged(TownInfluence.ACTIVITY_FOOD), "clicking it puts food first, with its ask")
	var food_page: Array = SidebarCommunityPage.build({"city": city})
	_check(food_page.any(func(b: Dictionary) -> bool: return str(b.get("title", "")) == "How the town takes it" and str(b.get("tag", "")).begins_with("backed")), "the page shows the town's backing for it")
	_check(food_page.any(func(b: Dictionary) -> bool: return str(b.get("id", "")) == "community_views" and (b["blocks"] as Array).size() == city.households.size()), "and each family's stance, with its reasons")
	var warned: Array[String] = CommunityPriority.get_warnings(city, CommunityPriority.FOOD, city.influence.store_rule)
	_check(warned.is_empty() or food_page.any(func(b: Dictionary) -> bool: return str(b.get("title", "")) == "Before you lean on it" and b["lines"] == warned), "and its warnings, as the town records them")
	_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "set_store_rule" and a.get("rule") == TownInfluence.RULE_PRIORITIES), "the community page has the priorities rule")
	_check(city.influence.store_rule == TownInfluence.RULE_PRIORITIES and city.influence.priority == CommunityPriority.FOOD, "clicking 'priorities first' sets the stores rule, and leaves the priority")
	_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "set_priority" and a.get("priority") == CommunityPriority.NONE), "the community page has no priority")
	_check(city.influence.priority == CommunityPriority.NONE and city.influence.encouraged.is_empty(), "clicking it withdraws the priority and its asks")
	city.influence.store_rule = TownInfluence.RULE_OPEN
	# A town saved under the four work asks keeps them, named, until a priority (or none) is chosen.
	city.influence.set_encouraged(TownInfluence.ACTIVITY_WOOD, true)
	_check(SidebarCommunityPage.build({"city": city}).any(func(b: Dictionary) -> bool: return str(b.get("text", "")).begins_with("Asks from before")), "asks from before the priority are named")
	city.influence.set_priority(CommunityPriority.NONE)
	_check(city.influence.encouraged.is_empty(), "and choosing no priority withdraws them")

	main.show_sidebar_tab(TownSidebar.TAB_PLANNING)
	await _settle()
	var buildings: int = city.buildings.size()
	var projects: int = city.construction.projects.size()
	_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "select_tool" and a.get("tool") == "storehouse"), "the planning page lists the storehouse")
	_check(main.is_placing_building and main.selected_building_type == "storehouse", "clicking the storehouse picks it up")
	_check(city.buildings.size() == buildings and city.construction.projects.size() == projects, "clicks on the sidebar never plan anything on the map")
	main.is_placing_building = false

	main.show_sidebar_tab(TownSidebar.TAB_OVERVIEW)
	await _settle()
	var opened: bool = sidebar.expanded.get("overview_figures", false)
	_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "toggle_expand" and a.get("id") == "overview_figures"), "the overview has its figures section")
	_check(sidebar.expanded.get("overview_figures", false) != opened, "clicking a section's title opens it")

func test_family_focus(main: Node2D, city: City) -> void:
	var sidebar: TownSidebar = main.town_sidebar
	var housed: Household = null
	for household: Household in city.households:
		if household.residence_building_id >= 0 and city.buildings[household.residence_building_id].is_house():
			housed = household
			break
	_check(housed != null, "the grown town has a housed family")
	if housed == null:
		return
	main.show_sidebar_tab(TownSidebar.TAB_FAMILIES)
	main.clear_selected_household()
	await _settle()
	_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "focus_household" and int(a.get("household")) == housed.id), "the families page has a card for each family")
	await _settle()
	_check(sidebar.focused_household_id == housed.id, "clicking a family's card opens its details")
	_check(main.get_inspected_household() == housed, "clicking a family's card selects its home on the map")
	main.clear_selected_household()
	await _settle()
	_check(sidebar.focused_household_id == -1, "clearing the map's selection closes the family")
	main.city_building_overlay.inspected_building_index = housed.residence_building_id
	main.city_building_overlay.selected_house_building_index = housed.residence_building_id
	await _settle()
	_check(sidebar.focused_household_id == housed.id, "selecting a house on the map opens its family in the sidebar")
	main.clear_selected_household()

func test_footer(main: Node2D, city: City) -> void:
	var sidebar: TownSidebar = main.town_sidebar
	main.select_building_type("farm")
	await _settle()
	_check(not sidebar.footer_blocks.is_empty() and str(sidebar.footer_blocks[0]["label"]) == "Placing", "a tool in hand shows the placing footer")
	main.is_placing_building = false
	await _settle()
	_check(sidebar.footer_blocks.is_empty() or str(sidebar.footer_blocks[0]["label"]) == "Ground", "with no tool the footer only describes the ground")
	_check(TownSidebar.describe_ground(city, city.logistics.stockpile_tile) != "", "the ground at the town's heart has a description")

func test_scrolling(main: Node2D) -> void:
	var sidebar: TownSidebar = main.town_sidebar
	root.size = Vector2i(1366, 768)
	await _settle()
	_check(is_equal_approx(main.get_city_sidebar_rect().size.x, 320.0), "a small window keeps the sidebar at its least width")
	main.show_sidebar_tab(TownSidebar.TAB_PLANNING)
	await _settle()
	sidebar.scroll_to(0.0)
	_check(sidebar.get_max_scroll() > 0.0, "the planning page is longer than a small window")
	var zoom: float = main.town_map_view.zoom
	var point: Vector2 = sidebar.position + Vector2(sidebar.size.x * 0.5, sidebar.size.y * 0.5)
	_mouse_button(MOUSE_BUTTON_WHEEL_DOWN, true, point)
	_mouse_button(MOUSE_BUTTON_WHEEL_DOWN, false, point)
	await _settle()
	_check(sidebar.get_scroll() > 0.0, "the wheel over the sidebar scrolls it")
	_check(is_equal_approx(main.town_map_view.zoom, zoom), "the wheel over the sidebar leaves the map's zoom alone")
	sidebar.scroll_to(1.0e6)
	_check(is_equal_approx(sidebar.get_scroll(), sidebar.get_max_scroll()), "scrolling stops at the page's end")

# Every key the Planning page lists picks up the tool it names.
func test_shortcuts(main: Node2D) -> void:
	var town: City = main.cities[main.selected_city_index]
	var influence_was: bool = town.influence.enabled
	town.influence.enabled = true
	for tool: String in SidebarPlanningPage.TOOL_KEYS.keys():
		var key: String = SidebarPlanningPage.TOOL_KEYS[tool]
		var keycode: int = (KEY_0 + int(key)) if key.is_valid_int() else (KEY_A + key.unicode_at(0) - "A".unicode_at(0))
		main.is_placing_building = false
		_key(main, keycode)
		_check(main.is_placing_building and main.selected_building_type == tool, "key %s should pick up %s, got %s" % [key, tool, main.selected_building_type])
	town.influence.enabled = influence_was
	main.is_placing_building = false

# Residential land in play: the Planning card's tools, marking and clearing a block on the map, the
# ground under the cursor, and the Overview's card when families find nowhere to build.
func test_residential_land(main: Node2D, city: City) -> void:
	main.show_sidebar_tab(TownSidebar.TAB_PLANNING)
	await _settle()
	main.town_sidebar.rebuild()
	for tool: String in HomeSites.TOOL_LEVELS.keys():
		_check(main.town_sidebar.prims.any(func(p: Dictionary) -> bool: return str(p["p"]) == "hit" and p["action"].get("action") == "select_tool" and p["action"].get("tool") == tool), "the planning page offers %s" % HomeSites.TOOL_NAMES[tool])
	_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "select_tool" and a.get("tool") == HomeSites.TOOL_PREFERRED), "the preferred land tool can be clicked")
	_check(main.is_placing_building and main.selected_building_type == HomeSites.TOOL_PREFERRED, "clicking it picks up the tool")
	# A 4x4 block of open ground, none of it set aside yet.
	var corner: Vector2i = Vector2i(-1, -1)
	var size: Vector2i = city.logistics.map_size()
	for y in range(2, size.y - 6):
		for x in range(2, size.x - 6):
			if corner.x >= 0:
				break
			var open: bool = true
			for dy in range(4):
				for dx in range(4):
					var tile: Vector2i = Vector2i(x + dx, y + dy)
					open = open and HomeSites.get_land(city, tile) == HomeSites.LAND_NONE and city.construction.validate(Building.BUILDING_HOUSE, tile)["is_valid"] == true
			if open:
				corner = Vector2i(x, y)
	_check(corner.x >= 0, "the grown town has open ground to set aside")
	var room: int = HomeSites.count_room(city)
	main.city_hovered_tile = corner
	_check(main.get_placement_status_message().contains("corner"), "the footer says how to mark: %s" % main.get_placement_status_message())
	main.place_block_corner(city)
	main.city_hovered_tile = corner + Vector2i(3, 3)
	main.place_block_corner(city)
	_check(HomeSites.count_land(city, HomeSites.LAND_PREFERRED) == 16 and HomeSites.count_room(city) == room + 16, "two corners mark a block preferred, and it adds room for homes")
	_check(TownSidebar.describe_ground(city, corner).contains("set aside for homes (preferred)"), "the ground under the cursor says so")
	main.select_building_type(HomeSites.TOOL_CLEAR)
	main.city_hovered_tile = corner
	main.place_block_corner(city)
	main.city_hovered_tile = corner + Vector2i(3, 3)
	main.place_block_corner(city)
	_check(HomeSites.count_land(city, HomeSites.LAND_PREFERRED) == 0 and HomeSites.count_room(city) == room, "the clear tool takes it back")
	main.is_placing_building = false
	var family: Household = city.households[0]
	var note: String = family.home_site_note
	var waiting: int = city.construction.families_without_plot
	family.home_site_note = "%s cannot build a home: every spot set aside for homes is taken or cannot hold one" % city.get_household_label(family.id)
	family.home_site_day = city.construction.day + 1
	city.construction.families_without_plot = 1
	var cards: Array = SidebarOverviewPage.get_attention(city).filter(func(card: Dictionary) -> bool: return (card["buttons"] as Array).any(func(b: Dictionary) -> bool: return b["action"].get("tool") == HomeSites.TOOL_LAND))
	_check(cards.size() == 1 and (cards[0]["lines"] as Array).any(func(line: String) -> bool: return line.contains("every spot set aside for homes is taken")), "the overview says families cannot find a home site, and why")
	family.home_site_note = note
	city.construction.families_without_plot = waiting

# Scrolls the hit for the first action `matches` accepts into view and clicks it.
func _click_action(main: Node2D, matches: Callable) -> bool:
	var sidebar: TownSidebar = main.town_sidebar
	sidebar.rebuild()
	for prim: Dictionary in sidebar.prims:
		if str(prim["p"]) != "hit" or not matches.call(prim["action"]):
			continue
		var rect: Rect2 = prim["rect"]
		sidebar.scroll_to(rect.position.y - TownSidebar.HEADER_HEIGHT - 20.0)
		var screen: Vector2 = sidebar.position + rect.get_center() - Vector2(0.0, sidebar.get_scroll())
		_click(screen)
		await _settle()
		return true
	return false

func _key(main: Node2D, keycode: int, shift: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	event.shift_pressed = shift
	root.push_input(event)
	var release: InputEventKey = event.duplicate()
	release.pressed = false
	root.push_input(release)

func _click(position: Vector2) -> void:
	_mouse_button(MOUSE_BUTTON_LEFT, true, position)
	_mouse_button(MOUSE_BUTTON_LEFT, false, position)

func _mouse_button(button: MouseButton, pressed: bool, position: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	event.global_position = position
	root.push_input(event)

func _settle() -> void:
	for _frame in range(3):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
