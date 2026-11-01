class_name SidebarPlanningPage
extends RefCounted

# What the player plans for the community (docs/TOWN_UI.md): land marked for a purpose
# (Designate), shared works paid from the common stores, and a pointer to the appeals that shape
# families' own choices (Encourage, under Community). While families lead, placing any other
# building directly is an optional, folded-away Commission; under the classic rules the whole
# catalog shows. Every entry selects an existing tool; nothing here adds a way to build.

const SP = preload("res://scripts/ui/town_sidebar/sidebar_painter.gd")

# The town view's shortcut for each tool. It mirrors main.gd's handle_building_selection_key_event;
# tests/town_sidebar_validation.gd presses each key and checks the tool it selects.
const TOOL_KEYS: Dictionary = {
	"house": "1", "farm": "2", "woodcutter": "3", "toolmaker": "4", "quarry": "5", "stonecutter": "6",
	"brickworks": "7", "lime_kiln": "8", "mortar_yard": "9", "mason_yard": "0", "sculptor": "Q",
	"carver": "W", "tileworks": "E", "paver_yard": "R", "storehouse": "T", "fisher": "Y",
	"hunter": "U", "watch_post": "O", "herder": "H", "plot": "P", "clear_woods": "C", "till_land": "F",
	"road": "G", "work_ground": "K", "residential": "N",
}
const DESIGNATIONS: Array[String] = [TownConstruction.PLOT, TownInfluence.WORK_GROUND, TownWoodland.CLEAR, TownFarmland.TILL]
# Communal infrastructure: what families leading their own work still look to the community for.
const SHARED_WORKS: Array[String] = [TownConstruction.ROAD, Building.BUILDING_STOREHOUSE, Building.BUILDING_WATCH_POST]
const PROJECTS_SHOWN: int = 6
# Catalog categories under the names this page gives them.
const CATEGORY_NAMES: Dictionary = {"Town Planning": "Roads and stores", "Hand Work (Tier 0)": "Hand work"}

static func build(context: Dictionary) -> Array:
	var city: City = context["city"]
	var tool: String = str(context.get("tool", ""))
	var placing: bool = bool(context.get("placing", false))
	var blocks: Array = []
	if city.influence.enabled:
		blocks.append({"kind": "text", "text": "You plan what the community holds in common. Families build their own homes and choose their own work.", "muted": true})
	else:
		blocks.append({"kind": "text", "text": "Classic rules: you plan every building, and families build them.", "muted": true})

	blocks.append({"kind": "heading", "text": "Designate", "note": "where things may go"})
	if city.influence.enabled:
		blocks.append(get_residential_card(city, tool if placing else ""))
	for designation: String in DESIGNATIONS:
		if designation == TownInfluence.WORK_GROUND and not city.influence.enabled:
			continue
		blocks.append(get_designation_card(city, designation, placing and tool == designation))

	if city.influence.enabled:
		# Families lead: land and what the community holds in common come first; placing a family's
		# building directly stays possible, folded away as an optional commission.
		blocks.append({"kind": "heading", "text": "Shared works", "note": "paid from the stores"})
		blocks.append({"kind": "text", "text": "Roads, stores and the watch serve everyone. Families do the building, carrying materials from the stores.", "muted": true})
		blocks.append_array(get_catalog_rows(city, tool, placing, func(id: String) -> bool: return SHARED_WORKS.has(id), false))
		var private: Array = [{"kind": "text", "text": "Families build their own homes and choose their own work. Commissioning places a building for them, paid from the stores, for when one is wanted just there.", "muted": true}]
		private.append_array(get_catalog_rows(city, tool, placing, func(id: String) -> bool: return not SHARED_WORKS.has(id), true))
		blocks.append({"kind": "gap", "size": 4.0})
		blocks.append({"kind": "expander", "id": "planning_commission", "title": "Commission a building (optional)", "blocks": private})
	else:
		blocks.append({"kind": "heading", "text": "Commission", "note": "paid from the stores"})
		blocks.append({"kind": "text", "text": "Families do the building, carrying materials from the stores.", "muted": true})
		blocks.append_array(get_catalog_rows(city, tool, placing, func(_id: String) -> bool: return true, true))
	blocks.append({"kind": "text", "text": "A dot: the stores can supply it now. A triangle: it waits for materials.", "muted": true})

	if city.influence.enabled:
		blocks.append({"kind": "heading", "text": "Encourage", "note": "families' own choices"})
		blocks.append({"kind": "text", "text": "What families should put first, and how they may draw on the stores, is set under Community.", "muted": true})
		blocks.append({"kind": "buttons", "items": [{"text": "Community priorities", "action": {"action": "show_tab", "tab": "community"}}]})

	blocks.append({"kind": "heading", "text": "Underway", "note": "%d" % city.construction.projects.size() if not city.construction.projects.is_empty() else ""})
	blocks.append_array(get_project_blocks(city))

	var keys: Array = []
	for line: String in ["1-0, Q-R, T, Y, U, O, H choose a building (B opens the catalog)", "P home plot, G road, C clear woods, F till land" + (", K work ground, N residential land" if city.influence.enabled else ""), "Click the map to place; roads and areas take two clicks", "Esc or right click stops placing and clears a selection", "M calls the militia, L shows families, Tab changes page", "Space pauses; I switches the town's rules"]:
		keys.append({"kind": "text", "text": line, "muted": true})
	blocks.append({"kind": "gap", "size": 6.0})
	blocks.append({"kind": "expander", "id": "planning_keys", "title": "Keyboard shortcuts", "blocks": keys})
	return blocks

