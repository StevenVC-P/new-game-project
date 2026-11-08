extends SceneTree

# E13 V0 report (docs/economic_foundations/E13_local_value.md, section 4): reads the observer's saved
# logs (value_observer.gd) and answers the proposal's eight questions, so settings and formula
# variants can be tried without repeating the runs. Lines start "[V0]".
#   <godot> --headless --path . --script res://tests/sim/value_report.gd -- --logs=DIR[,DIR...] > v0.log
# Each DIR holds one arrangement's logs; its folder name labels it.
#
# The formula, as proposed: coverage is the lowest R'(t) over the horizons (1, 3, 6, 12 months), with
# R(t) = (stock + expected production to t) / use to t, and a shortfall counted by nearness
# (NEARNESS); value = clamp((TARGET / coverage)^K, LIMITS). Defaults follow the proposal's direction;
# the sensitivity section varies them.

const HORIZON_MONTHS: Array[int] = [1, 3, 6, 12]
const HORIZON_DAYS: Array[int] = [30, 90, 180, 360]
const NEARNESS: Array[float] = [1.0, 0.75, 0.5, 0.25]
const TARGET: float = 1.25
const K: float = 1.0
const LIMITS: Vector2 = Vector2(0.25, 4.0)
const GOODS: Array[String] = ["food", "wood", "tools", "stone_blocks", "bricks"]
# A family short on this many days of a month is going hungry (TownCommons' danger line).
const HUNGRY_DAYS: int = 5

func _init() -> void:
	call_deferred("run")

func say(line: String) -> void:
	print("[V0] " + line)

func run() -> void:
	var dirs: Array[String] = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--logs="):
			dirs.assign(argument.trim_prefix("--logs=").split(","))
	var arrangements: Dictionary = {}
	for dir: String in dirs:
		arrangements[dir.get_file()] = load_dir(dir)
		say("%s: %d towns" % [dir.get_file(), (arrangements[dir.get_file()] as Array).size()])
	for name: String in arrangements:
		report(name, arrangements[name])
	sensitivity(arrangements)
	quit()

func load_dir(dir: String) -> Array:
	var towns: Array = []
	var access: DirAccess = DirAccess.open(dir)
	if access == null:
		push_error("value report: no logs in " + dir)
		return towns
	var names: Array = Array(access.get_files())
	names.sort()
	for file_name: String in names:
		if not file_name.ends_with(".jsonl"):
			continue
		var months: Array = []
		for line: String in FileAccess.get_file_as_string(dir.path_join(file_name)).split("\n", false):
			months.append(JSON.parse_string(line))
		towns.append(months)
	return towns

# --- The formula ---------------------------------------------------------------------------------

# What a good's stock is for its town: food counts families' larders too.
static func stock_of(month: Dictionary, good: String) -> float:
	var stock: float = float(month["goods"][good]["stock"])
	if good == "food":
		for household: Dictionary in month["households"]:
			stock += float(household["larder"])
	return stock

# Production per day "if current work continues", two ways: the proposal's expected output of the
# work families hold today (FamilyInitiative.get_expected_output), or what the town actually made over
# the last TRAILING_MONTHS (its "made" flows), the forecast V0 found more believable.
const TRAILING_MONTHS: int = 3

static func trailing_output(months: Array, m: int, good: String) -> float:
	var back: int = mini(TRAILING_MONTHS, m)
	if back <= 0:
		return float(months[m]["goods"][good]["daily_output"])
	var now: float = float((months[m]["goods"][good]["flows"] as Dictionary).get("made", 0))
	var then: float = float((months[m - back]["goods"][good]["flows"] as Dictionary).get("made", 0))
	return maxf(0.0, now - then) / (30.0 * back)

static func coverage(month: Dictionary, good: String, nearness: Array[float] = NEARNESS, output: float = -1.0) -> float:
	var entry: Dictionary = month["goods"][good]
	var daily: float = float(entry["daily_output"]) if output < 0.0 else output
	var lowest: float = INF
	for i in range(HORIZON_DAYS.size()):
		var use: float = float(entry["use"][i]) + (float(entry["committed"]) if i == 0 else 0.0)
		if use <= 0.0:
			continue
		var r: float = (stock_of(month, good) + daily * HORIZON_DAYS[i]) / use
		var counted: float = r if r >= 1.0 else 1.0 - nearness[i] * (1.0 - r)
		lowest = minf(lowest, counted)
	return lowest

