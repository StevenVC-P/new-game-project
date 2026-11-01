extends SceneTree

# Emergent recognition and the Speaker of the Gathering (docs/EMERGENT_RECOGNITION_AND_LEADERSHIP.md):
# an achievement is noticed once, admired by some and resented by others; influence comes from
# several sources; no Speaker before Village; families judge the appointment; the Speaker leads its
# followers one way and its opponents the other; it decides first claim by its own values, within
# the Elder's rules, and is judged for it; it urges settlement through its ties; replacing it
# plays out by the circumstances; the office falls vacant when its family leaves; off and saved.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_an_achievement_divides_the_town_once()
	test_influence_has_many_sources()
	test_appointment_from_village_judged_by_families()
	test_speaker_leads_both_ways()
	test_speaker_decides_first_claim_by_its_values()
	test_speaker_urges_settlement()
	test_replacement_follows_circumstances()
	test_vacancy_off_and_saved()
	if failure_count > 0:
		push_error("Town regard validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Town regard validation passed.")
	quit()

func profile(calling: String) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var preset: Dictionary = {
		CultureValues.CATEGORY_CALLING: [calling],
		CultureValues.CATEGORY_WORK_ETHIC: ["steady"],
		CultureValues.CATEGORY_KIN: ["fathers_line"],
		CultureValues.CATEGORY_WEALTH: ["sharing"],
		CultureValues.CATEGORY_TRADE_COIN: ["fair_dealers"],
		CultureValues.CATEGORY_AUTHORITY: ["lawful"],
		CultureValues.CATEGORY_CHANGE_RISK: ["rooted"],
		CultureValues.CATEGORY_CRAFT_LEARNING: ["hands_on"],
		CultureValues.CATEGORY_CONFLICT: ["pragmatic"],
		CultureValues.CATEGORY_FAITH: ["worldly"],
		CultureValues.CATEGORY_COMMUNITY: ["welcoming"],
		CultureValues.CATEGORY_HOME_PLACE: ["monument_makers"],
	}
	return CultureValues.make_random_profile(rng, preset)

# A town where families lead and the social model is on; every family of the soil, with a neutral
# temperament and no strong convictions, all knowing one another.
func town(village: bool = true) -> City:
	var city: City = ConstructionTest.make_city()
	city.influence.enabled = true
	city.social.set_enabled(true)
	city.resources["food"] = 5000
	city.resources["wood"] = 500
	city.resources["tools"] = 200
	for household: Household in city.households:
		household.set_values(profile("soil"))
		for axis: String in HouseholdCharacter.AXES:
			household.personality[axis] = 0
		household.value_strengths.clear()
		for value_id: String in HouseholdCharacter.get_held_values(household):
			household.value_strengths[value_id] = 0
	for household: Household in city.households:
		for other: Household in city.households:
			if other != household:
				HouseholdMemory.touch_tie(city, household, other, 0, "")
	if village:
		city.settlement.stage = SettlementStage.VILLAGE
	return city

func give(city: City, household: Household, type: String, origin: Vector2i) -> Building:
	var building: Building = Building.new(-1, type, origin, city.construction.get_size(type))
	city.add_building(building, household)
	return building

func set_tie(city: City, from: Household, to: Household, disposition: int) -> void:
	var tie: Dictionary = HouseholdMemory.touch_tie(city, from, to, 0, "")
	tie["disposition"] = disposition

func values(household: Household, strengths: Dictionary) -> void:
	for value_id: String in strengths.keys():
		HouseholdCharacter.set_strength(household, value_id, int(strengths[value_id]))