# Land set aside for homes (HomeSites): families choose their own sites on it, by what they value;
# preferred land is the community's hope, which receptive families heed more. No workplace may be
# opened on either.
static func get_residential_card(city: City, tool: String) -> Dictionary:
	var land: int = HomeSites.count_land(city)
	var preferred: int = HomeSites.count_land(city, HomeSites.LAND_PREFERRED)
	var muted: Array = []
	if land == 0:
		muted.append("None set aside: families cannot build homes except on plots.")
	else:
		muted.append("%d tiles set aside%s; room for %d more homes" % [land, " (%d preferred)" % preferred if preferred > 0 else "", HomeSites.count_room(city)])
	var waiting: int = city.construction.families_without_plot
	if waiting > 0:
		muted.append("%d famil%s found nowhere to build last month" % [waiting, "y" if waiting == 1 else "ies"])
	var buttons: Array = []
	for id: String in [HomeSites.TOOL_LAND, HomeSites.TOOL_PREFERRED, HomeSites.TOOL_CLEAR]:
		buttons.append({"text": ["Mark", "Prefer", "Clear"][buttons.size()], "toggle": true, "active": tool == id, "action": {"action": "select_tool", "tool": id}})
	return {"kind": "card", "title": "Residential land", "tag": "key N", "lines": ["Families choose their own home sites here, by what they value. Preferred land is where the community would rather they build; receptive families heed it more, none is bound to. Storehouses and roads may go among the homes, taking their room; no private workplace may.", "Mark sets land aside, Prefer marks the community's preferred land, Clear takes it back: two corners each; the same block again unmarks it."], "muted": muted, "buttons": buttons, "columns": 3, "selected": HomeSites.TOOL_LEVELS.has(tool)}

