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
	# Owner decisions after the first review (docs/HOUSEHOLD_SOCIAL_MODEL.md, Owner decisions).
	test_diligence_decides_hours_not_output()
	test_kin_come_first_but_help_stays_voluntary()
	test_recognition_kinds_read_by_convictions()
	test_trust_has_positive_sources_judged_by_conviction()
	test_respected_voices_carry_appeals()
	test_land_same_field()
	test_land_path_across_holding()
	test_land_newcomer_needs_land_in_use()
	test_land_communal_designation()
	test_opposite_values_do_not_both_grow()
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
	_check(worker.trust < 0, "but its trust in the gathering falls: %d" % worker.trust)
	_check(remembers(worker, "accepted the gathering's help"), "it remembers accepting help while another got more")
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
	_check(levelling_reads.has("the gathering plays favourites") or levelling_reads.has("everyone's work deserves its due"), "the egalitarian family sees favouritism: %s" % str(levelling_reads))
	_check(climbing_reads.has("honour goes to those who seek it"), "the ambitious, hierarchical family sees how honour is won: %s" % str(climbing_reads))
	_check(levelling.trust < climbing.trust, "and trusts the gathering less (%d against %d)" % [levelling.trust, climbing.trust])
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
	a.long_days = true
	a.long_weeks_this_month = 2
	a.civic_acts = 2
	a.inspired_by = TownSocial.RECOGNITION_CRAFT
	a.inspired_until = 400
	city.social.adjust_trust(a, 0.5, "promise kept")
	city.social.record_policy()
	var loaded: City = GameState.restore_city(GameState.capture_city(city))
	var b: Household = loaded.households[0]
	_check(loaded.social.enabled and bool(loaded.social.norms[TownSocial.NORM_CLAIMS]["promoted"]), "a loaded town keeps the social model and its norms")
	_check(b.personality == a.personality and b.value_strengths == a.value_strengths, "and each household's character")
	_check(b.ties.size() == a.ties.size() and b.memories.size() == a.memories.size(), "and its ties and memories")
	_check(b.long_days and b.long_weeks_this_month == 2 and b.civic_acts == 2 and b.inspired_by == TownSocial.RECOGNITION_CRAFT and b.inspired_until == 400, "and its hours, civic acts, and what inspires it")
	_check(loaded.social.trust_by_source == city.social.trust_by_source and loaded.social.policy_signature == city.social.policy_signature, "and the town's record of trust and of the gathering's decisions")

# --- Owner decisions after the first review --------------------------------------------------------

func trust_value(household: Household) -> float:
	return float(household.trust) + household.trust_progress

# Decision 1: industrious and leisurely change how much a family chooses to work, never what a day
# of its work yields (that is checked in culture_values_validation).
func test_diligence_decides_hours_not_output() -> void:
	var city: City = social_city()
	var tireless: Household = blank(city.households[0], {HouseholdCharacter.DILIGENCE: 2})
	var easy: Household = blank(city.households[1], {HouseholdCharacter.DILIGENCE: -2})
	give_holding(city, tireless, Vector2i(28, 4))
	give_holding(city, easy, Vector2i(40, 4))
	var own: ConstructionProject = home_project(city, tireless, Vector2i(30, 20))
	var theirs: ConstructionProject = home_project(city, easy, Vector2i(40, 20))
	city.social.choose_hours(tireless)
	city.social.choose_hours(easy)
	_check(tireless.long_days and tireless.hours_note.contains("glad of the work"), "a tireless family works long days on its own home: %s" % tireless.hours_note)
	_check(not easy.long_days and easy.hours_note.contains("guards its rest"), "a leisure-loving one keeps its usual hours: %s" % easy.hours_note)
	# Long days come out of the family's rest, not its holding's day.
	city.construction.project_add_spare(own, tireless)
	city.construction.project_add_spare(theirs, easy)
	_check(is_zero_approx(float(city.construction.spare_time_today[tireless.id])), "working long days, its holding loses no time")
	_check(is_equal_approx(float(city.construction.spare_time_today[easy.id]), EconomyBalance.SPARE_TIME_SHARE), "keeping its hours, its spare time comes out of its holding's day")
	# The cost is real: weeks of long days weary a family, and a month of them is a month's hardship.
	var rested: int = HouseholdMigration.get_monthly_hardship_points(city, tireless)
	tireless.long_weeks_this_month = EconomyBalance.OVERWORK_WEEKS
	var weary: Dictionary = SocialDecisions.get_hours_desire(city, tireless, own, true)
	_check(FamilyInitiative.get_reasons(weary["terms"], false).has("it is weary"), "after weeks of long days it is weary: %s" % str(weary["terms"]))
	_check(HouseholdMigration.get_monthly_hardship_points(city, tireless) == rested + EconomyBalance.OVERWORK_HARDSHIP_POINTS, "and a month of long days counts as hardship")
	# Close to leaving, even a tireless family keeps its strength.
	tireless.long_weeks_this_month = 0
	tireless.hardship_points = HouseholdMigration.get_departure_threshold(tireless) - 1
	city.social.choose_hours(tireless)
	_check(not tireless.long_days, "close to leaving, it does not wear itself out: %s" % tireless.hours_note)