# 1. A family's craft is noticed when it achieves it: a craft-minded family on good terms admires
# it, a service-minded, levelling family whose own service goes unnoticed resents it; and it is not
# noticed again until it achieves more.
func test_an_achievement_divides_the_town_once() -> void:
	var city: City = town(false)
	var smith: Household = city.households[0]
	var admirer: Household = city.households[1]
	var critic: Household = city.households[2]
	smith.set_values(profile("forge_bench"))
	give(city, smith, "toolmaker", Vector2i(30, 20))
	smith.standing = 2
	values(admirer, {"perfectionist": 2, "keepers_of_craft": 2})
	set_tie(city, admirer, smith, 2)
	values(critic, {"mutual_aid": 2, "expedient": 2, "egalitarian": 3})
	critic.personality[HouseholdCharacter.AMBITION] = 2
	critic.help_given = 6
	set_tie(city, critic, smith, -3)
	TownRegard.advance_month(city)
	var social: TownSocial = city.social
	_check(HouseholdMemory.get_disposition(admirer, smith.id) == 3 and HouseholdMemory.get_tie(admirer, smith.id)["reasons"].has("admires its craftsmanship"), "the craft-minded family admires the toolmaker's craft: %s" % admirer.social_note)
	_check(HouseholdMemory.get_tie(critic, smith.id)["reasons"].has("thinks itself above us"), "the family whose own service goes unnoticed resents it: %s" % critic.social_note)
	_check(social.divided_notices >= 1, "the same achievement divides the town")
	var notices: int = social.notices
	var standing: float = float(smith.standing) + smith.standing_progress
	TownRegard.advance_month(city)
	_check(social.notices == notices and is_equal_approx(float(smith.standing) + smith.standing_progress, standing), "nothing new, nothing noticed again (%d notices)" % social.notices)
	# Service is noticed at two weeks' help, then at each doubling.
	var helper: Household = city.households[3]
	helper.help_given = 2
	TownRegard.advance_month(city)
	_check(float(helper.noticed_merit.get(TownSocial.RECOGNITION_SERVICE, 0.0)) == 2.0, "service noticed at its first two weeks")
	helper.help_given = 3
	var before: int = social.notices
	TownRegard.advance_month(city)
	_check(social.notices == before, "one more week is not a new achievement")
	helper.help_given = 4
	TownRegard.advance_month(city)
	_check(social.notices > before, "twice as much is")

# 2. Influence comes from regard, following, weight in the town's work and contribution; a family
# can rise on any of them, and the three most influential are the candidates.
func test_influence_has_many_sources() -> void:
	var city: City = town()
	var regarded: Household = city.households[0]
	var followed: Household = city.households[1]
	var needed: Household = city.households[2]
	regarded.standing = 3
	for other: Household in city.households:
		if other != followed:
			set_tie(city, other, followed, 1)
	needed.set_values(profile("forge_bench"))
	give(city, needed, "toolmaker", Vector2i(30, 20))
	needed.help_given = 20
	var ranked: Array = TownRegard.get_ranked(city)
	var top: Array = ranked.map(func(entry: Dictionary) -> int: return (entry["household"] as Household).id)
	_check(top.has(regarded.id) and top.has(followed.id) and top.has(needed.id), "regard, a following, and the town's only toolmaker each bring influence (%s)" % str(top))
	var parts: Dictionary = TownRegard.get_influence(city, needed)
	_check(float(parts["weight"]) >= 2.0 and float(parts["contribution"]) == TownRegard.CONTRIBUTION_MAX, "its influence shows its parts: %s" % TownRegard.describe_influence(parts))
	var voices: Array[Household] = city.social.get_respected_voices()
	_check(not voices.is_empty() and voices.all(func(voice: Household) -> bool: return top.has(voice.id)), "the gathering's voices are the most influential (%d)" % voices.size())

# 3. No Speaker before Village. At Village the Elder appoints one; families who like it and defer
# welcome it, families at odds with it who govern themselves doubt it; an ambitious candidate passed
# over minds.
func test_appointment_from_village_judged_by_families() -> void:
	var city: City = town(false)
	var chosen: Household = city.households[0]
	_check(not TownRegard.appoint(city, chosen) and city.social.speaker_id < 0, "no Speaker before Village")
	city.settlement.stage = SettlementStage.VILLAGE
	var friend: Household = city.households[1]
	var foe: Household = city.households[2]
	set_tie(city, friend, chosen, 3)
	values(friend, {"deferential": 2})
	set_tie(city, foe, chosen, -3)
	values(foe, {"self_governing": 3})
	var friend_trust: float = friend.trust + friend.trust_progress
	var foe_trust: float = foe.trust + foe.trust_progress
	_check(TownRegard.appoint(city, chosen) and city.social.speaker_id == chosen.id, "at Village, the Elder appoints a Speaker")
	_check(friend.trust + friend.trust_progress > friend_trust and foe.trust + foe.trust_progress < foe_trust, "its friend welcomes it, its foe doubts it: %s | %s" % [friend.social_note, foe.social_note])
	_check(float(city.social.speaker_verdicts[str(friend.id)]) >= TownRegard.SUPPORT_AT and float(city.social.speaker_verdicts[str(foe.id)]) <= TownRegard.DOUBT_AT, "and each family's view is kept")