static func value_of(cover: float, target: float = TARGET, k: float = K) -> float:
	if is_inf(cover):
		return LIMITS.x
	return clampf(pow(target / maxf(cover, 0.001), k), LIMITS.x, LIMITS.y)

# --- The report ----------------------------------------------------------------------------------

func report(name: String, towns: Array) -> void:
	say("=== %s ===" % name)
	forecast_quality(towns)
	warnings(towns)
	hunger_causes(towns)
	access_gap(towns)
	claim_types(towns)
	anchors(towns)
	stability(towns)
	cost(towns)

# 1. Predicted against actual stock at 1, 3, 6 and 12 months, as a share of the goods that pass
# through in that time (use plus production), for both forecasts of production.
func forecast_quality(towns: Array) -> void:
	for good: String in ["food", "wood", "tools"]:
		for trailing: bool in [false, true]:
			var parts: Array[String] = []
			for i in range(HORIZON_MONTHS.size()):
				var errors: Array[float] = []
				for months: Array in towns:
					for m in range(months.size() - HORIZON_MONTHS[i]):
						var month: Dictionary = months[m]
						var entry: Dictionary = month["goods"][good]
						var use: float = float(entry["use"][i])
						if int(month["people"]) == 0:
							continue
						var made: float = (trailing_output(months, m, good) if trailing else float(entry["daily_output"])) * HORIZON_DAYS[i]
						if use + made < 1.0:
							continue
						var predicted: float = stock_of(month, good) + made - use
						var actual: float = stock_of(months[m + HORIZON_MONTHS[i]], good)
						errors.append(absf(predicted - actual) / (use + made))
				parts.append("%d mo %s" % [HORIZON_MONTHS[i], quantiles(errors)])
			say("Q1 forecast error / turnover, %s, %s: %s" % [good, "trailing output" if trailing else "expected output", " | ".join(parts)])

# 2. Lead time of the food alarm (coverage under 1) before families first go hungry, against the
# families' own food signal (FamilyInitiative.get_waiting_risk), and alarms with no hunger in a year.
func warnings(towns: Array) -> void:
	var alarm_leads: Array[float] = []
	var signal_leads: Array[float] = []
	var false_alarms: int = 0
	var alarms: int = 0
	var hungry_towns: int = 0
	for months: Array in towns:
		var hunger: int = -1
		for m in range(months.size()):
			if (months[m]["households"] as Array).any(func(h: Dictionary) -> bool: return int(h["short_days"]) >= HUNGRY_DAYS):
				hunger = m
				break
		var alarm: int = -1
		var family: int = -1
		for m in range(months.size()):
			if alarm < 0 and coverage(months[m], "food", NEARNESS, trailing_output(months, m, "food")) < 1.0:
				alarm = m
			if family < 0 and float(months[m]["signals"]["food"]) > 0.0:
				family = m
		if alarm >= 0:
			alarms += 1
			if hunger < 0 or hunger - alarm > 12:
				false_alarms += 1
		if hunger >= 0:
			hungry_towns += 1
			if alarm >= 0 and alarm <= hunger:
				alarm_leads.append(hunger - alarm)
			if family >= 0 and family <= hunger:
				signal_leads.append(hunger - family)
	say("Q2 warnings (trailing output): %d towns ever hungry; alarm lead (months) %s over %d; families' signal lead %s over %d; %d of %d alarms with no hunger within a year" % [hungry_towns, quantiles(alarm_leads), alarm_leads.size(), quantiles(signal_leads), signal_leads.size(), false_alarms, alarms])

