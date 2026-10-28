extends SceneTree

# The household social model (docs/HOUSEHOLD_SOCIAL_MODEL.md): personality and value strengths,
# helping, sharing, and disputes over fields, ties and memories, norms, trust and standing, and the
# owner's ten required demonstrations (directive Section 16, "Specific test cases"). Each case sets
# up a small town of founding households with chosen characters and checks both what they do and
# the reasons they give.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_off_by_default()
	test_characters_are_drawn_and_inherited()
	test_cautious_household_improves_to_reduce_risk()
	test_industrious_household_refuses_communal_work()
	test_charitable_household_without_reserves_refuses()
	test_accepts_assistance_but_resents_favoritism()
	test_unfriendly_relationship_improves()
	test_unresolved_dispute_has_consequences()
	test_follows_norm_against_material_payoff()
	test_violates_norm_when_circumstances_outweigh()
	test_actions_change_before_values()
	test_same_event_read_differently()
	test_norms_move_only_with_behavior()
	test_values_change_slowly()
	test_bounded_ties_and_memories()
	test_saved_with_the_town()

	if failure_count > 0:
		push_error("Household social validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Household social validation passed.")
	quit()

# --- Setting up characters -------------------------------------------------------------------------

func social_city() -> City:
	var city: City = ConstructionTest.make_city()
	city.social.set_enabled(true)
	for household: Household in city.households:
		blank(household)
	return city

# A household with no marked temperament and no strong conviction, then the given ones.
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
	return household

func give_holding(city: City, household: Household, origin: Vector2i) -> Building:
	var farm: Building = Building.new(-1, "farm", origin, city.construction.get_size("farm"))
	city.add_building(farm, household)
	return farm

func home_project(city: City, household: Household, origin: Vector2i) -> ConstructionProject:
	return city.construction.request_building("house", origin, ConstructionProject.REQUESTED_BY_HOUSEHOLD, household.id, household.id)

func remembers(household: Household, fragment: String) -> bool:
	for memory: Dictionary in household.memories:
		if str(memory["text"]).contains(fragment) or (memory["lessons"] as Array).any(func(lesson: String) -> bool: return lesson.contains(fragment)):
			return true
	return false

func lessons_of(household: Household, kind: String) -> Array:
	for memory: Dictionary in household.memories:
		if memory["kind"] == kind:
			return memory["lessons"]
	return []

# --- Tests -----------------------------------------------------------------------------------------

func test_off_by_default() -> void:
	var city: City = ConstructionTest.make_city()
	_check(not city.social.enabled, "the social model is off unless enabled")
	ConstructionTest.run_days(city, 10)
	_check(city.households.all(func(h: Household) -> bool: return h.ties.is_empty() and h.personality.is_empty()), "with it off, households gain no ties or character")

func test_characters_are_drawn_and_inherited() -> void:
	var city: City = ConstructionTest.make_city()
	city.social.set_enabled(true)
	var strong_counts: Array[int] = []
	for household: Household in city.households:
		_check(household.personality.size() == HouseholdCharacter.AXES.size(), "every founder has all seven axes")
		var strong: int = HouseholdCharacter.get_held_values(household).filter(func(v: String) -> bool: return HouseholdCharacter.get_strength(household, v) >= 2).size()
		strong_counts.append(strong)
		for value_id: String in HouseholdCharacter.MIGRATED_VALUES.keys():
			if CultureValues.has_value(household.values, value_id):
				var axis: String = HouseholdCharacter.MIGRATED_VALUES[value_id][0]
				_check(signi(HouseholdCharacter.get_axis(household, axis)) == signi(int(HouseholdCharacter.MIGRATED_VALUES[value_id][1])), "a household holding %s carries it as temperament" % value_id)
	_check(strong_counts.all(func(n: int) -> bool: return n >= 3 and n <= 5), "founders hold 3-5 strong convictions: %s" % str(strong_counts))
	var again: City = ConstructionTest.make_city()
	again.social.set_enabled(true)
	_check(again.households[2].personality == city.households[2].personality, "characters are the same for the same town")
	# A new household from two lines: temperament near its parents', their convictions carried on.
	var a: Household = city.households[0]
	var b: Household = city.households[1]
	var child: Household = Household.new(99)
	child.parent_household_id = a.id
	child.second_parent_household_id = b.id
	child.set_values(a.values.duplicate(true))
	city.households.append(child)
	HouseholdCharacter.ensure(city, child)
	for axis: String in HouseholdCharacter.AXES:
		var middle: float = (float(a.personality[axis]) + float(b.personality[axis])) * 0.5
		_check(absf(float(child.personality[axis]) - middle) <= 1.5, "a new household's %s stays near its parents'" % axis)
	_check(HouseholdCharacter.get_held_values(child).any(func(v: String) -> bool: return HouseholdCharacter.get_strength(child, v) >= 2), "and carries strong convictions on")

