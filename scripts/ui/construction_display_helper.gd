class_name ConstructionDisplayHelper

# Plain-language text for building sites, plots, and travel, for the sidebar and the town map's
# cards. Reads TownConstruction and TownLogistics; changes nothing.

const SIDEBAR_PROJECT_LINES: int = 3

static func get_requester_text(city: City, project: ConstructionProject) -> String:
	match project.requested_by:
		ConstructionProject.REQUESTED_BY_HOUSEHOLD:
			return city.get_household_label(project.requester_household_id) + " (their own)"
		ConstructionProject.REQUESTED_BY_TOWN:
			return "the town"
	return "you"

static func get_funder_text(project: ConstructionProject) -> String:
	if project.funded_by == ConstructionProject.FUNDED_BY_TOWN_STORES:
		return "the town's stores"
	return project.funded_by

static func get_project_title(city: City, project: ConstructionProject) -> String:
	var title: String = TownConstruction.get_display_name(project)
	if project.claimant_household_id >= 0 and project.kind == ConstructionProject.KIND_BUILDING:
		title += " for " + city.get_household_label(project.claimant_household_id)
	return title

static func get_sidebar_summary(city: City) -> String:
	var construction: TownConstruction = city.construction
	if construction.projects.is_empty():
		return "nothing planned"
	return "%d site%s, %d building today" % [construction.projects.size(), "" if construction.projects.size() == 1 else "s", construction.builders_today.size()]

static func get_sidebar_lines(city: City) -> Array[String]:
	var lines: Array[String] = []
	var construction: TownConstruction = city.construction
	for index in range(mini(SIDEBAR_PROJECT_LINES, construction.projects.size())):
		var project: ConstructionProject = construction.projects[index]
		lines.append(TownConstruction.get_display_name(project) + ": " + construction.get_status_text(project))
	if construction.projects.size() > SIDEBAR_PROJECT_LINES:
		lines.append("+%d more planned" % (construction.projects.size() - SIDEBAR_PROJECT_LINES))
	if construction.families_without_plot > 0:
		lines.append("%d famil%s want a home plot (P)" % [construction.families_without_plot, "y" if construction.families_without_plot == 1 else "ies"])
	return lines

static func get_project_lines(city: City, project: ConstructionProject) -> Array[String]:
	var construction: TownConstruction = city.construction
	var lines: Array[String] = []
	lines.append("Status: " + construction.get_status_text(project))
	if not project.materials_needed.is_empty():
		var parts: Array[String] = []
		for material: String in project.materials_needed.keys():
			parts.append("%d/%d %s" % [int(project.materials_delivered.get(material, 0)), int(project.materials_needed[material]), material])
		lines.append("On site: " + ", ".join(parts))
	lines.append("Work: %.1f of %.1f family-days" % [project.work_done, project.work_required])
	var crew: Array[String] = []
	for household_id: int in project.crew_household_ids:
		var label: String = city.get_household_label(household_id)
		if construction.spare_time_today.has(household_id):
			label += " (spare)"
		crew.append(label)
	lines.append("Builders: " + (", ".join(crew) if not crew.is_empty() else "none today"))
	var per_unit: float = city.logistics.get_site_haul_days_per_unit(project.get_site_tile())
	if not project.materials_needed.is_empty() and city.logistics.has_map() and not is_inf(per_unit):
		lines.append("Carrying: %.2f family-days a load" % (per_unit * EconomyBalance.CARRY_LOAD))
	lines.append("Asked by: " + get_requester_text(city, project))
	lines.append("Paid from: " + get_funder_text(project))
	return lines

static func get_plot_lines(city: City, plot: Dictionary) -> Array[String]:
	var lines: Array[String] = ["Land set aside for a family home."]
	var project: ConstructionProject = city.construction.get_project(int(plot["project_id"]))
	if project == null:
		lines.append("Open: a family without a home will claim it.")
	else:
		lines.append("Claimed by " + city.get_household_label(project.claimant_household_id))
	return lines

# What travel costs a workplace's family, for its card: one or two lines.
static func get_travel_lines(city: City, building: Building) -> Array[String]:
	var lines: Array[String] = []
	if not city.logistics.has_map() or not building.is_production_building():
		return lines
	var travel: Dictionary = city.logistics.get_travel(building)
	if not travel["reachable"]:
		lines.append("Travel: no route to a store or home (-%d%%)" % int(round(float(travel["share"]) * 100.0)))
		return lines
	lines.append("Travel: -%d%% output" % int(round(float(travel["share"]) * 100.0)))
	var detail: String = "haul %d to store -%d%%" % [int(round(float(travel["haul_effort"]))), int(round(float(travel["haul_share"]) * 100.0))]
	if building.assigned_household_id >= 0:
		detail += ", walk %d -%d%%" % [int(round(float(travel["commute_effort"]))), int(round(float(travel["commute_share"]) * 100.0))]
	lines.append("  " + detail)
	return lines
