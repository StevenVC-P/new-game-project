extends SceneTree

# X4, cultural transmission (master roadmap Phase 1; Scale Brief 1's open question 2): a standalone
# model of how values pass down 70 generations, using the game's own value catalog and inheritance
# (CultureValues.inherit_profile), against the candidate rules Phase 3 decides between. It answers how
# fast values spread and whether combinations survive. No town, no economy: families marry, have
# children who found families, migrants arrive, and some values carry an economic advantage (more
# surviving children), standing in for selection by the economy.
# Run: <godot> --headless --path . --script res://tests/sim/culture_transmission_model.gd > x4.log
#   (filter for [X4]; "-- --generations=N --families=N,N --seeds=N")
#
# Rules compared:
# - current: each value of either parent kept with 80% (CultureValues.INHERIT_KEEP_CHANCE);
# - shared_persists: a value both parents hold is kept with 95%, one only one holds with 60% (existing
#   values shape persistence; the owner's direction);
# - lineage: the lineage parent's values kept with 90%, the other parent's with 30%.
# Marriage: assortative, partners chosen among a few candidates by shared values (MATCH_TRIES).

const RULES: Array[String] = ["current", "shared_persists", "lineage"]
const MATCH_TRIES: int = 4
const MIGRANT_SHARE: float = 0.02
# A few values give their families more surviving children: the economy's selection, abstracted.
const FAVOURED: int = 3
const FAVOURED_GAIN: float = 0.15
const CHILDREN_MEAN: float = 2.0
const CHECKPOINTS: Array[int] = [1, 5, 10, 20, 40, 70]

var generations: int = 70
# This generation's fidelity: [parent pairs children kept (share, summed), children keeping the
# parent's defining values, children].
var fidelity: Array = [0.0, 0.0, 0.0]
var sizes: Array[int] = [200, 2000]
var seeds: int = 3
var all_values: Array[String] = []

func _init() -> void:
	call_deferred("run")

func say(line: String) -> void:
	print("[X4] " + line)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--generations="):
			generations = int(argument.trim_prefix("--generations="))
		elif argument.begins_with("--families="):
			sizes.assign(Array(argument.trim_prefix("--families=").split(",")).map(func(s: String) -> int: return int(s)))
		elif argument.begins_with("--seeds="):
			seeds = int(argument.trim_prefix("--seeds="))
	for category: String in CultureValues.CATEGORY_ORDER:
		for value: Variant in CultureValues.CATEGORY_VALUES[category]:
			all_values.append(str(value))
	say("catalog: %d values in %d categories; %d generations; families %s; %d seeds" % [all_values.size(), CultureValues.CATEGORY_ORDER.size(), generations, str(sizes), seeds])
	say("rule | families | generation | intact founding combinations | parent pairs a child keeps | children keeping the parent's 3 defining values | values present | favoured value share | mean values per family")
	for size: int in sizes:
		for rule: String in RULES:
			var results: Dictionary = {}
			for seed in range(seeds):
				var series: Dictionary = simulate(rule, size, seed)
				for generation: int in series:
					if not results.has(generation):
						results[generation] = []
					(results[generation] as Array).append(series[generation])
			for generation: int in CHECKPOINTS:
				if generation > generations or not results.has(generation):
					continue
				var rows: Array = results[generation]
				say("%s | %d | %d | %.3f | %.2f | %.2f | %.0f | %.2f | %.1f" % [rule, size, generation, mean(rows, 0), mean(rows, 5), mean(rows, 6), mean(rows, 2), mean(rows, 3), mean(rows, 4)])
	quit()