# 1. A cautious household willingly improves a workplace because it reduces future risk.
func test_cautious_household_improves_to_reduce_risk() -> void:
	var city: City = social_city()
	city.influence.enabled = true
	var careful: Household = blank(city.households[0], {HouseholdCharacter.RISK: -2})
	city.add_building(Building.new(-1, "forager_garden", Vector2i(28, 4), city.construction.get_size("forager_garden")), careful)
	city.resources["food"] = 250
	FamilyInitiative.advance(city)
	var garden: Building = FamilyInitiative.get_holding(city, careful)
	_check(city.construction.get_upgrade_project(garden.id) != null, "with food short, a very cautious family improves its garden: %s" % careful.initiative_note)
	_check(careful.initiative_note.contains("waiting is the greater risk"), "because waiting is the greater risk: %s" % careful.initiative_note)
	var calm: City = social_city()
	calm.influence.enabled = true
	var same: Household = blank(calm.households[0], {HouseholdCharacter.RISK: -2})
	calm.add_building(Building.new(-1, "forager_garden", Vector2i(28, 4), calm.construction.get_size("forager_garden")), same)
	calm.resources["food"] = 50000
	FamilyInitiative.advance(calm)
	_check(calm.construction.get_upgrade_project(FamilyInitiative.get_holding(calm, same).id) == null, "the same family keeps to hand work when the town is fed: %s" % same.initiative_note)

# 2. An industrious household refuses communal work because it values independence.
func test_industrious_household_refuses_communal_work() -> void:
	var city: City = social_city()
	var free_hand: Household = blank(city.households[0], {HouseholdCharacter.DILIGENCE: 2}, {"self_governing": 3})
	give_holding(city, free_hand, Vector2i(28, 4))
	var store: ConstructionProject = city.construction.request_building(Building.BUILDING_STOREHOUSE, Vector2i(34, 24))
	_check(store != null and TownSocial.is_communal(store), "a storehouse is communal work")
	city.social.choose_help(free_hand)
	_check(free_hand.helping_project_id == -1, "an industrious, self-governing family does not help build the storehouse")
	_check(free_hand.social_note.contains("families should choose their own work") and free_hand.social_note.contains("Keeps to its own work"), "it says why: %s" % free_hand.social_note)
	var willing: Household = blank(city.households[1], {HouseholdCharacter.DILIGENCE: 2}, {"communal_labor": 3})
	give_holding(city, willing, Vector2i(40, 4))
	city.social.choose_help(willing)
	_check(willing.helping_project_id == store.id, "an industrious family that values working together does: %s" % willing.social_note)

