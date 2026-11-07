extends SceneTree

# Guiding wisdom (docs/GUIDING_WISDOM.md): leadership and fixed choices; a town without a wisdom
# decides as before; each wisdom is the gathering's expectation in the decisions it concerns, no
# more; two wisdoms can pull one decision both ways; a family's conduct becomes its own experience,
# from which followers and refusers learn different things, a level a year at most; lessons that
# bear the wisdom out come a little more readily; the Community page and saves.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_leadership_and_fixed_choices()
	test_no_wisdom_changes_nothing()
	test_each_wisdom_is_one_expectation()
	test_conflicting_wisdoms_pull_both_ways()
	test_conduct_becomes_experience()
	test_refusal_grows_other_qualities()
	test_values_still_move_a_level_a_year()
	test_wisdom_makes_its_lessons_readier()
	test_community_page()
	test_saved_and_older_saves()
	if failure_count > 0:
		push_error("Guiding wisdom validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Guiding wisdom validation passed.")
	quit()

func social_city() -> City:
	var city: City = ConstructionTest.make_city()
	city.social.set_enabled(true)
	city.influence.enabled = true
	for household: Household in city.households:
		blank(household)
	return city

func blank(household: Household, axes: Dictionary = {}, strengths: Dictionary = {}) -> Household:
	for axis: String in HouseholdCharacter.AXES:
		household.personality[axis] = int(axes.get(axis, 0))
	household.value_strengths.clear()
	for value_id: String in HouseholdCharacter.get_held_values(household):
		household.value_strengths[value_id] = 0
	for value_id: String in strengths.keys():
		household.value_strengths[value_id] = int(strengths[value_id])
	household.ties.clear()
	household.memories.clear()
	household.value_evidence.clear()
	household.value_changed_day.clear()
	return household

func give_holding(city: City, household: Household, origin: Vector2i, type: String = "farm") -> Building:
	var building: Building = Building.new(-1, type, origin, city.construction.get_size(type))
	city.add_building(building, household)
	return building

func reasons(terms: Array) -> String:
	return " | ".join(terms.map(func(t: Dictionary) -> String: return "%s %.2f" % [t["reason"], float(t["weight"])]))

func has_reason(terms: Array, fragment: String, sign: float) -> bool:
	return terms.any(func(t: Dictionary) -> bool: return str(t["reason"]).contains(fragment) and float(t["weight"]) * sign > 0.0)

# 1. Two wisdoms for the Expedition Leader, a third for the Elder of a village; a choice stays.
func test_leadership_and_fixed_choices() -> void:
	var city: City = social_city()
	_check(GuidingWisdom.get_title(city) == GuidingWisdom.EXPEDITION_LEADER and GuidingWisdom.get_slots(city) == 2, "a founding town is led by an Expedition Leader with two wisdoms")
	_check(GuidingWisdom.choose(city, GuidingWisdom.ENDURE) and GuidingWisdom.choose(city, GuidingWisdom.PREPARE), "the leader chooses two")
	_check(bool(city.social.norms[TownSocial.NORM_HELP]["promoted"]) and bool(city.social.norms[TownSocial.NORM_PREPARE]["promoted"]), "each chosen wisdom is what the gathering asks")
	_check(not GuidingWisdom.choose(city, GuidingWisdom.PRIDE) and not GuidingWisdom.choose(city, GuidingWisdom.ENDURE), "a third, or the same again, cannot be chosen")
	city.settlement.stage = SettlementStage.VILLAGE
	_check(GuidingWisdom.get_title(city) == GuidingWisdom.ELDER and GuidingWisdom.get_slots(city) == 3, "a village's leader is an Elder with three")
	_check(GuidingWisdom.choose(city, GuidingWisdom.PRIDE) and city.social.wisdoms.size() == 3, "and chooses a third")
	_check(not GuidingWisdom.choose(city, GuidingWisdom.RESPECT), "no fourth")

