# Track A Review (S1–S5): Final Comparison

The finished Track A build (`110a128`; the S4 review fix included), against the baseline B0 (`e5410ba`, the game before Track A).

- **Tables:** `F_summary_y6.md` and `F_summary_y3.md`.
- **Runs:**
  - `F`: 8 starts, ordinary and stressed conditions, no player;
  - `F-nodeaths`: hardship deaths off;
  - `F-nofuel`: deaths and winter fuel off, about the S2 game;
  - `F-review`: 6 starts with the attentive, investment-first and overprotecting players;
  - all 6 years.
- **B0** had 12 starts, so shifts in `ok` counts are indicative.
- **No invariant failed in any run.**

## 1. How complex the game has become, and whether it holds

- **Cost:** the town's own tick is 3–17 ms a day (median per group), well inside budget. The stand-in player's searching, not the simulation, is the larger cost.
- **Correctness:** none of the invariants checked on this build (I1, I2, I6, I7, I14) failed on any day of any run. Determinism was checked earlier with `--repeat` (S1a), not in these runs.
- **The parts now interact:** stone and clay by land, finite forests, winter fuel, materials, deaths, and families choosing stone and brick work. Each lever shows in the results: switching fuel off or deaths off visibly changes outcomes.

## 2. Do towns form differently by land? Yes

Year 6, no player, ordinary condition:

| Land | Towns ok (F) | Median people | Hunger days | Cold days | Stone made | Bricks made |
|---|---|---|---|---|---|---|
| Balanced | 6/8 | 33 | 147 | 2 | 225 | 0 |
| Fertile valley | 6/8 | 39 | 133 | 63 | 165 | 32 |
| Forested | 4/8 | 22 | 308 | 54 | 41 | 0 |
| Marginal | 3/8 | 22 | 141 | 122 | 0 | 0 |
| Rocky highland | 2/8 | 0 | 247 | 116 | 379 | 0 |

- **What the land holds now shapes the town:**
  - stone where the rock is;
  - bricks only in fertile valleys, where the clay lies by the water;
  - neither on marginal land.
- With an attentive player, forested towns quarry the most stone (843) and build the most stone homes.
- **Viability now differs sharply by land.** Balanced and fertile sites mostly succeed; marginal and rocky mostly fail. That is D8's intent in direction. Section 4 asks whether the rocky case is intended.

## 3. Do player choices make or break towns? Yes

Year 6, 6 starts per land:

| Player | Towns ok, by land (balanced / fertile / forested / marginal / rocky) | Note |
|---|---|---|
| None (F, 8 starts) | 6 / 6 / 4 / 3 / 2 | |
| Attentive | 4 / 3 / 4 / 3 / 2 | Cuts hunger sharply (forested 308 → 52 days) and deaths |
| Investment first | 3 / 3 / 3 / 2 / 0 | More stone, more hunger and cold deaths |
| Overprotect (keeps every wood) | 1 / 0 / 0 / 0 / 0 | Ruins nearly every town |

- Choices clearly matter, in both directions.
- The attentive player's `ok` count isn't higher than no player's. Its towns are better fed but not more often "ok" by the strict measure (all founding families kept, all housed, fed this past month).

## 4. Problem found: cold sites collapse, mostly through hunger

- **Six of the eight rocky towns empty completely** (every family leaves) by year 6. Marginal towns suffer the same way (122 cold days).
- **With winter fuel off, all eight rocky towns survive** (median 49 people, 1,501 stone quarried), so fuel is the trigger.
- **Traced** (`tests/sim/fuel_trace.gd`, rocky start 2, a cold site at temperature 0.31 with plenty of woods):
  1. Hearths burn even in spring at a cold site, so the expedition's 45 wood is gone at once and the town has 34 fuel-short days in its first three months.
  2. Cold reviews (6 in the first months) move families into wood work: 3 of 5 families are woodcutters by day 90, and others give 30% of their day to gathering wood.
  3. Food work falls, cold days cost working days, and hunger drives families away: 5 → 3 by day 180, all gone in year 2.
  4. Meanwhile wood piles up (300–500) with no use: the cold has passed, but nothing brings families back from wood to food in time.
- **My reading:** part of this is intended disadvantage (a cold, poor site *should* be hard to found on, D8). Part looks like a defect: survival-first for cold overshoots. It trades the town's food for wood it then can't use, and once the cold has passed nothing pulls families back to food in time.
- **Options for the owner:**
  - **a.** Accept as intended hardship.
  - **b.** Let families weigh the town's wood stock against the coming need before taking up wood work for cold (the cold trigger and pull would ease once the store covers the season), and treat wood beyond the coming winter's need as oversupplied, so families return to food.
  - **c.** Give a founding expedition at a cold site some winter fuel, as it brings food (a founding-stores change, not an equaliser).
  - I'd recommend b, possibly with c, and re-measuring rocky and marginal sites before deciding what is intended.

## 5. Other observations

- **Deaths reduce mouths as well as people:** with deaths off, fertile valleys did worse (3/8 ok, against 6/8 with them), because families in hardship lingered and then left. Small samples; not a defect.
- **The stressed first winter** now costs more on every land than in B0 (where it was mild), so the test plan's stress condition is now a real test.

## Status of S3–S5

- **Built and validated:** S3 winter fuel, S3b fatal hardship, S4 materials (with the S4 review fix), S5 clay and lime. Their individual reports are in this folder; this review is their final comparison.
- **They stay Active, not Complete,** until the owner decides on section 4. If option b or c is chosen, it would be a Track A follow-up sprint, measured against these runs.
