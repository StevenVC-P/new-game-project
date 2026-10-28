class_name HouseholdRosterHelper
extends RefCounted

# What the player can read about the town's families (docs/HOUSEHOLD_SOCIAL_MODEL.md, Section 12):
# the roster, one line a family, and the social lines of a family's card. Descriptive words, not
# numbers: what a family did is stated as fact, why it did it as its own reasons.

const TIE_WORDS: Dictionary = {"kin": "kin of", "friend": "friends with", "cooperation": "works well with", "obligation": "owes or is owed by", "rival": "at odds with", "feud": "feuding with", "acquaintance": "knows"}

static func get_lines(city: City) -> Array[String]:
	var lines: Array[String] = []
	for household: Household in city.households:
		lines.append(get_line(city, household))
	return lines

# "Household 3: farm, housed, secure; wants its field fenced; very cautious, communal labor; trusts
# the leadership."
static func get_line(city: City, household: Household) -> String:
	var parts: Array[String] = []
	var work: Building = FamilyInitiative.get_holding(city, household)
	var where: String = "housed" if household.housing_status == Household.RESIDENCE_HOUSED and not city.is_household_in_rough_housing(household) else "in rough shelter"
	parts.append("%s, %s, %s" % [BuildingTiers.get_display_name(work.type).to_lower() if work != null else "no work yet", where, TownSocial.describe_security(household)])
	var wants: String = FamilyAmbitions.describe(city, household)
	if wants != "":
		parts.append("wants " + wants)
	var brief: String = HouseholdCharacter.describe_briefly(household)
	if brief != "":
		parts.append(brief)
	if household.trust != 0:
		parts.append(describe_trust(household))
	return city.get_household_label(household.id).replace("Household ", "H") + ": " + "; ".join(parts)

static func describe_trust(household: Household) -> String:
	if household.trust >= 2:
		return "trusts the leadership"
	if household.trust == 1:
		return "inclined to trust the leadership"
	if household.trust == -1:
		return "wary of the leadership"
	if household.trust <= -2:
		return "distrusts the leadership"
	return "undecided about the leadership"

static func describe_standing(household: Household) -> String:
	if household.standing >= 2:
		return "well regarded"
	if household.standing == 1:
		return "respected"
	if household.standing == -1:
		return "looked at askance"
	if household.standing <= -2:
		return "poorly regarded"
	return "an ordinary standing"

# The social lines of a family's card.
static func get_card_lines(city: City, household: Household) -> Array[String]:
	var lines: Array[String] = []
	if household.personality.is_empty():
		return lines
	lines.append("Temperament: " + HouseholdCharacter.describe_personality(household, 3))
	lines.append("Convictions: " + HouseholdCharacter.describe_convictions(household))
	lines.append("Among neighbours: %s; %s; %s" % [describe_standing(household), describe_trust(household), TownSocial.describe_security(household)])
	var ties: Array = household.ties.duplicate()
	ties.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absi(int(a["disposition"])) > absi(int(b["disposition"])))
	var tie_words: Array[String] = []
	for tie: Dictionary in ties.slice(0, 3):
		var reasons: Array = tie["reasons"]
		var relation: String = TIE_WORDS.get(tie["kind"], "knows")
		if tie["kind"] == "obligation":
			relation = "owes" if int(tie["owes"]) > 0 else "is owed by"
		tie_words.append("%s %s%s" % [relation, city.get_household_label(int(tie["with"])), " (" + str(reasons.back()) + ")" if not reasons.is_empty() and str(reasons.back()) != "kin" else ""])
	if not tie_words.is_empty():
		lines.append("Ties: " + "; ".join(tie_words))
	if household.social_note != "":
		lines.append("Lately: " + household.social_note)
	for memory: Dictionary in household.memories.slice(maxi(0, household.memories.size() - 2)):
		var lessons: Array = memory["lessons"]
		lines.append("Remembers: %s%s" % [memory["text"], " - \"" + "\"; \"".join(lessons) + "\"" if not lessons.is_empty() else ""])
	if not household.value_change_notes.is_empty():
		lines.append("Changed: " + str(household.value_change_notes.back()))
	return lines