# 3. A charitable household refuses to share food because it lacks sufficient reserves.
func test_charitable_household_without_reserves_refuses() -> void:
	var city: City = social_city()
	var hungry: Household = city.households[0]
	var giver: Household = blank(city.households[1], {HouseholdCharacter.EMPATHY: 2}, {"charitable": 3})
	for household: Household in city.households.slice(2):
		blank(household, {HouseholdCharacter.EMPATHY: -2}, {"each_to_their_own": 3})
	hungry.hardship_points = HouseholdMigration.get_departure_threshold(hungry) - 2
	# Clear of leaving itself, but with nothing to spare once the shortage is counted.
	giver.hardship_points = HouseholdMigration.get_departure_threshold(giver) - 5
	city.resources["shortage_days_this_month"] = 20
	city.social.share_in_shortage()
	_check(giver.shortage_hardship_adjust == 0 and hungry.shortage_hardship_adjust == 0, "a charitable family close to the edge itself does not share")
	_check(giver.social_note.contains("lacks reserves of its own"), "because it lacks reserves: %s" % giver.social_note)
	_check(remembers(hungry, "did not share"), "the hungry family remembers")
	_check(lessons_of(hungry, "food_refused").has("they could not spare it"), "and, seeing the giver's own want, does not blame it: %s" % str(lessons_of(hungry, "food_refused")))
	# With reserves, the same family shares and both remember it.
	city.social.disputes.clear()
	giver.hardship_points = 0
	hungry.shortage_hardship_adjust = 0
	city.construction.day += 30
	city.social.share_in_shortage()
	_check(giver.shortage_hardship_adjust == 1 and hungry.shortage_hardship_adjust == -1, "with a margin, it shares its ration: %s" % giver.social_note)
	_check(int(HouseholdMemory.get_tie(hungry, giver.id)["owes"]) >= 1, "and the family helped owes it")

# 4. A household accepts material assistance but resents perceived favoritism.
func test_accepts_assistance_but_resents_favoritism() -> void:
	var city: City = social_city()
	var favoured: Household = city.households[0]
	var worker: Household = city.households[1]
	worker.help_given = 4
	city.social.grant(worker)
	city.social.grant(favoured)
	city.social.grant(favoured)
	_check(worker.grants_received == 1 and worker.first_claim_until > city.construction.day, "the hard-working family accepts first claim on the stores")
	_check(worker.trust < 0, "but its trust in the leadership falls: %d" % worker.trust)
	_check(remembers(worker, "accepted the community's help"), "it remembers accepting help while another got more")
	_check(HouseholdMemory.get_disposition(worker, favoured.id) < 0, "and resents the favoured family")

# 5. An initially unfriendly relationship improves through repeated cooperation.
func test_unfriendly_relationship_improves() -> void:
	var city: City = social_city()
	var a: Household = city.households[0]
	var b: Household = city.households[1]
	HouseholdMemory.touch_tie(city, a, b, -2, "old quarrel")
	_check(HouseholdMemory.get_tie(a, b.id)["kind"] == "rival", "they start as rivals")
	var project: ConstructionProject = home_project(city, a, Vector2i(30, 20))
	for _week in range(4):
		city.social.record_help_day(b, project)
		city.social.record_help_day(b, project)
		city.social.settle_help_week()
	var tie: Dictionary = HouseholdMemory.get_tie(a, b.id)
	_check(int(tie["disposition"]) >= 2 and tie["kind"] == "friend", "four weeks of help make them friends: %s" % str(tie))
	_check((tie["reasons"] as Array).has("helped us build"), "and the tie says why")