# 4. The Speaker sways how families take the community's priority: those who back it lean its way,
# those who oppose it lean the other.
func test_speaker_leads_both_ways() -> void:
	var city: City = town()
	city.influence.set_priority(CommunityPriority.FOOD)
	var speaker: Household = city.households[0]
	var follower: Household = city.households[1]
	var opponent: Household = city.households[2]
	set_tie(city, follower, speaker, 2)
	set_tie(city, opponent, speaker, -2)
	var follower_before: float = float(CommunityPriority.get_view(city, follower, CommunityPriority.FOOD)["score"])
	var opponent_before: float = float(CommunityPriority.get_view(city, opponent, CommunityPriority.FOOD)["score"])
	TownRegard.appoint(city, speaker)
	city.social.speaker_stance = CommunityPriority.SUPPORTS
	var follower_after: float = float(CommunityPriority.get_view(city, follower, CommunityPriority.FOOD)["score"])
	var opponent_after: float = float(CommunityPriority.get_view(city, opponent, CommunityPriority.FOOD)["score"])
	_check(follower_after > follower_before and opponent_after < opponent_before, "the Speaker backing food: its follower %.2f -> %.2f, its opponent %.2f -> %.2f" % [follower_before, follower_after, opponent_before, opponent_after])
	var receptive: Dictionary = FamilyInitiative.get_receptiveness(follower, city, CommunityPriority.KIND_DIRECTING)
	_check(str(receptive["note"]).contains("Speaker"), "and its follower heeds the appeal more readily: %s" % receptive["note"])
	city.social.speaker_stance = CommunityPriority.OPPOSES
	_check(float(CommunityPriority.get_view(city, follower, CommunityPriority.FOOD)["score"]) < follower_before, "speaking against it, the Speaker turns its follower against it")

# 5. Every season the Speaker decides first claim on the stores by its own values: a charitable one
# gives it to families in hardship; an acquisitive one to its own kin and friends, which families
# overlooked hold against the Speaker. First claim it gives stays within the Elder's rule.
func test_speaker_decides_first_claim_by_its_values() -> void:
	var city: City = town()
	var speaker: Household = city.households[0]
	var needy: Household = city.households[1]
	values(speaker, {"charitable": 3})
	speaker.personality[HouseholdCharacter.EMPATHY] = 2
	needy.hardship_points = HouseholdMigration.get_departure_threshold(needy)
	TownRegard.appoint(city, speaker)
	TownRegard.speaker_acts(city)
	_check(city.social.speaker_policy == TownRegard.POLICY_NEEDY and needy.first_claim_until > city.construction.day, "a charitable Speaker gives first claim to the family in hardship: %s" % city.social.speaker_policy_note)
	var greedy_town: City = town()
	var greedy: Household = greedy_town.households[0]
	var friend: Household = greedy_town.households[1]
	var overlooked: Household = greedy_town.households[2]
	values(greedy, {"acquisitive": 3, "private_holdings": 2})
	greedy.personality[HouseholdCharacter.AMBITION] = 2
	set_tie(greedy_town, greedy, friend, 3)
	values(overlooked, {"egalitarian": 3})
	overlooked.help_given = 6
	TownRegard.appoint(greedy_town, greedy)
	TownRegard.speaker_acts(greedy_town)
	_check(greedy_town.social.speaker_policy == TownRegard.POLICY_OWN and friend.first_claim_until > greedy_town.construction.day, "an acquisitive Speaker favours its friends: %s" % greedy_town.social.speaker_policy_note)
	_check(HouseholdMemory.get_tie(overlooked, greedy.id).get("reasons", []).has("the Speaker plays favourites"), "and the family overlooked holds it against the Speaker")
	greedy_town.influence.store_rule = TownInfluence.RULE_PRIORITIES
	greedy_town.influence.set_encouraged(TownInfluence.ACTIVITY_FOOD, true)
	_check(greedy_town.influence.get_funding_block({"wood": 4}, [TownInfluence.ACTIVITY_TOOLS] as Array[String], friend) != "", "first claim from the Speaker does not pass the Elder's priorities rule")

