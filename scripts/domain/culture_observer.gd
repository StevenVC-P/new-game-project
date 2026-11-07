class_name CultureObserver
extends RefCounted

# What a town's culture holds, as distributions (master roadmap Phase 1, Stage C; the scale
# guardrail "statistics keep distributions"): how many households hold each value, each pair of
# values held together, and the whole combinations households carry. It reads the town and changes
# nothing. Weighted family records (Phase 4) must reproduce these distributions, and X4 reads how
# fast they move.

# A household's held values (Household.values, by CultureValues category), sorted.
static func values_of(household: Household) -> Array[String]:
	var held: Array[String] = []
	for category: String in household.values:
		for value: Variant in household.values[category]:
			held.append(str(value))
	held.sort()
	return held

# Value -> households holding it.
static func spread(city: City) -> Dictionary:
	var counts: Dictionary = {}
	for household: Household in city.households:
		for value: String in values_of(household):
			counts[value] = int(counts.get(value, 0)) + 1
	return counts

# "a|b" (sorted) -> households holding both.
static func pairs(city: City) -> Dictionary:
	var counts: Dictionary = {}
	for household: Household in city.households:
		var held: Array[String] = values_of(household)
		for i in range(held.size()):
			for j in range(i + 1, held.size()):
				var key: String = held[i] + "|" + held[j]
				counts[key] = int(counts.get(key, 0)) + 1
	return counts

# The most common whole combinations: [[combination, households], ...], most held first, ties by name.
static func top_combinations(city: City, count: int) -> Array:
	var counts: Dictionary = {}
	for household: Household in city.households:
		var key: String = ",".join(values_of(household))
		counts[key] = int(counts.get(key, 0)) + 1
	var ranked: Array = []
	for key: String in counts:
		ranked.append([key, counts[key]])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]) or (int(a[1]) == int(b[1]) and str(a[0]) < str(b[0])))
	return ranked.slice(0, count)
