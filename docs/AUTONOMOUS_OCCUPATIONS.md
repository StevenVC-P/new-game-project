# Autonomous Occupations and Survival-Aware Work Decisions

**Status: implemented (2026-11-01), awaiting owner review.** Branch `feature/autonomous-occupations`, from `develop`. Not merged.

Code:
- `scripts/domain/building_tiers.gd`: the three new hand-work stages.
- `scripts/domain/family_initiative.gd`: occupations, land in reach, shortages, hardship.
- `scripts/domain/occupation_review.gd`: early reviews for a shortage or a family's own hunger.
- `scripts/domain/economy_balance.gd`: build cost and work for the new stages only.

Tests:
- `tests/autonomous_occupations_validation.gd`: the rules.
- `tests/founded_town_regression.gd`: gameplay, one founded town for a year.
- `tests/town_sidebar_validation.gd`: now deterministic, interface only.

Comparison: `tests/sim/occupation_check.gd`. Owner's town: `tests/sim/autosave_replay.gd`. Commands in `docs/TESTING.md`.

## Third Round (2026-11-01): Reasoning Corrections, the Full Comparison, Player Agency

The player agency audit has its own document: `docs/PLAYER_AGENCY_AUDIT.md`.

**Owner decisions:**
- **Approved:** narrow shortage recognition and survival awareness.
- **Under evaluation:** the new trades. Herding makes clothing only.
- **To fix:** two reasoning problems, without forcing anyone off their work:
  - the old food judgement counting empty farms;
  - families valuing workplaces whose resources are gone.
- **The comparison asked for:** five modes on the same seeds, with the corrections' effects reported separately.

### The two corrections

1. **The food judgement uses work actually done** (`FamilyInitiative.get_food_ratio`, `get_working_output`).
   - **Where it is used:** "The town grows less food than it eats / plenty of food", in first choices and in the review's oversupply reason.
   - **What it counts now:** only work a family does or has claimed, on its land, at its pace (hands, skill, the share of its day left after walking and other work), and at hand pace where short of tools.
   - **Shared:** the survival outlook uses the same count.
   - **The old count:** meta `food_ratio_counts_empty`.
2. **A holding is worth what its land still yields** (`OccupationReview.get_holding_worth`).
   - **What scales:** "it has built up its …" and "its … would stand idle" scale with the share of a full yield the workplace's water, woods or pasture still gives ("…, though its land yields little now").
   - **What stays in full:** its years at the work, its skill, its calling and convictions. A family may still stay.
   - **Fields, woodcutters and workshops** are unaffected (their land is judged elsewhere).
   - **The old weighting:** meta `stay_value_ignores_yield`.

**Tests:**
- **Fixtures:** the review tests' fixtures now work at full pace without skill (`economy_no_proficiency_effects`). Their subject is the review rules, and their premise ("food to spare") is about how much the town grows. Before, families with no skill were counted at full pace by the old judgement.
- **New checks:** `tests/autonomous_occupations_validation.gd` covers both corrections.

### Five modes, six years (people; towns kept of 12)

All modes but "existing" include the two corrections.

| | 1. Existing | 2. Narrow recognition | 3. Survival awareness | 4. Recognition + survival | 5. All (new trades too) |
|---|---|---|---|---|---|
| **Ordinary** | 57.8 (10) | **61.9 (11)** | 38.4 (9) | 60.8 (11) | 57.6 (10) |
| **Stressed** | **63.2 (10)** | 62.8 (10) | 24.7 (5) | 57.3 (10) | 49.0 (9) |
| **Difficult** | 42.8 (7) | 45.9 (8) | **52.2 (9)** | 41.1 (9) | 51.2 (9) |

