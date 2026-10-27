class_name WorldNameGenerator
extends RefCounted

# Names for a generated world. Each culture has its own sounds, so one kingdom's towns,
# regions, and rivers read as one people's. Every name is handed out once: roads refer to
# settlements by name, and a region's regional map seed is the hash of its name.

const CULTURES: Array = [
	{"key": "northern",
		"syllables": ["hrot", "skar", "vin", "dal", "bjor", "kol", "ost", "thor", "grim", "ulf", "sig", "rav", "hal",
			"bran", "tor", "eld", "frey", "var", "ask", "sten", "hed", "mor", "ing", "rik", "sol", "gun", "ey"],
		"places": ["gard", "vik", "holm", "by", "stad", "heim", "borg", "nes", "fjord", "dal", "vang"],
		"realms": ["mark", "heim", "land", "rike"]},
	{"key": "anglic",
		"syllables": ["ash", "oak", "elm", "black", "white", "red", "green", "stone", "mill", "wolf", "raven", "hart",
			"fern", "thorn", "bright", "cold", "fair", "long", "high", "wind", "alder", "bram", "wil", "hollow",
			"marsh", "bar", "sel", "hey", "kings", "ember"],
		"places": ["ford", "ton", "wick", "bury", "ham", "stead", "mere", "field", "dale", "hold", "gate", "bridge",
			"well", "moor", "brook", "wood", "hurst", "ley", "cliff", "haven"],
		"realms": ["mark", "shire", "land", "wold"],
		"compound": true},
	{"key": "southern",
		"syllables": ["ka", "sha", "ma", "ru", "ze", "ta", "ne", "ha", "sa", "mi", "da", "ku", "zi", "ra", "be", "ya",
			"om", "ar", "el", "id", "um", "tu", "az", "qa", "nu", "ke"],
		"places": ["ar", "esh", "et", "un", "ir", "a", "ah", "im", "ur", "an"],
		"realms": ["esh", "ar", "a", "un"]},
	{"key": "eastern",
		"syllables": ["jin", "ma", "lo", "han", "tsu", "ren", "wei", "yan", "shi", "kai", "lan", "xi", "bao", "dao",
			"fen", "qu", "yu", "lin", "hai", "su", "mei", "zhou", "tan", "ho", "sen"],
		"places": ["", "shan", "hai", "an", "ling", "zhou", "men", "du"],
		"realms": ["", "an", "dao"]},
	{"key": "romance",
		"syllables": ["vel", "ar", "en", "lis", "mor", "sa", "tor", "ve", "ren", "cal", "an", "bel", "ri", "ol", "du",
			"ma", "ne", "ta", "sel", "au", "var", "mon", "lu", "cor"],
		"places": ["ne", "a", "elle", "ac", "on", "ia", "enne", "ay", "ille", "onne", "ers"],
		"realms": ["ia", "ne", "ac", "on"]},
	{"key": "islander",
		"syllables": ["ka", "lo", "ma", "nu", "te", "va", "ri", "ho", "pa", "ui", "le", "ta", "mo", "ke", "a", "o", "wa"],
		"places": ["", "a", "u", "i", "ani"],
		"realms": ["a", "u", "ia"]},
]

const REGION_WORDS: Dictionary = {
	"coast": ["Coast", "Shore", "Strand"],
	"mountains": ["Heights", "Fells", "Peaks"],
	"hills": ["Hills", "Downs", "Uplands"],
	"river": ["Vale", "Valley", "Basin"],
	"desert": ["Erg", "Waste", "Sands"],
	"steppe": ["Steppe", "Plains"],
	"forest": ["Wood", "Forest", "Weald"],
	"cold": ["Tundra", "Barrens"],
	"plain": ["Plain", "March", "Reach", "Lands", "Wold", "Country"],
}

# Random syllables occasionally spell something a player would read as a joke or a slur.
const BLOCKED: Array[String] = ["moron", "anus", "nazi", "rape", "shit", "fuk", "fuck", "cum", "penis", "dick",
	"cock", "slut", "whore", "nig", "fag", "kkk", "isis", "poo", "piss", "butt", "turd", "porn", "sex"]

var rng: RandomNumberGenerator
var used: Dictionary = {}

func _init(random: RandomNumberGenerator) -> void:
	rng = random

func culture_count() -> int:
	return CULTURES.size()

# A bare name in the culture's sounds, used for nothing else yet.
func base_name(culture: int, endings_key: String = "", min_length: int = 3) -> String:
	var spec: Dictionary = CULTURES[culture % CULTURES.size()]
	for _attempt in range(40):
		var word: String = compose(spec, endings_key)
		if word.length() >= min_length and word.length() <= 12 and not used.has(word) and not is_blocked(word):
			used[word] = true
			return word
	# A crowded culture still yields a name rather than a duplicate.
	var fallback: String = compose(spec, endings_key) + compose(spec, "")
	while used.has(fallback):
		fallback += pick(spec["syllables"])
	used[fallback] = true
	return fallback

func place_name(culture: int) -> String:
	return base_name(culture, "places")

# Kingdom names are printed large across their land; three letters read as an abbreviation.
func realm_name(culture: int) -> String:
	return base_name(culture, "realms", 5)

# Full names built around a base; the full name is reserved too, so it cannot repeat.
func unique(text: String) -> String:
	var result: String = text
	var n: int = 2
	while used.has(result):
		result = text + " " + roman(n)
		n += 1
	used[result] = true
	return result

func region_name(culture: int, feature: String) -> String:
	var base: String = base_name(culture)
	if rng.randf() < 0.3:
		return base
	return unique(base + " " + pick(REGION_WORDS.get(feature, REGION_WORDS["plain"])))

func range_name(culture: int) -> String:
	var base: String = base_name(culture)
	match rng.randi_range(0, 2):
		0:
			return unique("The " + base + " Mountains")
		1:
			return unique("The " + base + " Range")
	return unique(base + " Peaks")

func compose(spec: Dictionary, endings_key: String) -> String:
	var syllables: Array = spec["syllables"]
	var word: String = pick(syllables)
	if bool(spec.get("compound", false)):
		var ending_list: Array = spec[endings_key] if endings_key != "" else spec["places"]
		return (word + pick(ending_list)).capitalize().replace(" ", "")
	var extra: int = rng.randi_range(0, 2) if endings_key == "" else rng.randi_range(0, 1)
	for _i in range(extra):
		word += pick(syllables)
	if endings_key != "":
		word += pick(spec[endings_key])
	return word.capitalize().replace(" ", "")

static func is_blocked(word: String) -> bool:
	var lower: String = word.to_lower()
	for blocked: String in BLOCKED:
		if lower.contains(blocked):
			return true
	return false

func pick(list: Array) -> String:
	return list[rng.randi_range(0, list.size() - 1)]

static func roman(n: int) -> String:
	var numerals: Array[String] = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	return numerals[n] if n < numerals.size() else str(n)