# 6. In a dispute the Speaker urges amends: a crossing family that backs it is moved, one that
# opposes it bristles.
func test_speaker_urges_settlement() -> void:
	var city: City = town()
	var speaker: Household = city.households[0]
	var crosser: Household = city.households[1]
	var victim: Household = city.households[2]
	TownRegard.appoint(city, speaker)
	set_tie(city, crosser, speaker, 2)
	var terms: Array = []
	_check(TownRegard.add_mediation(city, crosser, victim, terms) and FamilyInitiative.sum(terms) > 0.0, "a Speaker the crossing family backs moves it toward amends")
	set_tie(city, crosser, speaker, -2)
	terms = []
	TownRegard.add_mediation(city, crosser, victim, terms)
	_check(FamilyInitiative.sum(terms) < 0.0, "one it opposes, away from them")
	terms = []
	_check(not TownRegard.add_mediation(city, speaker, victim, terms), "the Speaker does not mediate its own quarrel")

# 7. Replacing a Speaker: an ambitious, well-regarded one with families behind it resents it; one
# that never sought the office and had lost the town's confidence steps down; families for whom
# things went badly under it approve.
func test_replacement_follows_circumstances() -> void:
	var city: City = town()
	var proud: Household = city.households[0]
	var successor: Household = city.households[1]
	proud.personality[HouseholdCharacter.AMBITION] = 2
	proud.personality[HouseholdCharacter.ASSERTIVENESS] = 2
	proud.standing = 2
	for other: Household in city.households.slice(2, 5):
		set_tie(city, other, proud, 2)
	TownRegard.appoint(city, proud)
	TownRegard.appoint(city, successor)
	_check(HouseholdMemory.get_disposition(proud, successor.id) < 0 and (city.social.former_speaker_responses.has("resentful") or city.social.former_speaker_responses.has("aggrieved")), "a proud Speaker with a following resents its removal: %s" % proud.social_note)
	var other_town: City = town()
	var tired: Household = other_town.households[0]
	var next: Household = other_town.households[1]
	var unhappy: Household = other_town.households[2]
	tired.personality[HouseholdCharacter.AMBITION] = -2
	tired.personality[HouseholdCharacter.ASSERTIVENESS] = -2
	for other: Household in other_town.households.slice(2, 6):
		set_tie(other_town, other, tired, -2)
	TownRegard.appoint(other_town, tired)
	other_town.social.speaker_start_trust[str(unhappy.id)] = 2.0
	other_town.social.speaker_record["favours_resented"] = 3
	TownRegard.appoint(other_town, next)
	_check(other_town.social.former_speaker_responses.has("accepting") and HouseholdMemory.get_disposition(tired, next.id) >= 0, "a Speaker that lost the town's confidence steps down: %s" % tired.social_note)
	_check(other_town.social.removal_approved >= 1, "and families for whom things went badly approve (%d approve, %d oppose)" % [other_town.social.removal_approved, other_town.social.removal_opposed])
	_check(other_town.social.speaker_history.size() == 2 and str(other_town.social.speaker_history[0]["ended"]) == "replaced", "the term is recorded")

# 8. A Speaker's family leaving empties the office; with emergent regard off nothing is noticed and
# the old voices return; it all survives a save.
func test_vacancy_off_and_saved() -> void:
	var city: City = town()
	var speaker: Household = city.households[0]
	TownRegard.appoint(city, speaker)
	city.households.erase(speaker)
	TownRegard.advance_month(city)
	_check(city.social.speaker_id < 0 and city.social.vacancies == 1, "the Speaker's family left: the office is empty")
	var saved: City = town()
	saved.households[0].noticed_merit = {"craft": 3.0}
	TownRegard.appoint(saved, saved.households[1])
	var loaded: City = GameState.restore_city(GameState.capture_city(saved))
	_check(loaded.social.speaker_id == saved.households[1].id and loaded.social.emergent_regard and loaded.get_household_by_id(saved.households[0].id).noticed_merit == {"craft": 3.0}, "the Speaker and what the town has noticed are saved")
	var off: City = town()
	off.social.emergent_regard = false
	off.households[0].help_given = 8
	TownRegard.advance_month(off)
	_check(off.social.notices == 0 and not TownRegard.appoint(off, off.households[0]), "off: nothing noticed, no Speaker")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