# 6. A dispute remains unresolved and produces subsequent consequences.
func test_unresolved_dispute_has_consequences() -> void:
	var city: City = social_city()
	var owner: Household = blank(city.households[0], {HouseholdCharacter.ASSERTIVENESS: 2}, {"vindication": 2, "respect_for_holdings": 2})
	var crosser: Household = blank(city.households[1], {HouseholdCharacter.ASSERTIVENESS: 2})
	var field: Building = give_holding(city, owner, Vector2i(28, 4))
	give_holding(city, crosser, Vector2i(40, 4))
	city.social.set_promoted(TownSocial.NORM_CLAIMS, true)
	city.logistics.trampled_by = {field.id: {crosser.id: 3.0}}
	city.logistics.trampled_trips = {field.id: 3.0}
	city.social.run_disputes()
	_check(city.social.disputes_raised == 1 and city.social.disputes_settled == 0, "the owner presses its claim and the forceful crosser refuses: %s / %s" % [owner.social_note, crosser.social_note])
	var tie: Dictionary = HouseholdMemory.get_tie(owner, crosser.id)
	_check(str(tie.get("grievance", "")) != "", "a grievance stands")
	_check(crosser.standing < 0, "refusing, where the community asked that claims be respected, costs standing: %d" % crosser.standing)
	_check(city.social.dispute_pressure == 1, "an unsettled dispute is pressure for agreed rules")
	# Consequence: the owner will not help the crosser build.
	var crosser_home: ConstructionProject = home_project(city, crosser, Vector2i(30, 20))
	var desire: Dictionary = SocialDecisions.get_help_desire(city, owner, crosser_home, crosser)
	_check(FamilyInitiative.get_reasons(desire["terms"], false).any(func(r: String) -> bool: return r.contains("grievance")), "the grievance weighs against helping them: %s" % str(desire["terms"]))
	city.social.choose_help(owner)
	_check(owner.helping_project_id != crosser_home.id, "and the owner does not help")
	# Unsettled again after the dispute rests: a feud.
	city.construction.day += TownSocial.DISPUTE_COOLDOWN_DAYS
	city.social.run_disputes()
	_check(HouseholdMemory.get_tie(owner, crosser.id)["kind"] == "feud", "a second refusal hardens into a feud: %s" % str(HouseholdMemory.get_tie(owner, crosser.id)))

# 7. A household voluntarily follows a norm even when the immediate material payoff favors
# violating it.
func test_follows_norm_against_material_payoff() -> void:
	var city: City = social_city()
	var helper: Household = blank(city.households[0], {}, {"communal_labor": 1})
	give_holding(city, helper, Vector2i(28, 4))
	var needy: Household = city.households[1]
	var project: ConstructionProject = home_project(city, needy, Vector2i(30, 20))
	var alone: Dictionary = SocialDecisions.get_help_desire(city, helper, project, needy)
	_check(float(alone["score"]) < SocialDecisions.HELP_THRESHOLD, "on its own account, helping does not pay: %.2f" % float(alone["score"]))
	var norm: Dictionary = city.social.norms[TownSocial.NORM_HELP]
	norm["acceptance"] = 0.95
	norm["status"] = TownSocial.STATUS_CUSTOM
	city.social.choose_help(helper)
	_check(helper.helping_project_id == project.id, "where helping neighbours is the custom, it helps: %s" % helper.social_note)
	_check(helper.social_note.contains("custom") or helper.social_note.contains("most neighbours"), "and says it is what neighbours do: %s" % helper.social_note)
	var costs: Array[String] = FamilyInitiative.get_reasons(SocialDecisions.get_help_desire(city, helper, project, needy)["terms"], false)
	_check(costs.any(func(r: String) -> bool: return r.contains("own working day")), "though it costs it part of its own day: %s" % str(costs))

# 8. A household violates a norm because its circumstances outweigh its conviction.
func test_violates_norm_when_circumstances_outweigh() -> void:
	var city: City = social_city()
	var helper: Household = blank(city.households[0], {HouseholdCharacter.EMPATHY: 2}, {"communal_labor": 3})
	give_holding(city, helper, Vector2i(28, 4))
	var needy: Household = city.households[1]
	var project: ConstructionProject = home_project(city, needy, Vector2i(30, 20))
	city.social.set_promoted(TownSocial.NORM_HELP, true)
	city.social.choose_help(helper)
	_check(helper.helping_project_id == project.id, "a caring family that values working together helps: %s" % helper.social_note)
	helper.hardship_points = HouseholdMigration.get_departure_threshold(helper) - 1
	city.construction.day += FamilyInitiative.INTERVAL_DAYS
	city.social.choose_help(helper)
	_check(helper.helping_project_id == -1, "close to having to leave, it keeps to its own work: %s" % helper.social_note)
	_check(helper.social_note.contains("close to having to leave"), "and says so: %s" % helper.social_note)
	_check(HouseholdCharacter.get_strength(helper, "communal_labor") == 3, "its conviction is unchanged")

