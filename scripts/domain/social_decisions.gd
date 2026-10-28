class_name SocialDecisions
extends RefCounted

# What a household wants in its dealings with others (docs/HOUSEHOLD_SOCIAL_MODEL.md, Sections 6-8):
# helping with someone's construction, sharing in a shortage, pressing or settling a claim. Each
# returns {"score", "terms"} like FamilyInitiative: weighted reasons in plain words, compared with a
# threshold after a bounded unknown. Ability is checked by the caller (TownSocial).
#
# Every term reads the household's profile (personality, value strengths, trust, standing), its tie
# to the other household, and the town's state, so the same rules can later run on a
# representative profile for a group of households.

const HELP_THRESHOLD: float = 1.5
const SHARE_THRESHOLD: float = 1.5
const RAISE_THRESHOLD: float = 1.5
const AMENDS_THRESHOLD: float = 1.5
const NORM_APPEAL_WEIGHT: float = 1.5
const INCENTIVE_WEIGHT: float = 1.25

# --- Helping someone build ------------------------------------------------------------------------

# A household's wish to give its spare time this week to a project: a neighbour's (target set) or a
# communal one (target null).
static func get_help_desire(city: City, household: Household, project: ConstructionProject, target: Household) -> Dictionary:
	var terms: Array = []
	add(terms, -0.5, "it would cost a fifth of its own working day")
	var empathy: int = axis(household, HouseholdCharacter.EMPATHY)
	var sociability: int = axis(household, HouseholdCharacter.SOCIABILITY)
	var diligence: int = axis(household, HouseholdCharacter.DILIGENCE)
	var in_need: bool = target != null and TownSocial.is_in_need(city, target, project)
	if in_need:
		add(terms, 1.0, "they are building their first home" if project.is_home() else "they are in hardship")
	if empathy != 0:
		add(terms, (1.0 if in_need else 0.5) * empathy, ("it is attuned to their need" if in_need else "it notices others' troubles") if empathy > 0 else "it pays little heed to others' troubles")
	if sociability != 0:
		add(terms, 0.5 * sociability, "it enjoys working alongside others" if sociability > 0 else "it keeps to itself")
	if diligence != 0:
		add(terms, 0.5 * diligence, "it is glad of extra work" if diligence > 0 else "it guards its rest")
	add_strength(terms, household, "communal_labor", 0.75, "it values working together")
	add_strength(terms, household, "solitary", -0.75, "it prefers to work alone")
	if target == null:
		add_strength(terms, household, "self_governing", -0.75, "it holds that families should choose their own work")
		add_strength(terms, household, "private_holdings", -0.5, "it puts its own holding first")
		add_strength(terms, household, "deferential", 0.5, "it answers the community's needs")
		if household.trust != 0:
			add(terms, 0.5 * household.trust, "it trusts the leadership" if household.trust > 0 else "it distrusts the leadership")
	else:
		add_strength(terms, household, "mutual_aid", 0.5, "it believes neighbours should help one another")
		add_relationship(terms, household, target, 0.75, 1.5, -2.5)
	add_own_security(city, household, terms, "it cannot spare time from its own work")
	if target != null and in_need:
		add_norm(city, household, TownSocial.NORM_HELP, terms)
	if city.social.incentive:
		add(terms, INCENTIVE_WEIGHT + 0.25 * maxi(0, axis(household, HouseholdCharacter.AMBITION)), "the community gives first claim on the stores to families who help")
	if city.social.helping_honoured_recently() and axis(household, HouseholdCharacter.AMBITION) > 0:
		add(terms, 0.5, "helping is honoured here")
	return {"score": sum(terms), "terms": terms}

# --- Sharing in a shortage ------------------------------------------------------------------------

# A donor's wish to give up part of its ration to a household the shortage may drive away.
static func get_share_desire(city: City, donor: Household, recipient: Household) -> Dictionary:
	var terms: Array = []
	add(terms, 2.0, "they may have to leave")
	var empathy: int = axis(donor, HouseholdCharacter.EMPATHY)
	if empathy != 0:
		add(terms, 1.0 * empathy, "it is attuned to their hardship" if empathy > 0 else "it is little moved by others' hardship")
	add_strength(terms, donor, "charitable", 0.75, "it is charitable")
	add_strength(terms, donor, "sharing", 0.75, "it believes in sharing")
	add_strength(terms, donor, "mutual_aid", 0.5, "it believes neighbours should help one another")
	add_strength(terms, donor, "acquisitive", -0.75, "it holds on to what it has")
	add_strength(terms, donor, "each_to_their_own", -0.75, "it holds that each family fends for itself")
	add_strength(terms, donor, "thrifty", -0.25, "it is thrifty")
	var after: int = TownSocial.get_margin_after_giving(donor)
	if after <= HouseholdMigration.DEPARTURE_WARNING_MARGIN:
		add(terms, -6.0, "it lacks reserves of its own")
	elif after <= 4:
		add(terms, -1.5, "its own margin is thin")
	elif after >= 7:
		add(terms, 0.5, "it can spare it")
	var risk: int = axis(donor, HouseholdCharacter.RISK)
	if risk < 0:
		add(terms, 0.5 * risk, "it keeps a margin against the worst")
	add_relationship(terms, donor, recipient, 0.75, 2.0, -3.0)
	add_norm(city, donor, TownSocial.NORM_HELP, terms)
	if city.social.incentive:
		add(terms, 1.0, "the community gives first claim on the stores to families who share")
	return {"score": sum(terms), "terms": terms}

# --- A claim on a field ---------------------------------------------------------------------------