# A town where a family on a holding can help its kin or an unrelated neighbour build a first home.
func kin_city() -> Dictionary:
	var city: City = social_city()
	var helper: Household = city.households[0]
	give_holding(city, helper, Vector2i(28, 4))
	var kin: Household = city.households[1]
	kin.parent_household_id = helper.id
	city.social.rebuild_neighbours()
	HouseholdMemory.ensure_kin_ties(city, helper)
	return {
		"city": city, "helper": helper, "kin": kin, "other": city.households[2],
		"kin_home": home_project(city, kin, Vector2i(30, 20)),
		"other_home": home_project(city, city.households[2], Vector2i(40, 20)),
	}

# Decision 2: kinship pulls hard on a household's willingness to help; it does not decide for it.
func test_kin_come_first_but_help_stays_voluntary() -> void:
	var set_up: Dictionary = kin_city()
	var city: City = set_up["city"]
	var helper: Household = set_up["helper"]
	var kin_home: ConstructionProject = set_up["kin_home"]
	city.social.choose_help(helper)
	_check(helper.helping_project_id == kin_home.id and helper.social_note.contains("they are kin"), "all else equal, it helps its kin build first: %s" % helper.social_note)
	# Two obligations, one household's labor: a close-knit family helps kin over an old friend, and says
	# what it passed over.
	HouseholdMemory.touch_tie(city, helper, set_up["other"], 3, "old friends")
	helper.value_strengths["close_knit"] = 3
	city.social.choose_help(helper)
	_check(helper.helping_project_id == kin_home.id and helper.social_note.contains("would also have helped"), "torn between kin and an old friend, it helps its kin: %s" % helper.social_note)
	# A grievance between relatives outweighs kinship.
	set_up = kin_city()
	city = set_up["city"]
	helper = set_up["helper"]
	HouseholdMemory.touch_tie(city, helper, set_up["kin"], -3, "took our tools", 0, "took our tools")
	city.social.choose_help(helper)
	_check(helper.helping_project_id != (set_up["kin_home"] as ConstructionProject).id, "with a grievance between them, it does not help its kin: %s" % helper.social_note)
	# Its own survival comes first.
	set_up = kin_city()
	city = set_up["city"]
	helper = set_up["helper"]
	helper.hardship_points = HouseholdMigration.get_departure_threshold(helper) - 1
	city.social.choose_help(helper)
	_check(helper.helping_project_id == -1 and helper.social_note.contains("close to having to leave"), "close to leaving, it keeps to its own work, kin or not: %s" % helper.social_note)
	# Help given again and again without return wears thin, if more slowly with kin.
	set_up = kin_city()
	city = set_up["city"]
	helper = set_up["helper"]
	HouseholdMemory.touch_tie(city, helper, set_up["kin"], 0, "", -5)
	var desire: Dictionary = SocialDecisions.get_help_desire(city, helper, set_up["kin_home"], set_up["kin"])
	_check(FamilyInitiative.get_reasons(desire["terms"], false).any(func(r: String) -> bool: return r.contains("without return")), "helping kin who never return it weighs against helping again: %s" % str(desire["terms"]))
	# A family with no labor to spare (no holding: it builds full days on whatever site needs it)
	# chooses nothing.
	var free: Household = city.households[3]
	city.social.choose_help(free)
	_check(free.helping_project_id == -1, "a family without a holding gives no spare time")

