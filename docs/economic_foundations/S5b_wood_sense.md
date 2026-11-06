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
  - Results: pending.