func simulate(rule: String, size: int, seed: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([rule, size, seed])
	# The same founders and favoured values for every rule at a seed.
	var founder_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	founder_rng.seed = hash([size, seed, "founders"])
	var families: Array[Dictionary] = []
	for i in range(size):
		families.append(CultureValues.make_random_profile(founder_rng))
	var favoured: Array[String] = []
	while favoured.size() < FAVOURED:
		var pick: String = all_values[founder_rng.randi_range(0, all_values.size() - 1)]
		if not favoured.has(pick):
			favoured.append(pick)
	var founding_combos: Dictionary = {}
	for profile: Dictionary in families:
		founding_combos[key(profile)] = true
	var series: Dictionary = {}
	for generation in range(1, generations + 1):
		fidelity = [0.0, 0.0, 0.0]
		families = next_generation(families, rule, size, favoured, rng)
		if CHECKPOINTS.has(generation):
			var intact: int = 0
			var present: Dictionary = {}
			var held_total: int = 0
			var favoured_held: int = 0
			for profile: Dictionary in families:
				intact += 1 if founding_combos.has(key(profile)) else 0
				var values: Array[String] = flat(profile)
				held_total += values.size()
				for value: String in values:
					present[value] = true
				favoured_held += 1 if values.any(func(v: String) -> bool: return favoured.has(v)) else 0
			series[generation] = [float(intact) / families.size(), 0.0, float(present.size()), float(favoured_held) / families.size(), float(held_total) / families.size(), float(fidelity[0]) / maxf(1.0, fidelity[2]), float(fidelity[1]) / maxf(1.0, fidelity[2])]
	return series

# Each family marries (assortatively), has children by its values' advantage, and each child founds a
# family inheriting by the rule; the generation is drawn back to size, and migrants replace a share.
func next_generation(families: Array[Dictionary], rule: String, size: int, favoured: Array[String], rng: RandomNumberGenerator) -> Array[Dictionary]:
	var counts: Dictionary = CultureValues.count_values(families)
	var children: Array[Dictionary] = []
	for i in range(families.size()):
		var parent: Dictionary = families[i]
		var partner: Dictionary = families[rng.randi_range(0, families.size() - 1)]
		var best_shared: int = -1
		for _try in range(MATCH_TRIES):
			var candidate: Dictionary = families[rng.randi_range(0, families.size() - 1)]
			var shared: int = shared_count(parent, candidate)
			if shared > best_shared:
				best_shared = shared
				partner = candidate
		var values: Array[String] = flat(parent)
		var gain: float = FAVOURED_GAIN * values.filter(func(v: String) -> bool: return favoured.has(v)).size()
		var born: int = poisson(CHILDREN_MEAN * (1.0 + gain) / 2.0, rng)
		var defining: Array[String] = CultureValues.get_defining_values(parent, counts, families.size(), 3)
		var parent_pairs: Array[String] = pairs_of(values)
		for _child in range(born):
			var child: Dictionary = inherit(parent, partner, rule, rng, counts)
			var child_values: Array[String] = flat(child)
			var kept: int = 0
			for pair: String in pairs_of(child_values):
				kept += 1 if parent_pairs.has(pair) else 0
			fidelity[0] += float(kept) / maxf(1.0, parent_pairs.size())
			fidelity[1] += 1.0 if defining.all(func(v: String) -> bool: return child_values.has(v)) else 0.0
			fidelity[2] += 1.0
			children.append(child)
	children.shuffle()
	var next: Array[Dictionary] = []
	for i in range(size):
		if rng.randf() < MIGRANT_SHARE or children.is_empty():
			next.append(CultureValues.make_random_profile(rng))
		else:
			next.append(children[i % children.size()])
	return next

func inherit(lineage_parent: Dictionary, other: Dictionary, rule: String, rng: RandomNumberGenerator, counts: Dictionary) -> Dictionary:
	if rule == "current":
		return CultureValues.inherit_profile([lineage_parent, other], rng, counts)
	var profile: Dictionary = {}
	for category: String in CultureValues.CATEGORY_ORDER:
		var mine: Array = lineage_parent.get(category, [])
		var theirs: Array = other.get(category, [])
		var candidates: Array[String] = []
		for value: Variant in mine + theirs:
			var id: String = str(value)
			if candidates.has(id):
				continue
			var keep: float = 0.0
			if rule == "shared_persists":
				keep = 0.95 if mine.has(value) and theirs.has(value) else 0.6
			else:
				keep = 0.9 if mine.has(value) else 0.3
			if rng.randf() < keep:
				candidates.append(id)
		candidates.shuffle()
		var held: Array[String] = []
		for id: String in candidates:
			if held.size() >= CultureValues.MAX_VALUES_PER_CATEGORY:
				break
			if held.any(func(h: String) -> bool: return h == id or CultureValues.values_conflict(h, id)):
				continue
			held.append(id)
		if held.is_empty():
			# As the game fills an empty category: from the settlement's spread.
			held = CultureValues.inherit_profile([], rng, counts)[category]
		profile[category] = held
	return profile

# --- Measures -----------------------------------------------------------------------------------

static func flat(profile: Dictionary) -> Array[String]:
	var values: Array[String] = []
	for category: String in profile:
		for value: Variant in profile[category]:
			values.append(str(value))
	values.sort()
	return values

static func key(profile: Dictionary) -> String:
	return ",".join(flat(profile))

static func shared_count(a: Dictionary, b: Dictionary) -> int:
	var shared: int = 0
	var held: Array[String] = flat(b)
	for value: String in flat(a):
		shared += 1 if held.has(value) else 0
	return shared

# Every pair of a sorted value list, as "a|b".
static func pairs_of(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for i in range(values.size()):
		for j in range(i + 1, values.size()):
			result.append(values[i] + "|" + values[j])
	return result

# The founding population's most held pairs.
static func top_pairs(families: Array[Dictionary], count: int) -> Array:
	var counts: Dictionary = {}
	for profile: Dictionary in families:
		var values: Array[String] = flat(profile)
		for i in range(values.size()):
			for j in range(i + 1, values.size()):
				var pair: String = values[i] + "|" + values[j]
				counts[pair] = int(counts.get(pair, 0)) + 1
	var ranked: Array = counts.keys()
	ranked.sort_custom(func(a: String, b: String) -> bool: return int(counts[a]) > int(counts[b]) or (int(counts[a]) == int(counts[b]) and a < b))
	return ranked.slice(0, count)

# How strongly the founding pairs still go together: the mean phi coefficient across families.
static func pair_phi(families: Array[Dictionary], pairs: Array) -> float:
	var total: float = 0.0
	var counted: int = 0
	for pair: String in pairs:
		var parts: PackedStringArray = pair.split("|")
		var n11: int = 0
		var n1x: int = 0
		var nx1: int = 0
		for profile: Dictionary in families:
			var values: Array[String] = flat(profile)
			var a: bool = values.has(parts[0])
			var b: bool = values.has(parts[1])
			n11 += 1 if a and b else 0
			n1x += 1 if a else 0
			nx1 += 1 if b else 0
		var n: float = families.size()
		var denominator: float = sqrt(float(n1x) * (n - n1x) * float(nx1) * (n - nx1))
		if denominator > 0.0:
			total += (n11 * n - float(n1x) * nx1) / denominator
			counted += 1
	return total / counted if counted > 0 else 0.0

static func poisson(mean_count: float, rng: RandomNumberGenerator) -> int:
	var limit: float = exp(-mean_count)
	var product: float = rng.randf()
	var count: int = 0
	while product > limit:
		product *= rng.randf()
		count += 1
	return count

static func mean(rows: Array, index: int) -> float:
	var total: float = 0.0
	for row: Array in rows:
		total += float(row[index])
	return total / rows.size() if not rows.is_empty() else 0.0