# Decision 3: recognition comes in kinds, and each household judges an honour by what it prizes.
func test_recognition_kinds_read_by_convictions() -> void:
	var city: City = social_city()
	var farmer: Household = city.households[0]
	var farm: Building = give_holding(city, farmer, Vector2i(28, 4))
	farm.maintenance_level = 100
	farmer.improve_decision_day = 5
	city.add_building(Building.new(-1, "house", Vector2i(30, 20), city.construction.get_size("house")), farmer)
	var striver: Household = blank(city.households[1], {HouseholdCharacter.AMBITION: 2, HouseholdCharacter.DILIGENCE: 2}, {"private_holdings": 2})
	var levelling: Household = blank(city.households[2], {}, {"communal_labor": 3, "egalitarian": 2})
	levelling.help_given = 4
	_check(city.social.is_prosperous(farmer), "the farmer is already prosperous")
	var striver_trust: float = trust_value(striver)
	city.social.recognize(farmer, TownSocial.RECOGNITION_ACHIEVEMENT)
	_check(lessons_of(striver, "honour_fair").has("building up a holding is honoured here") and trust_value(striver) > striver_trust, "a family that prizes a well-built holding finds the honour deserved: %s" % striver.social_note)
	_check(striver.inspired_by == TownSocial.RECOGNITION_ACHIEVEMENT, "and, ambitious, wants to match it")
	_check(not lessons_of(levelling, "honour_unfair").is_empty() and levelling.social_note.contains("already prosperous"), "one that prizes service questions an honour for the already prosperous: %s" % levelling.social_note)
	_check(lessons_of(levelling, "honour_unfair") != lessons_of(striver, "honour_fair"), "the same honour, read two ways")
	# Inspired, the striver weighs improving its own hand work more.
	city.add_building(Building.new(-1, "forager_garden", Vector2i(40, 4), city.construction.get_size("forager_garden")), striver)
	var improve: Dictionary = FamilyInitiative.get_improve_desire(city, striver, "farm")
	_check(FamilyInitiative.get_reasons(improve["terms"], true, 12).any(func(r: String) -> bool: return r.contains("would match")), "the honour moves it to improve its own work: %s" % str(improve["terms"]))
	# The same family honoured for service it never gave: now the one who served is overlooked.
	var trust_before: float = trust_value(levelling)
	city.social.recognize(farmer, TownSocial.RECOGNITION_SERVICE)
	_check(trust_value(levelling) < trust_before - 0.5 and levelling.social_note.contains("Resents"), "the family that served resents an honour for service to a family that gave none: %s" % levelling.social_note)
	# A deserved honour for service, judged by a family that prizes it.
	var server: Household = blank(city.households[3], {}, {"mutual_aid": 2})
	server.help_given = 5
	var judged: Dictionary = city.social.judge_recognition(levelling, server, TownSocial.RECOGNITION_SERVICE, city.social.get_middle_merit(TownSocial.RECOGNITION_SERVICE), false, true, "test")
	_check(float(judged["score"]) >= TownSocial.HONOUR_FAIR_AT, "a family that prizes service finds an honour for real service deserved: %s" % str(judged["terms"]))