# 2. A town without a wisdom decides as it always did.
func test_no_wisdom_changes_nothing() -> void:
	var city: City = social_city()
	var family: Household = city.households[0]
	var terms: Array = []
	_check(GuidingWisdom.add_appeal(city, family, GuidingWisdom.PREPARE, terms) == 0.0 and terms.is_empty(), "no appeal is made")
	GuidingWisdom.record(city, family, GuidingWisdom.ENDURE, true)
	_check(family.wisdom_conduct.is_empty() and city.social.wisdom_record.is_empty(), "no conduct is counted")
	_check(not GuidingWisdom.frames(city, "mutual_aid", 1), "no lesson is framed")
	_check(int(city.social.norms[TownSocial.NORM_PREPARE]["opportunities"]) == 0, "the expectations the wisdoms add are not observed")

# 3. Each wisdom is one expectation in the decisions it concerns, with the expectation's own
# appeal and no other weight.
func test_each_wisdom_is_one_expectation() -> void:
	var city: City = social_city()
	var family: Household = city.households[0]
	give_holding(city, family, Vector2i(28, 4), "forager_garden")
	var before: Array = FamilyInitiative.get_improve_desire(city, family, "farm")["terms"]
	GuidingWisdom.choose(city, GuidingWisdom.PRIDE)
	var after: Array = FamilyInitiative.get_improve_desire(city, family, "farm")["terms"]
	var receptive: float = float(FamilyInitiative.get_receptiveness(family, city)["factor"])
	_check(has_reason(after, "take pride in their work", 1.0) and not has_reason(before, "take pride", 1.0), "Take Pride in Your Work asks families to improve their work: %s" % reasons(after))
	var added: float = FamilyInitiative.sum(after) - FamilyInitiative.sum(before)
	# The expectation's appeal, and what neighbours are seen to do (acceptance starts below half).
	var conformity: float = (TownSocial.ACCEPTANCE_START - 0.5) * 2.0
	conformity = conformity if absf(conformity) >= 0.2 else 0.0
	_check(is_equal_approx(added, SocialDecisions.NORM_APPEAL_WEIGHT * receptive + conformity), "with the expectation's own weight, no more (%.2f)" % added)
	var project: ConstructionProject = city.construction.request_building("house", Vector2i(30, 20), ConstructionProject.REQUESTED_BY_HOUSEHOLD, family.id, family.id)
	_check(has_reason(SocialDecisions.get_hours_desire(city, family, project, true)["terms"], "take pride", 1.0), "and to put long days into its own building")
	_check(not has_reason(SocialDecisions.get_hours_desire(city, family, project, false)["terms"], "take pride", 1.0), "not into others'")
	var helper: Household = city.households[1]
	give_holding(city, helper, Vector2i(40, 4))
	GuidingWisdom.choose(city, GuidingWisdom.ENDURE)
	_check(has_reason(SocialDecisions.get_help_desire(city, helper, project, family)["terms"], "help neighbours in need", 1.0), "We Endure Together asks families to help a neighbour building its first home")