| Ordinary / stressed / difficult | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| days out of food | 104 / 107 / 128 | 96 / 131 / 120 | 143 / 204 / 91 | 81 / 106 / 97 | 126 / 140 / 108 |
| days out of tools | 168 / 236 / 818 | 229 / 297 / 720 | 1107 / 1239 / 952 | 392 / 550 / 552 | 328 / 422 / 799 |
| towns never making tools | 1 / 1 / 2 | **0 / 0 / 1** | 4 / 5 / 1 | 0 / 1 / 0 | 1 / 1 / 2 |
| trades per town | 2.5 / 2.4 / 1.8 | 2.7 / 2.6 / 1.8 | 2.2 / 1.3 / 2.2 | 2.7 / 2.4 / 2.1 | 3.8 / 3.7 / 3.4 |
| months clothing unmet | 69 / 65 / 52 | 69 / 68 / 52 | 66 / 56 / 57 | 67 / 67 / 61 | 44 / 49 / 39 |

### The corrections' effects, separately

| People | Without the corrections | With both | Food judgement only | Staying worth only |
|---|---|---|---|---|
| **First three trades (existing)** | 57.8 / 63.2 / 42.8 | 44.3 / 43.8 / 44.4 | (the same; the staying correction does not apply without land trades) | — |
| **All (new trades)** | 51.8 / 41.7 / 44.8 | **57.6 / 49.0 / 51.2** | 61.2 / 48.5 / 45.6 | 51.8 / 46.5 / 42.5 |

- **With the full rules,** the corrections are worth +6 to +7 people in every condition. Most comes from the food judgement. The staying correction alone helps stressed towns (+4.8), where hunting lodges lose their woods.
- **The food correction alone, without shortage recognition, makes towns worse** (−13 to −19 on ordinary and stressed sites, 3 towns never making tools).
  - **Why:** judging food honestly, families see more often that the town grows less than it eats. More choose food work and stay at it, and no one takes up tools.
  - **What fixes it:** paired with narrow recognition, which lets them see the tool danger too, it is the best mode on ordinary sites (61.9).
  - **So:** the food correction should ship only with shortage recognition.
- **Survival awareness without shortage recognition collapses stressed towns** (24.7), for the same reason, more strongly. The old food term ("the town grows less food than it eats", up to +3.75) and the survival term (up to +4) now weigh the same hunger twice, so a family may set aside every other need. That double count is decision 3 below.
- **Callings and geography** (mode 5, as in the second round): water families fish, loom families herd, forest and shield families hunt. Lake towns build fisher-and-farm economies, wooded towns hunt, open farmland farms and herds.
- **Player priorities change outcomes:**
  - **Investment from founding** gives difficult sites 64.2 people and 11 towns kept (against 51.2), but costs ordinary sites 14 people.
  - **Answering every warning promptly** does worse than no player (`docs/PLAYER_AGENCY_AUDIT.md`).

### The owner's town (day-82 autosave, replayed two years)

- **The newcomer now farms.** It judges the town's food "only just enough" (+1.5), not "plenty" (−1.5), and takes up a garden instead of a grazing pen.
- **The Investment priority decides the tool response.**
  - **With it:** family 0 (muse) leaves its farm for tool mending on day 112, margin 3.27. Without the priority's +2.0 it would be 1.27 against the 2.0 needed.
  - **Priority cleared:** the families weigh the shortage 49 times in two years and keep their work; tools wait until day 687.
- **Outcome:** all three rule sets end at 37 people at day 802.

### Before Merging (owner decisions)

**What improves simulation correctness:**
- narrow shortage recognition;
- survival awareness;
- the food judgement from work actually done;
- a holding worth what it yields;
- the hunger reason for review;
- the deterministic sidebar test, and the gameplay regression kept apart from it.

**What improves player agency:**
- **Real influence:** priorities now have measurable, decisive effects. The Investment priority is what gets the owner's town making tools.
- **Not yet meaningful:** the warnings the player sees do not suggest controls that help (`docs/PLAYER_AGENCY_AUDIT.md`). No new control was built; five proposals await decision there.

**Unresolved:**
1. **What to merge:**
   - **Recommended:** modes 2 + corrections (narrow recognition, both corrections), or 4 (with survival awareness), both with the first three trades. These are the strongest and most even modes.
   - **The new trades:** they make towns differ by land and calling, and cost stressed sites 14 people against today's game.