# Required refinement: trust grows from more than kept promises, and each family judges by its own
# convictions; no single act of the player's earns everyone's trust.
func test_trust_has_positive_sources_judged_by_conviction() -> void:
	var city: City = social_city()
	var builder: Household = blank(city.households[0], {}, {"communal_labor": 2})
	var loner: Household = blank(city.households[1], {}, {"self_governing": 3})
	var orderly: Household = blank(city.households[2], {}, {"lawful": 2})
	var store: ConstructionProject = city.construction.request_building(Building.BUILDING_STOREHOUSE, Vector2i(34, 24))
	city.social.record_contribution(builder, store)
	city.social.record_contribution(loner, store)
	var before: Array[float] = [trust_value(builder), trust_value(loner), trust_value(orderly)]
	city.social.on_project_finished(store)
	_check(trust_value(builder) > before[0], "a family that helped build the storehouse trusts what the town does together more")
	_check(trust_value(loner) - before[1] < trust_value(builder) - before[0], "a self-governing family that worked on it, less so")
	_check(trust_value(orderly) == before[2], "a family that neither built it nor prizes shared work is unmoved")
	# Steady decisions reassure a family that values order; a gathering that keeps changing its mind
	# loses it.
	city.social.set_promoted(TownSocial.NORM_HELP, true)
	city.social.record_policy()
	var steady: float = trust_value(orderly)
	var loner_steady: float = trust_value(loner)
	city.social.review_month()
	_check(trust_value(orderly) > steady, "steady decisions reassure a lawful family")
	_check(trust_value(loner) == loner_steady, "and leave a free-minded one unmoved")
	for _i in range(TownSocial.MANY_CHANGES):
		city.construction.day += FamilyInitiative.INTERVAL_DAYS
		city.social.incentive = not city.social.incentive
		city.social.record_policy()
	var settled: float = trust_value(orderly)
	city.social.review_month()
	_check(trust_value(orderly) < settled, "decisions that keep changing cost its trust")
	# A promise broken: first claim on the stores promised, and the stores still would not fund it.
	var promised: Household = city.households[3]
	promised.first_claim_until = city.construction.day + 30
	var promised_before: float = trust_value(promised)
	city.social.on_held_back(promised)
	_check(trust_value(promised) < promised_before - 0.5, "a broken promise costs trust")
	# A dispute settled under the custom: legitimate to the lawful family, pressed on the free-minded one.
	city.social.set_promoted(TownSocial.NORM_CLAIMS, true)
	var lawful_before: float = trust_value(orderly)
	var loner_before: float = trust_value(loner)
	city.social.judge_settlement([orderly, loner] as Array[Household])
	_check(trust_value(orderly) > lawful_before and trust_value(loner) < loner_before, "the same settlement, legitimate to one family and imposed on the other")
	_check(float(city.social.trust_by_source.get("shared work finished", 0.0)) > 0.0 and float(city.social.trust_by_source.get("steady decisions", 0.0)) > 0.0, "and the town records where trust came from: %s" % str(city.social.trust_by_source))

# Decision 4: before institutions, the gathering of households decides; families that others regard
# carry its appeals further with those on good terms with them.
func test_respected_voices_carry_appeals() -> void:
	var city: City = social_city()
	var elder: Household = city.households[0]
	elder.standing = TownSocial.VOICE_STANDING
	var friend: Household = city.households[1]
	var rival: Household = city.households[2]
	var plain: Household = city.households[3]
	HouseholdMemory.touch_tie(city, friend, elder, 2, "helped us build")
	HouseholdMemory.touch_tie(city, rival, elder, -2, "old quarrel")
	var voices: Array[Household] = city.social.get_respected_voices()
	_check(voices.size() == 1 and voices[0] == elder, "the family of highest standing is the gathering's respected voice")
	var for_friend: Dictionary = FamilyInitiative.get_receptiveness(friend, city)
	var for_plain: Dictionary = FamilyInitiative.get_receptiveness(plain, city)
	var for_rival: Dictionary = FamilyInitiative.get_receptiveness(rival, city)
	_check(float(for_friend["factor"]) > float(for_plain["factor"]) and float(for_plain["factor"]) > float(for_rival["factor"]), "an appeal carries further with the respected family's friends than with its rivals")
	_check(str(for_friend["note"]).contains("families it respects speak for it"), "and the friend says so: %s" % str(for_friend["note"]))
	_check(city.social.get_sidebar_lines().any(func(line: String) -> bool: return line.contains("voices heeded")), "the sidebar names the voices the town heeds")
	# Standing is earned, not granted: weeks of help raise it.
	var helper: Household = city.households[4]
	var project: ConstructionProject = home_project(city, plain, Vector2i(30, 20))
	for _week in range(8):
		city.social.record_help_day(helper, project)
		city.social.settle_help_week()
	_check(helper.standing >= TownSocial.VOICE_STANDING and city.social.get_respected_voices().has(helper), "a family that keeps helping becomes a voice the gathering heeds")

# --- Contested land (owner verification request) ---------------------------------------------------