# 4. Two wisdoms that pull one decision both ways: sharing in a shortage under We Endure Together
# and Prepare for Hard Times; improving before winter under Prepare and Pride.
func test_conflicting_wisdoms_pull_both_ways() -> void:
	var city: City = social_city()
	GuidingWisdom.choose(city, GuidingWisdom.ENDURE)
	GuidingWisdom.choose(city, GuidingWisdom.PREPARE)
	var donor: Household = city.households[0]
	var needy: Household = city.households[1]
	var share: Array = SocialDecisions.get_share_desire(city, donor, needy)["terms"]
	_check(has_reason(share, "help neighbours in need", 1.0) and has_reason(share, "keep something back", -1.0), "a family asked to share is also asked to keep something back: %s" % reasons(share))
	var other: City = social_city()
	GuidingWisdom.choose(other, GuidingWisdom.PREPARE)
	GuidingWisdom.choose(other, GuidingWisdom.PRIDE)
	var family: Household = other.households[0]
	give_holding(other, family, Vector2i(28, 4), "gatherer_camp")
	# Plentiful even with the winter's firewood to come (TownFuel, sprint S3).
	other.resources["wood"] = 2000
	other.resources["tools"] = 100
	other.construction.day = 10
	_check(not GuidingWisdom.asks_to_hold_off(other, "woodcutter"), "in spring, preparation does not ask families to hold off")
	other.construction.day = Calendar.DAYS_PER_YEAR * 3 / 4
	_check(GuidingWisdom.asks_to_hold_off(other, "woodcutter"), "late in the year it does")
	var improve: Array = FamilyInitiative.get_improve_desire(other, family, "woodcutter")["terms"]
	_check(has_reason(improve, "take pride", 1.0) and has_reason(improve, "keep something back", -1.0), "before winter, pride asks it to improve and preparation to wait: %s" % reasons(improve))
	other.resources["food"] = 0
	_check(not GuidingWisdom.asks_to_hold_off(other, "farm"), "but not to hold off growing more food while food is short")
	# Dangerously low tools or wood threaten the winter too (owner, 2026-10-31): the wisdom stops
	# asking to wait, and nothing else changes; spending the stores still weighs against it.
	_check(GuidingWisdom.asks_to_hold_off(other, "toolmaker"), "with tools enough, it asks to hold off a toolmaker")
	other.resources["tools"] = 4
	var toolmaker: Array = FamilyInitiative.get_improve_desire(other, family, "toolmaker")["terms"]
	_check(not GuidingWisdom.asks_to_hold_off(other, "toolmaker") and not has_reason(toolmaker, "keep something back", -1.0), "nor a toolmaker while tools run out: %s" % reasons(toolmaker))
	_check(GuidingWisdom.asks_to_hold_off(other, "woodcutter"), "while wood is plentiful it still asks to hold off a woodcutter")
	other.resources["wood"] = 5
	_check(not GuidingWisdom.asks_to_hold_off(other, "woodcutter"), "but not while wood runs out")
	_check(has_reason(FamilyInitiative.get_work_desire(other, family, "toolmaker")["terms"], "keep something back", 1.0), "and a family choosing its work is asked to take up the work the town is short of")
	other.resources["food"] = 5000
	other.resources["tools"] = 100
	_check(not has_reason(FamilyInitiative.get_work_desire(other, family, "toolmaker")["terms"], "keep something back", 1.0), "not when tools are plentiful")

# 5. A family's conduct becomes its own experience once it has met the wisdom's choice a few times,
# at most once a season; it draws lessons by its own lights.
func test_conduct_becomes_experience() -> void:
	var city: City = social_city()
	GuidingWisdom.choose(city, GuidingWisdom.ENDURE)
	var giver: Household = blank(city.households[0], {HouseholdCharacter.EMPATHY: 2, HouseholdCharacter.SOCIABILITY: 1})
	city.construction.day = 100
	GuidingWisdom.record(city, giver, GuidingWisdom.ENDURE, true)
	GuidingWisdom.review(city)
	_check(giver.memories.is_empty(), "once is not yet an experience")
	GuidingWisdom.record(city, giver, GuidingWisdom.ENDURE, true)
	GuidingWisdom.review(city)
	_check(giver.memories.size() == 1 and str(giver.memories[0]["text"]).contains("lived by 'We Endure Together'"), "living by it a few times is: %s" % str(giver.memories))
	_check(str(giver.memories[0]["lessons"]).contains("we endure together") and float(giver.value_evidence.get("mutual_aid", 0.0)) > 0.0, "an attuned, outgoing family takes mutual aid from it: %s" % str(giver.memories[0]["lessons"]))
	GuidingWisdom.record(city, giver, GuidingWisdom.ENDURE, true)
	GuidingWisdom.record(city, giver, GuidingWisdom.ENDURE, true)
	city.construction.day += 30
	GuidingWisdom.review(city)
	_check(giver.memories.size() == 1, "not again within the season")
	city.construction.day += GuidingWisdom.LESSON_INTERVAL_DAYS
	GuidingWisdom.review(city)
	_check(giver.memories.size() == 2, "a season on, it is")
	var counts: Dictionary = city.social.wisdom_record[GuidingWisdom.ENDURE]
	_check(int(counts["followed"]) == 4 and int(counts["lived"]) == 2, "the town counts the choices and the lessons: %s" % str(counts))

