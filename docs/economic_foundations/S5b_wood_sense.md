# S5b: Wood Beyond the Winter

A Track A follow-up to the final review (`Track_A_review.md` §4, on `feature/ef-s9-market`).

## Owner's decision (2026-11-05)

- **Cold and marginal sites stay genuinely dangerous.** Failure is a real possibility even with competent play; six of eight rocky towns failing is acceptable. No equal viability across lands.
- **Option b approved, c declined.**
  - Families weigh the wood the town already holds and the coming season's need when they choose work. It influences their choices and doesn't dictate them: callings, values, autonomy and poor decisions all stay possible.
  - Nothing reassigns families to food, guarantees supplies or steers a town toward survival.
  - No added founding winter fuel: a hard cold founding is intended.
- **Rerun the affected Track A comparisons** and report them without a survival target. Remaining hardship is accepted unless another genuine simulation defect turns up.
- The S9 comparison runs on the pre-fix build and is labelled as such. Whether any comparison needs repeating is decided after this review.

## The defect

Traced in a rocky town (`tests/sim/fuel_trace.gd`, rocky start 2):
- From day 270 to 480 the town held 300–500 wood against a need of about 2 a day, while its families went hungry and left.
- Woodcutters looking at their work found nothing against wood work in their weighing. Food has "the town has plenty of food", and other goods have "more than the town uses", but wood had neither: the only stock term was "wood is short".
- An oversupplied woodcutter waited for its yearly review, since oversupply isn't urgent.
- So the cold's pull into wood work was answered, then never unwound in time.

## Implementation

- **`FamilyInitiative.get_wood_plenty`:** the wood in store against what the town will burn (TownFuel, season by season) and use (workshops) through the end of the coming winter, plus what its building still waits for.
  - 0 when the store won't see that winter out.
  - 1 when the spare is as large again as the need, or 100 wood where little is needed.
  - It counts what families see in the store, not wood still to be cut.
- **Wood work:** "the town holds more wood than it needs through the coming winter" counts against wood work, up to −3.0 (as much as a pile no one uses), in choosing work and in staying at it.
- **Gathering wood as side work:** the same reason counts up to −2.0 against it.
- **A past cold hearth:** a family whose hearth went cold this month weighs that less once the store again holds the coming need (`get_cold_hardship`); with nothing in store, fully as before.
- **Looking again in time:** a woodcutter whose town holds that plenty while short of something else (`is_short_elsewhere`) looks at its work again without waiting for its year (trigger `wood_beyond_winter`, urgent). What it then chooses is its own weighing; nothing makes it change.
- **Comparison switch:** the meta `no_wood_plenty` restores the Track A judgment.
- **Files:** `family_initiative.gd`, `occupation_review.gd`, `household_economy.gd`; `tests/winter_fuel_validation.gd`.

## Verification

- **`tests/winter_fuel_validation.gd` (`test_wood_beyond_winter`):**
  - a store that won't see the winter out is no plenty, and the same store is plenty with only winter's end left;
  - plenty weighs against wood work and gathering;
  - a cold hearth weighs nothing once the store covers the coming need, and fully when it's empty;
  - a fed town's woodcutter goes on, while a hungry town's looks again;
  - the switch restores the old judgment.
- **The traced town, before and after:**
  - At day 300, midwinter with 483 wood, the new reason fires. The woodcutter already leaving for toolmaking does so by a margin of 6.4 instead of 3.4.
  - The other woodcutter looks again at day 330, but keeps to its work: quarrying is its calling.
  - The town still empties in year 2. Its farms don't feed it, which is the land's hardship, not this defect.
- **Suite:** 53/53.
  - One test's setup now keeps the old judgment (`occupation_review_validation.gd`, the one-change-a-month limit). There, the second family's other work had been woodcutting, against its calling, beside 500 wood its town never burns. The new reason now weighs against that, so it stays put and the limit is never reached. That's the intended effect, so the test sets `no_wood_plenty` and says why.
- **Comparisons (`../ngg-ef-runs6` at this sprint's commit):**
  - `G`: as F, with no player, ordinary and stressed conditions, 8 starts, 6 years;
  - `G-review`: as F-review, with the attentive, investment-first and overprotecting players, 6 starts.

## Results

No survival rate was aimed at. Logs: `test-logs/div/G`, `test-logs/div/G-review`.

**Wood at year 3, no player (mean over 8 towns, F → G):**

| Land | Cond. | Wood in store | Wood cut | Woodcutter families |
|---|---|---|---|---|
| Balanced | ordinary | 1053 → 708 | 2976 → 2243 | 1.00 → 0.88 |
| Balanced | stressed | 799 → 632 | 2015 → 1879 | 0.62 → 0.62 |
| Fertile valley | ordinary | 916 → 898 | 3433 → 3219 | 1.00 → 0.88 |
| Fertile valley | stressed | 1054 → 955 | 3229 → 2918 | 0.88 → 0.62 |
| Forested | ordinary | 425 → 345 | 2819 → 2573 | 0.88 → 0.75 |
| Forested | stressed | 416 → 374 | 2470 → 2429 | 0.75 → 0.75 |
| Marginal | ordinary | 393 → 295 | 2399 → 2075 | 1.00 → 1.00 |
| Marginal | stressed | 311 → 186 | 2057 → 1906 | 0.62 → 0.62 |
| Rocky | ordinary | 918 → 513 | 2183 → 1593 | 0.62 → 0.38 |
| Rocky | stressed | 922 → 201 | 2009 → 1396 | 0.38 → 0.38 |

The defect's signature is gone: idle wood falls everywhere, most on rocky land.

**Outcomes at year 6, towns ok (F → G):**

| | Balanced | Fertile valley | Forested | Marginal | Rocky | Total |
|---|---|---|---|---|---|---|
| No player, ordinary (of 8) | 6 → 6 | 6 → 5 | 4 → 3 | 3 → 2 | 2 → 2 | 21 → 18 of 40 |
| No player, stressed (of 8) | 4 → 5 | 5 → 4 | 3 → 3 | 3 → 4 | 2 → 2 | 17 → 18 of 40 |
| Three players (of 18) | 8 → 8 | 6 → 6 | 7 → 6 | 5 → 6 | 2 → 3 | 28 → 29 of 90 |

- **Survival is essentially unchanged.** On rocky land the same two founder sets (starts 0 and 1) live and the same six fail in both builds and both conditions. Those towns fail on food, the land's hardship.
- **Marginal land:** one town lost (ordinary, start 3) and one gained (stressed, start 1).
  - The lost town was already freezing in both builds, with about 1 wood in store at year 3, so the new reason rarely applied there.
  - The loss is the knock-on of earlier choices, not plenty pulling its woodcutters away.
- **Hunger days (as `summarize_divergence.ps1` reports them):**
  - Rises: fertile valley ordinary 133 → 249, fertile valley stressed 211 → 260, marginal ordinary 141 → 190.
  - Falls: balanced stressed 200 → 148.
  - The rest are within a few days.
  - Families leaving wood work don't reliably feed the town better: they go to other work, by their callings and values, as intended.
- **Investment-first player:** cold days rise on most lands (balanced 28 → 123, fertile valley 0 → 72, rocky 43 → 114). With fewer woodcutters, a player who pulls labour toward building runs the winter closer. That is a poor decision the town can still make, as intended.
- **Overprotecting player:** results are identical; those towns fail before plenty arises.
- **Tick time** is lower in G runs, but they shared the machine with fewer processes, so it's not attributed to the change.

**Reading:** S5b changes how families weigh wood without changing which towns can survive. The remaining hardship on rocky and marginal land is the land's, consistent with the owner's decision.