# A town where families may open work only on a marked patch that holds one garden.
func scarce_land_city() -> City:
	var city: City = social_city()
	city.influence.enabled = true
	var size: Vector2i = city.construction.get_size("forager_garden")
	city.influence.mark_work_ground(Vector2i(20, 2), Vector2i(20 + size.x - 1, 2 + size.y - 1))
	return city

func food_first() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for activity: String in FamilyInitiative.ACTIVITIES:
		choices.append({"activity": activity, "score": 5.0 if activity == TownInfluence.ACTIVITY_FOOD else 0.0, "terms": []})
	return choices

func garden_claim(city: City, household: Household, origin: Vector2i = Vector2i(20, 2)) -> ConstructionProject:
	return city.construction.request_building("forager_garden", origin, ConstructionProject.REQUESTED_BY_HOUSEHOLD, household.id, household.id)

# 1. Two households want the same field: the one patch of open land, which one has just claimed.
func test_land_same_field() -> void:
	var city: City = scarce_land_city()
	var first: Household = blank(city.households[0], {HouseholdCharacter.EMPATHY: 1}, {"close_knit": 3, "sharing": 2})
	var second: Household = blank(city.households[1], {HouseholdCharacter.ASSERTIVENESS: 1})
	second.parent_household_id = first.id
	city.social.rebuild_neighbours()
	HouseholdMemory.ensure_kin_ties(city, first)
	HouseholdMemory.ensure_kin_ties(city, second)
	var claim: ConstructionProject = garden_claim(city, first)
	_check(claim != null, "the first family claims the patch")
	if claim == null:
		return
	_check(FamilyInitiative.contest_for_land(city, second, food_first()), "its kin asks for the patch, and the first family makes room: %s / %s" % [second.social_note, first.social_note])
	_check(claim.claimant_household_id == second.id and claim.requester_household_id == second.id, "the claim is now the second family's")
	_check(int(HouseholdMemory.get_tie(second, first.id)["owes"]) >= 2 and first.civic_acts == 1, "which owes the first for it, and the first has kept the peace")
	_check(not FamilyInitiative.contest_for_land(city, first, food_first()), "the first family does not then ask for it back while the matter rests")
	# A family that respects claims does not ask.
	city = scarce_land_city()
	var holder: Household = blank(city.households[0], {}, {"landholding": 2})
	var polite: Household = blank(city.households[1], {}, {"respect_for_holdings": 2})
	garden_claim(city, holder)
	_check(not FamilyInitiative.contest_for_land(city, polite, food_first()) and polite.social_note.contains("Leaves"), "a family that respects claims leaves the claim be: %s" % polite.social_note)
	_check(city.social.land_not_pressed == 1, "and the town counts a claim respected")
	# A forceful family asks; a family that sets store by land refuses; with no custom, a grievance.
	city = scarce_land_city()
	var keeper: Household = blank(city.households[0], {}, {"landholding": 2, "acquisitive": 2})
	var pushy: Household = blank(city.households[1], {HouseholdCharacter.ASSERTIVENESS: 2})
	garden_claim(city, keeper)
	var acceptance: float = float(city.social.norms[TownSocial.NORM_CLAIMS]["acceptance"])
	_check(not FamilyInitiative.contest_for_land(city, pushy, food_first()) and keeper.social_note.contains("Keeps"), "the holder keeps its claim: %s" % keeper.social_note)
	_check(str(HouseholdMemory.get_tie(pushy, keeper.id).get("grievance", "")) != "" and city.social.dispute_pressure == 1, "and the forceful family holds a grievance: %s" % str(HouseholdMemory.get_tie(pushy, keeper.id)))
	_check(float(city.social.norms[TownSocial.NORM_CLAIMS]["acceptance"]) < acceptance, "a quarrel over land weakens the town's respect for claims")
	# Where respecting claims is the custom, the same families settle it without a grievance.
	city = scarce_land_city()
	keeper = blank(city.households[0], {}, {"landholding": 2, "acquisitive": 2})
	pushy = blank(city.households[1], {HouseholdCharacter.ASSERTIVENESS: 2})
	var claims: Dictionary = city.social.norms[TownSocial.NORM_CLAIMS]
	claims["acceptance"] = 0.9
	claims["status"] = TownSocial.STATUS_CUSTOM
	garden_claim(city, keeper)
	FamilyInitiative.contest_for_land(city, pushy, food_first())
	_check(str(HouseholdMemory.get_tie(pushy, keeper.id).get("grievance", "")) == "" and city.social.dispute_pressure == 0, "under the custom, the forceful family accepts the prior claim: %s" % pushy.social_note)