# 6. Refusing a wisdom teaches too: something else, of worth in its own decisions.
func test_refusal_grows_other_qualities() -> void:
	var city: City = social_city()
	GuidingWisdom.choose(city, GuidingWisdom.ENDURE)
	GuidingWisdom.choose(city, GuidingWisdom.PRIDE)
	var independent: Household = blank(city.households[0], {HouseholdCharacter.ASSERTIVENESS: 2, HouseholdCharacter.AMBITION: 1})
	var easy: Household = blank(city.households[1], {HouseholdCharacter.DILIGENCE: -1, HouseholdCharacter.RISK: 1})
	city.construction.day = 100
	for _i in range(3):
		GuidingWisdom.record(city, independent, GuidingWisdom.ENDURE, false)
		GuidingWisdom.record(city, easy, GuidingWisdom.PRIDE, false)
	GuidingWisdom.review(city)
	_check(str(independent.memories[0]["text"]).contains("went its own way") and float(independent.value_evidence.get("self_governing", 0.0)) > 0.0, "a forceful family that would not give its time learns self-government: %s" % str(independent.memories[0]["lessons"]))
	_check(float(easy.value_evidence.get("expedient", 0.0)) > 0.0, "an easygoing family that would not strain for its work learns that good enough will do: %s" % str(easy.memories[0]["lessons"]))
	_check(float(independent.value_evidence.get("mutual_aid", 0.0)) <= 0.0, "not what the wisdom asks")

# 7. However many lessons, a value moves a level a year at most.
func test_values_still_move_a_level_a_year() -> void:
	var city: City = social_city()
	GuidingWisdom.choose(city, GuidingWisdom.ENDURE)
	var giver: Household = blank(city.households[0], {HouseholdCharacter.EMPATHY: 2, HouseholdCharacter.SOCIABILITY: 2})
	var day: int = 100
	var strengths: Array[int] = []
	for season in range(8):
		city.construction.day = day + season * GuidingWisdom.LESSON_INTERVAL_DAYS
		for _i in range(4):
			GuidingWisdom.record(city, giver, GuidingWisdom.ENDURE, true)
		GuidingWisdom.review(city)
		strengths.append(HouseholdCharacter.get_strength(giver, "mutual_aid"))
	_check(strengths[0] == 0 or strengths[0] == 1, "the first season's lesson alone moves it a level at most")
	_check(strengths[3] <= 1 and strengths.back() <= 2 and strengths.back() >= 1, "two years of living by it: a level a year at most (%s)" % str(strengths))

# 8. A lesson that bears the town's wisdom out comes more readily, from the same experience.
func test_wisdom_makes_its_lessons_readier() -> void:
	var plain: City = social_city()
	var framed: City = social_city()
	GuidingWisdom.choose(framed, GuidingWisdom.ENDURE)
	# A family the help reads two ways: neighbours can be trusted, and it is humbling to depend.
	var axes: Dictionary = {HouseholdCharacter.EMPATHY: -1, HouseholdCharacter.AMBITION: 1}
	var a: Household = blank(plain.households[0], axes)
	var b: Household = blank(framed.households[0], axes)
	var lessons_a: Array[String] = HouseholdMemory.experience(plain, a, "helped", "Neighbours helped build its home", plain.households[1], {"benefit": 1, "voluntary": true})
	var lessons_b: Array[String] = HouseholdMemory.experience(framed, b, "helped", "Neighbours helped build its home", framed.households[1], {"benefit": 1, "voluntary": true})
	_check(lessons_a.has("it is humbling to depend on others") and not lessons_b.has("it is humbling to depend on others") and lessons_b.has("we should help others in turn"), "where the town holds We Endure Together the same help is read as a call to help in turn, not a humbling (%s / %s)" % [str(lessons_a), str(lessons_b)])