# 9. A household's actions change before its values change.
func test_actions_change_before_values() -> void:
	var city: City = social_city()
	var receiver: Household = city.households[0]
	var neighbour: Household = city.households[1]
	give_holding(city, receiver, Vector2i(28, 4))
	var neighbour_project: ConstructionProject = home_project(city, neighbour, Vector2i(30, 20))
	city.social.choose_help(receiver)
	_check(receiver.helping_project_id == -1, "at first it does not help its neighbour")
	var strengths_before: Dictionary = receiver.value_strengths.duplicate()
	var own: ConstructionProject = city.construction.request_fence(FamilyInitiative.get_holding(city, receiver).id)
	for _week in range(2):
		city.social.record_help_day(neighbour, own)
		city.social.settle_help_week()
	city.construction.cancel(own.id)
	city.construction.day += FamilyInitiative.INTERVAL_DAYS
	city.social.choose_help(receiver)
	_check(receiver.helping_project_id == neighbour_project.id, "after being helped twice, it helps them back: %s" % receiver.social_note)
	_check(receiver.social_note.contains("owes them"), "because it owes them: %s" % receiver.social_note)
	_check(receiver.value_strengths == strengths_before, "while its values have not changed yet")

# 10. Two households interpret the same community event differently.
func test_same_event_read_differently() -> void:
	var city: City = social_city()
	var honoured: Household = city.households[0]
	var levelling: Household = blank(city.households[1], {HouseholdCharacter.EMPATHY: 1}, {"egalitarian": 3})
	var climbing: Household = blank(city.households[2], {HouseholdCharacter.AMBITION: 2}, {"hierarchical": 3})
	levelling.help_given = 3
	climbing.help_given = 3
	city.social.recognize(honoured)
	var levelling_reads: Array = lessons_of(levelling, "honour_unfair")
	var climbing_reads: Array = lessons_of(climbing, "honour_unfair")
	_check(not levelling_reads.is_empty() and not climbing_reads.is_empty(), "both remember the honour")
	_check(levelling_reads != climbing_reads, "and read it differently: %s / %s" % [str(levelling_reads), str(climbing_reads)])
	_check(levelling_reads.has("the leadership plays favourites") or levelling_reads.has("everyone's work deserves its due"), "the egalitarian family sees favouritism: %s" % str(levelling_reads))
	_check(climbing_reads.has("honour goes to those who seek it"), "the ambitious, hierarchical family sees how honour is won: %s" % str(climbing_reads))
	_check(levelling.trust < climbing.trust, "and trusts the leadership less (%d against %d)" % [levelling.trust, climbing.trust])
	_check(honoured.standing >= 1, "the honoured family's standing rises")

func test_norms_move_only_with_behavior() -> void:
	var city: City = social_city()
	var norm: Dictionary = city.social.norms[TownSocial.NORM_HELP]
	var before: float = float(norm["acceptance"])
	city.social.set_promoted(TownSocial.NORM_HELP, true)
	_check(float(norm["acceptance"]) == before, "asking for a norm does not change what the town accepts")
	for _i in range(20):
		city.social.observe_norm(TownSocial.NORM_HELP, true)
	city.social.update_norms()
	_check(norm["status"] == TownSocial.STATUS_HABIT, "followed repeatedly, it becomes a habit: %.2f" % float(norm["acceptance"]))
	city.construction.day += TownSocial.CUSTOM_AFTER_DAYS
	city.social.update_norms()
	_check(norm["status"] == TownSocial.STATUS_HABIT, "with no reaction to anyone breaking it, it is not yet a custom")
	norm["sanctions"] = 1
	city.social.update_norms()
	_check(norm["status"] == TownSocial.STATUS_CUSTOM, "once breaking it draws a reaction, it is a custom")
	for _i in range(30):
		city.social.observe_norm(TownSocial.NORM_HELP, false)
	city.social.update_norms()
	_check(norm["status"] != TownSocial.STATUS_CUSTOM, "neglected, it falls back: %.2f" % float(norm["acceptance"]))