# 2. A useful path crosses an established field. Town routes slip along field edges where they can
# (town_construction_validation), so the path is laid straight through the field's middle row, as a
# family's daily walk, and the town's own trampling count and weekly disputes do the rest.
func test_land_path_across_holding() -> void:
	var city: City = social_city()
	var owner: Household = blank(city.households[0], {HouseholdCharacter.ASSERTIVENESS: 2}, {"respect_for_holdings": 2})
	var crosser: Household = blank(city.households[1], {}, {"respect_for_holdings": 2, "honesty": 2})
	var field: Building = give_holding(city, owner, Vector2i(20, 20))
	give_holding(city, crosser, Vector2i(40, 4))
	city.resources["wood"] = 100
	var through: Array = []
	for x in range(39, 51):
		through.append(Vector2i(x, 43))
	for _day in range(16):
		city.logistics.ensure_grid()
		city.logistics.add_traffic(through, 2.0, crosser.id)
		city.tick()
	var crossed: bool = city.social.disputes.any(func(d: Dictionary) -> bool: return int(d["victim"]) == owner.id and int(d["crosser"]) == crosser.id)
	_check(crossed, "the family walking to work across the river tramples the field, and its owner notices: %s" % owner.social_note)
	_check(city.social.disputes_raised >= 1 and city.social.disputes_settled >= 1, "the owner presses its claim, and the crosser, who respects holdings, makes amends: %s / %s" % [owner.social_note, crosser.social_note])
	_check((HouseholdMemory.get_tie(owner, crosser.id).get("reasons", []) as Array).has("made amends for crossing our field"), "the owner's tie says so")
	_check(crosser.civic_acts >= 1 and int(city.social.norms[TownSocial.NORM_CLAIMS]["followed"]) >= 1, "the crosser has kept the peace, and the town has seen a claim respected")
	_check(field.assigned_household_id == owner.id, "the field stays its owner's")

# 3. A new household needs land a neighbour already works.
func test_land_newcomer_needs_land_in_use() -> void:
	var city: City = scarce_land_city()
	var size: Vector2i = city.construction.get_size("forager_garden")
	var settled: Household = blank(city.households[0], {}, {"landholding": 1})
	var garden: Building = Building.new(-1, "forager_garden", Vector2i(20, 2), size)
	city.construction.set_occupied(TownLogistics.footprint(garden.tile, size), true)
	city.add_building(garden, settled)
	var newcomer: Household = blank(city.households[1], {HouseholdCharacter.ASSERTIVENESS: 2}, {"landholding": 1})
	_check(not FamilyInitiative.contest_for_land(city, newcomer, food_first()), "the settled family will not give up the only work it has")
	_check(settled.social_note.contains("nowhere else to work"), "and says why: %s" % settled.social_note)
	_check(city.social.dispute_pressure == 1, "the newcomer, with no land, holds a grievance: pressure the player can see: %s" % newcomer.social_note)
	# The player answers by opening more ground; the newcomer takes it up without a quarrel.
	city.influence.mark_work_ground(Vector2i(30, 2), Vector2i(30 + size.x - 1, 2 + size.y - 1))
	city.construction.day += FamilyInitiative.INTERVAL_DAYS
	var project: ConstructionProject = FamilyInitiative.take_up_work(city, newcomer)
	_check(project != null and project.claimant_household_id == newcomer.id, "with ground opened, the newcomer takes up work: %s" % newcomer.initiative_note)
	_check(city.social.land_contests == 1, "and no further contest arises")
	# A deeply generous relative makes room even so, and its kin takes over the garden.
	city = scarce_land_city()
	var giver: Household = blank(city.households[0], {HouseholdCharacter.EMPATHY: 2}, {"close_knit": 3, "sharing": 3, "mutual_aid": 2})
	var garden2: Building = Building.new(-1, "forager_garden", Vector2i(20, 2), size)
	city.construction.set_occupied(TownLogistics.footprint(garden2.tile, size), true)
	city.add_building(garden2, giver)
	var child: Household = blank(city.households[1], {HouseholdCharacter.ASSERTIVENESS: 2}, {"landholding": 1})
	child.parent_household_id = giver.id
	city.social.rebuild_neighbours()
	HouseholdMemory.ensure_kin_ties(city, giver)
	HouseholdMemory.ensure_kin_ties(city, child)
	_check(FamilyInitiative.contest_for_land(city, child, food_first()), "a generous parent household gives its garden to its child's: %s" % giver.social_note)
	_check(garden2.assigned_household_id == child.id and FamilyInitiative.get_holding(city, giver) == null, "the garden changes hands")
	_check(lessons_of(giver, "land_yielded").size() >= 1 and lessons_of(child, "land_given").size() >= 1, "and both draw their lessons")