# 9. The Community page: title, slots, wisdoms to choose with what they mean and how families take
# them; held wisdoms with what families did and the qualities appearing; customs read-only.
func test_community_page() -> void:
	var city: City = social_city()
	var page: Array = SidebarCommunityPage.build({"city": city})
	var actions: Array = []
	collect_actions(page, actions)
	_check(page.any(func(b: Dictionary) -> bool: return str(b.get("note", "")) == "Expedition Leader · 0 of 2"), "the leader's title and slots are shown")
	_check(GuidingWisdom.ALL.all(func(w: String) -> bool: return actions.any(func(a: Dictionary) -> bool: return a.get("action") == "choose_wisdom" and a.get("wisdom") == w)), "each wisdom can be chosen while slots are open")
	_check(not actions.any(func(a: Dictionary) -> bool: return a.get("action") == "toggle_norm"), "the expectations have no buttons of their own")
	GuidingWisdom.choose(city, GuidingWisdom.ENDURE)
	GuidingWisdom.choose(city, GuidingWisdom.RESPECT)
	GuidingWisdom.record(city, city.households[0], GuidingWisdom.ENDURE, true)
	page = SidebarCommunityPage.build({"city": city})
	actions.clear()
	collect_actions(page, actions)
	_check(not actions.any(func(a: Dictionary) -> bool: return a.get("action") == "choose_wisdom"), "with the slots full nothing more can be chosen")
	var held: Array = page.filter(func(b: Dictionary) -> bool: return str(b.get("tag", "")) == "held")
	_check(held.size() == 2 and (held[0]["muted"] as Array).any(func(line: String) -> bool: return line.contains("kept to it 1 times")), "held wisdoms show what families did")
	_check((held[0]["muted"] as Array).any(func(line: String) -> bool: return line.contains("Mutual Aid") and line.contains("Self-Governing")), "and the qualities on both sides")
	_check(page.any(func(b: Dictionary) -> bool: return str(b.get("id", "")).begins_with("community_wisdom_")), "and how each family takes them, with reasons")
	_check(page.any(func(b: Dictionary) -> bool: return str(b.get("title", "")) == "Respecting claims" and (b["muted"] as Array).any(func(l: String) -> bool: return l.contains("Respect What Others Build"))), "the customs say which wisdom asks them")
	# The village's Elder: a third slot opens on the page, for the two wisdoms not yet held.
	city.settlement.stage = SettlementStage.VILLAGE
	page = SidebarCommunityPage.build({"city": city})
	actions.clear()
	collect_actions(page, actions)
	_check(page.any(func(b: Dictionary) -> bool: return str(b.get("note", "")) == "Elder · 2 of 3"), "a village's page shows its Elder and the third slot")
	var open: Array = actions.filter(func(a: Dictionary) -> bool: return a.get("action") == "choose_wisdom").map(func(a: Dictionary) -> String: return str(a.get("wisdom")))
	_check(open.size() == 2 and open.has(GuidingWisdom.PREPARE) and open.has(GuidingWisdom.PRIDE), "where the two wisdoms not yet held can be chosen: %s" % [open])

func collect_actions(blocks: Array, into: Array) -> void:
	for block: Dictionary in blocks:
		if block.has("action"):
			into.append(block["action"])
		for button: Dictionary in block.get("buttons", []):
			into.append(button["action"])
		if block.has("blocks"):
			collect_actions(block["blocks"], into)

# 10. Saved with the town; a town saved when the gathering asked for helping takes it as its wisdom.
func test_saved_and_older_saves() -> void:
	var city: City = social_city()
	GuidingWisdom.choose(city, GuidingWisdom.PREPARE)
	GuidingWisdom.record(city, city.households[0], GuidingWisdom.PREPARE, true)
	var loaded: City = GameState.restore_city(GameState.capture_city(city))
	_check(loaded.social.wisdoms == city.social.wisdoms and loaded.households[0].wisdom_conduct == city.households[0].wisdom_conduct, "wisdoms and conduct are saved")
	GuidingWisdom.choose(city, GuidingWisdom.PRIDE)
	city.settlement.stage = SettlementStage.VILLAGE
	GuidingWisdom.choose(city, GuidingWisdom.ENDURE)
	var village: City = GameState.restore_city(GameState.capture_city(city))
	_check(village.social.wisdoms.size() == 3 and GuidingWisdom.get_slots(village) == 3 and not GuidingWisdom.can_choose(village, GuidingWisdom.RESPECT), "an Elder's three wisdoms are saved, with no slot left")
	var older: City = social_city()
	older.social.set_promoted(TownSocial.NORM_HELP, true)
	var data: Dictionary = GameState.capture_city(older)
	var norms: Dictionary = data["social"]["norms"]
	norms.erase(TownSocial.NORM_PREPARE)
	norms.erase(TownSocial.NORM_PRIDE)
	(data["social"] as Dictionary).erase("wisdoms")
	var restored: City = GameState.restore_city(data)
	_check(restored.social.norms.has(TownSocial.NORM_PRIDE) and restored.social.wisdoms.size() == 1 and restored.social.wisdoms[0] == GuidingWisdom.ENDURE, "an older town gains the new expectations and keeps its ask as its wisdom")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