2. **The food correction depends on shortage recognition.** Merge them together, or not at all.
3. **The double count of hunger** (the old food term and the survival term). Options:
   - leave it;
   - let the survival term replace the old food term when survival awareness is on;
   - cap the two together.

   Not changed without the owner.
4. **The agency proposals** (`docs/PLAYER_AGENCY_AUDIT.md`): two warning cards (interface only), woods kept for the town, narrower asks, rationing.
5. **Flaky tests on `develop` as well:**
   - `save_game_validation`, where an errand route's layout counter is off by one after loading: 1 failure in 3 runs on `develop`, and passed 3 of 3 on the branch when run alone;
   - `community_play_validation`, which failed once while running alongside other tests and passed alone.

## Owner Briefs and Decisions

**First brief (2026-11-01):** carry out the corrections in `docs/WORKPLACE_CHOICE_INVESTIGATION.md`. Every viable occupation open to autonomous families, none guaranteed. Families recognise economic danger without automatically solving the town's problems.

**Second brief (2026-11-01), after the first comparison** (history at the end):
1. **Shortage recognition:** the narrow version is approved and is the default. Emergency reconsideration and a family's first choice of work are separate decisions.
2. **First choices:** families should weigh whether the settlement can sustain itself before committing to work, from these, with no hard rule and mistakes allowed:
   - food in store and coming against what the town eats;
   - the seasons and the coming winter;
   - who already grows food;
   - essential trades, tools included;
   - realistic opportunities on the land;
   - the family's calling, skill, temperament and values.

   **The design principle:** calling drives the pursuit of prosperity; growing hardship makes survival matter more. Enterprising families may seize an opportunity, cautious ones put security first, and a desperate family tries some feasible response before it starves.
3. **The new occupations stay** (grazing pen, fish weir, snare line). Herding makes clothing only. No livestock. Production and upkeep numbers unchanged.
4. **Matched comparison:** four modes (existing, narrow shortage, occupations, both), ordinary, stressed and difficult sites, six years. Don't tune to restore survival numbers; find whether failures are understandable choices or defective reasoning.
5. **Replay the day-82 autosave.**
6. **The sidebar test:** make it deterministic without hiding simulation failures, and keep gameplay regression apart from interface validation.

## What Changed

### 1. Every trade with a hand-work stage is a family's choice

- **Three hand-work stages** (`BuildingTiers.TIER0_TO_TIER1`):
  - fish weir → fisher's hut;
  - snare line → hunter's lodge;
  - grazing pen → herder's fold (wool, for clothing).

  Like all hand work they need no materials (2–3 family-days), make a third of the proper output, need no upkeep, and take their placement, land yield, wolves and callings from the proper workplace. No art of their own yet: they draw as their proper building, washed toward earth. The player can plan them from the hand-work list.
- **Occupations come from the data** (`FamilyInitiative.get_occupations`): every proper workplace with a hand-work stage that makes a good. A future trade becomes a family's choice by adding its stage, with no decision code of its own. Trades are weighed by the good they make:
  - calling;
  - the town's need for the good;
  - skill;
  - the priority's ask;
  - Prepare for Hard Times.
- **What the town only goes without** (wool for clothing) pulls less than what it lives on: +0.5 when no one makes it, +1 when the need goes unmet.
- **Land:**
  - Work that lives off the land is a choice only where a site exists.
  - The site is drawn toward richer water, woods or pasture.
  - Poor yield deters: "little game in reach", "it yields less than other ways of getting food". Good land never makes it better than the best food work.
- **Hand work first:** families start by hand and improve through the same pipeline and stores rule.

### 2. Survival before prosperity (`FamilyInitiative.get_hardship`)

- **The town's food outlook** (`get_food_outlook`): over the coming 120 days, the food in store and in families' larders, plus what the town's food work will bring in:
  - **only work a family does or has claimed**, at that family's real pace (its hands, skill, and the share of its day left after walking, spare time and secondary work);
  - on its land;
  - through the seasons ahead (a winter coming yields less);

  all against what the town will eat. The shortfall is 0 (enough) to 1 (nothing).