# 3. Hungry family-months split into true shortage (the town's food, larders included, under the
# month's need) and access failure (enough in town, but not for this family).
func hunger_causes(towns: Array) -> void:
	var shortage: int = 0
	var access: int = 0
	for months: Array in towns:
		for month: Dictionary in months:
			var need: float = 0.0
			for household: Dictionary in month["households"]:
				need += float(household["need"]) * 30.0
			var enough: bool = stock_of(month, "food") >= need
			for household: Dictionary in month["households"]:
				if int(household["short_days"]) >= HUNGRY_DAYS:
					if enough:
						access += 1
					else:
						shortage += 1
	var total: int = shortage + access
	say("Q3 hungry family-months: %d; true shortage %d (%s), access failure %d (%s)" % [total, shortage, percent(shortage, total), access, percent(access, total)])

# 4. Physical against accessible coverage of the month's food need. Accessible: what a family owns,
# its part of the community's food (all of it in a pooled town; above the reserve, plus the reserve
# when in danger, under a compact), and what others hold beyond their keep and would sell.
func access_gap(towns: Array) -> void:
	var gaps: Array[float] = []
	var pooled_gaps: Array[float] = []
	for months: Array in towns:
		for month: Dictionary in months:
			var households: Array = month["households"]
			var need: float = 0.0
			for household: Dictionary in households:
				need += float(household["need"]) * 30.0
			if need <= 0.0:
				continue
			var physical: float = minf(1.0, stock_of(month, "food") / need)
			var community: float = float(month["goods"]["food"]["community"])
			var open: float = maxf(0.0, community - float(month["reserve"]))
			var spare: Dictionary = {}
			var spare_total: float = 0.0
			for household: Dictionary in households:
				var own: float = float((household["shares"] as Dictionary).get("food", 0)) + float(household["larder"])
				var beyond: float = maxf(0.0, own - float((household["keep"] as Dictionary).get("food", own)))
				spare[household["id"]] = beyond
				spare_total += beyond
			var reached: float = 0.0
			for household: Dictionary in households:
				var wanted: float = float(household["need"]) * 30.0
				var own: float = float((household["shares"] as Dictionary).get("food", 0)) + float(household["larder"])
				var share: float = wanted / need
				var entitled: float = open * share + (float(month["reserve"]) * share if bool(household["in_danger"]) else 0.0)
				if not bool(month["compact"]):
					entitled = community * share
				var bought: float = (spare_total - float(spare[household["id"]])) * share if bool(month["compact"]) else 0.0
				reached += minf(wanted, own + entitled + bought)
			var gap: float = physical - reached / need
			if bool(month["compact"]):
				gaps.append(gap)
			else:
				pooled_gaps.append(gap)
	say("Q4 physical minus accessible coverage: pooled %s (%d months); under a compact %s (%d months)" % [quantiles(pooled_gaps), pooled_gaps.size(), quantiles(gaps), gaps.size()])

# 5. Demand by claim type over the coming month, and goods at the floor that were later wanted.
func claim_types(towns: Array) -> void:
	var totals: Dictionary = {"continuous": 0.0, "periodic": 0.0, "committed": 0.0, "latent": 0.0}
	var latent_homes: Dictionary = {}
	var floor_then_wanted: Dictionary = {}
	for months: Array in towns:
		for m in range(months.size()):
			var month: Dictionary = months[m]
			totals["continuous"] += float(month["goods"]["food"]["use"][0]) + float(month["goods"]["wood"]["use"][0])
			totals["periodic"] += float(month["goods"]["tools"]["use"][0])
			for good: String in GOODS:
				totals["committed"] += float(month["goods"][good]["committed"])
			for household: Dictionary in month["households"]:
				if str(household["latent_home"]) != str(household["home_now"]):
					latent_homes[household["latent_home"]] = int(latent_homes.get(household["latent_home"], 0)) + 1
					# One typical home's worth, the proposal's safeguard for lumpy goods.
					totals["latent"] += 1.0
			for good: String in ["stone_blocks", "bricks"]:
				var entry: Dictionary = month["goods"][good]
				if int(entry["stock"]) == 0 and float(entry["use"][3]) <= 0.0 and m + 12 < months.size():
					var later: bool = false
					for ahead in range(m + 1, m + 13):
						later = later or int(months[ahead]["goods"][good]["committed"]) > 0
					if later:
						floor_then_wanted[good] = int(floor_then_wanted.get(good, 0)) + 1
	say("Q5 claims over the next month (units, latent in homes): %s; homes families would build with supply set aside: %s; months at the floor then wanted within a year: %s" % [JSON.stringify(totals), JSON.stringify(latent_homes), JSON.stringify(floor_then_wanted)])