# The catalog's buildings that `include` accepts (designations aside), with cost, readiness and
# shortcut; under their category names when `headed`.
static func get_catalog_rows(city: City, tool: String, placing: bool, include: Callable, headed: bool) -> Array:
	var blocks: Array = []
	var current_category: String = ""
	for entry: Dictionary in BuildMenuHelper.get_building_catalog():
		var id: String = str(entry["id"])
		if DESIGNATIONS.has(id) or not include.call(id):
			continue
		var category: String = str(CATEGORY_NAMES.get(entry["category"], entry["category"]))
		if headed and category != current_category:
			current_category = category
			blocks.append({"kind": "gap", "size": 4.0})
			blocks.append({"kind": "text", "text": category, "muted": true})
		var cost: Dictionary = EconomyBalance.get_build_cost(id)
		var ready: bool = city.construction.can_supply(cost)
		var row: Dictionary = {"kind": "row", "label": str(entry["display_name"]), "value": cost_text(cost), "tone": SP.TONE_GOOD if ready else SP.TONE_CAUTION, "action": {"action": "select_tool", "tool": id}, "selected": placing and tool == id}
		if TOOL_KEYS.has(id):
			row["key"] = TOOL_KEYS[id]
		blocks.append(row)
	return blocks

static func get_designation_card(city: City, designation: String, selected: bool) -> Dictionary:
	var title: String = ""
	var lines: Array = []
	var muted: Array = []
	match designation:
		TownConstruction.PLOT:
			title = "Home plots"
			lines.append("An exact site for one family home, for when a home should go just there. Families still choose among the sites open to them." if city.influence.enabled else "Land set aside for a family home. Families build their own houses there.")
			var waiting: int = city.construction.families_without_plot
			var free: int = city.construction.plots.filter(func(plot: Dictionary) -> bool: return int(plot["project_id"]) < 0).size()
			muted.append("%d plot%s free; %d famil%s waiting for one" % [free, "" if free == 1 else "s", waiting, "y" if waiting == 1 else "ies"])
		TownInfluence.WORK_GROUND:
			title = "Work ground"
			lines.append("Where families may open workplaces of their own. Two corners; again to unmark.")
			var marked: int = city.influence.count_work_ground()
			muted.append("%d tiles marked" % marked if marked > 0 else "None marked: families open workplaces anywhere the land allows")
		TownWoodland.CLEAR:
			title = "Clear woods"
			lines.append("Woods for the woodcutters to fell. Two corners.")
			muted.append("%d tiles marked%s" % [city.woodland.marked.size(), "" if not city.woodland.get_woodcutters().is_empty() or city.woodland.marked.is_empty() else "; needs a working woodcutter"])
		TownFarmland.TILL:
			title = "Till land"
			lines.append("Open land for a field's family to till into farmland. Two corners.")
			muted.append("%d tiles marked%s" % [city.farmland.marked.size(), "" if not city.farmland.get_farms().is_empty() or city.farmland.marked.is_empty() else "; needs a working field"])
	return {"kind": "card", "title": title, "tag": "key " + str(TOOL_KEYS.get(designation, "")), "lines": lines, "muted": muted, "action": {"action": "select_tool", "tool": designation}, "selected": selected}

static func get_project_blocks(city: City) -> Array:
	var blocks: Array = []
	var construction: TownConstruction = city.construction
	if construction.projects.is_empty():
		blocks.append({"kind": "text", "text": "Nothing is being built.", "muted": true})
		return blocks
	var cards: Array = []
	for project: ConstructionProject in construction.projects:
		cards.append({"kind": "card", "title": ConstructionDisplayHelper.get_project_title(city, project), "lines": [construction.get_status_text(project)], "muted": ["Asked by %s; paid from %s" % [ConstructionDisplayHelper.get_requester_text(city, project), ConstructionDisplayHelper.get_funder_text(project)]]})
	blocks.append_array(cards.slice(0, PROJECTS_SHOWN))
	if cards.size() > PROJECTS_SHOWN:
		blocks.append({"kind": "expander", "id": "planning_more_projects", "title": "%d more" % (cards.size() - PROJECTS_SHOWN), "blocks": cards.slice(PROJECTS_SHOWN)})
	return blocks

static func cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "free"
	var parts: Array[String] = []
	for material: String in cost.keys():
		if int(cost[material]) > 0:
			parts.append("%d %s" % [int(cost[material]), material.replace("_", " ")])
	return ", ".join(parts) if not parts.is_empty() else "free"