- **Temperament** weighs the town's outlook:
  - cautious: up to +50% (very cautious);
  - daring: −10% a step;
  - ambitious: −10% a step.
- **A family going hungry itself** (`short_days_this_month`, 10 days = fully desperate) weighs its own hunger in full, whatever its temperament.
- **What hardship does** to a family's choice of work:
  - **Calling yields:** up to half of the calling's pull (for or against) is set aside ("it is the family's calling, though survival comes first now").
  - **Clothing waits:** the pull of a need the town only goes without fades to nothing.
  - **Food work gains a survival reason:** 4 × the hardship × what that work would really bring in, against the best any food work brings in by hand ("the town will go hungry before the next harvest is in"). It counts the land in reach, the family's skill and the coming seasons, so snares in thin woods relieve less than a garden.
- **No rule:**
  - Herding, toolmaking and every other trade stay open.
  - A family of the loom in a starving town would rather grow food, but may still herd if the rest of its reasons are strong.
  - In a fed town hardship is 0, and calling and opportunity decide as before.

### 3. Narrow shortage recognition (owner-approved default)

- **What it is** (`get_shortage`): a good the town uses up that **no one here makes**, about to run out within the season (90 days).
  - **What the town uses up:** food eaten, tool upkeep its proper workplaces will draw after their grace, and what its workplaces consume.
  - **How it weighs:** 4 × the shortage as a term in choosing work.
  - **Early review:** a quarter missing starts one, after 30 days at the work (not 180) and 90 days after the last look (not 360).
- **Not this danger:** a deficit in a good the town does make. That is weighed in first choices (section 2). The broad version, kept for comparison, is meta `shortage_counts_deficits`.

### 4. A hungry family looks at its work again (`OccupationReview`, reason `hungry`)

- **The trigger:** a family that has itself gone short of food 5 or more days in each of two months running looks at its work again, without waiting for tenure or its year (as for a shortage).
- **The weighing:** its hunger makes survival weigh more than its calling. It changes only when the other work wins by 2, as in every review.
- **Why it was added:** the comparison traced hunting families whose woods were felled around them. They went hungry for months and never reconsidered, because none of the review's reasons applied.
- **Switch:** part of survival awareness (`no_survival_awareness` turns it off).

### 5. Tests