# 6. Anchors: the fixed grain table against market prices where exchange happened, and the value
# the formula gives, by good (medians over town-months).
func anchors(towns: Array) -> void:
	for good: String in GOODS:
		var prices: Array[float] = []
		var values: Array[float] = []
		var base: float = -1.0
		for months: Array in towns:
			for m in range(months.size()):
				var month: Dictionary = months[m]
				var entry: Dictionary = month["goods"][good]
				base = float(entry["base_value"])
				if float(entry["price"]) > 0.0:
					prices.append(float(entry["price"]))
				var cover: float = coverage(month, good, NEARNESS, trailing_output(months, m, good))
				if not is_inf(cover):
					values.append(value_of(cover))
		say("Q6 %s: table %.2f; market price %s (%d months); scarcity factor %s" % [good, base, quantiles(prices), prices.size(), quantiles(values)])

# 7. Stability: the monthly swing of the scarcity factor (|change in its log|) and time at its limits.
func stability(towns: Array) -> void:
	for good: String in ["food", "wood", "tools"]:
		var swings: Array[float] = []
		var at_limits: int = 0
		var months_counted: int = 0
		for months: Array in towns:
			var previous: float = -1.0
			for m in range(months.size()):
				var cover: float = coverage(months[m], good, NEARNESS, trailing_output(months, m, good))
				if is_inf(cover):
					previous = -1.0
					continue
				var value: float = value_of(cover)
				months_counted += 1
				at_limits += 1 if value <= LIMITS.x or value >= LIMITS.y else 0
				if previous > 0.0:
					swings.append(absf(log(value) - log(previous)))
				previous = value
		say("Q7 %s: monthly swing %s; at a limit %s of %d months" % [good, quantiles(swings), percent(at_limits, months_counted), months_counted])

# 8. The observer's own cost per month, by town size.
func cost(towns: Array) -> void:
	var by_size: Dictionary = {}
	for months: Array in towns:
		for month: Dictionary in months:
			var households: int = (month["households"] as Array).size()
			var bucket: String = "under 10" if households < 10 else ("10-24" if households < 25 else "25+")
			if not by_size.has(bucket):
				by_size[bucket] = []
			(by_size[bucket] as Array).append(float(month["observer_usec"]) / 1000.0)
	var parts: Array[String] = []
	for bucket: String in by_size:
		var values: Array[float] = []
		values.assign(by_size[bucket])
		parts.append("%s households: %s ms" % [bucket, quantiles(values)])
	say("Q8 monthly pass: " + " | ".join(parts))

# Sensitivity: time at the limits and median food value under other targets and powers, all arrangements.
func sensitivity(arrangements: Dictionary) -> void:
	for target: float in [1.0, 1.25, 1.5]:
		for k: float in [0.5, 1.0, 2.0]:
			var values: Array[float] = []
			var at_limits: int = 0
			for towns: Array in arrangements.values():
				for months: Array in towns:
					for m in range(months.size()):
						var cover: float = coverage(months[m], "food", NEARNESS, trailing_output(months, m, "food"))
						if is_inf(cover):
							continue
						var value: float = value_of(cover, target, k)
						values.append(value)
						at_limits += 1 if value <= LIMITS.x or value >= LIMITS.y else 0
			say("SENS food target %.2f k %.1f: value %s; at a limit %s" % [target, k, quantiles(values), percent(at_limits, values.size())])

# --- Helpers ------------------------------------------------------------------------------------

static func quantiles(values: Array[float]) -> String:
	if values.is_empty():
		return "n/a"
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var at: Callable = func(q: float) -> float: return sorted[clampi(roundi(q * (sorted.size() - 1)), 0, sorted.size() - 1)]
	return "median %.2f [p10 %.2f, p90 %.2f]" % [at.call(0.5), at.call(0.1), at.call(0.9)]

static func percent(part: int, whole: int) -> String:
	return "%.0f%%" % (100.0 * part / whole) if whole > 0 else "n/a"