func test_values_change_slowly() -> void:
	var city: City = social_city()
	var household: Household = city.households[0]
	HouseholdMemory.add_evidence(city, household, "mutual_aid", 2.0, "A neighbour shared food")
	_check(HouseholdCharacter.get_strength(household, "mutual_aid") == 0, "one experience is not enough")
	HouseholdMemory.add_evidence(city, household, "mutual_aid", 1.0, "Neighbours helped build its home")
	_check(HouseholdCharacter.get_strength(household, "mutual_aid") == 1, "accumulated evidence moves a value one level")
	_check(str(household.value_change_notes.back()).contains("neighbours helped build its home"), "and the change is explained: %s" % str(household.value_change_notes))
	HouseholdMemory.add_evidence(city, household, "mutual_aid", 4.0, "Another winter of help")
	_check(HouseholdCharacter.get_strength(household, "mutual_aid") == 1, "not twice within a year")
	city.construction.day += HouseholdMemory.DAYS_BETWEEN_CHANGES
	HouseholdMemory.add_evidence(city, household, "mutual_aid", 0.5, "A later kindness")
	_check(HouseholdCharacter.get_strength(household, "mutual_aid") == 2, "a year on, the built-up evidence counts")
	HouseholdMemory.add_evidence(city, household, "mutual_aid", -2.0, "A refusal")
	_check(HouseholdCharacter.get_strength(household, "mutual_aid") == 2, "and a little contrary evidence does not undo it at once")

func test_bounded_ties_and_memories() -> void:
	var city: City = social_city()
	var household: Household = city.households[0]
	for i in range(12):
		var other: Household = Household.new(100 + i)
		city.households.append(other)
		HouseholdMemory.touch_tie(city, household, other, 1 if i % 2 == 0 else -1, "met")
		HouseholdMemory.remember(city, household, "test", "event %d" % i, other, 1.0, [])
	_check(household.ties.size() <= HouseholdMemory.MAX_TIES, "ties stay sparse: %d" % household.ties.size())
	_check(household.memories.size() <= HouseholdMemory.MAX_MEMORIES, "memories stay bounded: %d" % household.memories.size())
	_check(city.social.get_neighbours(household).size() <= TownSocial.MAX_NEIGHBOURS, "and a household weighs only its nearest neighbours")

func test_saved_with_the_town() -> void:
	var city: City = social_city()
	var a: Household = city.households[0]
	HouseholdMemory.touch_tie(city, a, city.households[1], 2, "helped us build", 1)
	HouseholdMemory.experience(city, a, "helped", "Household 2 helped build its home", city.households[1], {})
	city.social.set_promoted(TownSocial.NORM_CLAIMS, true)
	city.social.observe_norm(TownSocial.NORM_HELP, true)
	var loaded: City = GameState.restore_city(GameState.capture_city(city))
	var b: Household = loaded.households[0]
	_check(loaded.social.enabled and bool(loaded.social.norms[TownSocial.NORM_CLAIMS]["promoted"]), "a loaded town keeps the social model and its norms")
	_check(b.personality == a.personality and b.value_strengths == a.value_strengths, "and each household's character")
	_check(b.ties.size() == a.ties.size() and b.memories.size() == a.memories.size(), "and its ties and memories")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