- **The sidebar test** founds the same town every run (`FOUNDING_SEED` for the game's random numbers), and its card checks set the food state they test. Before, its town was founded at random, and it failed on `develop` in 2 of 4 runs.
- **The gameplay regression** (`tests/founded_town_regression.gd`) plays that same town for a year. It must keep its founding families, be fed on the last day, and have a family in a proper home.
- **Both trees:** both tests pass on the branch and on `develop`, identically on repeated runs.

### Comparison switches

City metas, comparison only:
- `occupations_first_three`;
- `no_shortage_recognition`;
- `no_survival_awareness`;
- `shortage_counts_deficits`;
- `occupations_left_out`.

With the first three set, the branch plays as `develop`: 96 of 96 town snapshots identical (`wisdom_check`, ordinary and stressed, two years, with and without the investment priority).

## Validation

**Method.**
- **Towns:** `tests/sim/occupation_check.gd` on the wisdom check's 12 towns (identical seeds, founders and maps across modes), families leading, the social model on, the stand-in building only homes and shared works.
- **Conditions:** ordinary, stressed (the first winter's stores lost), and difficult sites.
- **Length:** six years.
- **Modes:**
  - "existing": today's game;
  - "shortage": narrow recognition only;
  - "occupations": the new trades with survival awareness;
  - "both";
  - **diagnostics:** "survival only" (survival awareness with the first three trades) and "occupations, blind" (the new trades without survival awareness, the first comparison's mode).

**How the weights were reached.** Three things were found in diagnosis and corrected before the final runs. They are reported because they changed results:
1. **Families counted empty workplaces as feeding the town** (a smoke run, then a food audit). In one town three of four farms stood empty and families still saw plenty. Actual food was 0–9% of what the outlook counted, and 8–13% in the first season, when families build, are novices and walk. The outlook now counts only worked or claimed work at its real pace (section 2). The older food term, `get_food_ratio` ("the town grows plenty of food"), has the same flaw and is unchanged: decision 3.
2. **Hungry families never looked again** (the trace above). The hunger reason was added (section 4).
3. **The survival weights** (4, 0.5, 120 days) were set before any measured run and not changed after.

### Six years (people; towns kept of 12)

| | Existing | Shortage | Occupations | **Both** | Survival only | Occupations, blind |
|---|---|---|---|---|---|---|
| **Ordinary** | 57.8 (10) | 56.1 (10) | 42.4 (6) | **51.8 (9)** | 67.5 (11) | 42.7 (7) |
| **Stressed** | 63.2 (10) | 59.7 (10) | 39.7 (8) | **41.7 (8)** | 56.2 (10) | 41.3 (6) |
| **Difficult** | 42.8 (7) | 46.3 (8) | 36.3 (7) | **44.8 (8)** | 47.4 (8) | 17.9 (4) |

| Ordinary / stressed / difficult | Existing | Shortage | Occupations | Both |
|---|---|---|---|---|
| days the town ran out of food | 104 / 107 / 128 | 100 / 118 / 104 | 212 / 216 / 135 | 124 / 151 / 119 |
| family-days short of food | 532 / 554 / 606 | 510 / 585 / 451 | 967 / 1056 / 621 | 599 / 707 / 541 |
| days out of tools | 168 / 236 / 818 | 167 / 235 / 557 | 573 / 778 / 1104 | 173 / 326 / 658 |
| towns never making tools | 1 / 1 / 2 | **0 / 0 / 1** | 2 / 3 / 4 | 1 / 1 / 1 |
| tool shortages followed by tool work | 1 of 2 / 2 of 3 / 6 of 8 | 2/2, 3/3, 7/8 | 3/5, 3/6, 5/9 | 3/4, 5/6, 8/9 |
| months clothing went unmet | 69 / 65 / 52 | 69 / 63 / 52 | 48 / 48 / 32 | 38 / 39 / 30 |
| trades worked per town | 2.5 / 2.4 / 1.8 | 2.5 / 2.4 / 1.9 | 2.7 / 2.8 / 2.6 | 3.5 / 3.2 / 3.2 |
| reviews (changes) per town | 3.9 (0.1) / 5.9 (0.1) / 4.2 (0.3) | 4.8 (0.2) / 4.8 (0.2) / 5.6 (0.6) | 21 (0.9) / 24 (0.8) / 14 (0.3) | 17 (1.0) / 18 (0.9) / 18 (1.2) |

### What the numbers say

1. **Survival awareness works.**
   - **With the first three trades,** it is the best mode on ordinary sites: 67.5 people, 11 towns kept, food-short days 104 → 74.
   - **With the new trades,** it halves their cost on difficult sites (blind 17.9 → 36.3; with shortage recognition, 44.8, above today's game).
   - **At founding,** families now take up food work when the town cannot feed itself. In the town traced, every founder took food work, and the forge family still took up tools.
2. **Narrow shortage recognition** closes the tool gap and costs little: ordinary −1.7 and stressed −3.5 people, difficult +3.5 and one more town kept. Together with the new trades it is what keeps toolmaking alive: days out of tools 573 → 173 on ordinary sites.
3. **Both against today's game:**

   | Sites | Change in people | Towns kept |
   |---|---|---|
   | difficult | +2.0 | +1 |
   | ordinary | −6.0 | −1 |
   | stressed | **−21.5** | −2 |

   The towns differ more: 3.2–3.5 trades each against 1.8–2.5. Clothing goes unmet half as often.
4. **Understandable choice or defective reasoning?**
   - **Fixed:** the two defects found (empty workplaces counted; no reason for a hungry family to look again).
   - **What remains:** the stressed gap is mostly four towns where founders took up hunting. Founding goes as intended: food work, a toolmaker. Over three to four years the town's woodcutter fells the woods round the hunting lodges (reach 1.0 → 0.33), and food falls to 61% of what the town eats.
   - **What the hungry hunters do:** they now look again, but stay by a wide margin (about −8). Their calling, their skill, "it has built up its hunter's lodge" (+3), years there (+1.5) and the lodge standing idle (+1.5) outweigh their hunger and a farm they would work as novices.
   - **The judgement:** the staying weights count an investment at full value when the land under it no longer yields. A lodge in felled woods is not worth what it was. That is arguably a reasoning gap rather than a choice. The weights are the owner-approved reconsideration weights, so they were not changed: decision 2.
   - **The rest is understandable:** families follow callings into work that yields less than farming in good times (stressed sites lose the winter's stores and so have no slack), and woodcutters and hunters compete for the same woods.
5. **Callings and values shape the economy** (all conditions, year 6):

   | Calling | Existing | Both |
   |---|---|---|
   | water | farm 85% | fisher 42%, farm 36% |
   | loom | farm 88% | herder 44%, farm 44% |
   | forest | woodcutter 66% | hunter 40%, woodcutter 36% |
   | shield | farm 65% | hunter 54% |
   | soil | farm 98% | farm 80% |
   | forge | toolmaker 74% | toolmaker 44% |
   | hearth (no material calling) | farm 92% | farm 74% |

   Families on work of their calling: 34–37% today, 35–47% in "both".
6. **Geography makes different economies** ("both", towns that kept their families, year 6):
   - **Lake and river towns fish:** 1,306 water tiles gives farm 8, fisher 8, herder 4, 111 people; 27 water tiles gives farm 10, fisher 8, 98 people.
   - **Wooded towns hunt:** 1,500 woods gives farm 8, hunter 6, 96 people.
   - **Open farmland farms and herds:** 906 fertile tiles gives farm 17, herder 3, 97 people.

   Today every town is mostly farms.
7. **Food coverage as the old term sees it** (`get_food_ratio`) stays at 2–5× in every mode, while towns go hungry 100–200 days. It overstates real production (point 1 of "How the weights were reached"), so it is not a fair measure of coverage; the hunger days are.

### Priorities ("both", set at founding and kept for six years)

| People (towns kept) | No priority | Productive investment | Food security |
|---|---|---|---|
| ordinary | 51.8 (9) | 45.1 (8) | 46.7 (8) |
| stressed | 41.7 (8) | 38.2 (7) | **49.8 (8)** |
| difficult | 44.8 (8) | **31.5 (6)** | **48.0 (8)** |

- **Priorities change outcomes, in both directions.**
  - **Food security** helps where food is the danger: stressed +8, difficult +3, food-short days unchanged or fewer. It costs tools (days out 326 → 713 on stressed sites) and wood work.
  - **Productive investment** costs people everywhere: ordinary −7, stressed −4, difficult −13. Families improve hand work and take up tools (most tool shortages followed by tool work, no town without toolmaking), but they lean away from food early.
- **The trades follow:** under investment, more lodges and toolmakers; under food, more farms and fewer woodcutters.
- **Setting the priority at founding has lasting effects:** it is an ask, weighed by each family's receptiveness, but it steers founders' first choices, and those shape the town for years.

## The Owner's Town (day-82 autosave, replayed two years)

A copy of the autosave was replayed alone (no neighbours or trade routes) under each mode, every work decision traced, with and without the priority's ask.

**At the start:**
- **Stores:** 8 tools, with six proper workplaces about to need upkeep (shortage 0.53), and 26 days of food in store.
- **Food:** five farms grow plenty for the year (hardship 0).
- **Rules:** the Productive investment priority, "priorities first" stores rule.
- **Families:** families 0–5 work; newcomer family 6 (deep_earth/soil) is free.

| Mode | First tool work | What decided it | Day 802 |
|---|---|---|---|
| Existing | day 687 | A newcomer, 605 days later. Tools stayed at 0–2 for a year and a half. | 37 people |
| Shortage | day 85 | The newcomer took up tool mending: toolmaker 3.76 against farm 3.43. **The priority tipped it:** without the ask it farms. | 37 |
| Shortage, priority cleared | day 112 | Family 0 (muse calling: nothing ties it to farming) saw the danger in an early review and left its farm, margin 2.77. No priority involved. | 37* |
| Both | day 112 | The newcomer took up a grazing pen (its calling; the town was fed, so survival did not weigh). Family 0 left its farm for tools on day 112. The priority added 2.0, but it changed without it too. Family 2 (loom) moved to herding on day 202. | 33, 23 days of food |
| Both, priority cleared | day 112 | As "both". | 31* |

\* The priority-cleared replays fund no improvements: the "priorities first" stores rule with no priority funds nothing. Compare their decisions, not their outcomes.

**The owner's questions:**
- **How do families respond to the approaching tool shortage?**
  - **Today:** no one can until day 687.
  - **With recognition:** every working family has the shortage among its reasons. The one with no stake in its farm acts within a month. The families of the soil weigh it and keep their farms.
- **Do they establish sustainable food production?**
  - **Shortage only:** yes. Five to seven farms, 200+ days of food at day 802.
  - **Both:** food is thinner (23 days in store at day 802). Two families herd for clothing while the town is fed, as the design allows, and the store runs down without hunger yet.
- **Does the Investment priority change any consequential decision?**
  - **Once:** the newcomer's first choice in "shortage" (tools instead of a farm).
  - **Not decisive elsewhere:** in every other mode it adds weight but decides nothing, and it starts no review.

## For the Owner (before merging)

1. **What to merge.** Each part switches off on its own.
   - **Recommended:** narrow shortage recognition and survival awareness. Together with the first three trades they are the best mode measured on ordinary sites, and close the tool gap.
   - **The new trades:** they make towns differ by land and calling, and halve unmet clothing, but cost stressed towns about 21 people and ordinary towns 6.
2. **The staying weights for land that has failed.** A family's built-up workplace, its years there and the workplace left idle count in full even when the land under it no longer yields (a lodge in felled woods). The recommendation is to scale them by the workplace's current yield, but they are the weights approved for reconsideration, so it is the owner's call. Expected effect: hungry hunters leave failing lodges for farms, which addresses most of the stressed gap. Not built or measured.
3. **The old food term** (`get_food_ratio`, "the town grows plenty of food", used in first choices and the oversupply reason for reviews) counts empty workplaces and full pace, like the outlook did before its correction. Correcting it changes today's game too. Not done.
4. **Woodcutters fell hunting grounds.** The two trades compete for the same woods with nothing to mediate it. Families could weigh it (a hunter's family opposing felling near its lodge, or woodcutters cutting elsewhere), or it could be left as a real conflict.
5. **Hand-work art** for the three stages, when wanted.

## Remaining Limitations

- **Families judge shortages by the store they see:** mending families do for themselves is not counted.
- **Work history** (`Household.work_history`) records goods: a family moving from farming to fishing records food twice.
- **Shared woods:** several lodges in the same woods each count the whole woods.
- **Fishing is rare:** only one ordinary site and two difficult sites have water in reach.
- **Saves:** no new saved fields; old saves load unchanged. Each family's monthly strain gains a "hungry" count.
- **Tests:** the full headless suite passes on the branch: 44 scripts, including the new rules test and the gameplay regression, plus the wrapped expanded-goods test.

## History: the First Comparison (superseded)

The first brief's comparison (before survival awareness, with the broad shortage, which counted food deficits too) found:
- **The new trades cost** a quarter to over half of towns' people. Families followed callings into hunting and herding during a founding year with no slack.
- **Broad recognition cost stressed towns 11 people.** The narrow version, measured beside it, did as well on tools without that cost.
- **Three errors were corrected in that first smoke run:**
  - the land term rewarded hunting above farming;
  - clothing pulled as hard as hunger;
  - the town's food count ignored the land.

The owner then approved the narrow version and asked for survival-aware first choices (above).