# Whether a household whose field is trampled presses its claim against the household crossing it.
static func get_raise_desire(city: City, victim: Household, crosser: Household, loss: float) -> Dictionary:
	var terms: Array = []
	add(terms, -1.0, "a quarrel with neighbours costs something")
	if loss >= 0.15:
		add(terms, 2.0, "the crossing costs %d%% of its harvest" % roundi(loss * 100.0))
	elif loss >= 0.05:
		add(terms, 1.0, "the crossing costs %d%% of its harvest" % roundi(loss * 100.0))
	var assertiveness: int = axis(victim, HouseholdCharacter.ASSERTIVENESS)
	if assertiveness != 0:
		add(terms, 0.75 * assertiveness, "it presses its claims" if assertiveness > 0 else "it would rather not confront anyone")
	add_strength(terms, victim, "vindication", 1.0, "it believes wrongs must be answered")
	add_strength(terms, victim, "forgiveness", -1.0, "it is forgiving")
	add_strength(terms, victim, "respect_for_holdings", 0.5, "it holds that claims must be respected")
	if HouseholdMemory.is_kin(victim, crosser):
		add(terms, -2.0, "they are kin")
	var disposition: int = HouseholdMemory.get_disposition(victim, crosser.id)
	if disposition != 0:
		add(terms, -0.5 * disposition, "they are on good terms" if disposition > 0 else "they are already at odds")
	if crosser.standing > victim.standing:
		add(terms, -0.5 * (crosser.standing - victim.standing), "the other family is better regarded")
	add_norm(city, victim, TownSocial.NORM_CLAIMS, terms)
	return {"score": sum(terms), "terms": terms}

# Whether the crossing household makes amends (fencing the field with its own labor) or refuses.
static func get_amends_desire(city: City, crosser: Household, victim: Household) -> Dictionary:
	var terms: Array = []
	add(terms, 0.5, "it would keep the peace")
	add_strength(terms, crosser, "respect_for_holdings", 1.0, "it respects others' holdings")
	add_strength(terms, crosser, "honesty", 0.5, "it owns up to what it does")
	add_strength(terms, crosser, "negotiation", 0.75, "it prefers to settle things")
	var assertiveness: int = axis(crosser, HouseholdCharacter.ASSERTIVENESS)
	if assertiveness != 0:
		add(terms, -0.75 * assertiveness, "it presses its own way" if assertiveness > 0 else "it yields rather than quarrel")
	add_relationship(terms, crosser, victim, 0.75, 1.5, -1.5)
	if victim.standing != 0:
		add(terms, 0.5 * victim.standing, "the other family is well regarded" if victim.standing > 0 else "the other family is little regarded")
	add_own_security(city, crosser, terms, "it cannot spare the labor")
	add_norm(city, crosser, TownSocial.NORM_CLAIMS, terms)
	return {"score": sum(terms), "terms": terms}

# --- Shared terms ---------------------------------------------------------------------------------

static func axis(household: Household, axis_id: String) -> int:
	return HouseholdCharacter.get_axis(household, axis_id)

static func add(terms: Array, weight: float, reason: String) -> void:
	FamilyInitiative.add(terms, weight, reason)

static func sum(terms: Array) -> float:
	return FamilyInitiative.sum(terms)

static func add_strength(terms: Array, household: Household, value_id: String, per_level: float, reason: String) -> void:
	var strength: int = HouseholdCharacter.get_strength(household, value_id)
	if strength > 0:
		add(terms, per_level * strength, reason)

# Kinship, how the household feels about the other, favours it owes them, and any grievance.
static func add_relationship(terms: Array, household: Household, other: Household, per_disposition: float, kin_weight: float, grievance_weight: float) -> void:
	if HouseholdMemory.is_kin(household, other):
		add(terms, kin_weight, "they are kin")
	var tie: Dictionary = HouseholdMemory.get_tie(household, other.id)
	if tie.is_empty():
		return
	var disposition: int = int(tie["disposition"])
	if disposition != 0 and not bool(tie.get("kin", false)):
		add(terms, per_disposition * disposition, "they are on good terms" if disposition > 0 else "they are on bad terms")
	if int(tie["owes"]) > 0:
		add(terms, minf(2.0, float(tie["owes"])), "it owes them for past help")
	if str(tie["grievance"]) != "":
		add(terms, grievance_weight, "a grievance stands between them: " + str(tie["grievance"]))

# A household close to leaving, or a town short of food, keeps its hands at home.
static func add_own_security(city: City, household: Household, terms: Array, reason: String) -> void:
	if TownSocial.get_security_margin(household) <= 2:
		add(terms, -6.0, reason + ": it is close to having to leave")
	elif city.social.get_food_days() < 30.0:
		add(terms, -1.5, "every hand is needed for food")

# What the household sees its neighbours do about a norm, and the community's appeal if it promotes
# it. Conformity is scaled by sociability; the appeal by receptiveness and trust (FamilyInitiative).
static func add_norm(city: City, household: Household, norm_id: String, terms: Array) -> void:
	var norm: Dictionary = city.social.norms[norm_id]
	var conformity: float = (float(norm["acceptance"]) - 0.5) * 2.0 * (1.0 + 0.25 * axis(household, HouseholdCharacter.SOCIABILITY))
	if absf(conformity) >= 0.2:
		add(terms, conformity, ("most neighbours " if conformity > 0.0 else "few neighbours ") + str(TownSocial.NORM_PHRASES[norm_id]))
	if str(norm["status"]) == TownSocial.STATUS_CUSTOM:
		add(terms, 0.5, "it is the custom here")
	if bool(norm["promoted"]):
		var receptive: Dictionary = FamilyInitiative.get_receptiveness(household)
		add(terms, NORM_APPEAL_WEIGHT * float(receptive["factor"]), "the community asks families to " + str(TownSocial.NORM_ASKS[norm_id]) + str(receptive["note"]))