# 4. A communal designation conflicts with a household's claim: the gathering wants the land for a
# storehouse.
func test_land_communal_designation() -> void:
	var city: City = social_city()
	var willing: Household = blank(city.households[0], {}, {"deferential": 2, "common_stores": 2, "communal_labor": 2})
	var claim: ConstructionProject = garden_claim(city, willing)
	var given: Dictionary = city.social.ask_for_land(claim, Building.BUILDING_STOREHOUSE)
	var store: ConstructionProject = given["project"]
	_check(given["outcome"] == "yielded" and store != null and store.building_type == Building.BUILDING_STOREHOUSE, "a deferential family gives up its claim for the storehouse: %s" % willing.social_note)
	_check(willing.first_claim_until > city.construction.day and willing.civic_acts == 1, "and is given first claim on the stores for new work")
	# A family that holds its land dear refuses; asked, not forced, it sees its say kept.
	var proud: Household = blank(city.households[1], {}, {"self_governing": 2, "landholding": 2})
	var proud_claim: ConstructionProject = garden_claim(city, proud, Vector2i(32, 2))
	var asked_trust: float = trust_value(proud)
	var refused: Dictionary = city.social.ask_for_land(proud_claim, Building.BUILDING_STOREHOUSE)
	_check(refused["outcome"] == "refused" and city.construction.get_project(proud_claim.id) != null, "a self-governing family that sets store by land refuses, and its claim stands: %s" % proud.social_note)
	_check(trust_value(proud) > asked_trust, "and it trusts the gathering a little more for being asked")
	# Required anyway: the land is taken, and families who hold claims dear see an arbitrary requirement.
	var holding_minded: Household = blank(city.households[2], {}, {"private_holdings": 2})
	var deferent: Household = blank(city.households[3], {}, {"deferential": 2})
	var before: Array[float] = [trust_value(proud), trust_value(holding_minded), trust_value(deferent)]
	var taken: Dictionary = city.social.ask_for_land(proud_claim, Building.BUILDING_STOREHOUSE, true)
	_check(taken["outcome"] == "taken" and city.construction.get_project(proud_claim.id) == null, "required, the land is taken")
	_check(trust_value(proud) <= before[0] - 1.0 and lessons_of(proud, "land_taken").has("the gathering takes what it wants"), "the family's trust falls hard: %s" % str(lessons_of(proud, "land_taken")))
	_check(trust_value(holding_minded) < before[1] and trust_value(deferent) == before[2], "a family that holds holdings dear trusts the gathering less; a deferential one does not")

# Values do not oscillate between opposites: evidence for one first wears down the other.
func test_opposite_values_do_not_both_grow() -> void:
	var city: City = social_city()
	var household: Household = blank(city.households[0], {}, {"egalitarian": 2})
	HouseholdMemory.add_evidence(city, household, "hierarchical", HouseholdMemory.EVIDENCE_TO_CHANGE, "An honour it admired")
	_check(HouseholdCharacter.get_strength(household, "hierarchical") == 0 and HouseholdCharacter.get_strength(household, "egalitarian") == 1, "evidence for hierarchy weakens its egalitarian conviction instead of growing a second, opposite one")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
