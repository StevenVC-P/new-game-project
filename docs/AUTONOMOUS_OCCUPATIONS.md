# Autonomous Occupations and Economic Adaptation

**Status: implemented (2026-11-01), awaiting owner review.** Branch `feature/autonomous-occupations`, from `develop`. Not merged.

Code:
- `scripts/domain/building_tiers.gd`: the three new hand-work stages.
- `scripts/domain/family_initiative.gd`: occupations, the land in reach, essential shortages.
- `scripts/domain/occupation_review.gd`: the early review in danger.
- `scripts/domain/economy_balance.gd`: build cost and work for the new stages only.

Tests: `tests/autonomous_occupations_validation.gd`. Comparison: `tests/sim/occupation_check.gd`. Owner's town: `tests/sim/autosave_replay.gd`. Commands in `docs/TESTING.md`.

Brief (owner, 2026-11-01): carry out the corrections in `docs/WORKPLACE_CHOICE_INVESTIGATION.md`. Every viable occupation should be open to autonomous families and none guaranteed. Families should recognise economic danger and respond to it with their own preferences, skills and convictions. They should not automatically solve the town's problems.

## What Was Found Before Building

- **The hand-work stages did not exist.** Nothing in the code or docs had a grazing pen, fish weir or snare line. A fisher's hut, hunter's lodge and herder's fold existed only as proper buildings the player places.
- **Hand work inherits nearly everything from its proper workplace** through `BuildingTiers.get_base_type`: footprint, placement rules (water beside a weir, woods near a snare line), a third of the output, land yield, wolves, callings and proficiency.
- **What was hardcoded:** families chose only among `FamilyInitiative.ACTIVITIES` (food, wood, tools), each tied to one workplace (`HAND_WORK`, `PROPER_WORK`). One word meant both the good and the trade.

## What Changed

### 1. Every trade with a hand-work stage is a family's choice

- **Three hand-work stages** (`BuildingTiers.TIER0_TO_TIER1`):
  - fish weir → fisher's hut;
  - snare line → hunter's lodge;
  - grazing pen → herder's fold.

  Like all hand work they need no materials (2–3 family-days of work), make a third of the proper output, and need no tool upkeep. They draw as their proper building, washed toward earth (no new art yet). The player can plan them from the hand-work list too.
- **Occupations come from the data.** `FamilyInitiative.get_occupations` is every proper workplace with a hand-work stage that makes a good: farm, woodcutter, toolmaker, fisher, hunter, herder. A future trade becomes a family's choice by adding its stage to `BuildingTiers`, with no decision path of its own.
- **Trades are weighed by the good they make,** with the same terms as before:
  - calling;
  - the town's need for the good;
  - what the family knows;
  - the priority's ask (a food priority asks for fishing and hunting as much as farming);
  - Prepare for Hard Times.

  Goods other than food, wood and tools (today only wool) use one shared rule (below).
- **Land:**
  - **No site, no choice.** Work that lives off the land is weighed only where a site exists, so a town without water never sees fishing.
  - **The site** is chosen near home, drawn toward richer water, woods or pasture.
  - **Poor yield deters.** The family weighs what the work would yield there against the best any trade yields of that good: "little game in reach", "it yields less than other ways of getting food".
  - **Good land never makes such work better than the best.**
- **Families still start with hand work and improve it later** through the same pipeline and stores rule as before. Nothing is built finished, and no family is directed to a trade.
- **Callings:** a family whose calling is herding, fishing or hunting now has calling work it can take up itself. Its first choice and its reconsideration both include those trades (`OccupationReview.is_against_calling`).

### 2. Recognising an essential shortage

- **What counts** (`FamilyInitiative.get_shortage`): a good the town uses up that no one here makes, where what is in store won't cover the coming season (90 days). It runs from 0 to 1. "Uses up" means:
  - food eaten;
  - tool upkeep its proper workplaces will draw once their grace is over;
  - what its workplaces consume (wood for tools).

  A good the town only goes without (wool for clothing) is never an essential shortage.
- **Seeing it:** the danger is a term in choosing work, 4 × the shortage: "the town will run out of tools within the season, and no one here makes any". It competes with calling (+3 or −2), knowing the work (up to +2), and what a family has built up (+3 for a proper workplace). It does not override them.
- **Looking again early** (`OccupationReview`):
  - **The trigger:** a quarter of the season's need missing starts a review.
  - **Waiting:** after 30 days at the work instead of 180, and 90 days after the last review instead of 360.
  - **What the family weighs:** the same as any review. It changes only when the other work wins by 2 or more.
  - **Limits:** at most one family a month in the town changes.
  - **When the danger passes:** once anyone takes up the work, no one else looks again for it. A family brought forward by the danger does not look again early for its other reasons.
- **What cannot start a review:** a Community Priority or a Guiding Wisdom still never starts one. The danger is read only from the stores and workplaces. The priority's ask is still one of the reasons once a family is reconsidering.

### 3. Unchanged

Tool output, upkeep numbers, every proper workplace's cost and output, the improvement threshold, the review's change margin and monthly limit, and proficiency are all unchanged. A cautious family may still take years to improve, and a town may still lack a trade.

## Validation

**Method.** `tests/sim/occupation_check.gd`:
- **Towns:** the wisdom check's 12 towns (seeds, founders and maps identical across modes), families leading, the social model on, and the stand-in player building only homes and shared works.
- **Conditions:** ordinary, stressed (the first winter's stores lost), and difficult sites.
- **Length:** six years, with a year-3 snapshot.
- **Modes:** "existing" (switches off), "occupations" (the new trades only), "shortage" (recognition only), and "both".

**"Existing" is today's game.** With both switches off, `wisdom_check` produced the same towns as `develop` in all 96 snapshots compared: ordinary and stressed, two years, with and without the investment priority.

**Weights.** They were fixed before the measured runs, but not before every run. A two-year trial run of the first version collapsed most towns (1 of 12 kept with the new trades). That exposed three errors in the decision terms, which were corrected before the measured comparison:
1. **The town's food count ignored the land.** A snare line counted at full yield whatever the woods.
2. **The land term rewarded fishing and hunting above farming.** Good land gave up to +1.2, which farming cannot get. It now only deters: what the work yields there against the best any work yields of that good.
3. **Clothing pulled almost as hard as hunger.** Wool's terms (+2.5) nearly matched the town growing less food than it eats (+3). A need the town only goes without now weighs +0.5 / +1.0.

After the trial, the shortage was also widened from "no one makes it" to "will run out within the season, counting what the town makes" (see "For the owner", decision 2). Nothing was changed after the measured runs.

### Six years (year-3 numbers in brackets where they differ in kind)

| | Ordinary | | | | Stressed | | | | Difficult | | | |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| | existing | occ. | shortage | both | existing | occ. | shortage | both | existing | occ. | shortage | both |
| towns kept (of 12) | 10 | 7 | 10 | 7 | 10 | 6 | 9 | 6 | 7 | 4 | 8 | 6 |
| people | 57.8 | 42.7 | 59.6 | 35.4 | 63.2 | 41.3 | 52.3 | 33.7 | 42.8 | 17.9 | 37.4 | 29.2 |
| families departed | 3.3 | 4.9 | 3.0 | 4.8 | 3.2 | 5.3 | 3.8 | 4.1 | 3.4 | 5.3 | 3.2 | 4.3 |
| days the town ran out of food | 104 | 199 | 102 | 191 | 107 | 196 | 163 | 195 | 128 | 226 | 101 | 163 |
| family-days short of food | 532 | 911 | 565 | 895 | 554 | 923 | 750 | 911 | 606 | 976 | 431 | 709 |
| months clothing unmet | 69 | 38 | 69 | 35 | 65 | 30 | 64 | 30 | 52 | 27 | 52 | 27 |
| months short of tools | 6.2 | 26.3 | 6.9 | 23.3 | 8.6 | 28.6 | 14.2 | 26.3 | 30.1 | 53.4 | 21.3 | 37.3 |
| days out of tools | 168 | 755 | 132 | 627 | 236 | 823 | 379 | 732 | 818 | 1522 | 557 | 1032 |
| towns short of tools / tool work began after / recovered | 2/1/1 | 5/2/1 | 3/3/2 | 5/5/1 | 3/2/1 | 5/1/0 | 4/4/1 | 6/6/1 | 8/6/3 | 11/5/1 | 8/7/4 | 10/10/4 |
| towns that never made tools | 1 | 3 | **0** | **0** | 1 | 4 | **0** | **0** | 2 | 6 | 1 | **0** |
| reviews (for a shortage) | 3.9 (0) | 6.8 (0) | 5.4 (0.5) | 10.2 (5.0) | 5.9 (0) | 6.1 (0) | 6.7 (0.5) | 10.0 (5.3) | 4.2 (0) | 4.7 (0) | 5.8 (4.7) | 17.2 (15.7) |
| changes of work (for a shortage) | 0.1 | 0.3 | 0.3 (0.2) | 0.9 (0.9) | 0.1 | 0.2 | 0.3 (0.2) | 1.0 (0.9) | 0.3 | 0.2 | 0.2 (0.2) | 0.7 (0.6) |
| trades worked per town | 2.5 | 3.1 | 2.6 | 2.8 | 2.4 | 2.5 | 2.2 | 2.6 | 1.8 | 1.2 | 1.9 | 2.4 |
| towns >5 people worse / better than existing (same seed) | | 5 / 2 | 1 / 2 | 6 / 1 | | 6 / 2 | 3 / 1 | 6 / 2 | | 6 / 1 | 3 / 2 | 5 / 3 |

**Work families do (ordinary, year 6, per town; improved share).**
- **Existing:** farm 10.5 (125/126), woodcutter 2.2, toolmaker 1.9.
- **Both:**
  - farm 4.9 (58/59), woodcutter 1.1, toolmaker 1.1;
  - fisher 0.7 (8/8, in the one town with water);
  - hunter 0.8 (9/9, 5 towns);
  - herder 0.8 (8/9, 6 towns).
- **Improvement:** every new trade that is taken up is improved into its proper workplace, at about the same rate as farms.

### What the numbers say

1. **Shortage recognition does what was asked.**
   - **No town is left without tool work** on ordinary or stressed sites (1 → 0), and on difficult sites 2 → 1 (0 with the new trades).
   - **Tool shortages are answered:** after a shortage, tool work began in 3 of 3 towns (ordinary), 4 of 4 (stressed) and 7 of 8 (difficult), against 1/2, 2/3 and 6/8.
   - **Difficult towns** spend 260 fewer days out of tools and have 175 fewer family-days of hunger.
   - **Few changes:** 0.2–0.3 changes of work per town in six years.
   - **The cost is on stressed sites:** 11 fewer people. Food recognition there brings families to food after the lost winter, and tools then run short later (379 days out against 236). The narrow version below separates this.
2. **Opening fishing, hunting and herding costs towns heavily, in every condition.**
   - **The size of it:** a quarter to over half the people, and 3–4 fewer towns kept.
   - **Food and tools:** twice the days without food, and four times the days without tools.
   - **The cause:** the cost is not a fault in the new work. Families follow their callings into hunting (yields less than a field), herding (no food) and fishing (only where there is water), and away from farming, woodcutting and toolmaking. Farms per town halve. The founding year has no slack: in the trace of one town, the cautious loom family that improves the town's first farm on day 7 under today's rules takes up a grazing pen instead, the first farm comes on day 30–60, and the town empties. Fewer families also take up toolmaking, while lodges, huts and folds add tool upkeep.
   - **Clothing:** better met (69 → 35 months unmet), but at that price.
3. **Together** ("both"), recognition does not make up for the trades' cost on ordinary and stressed sites (35 and 34 people). On difficult sites it recovers part of it (29 against 18). It does answer every tool shortage.
4. **Callings and values still decide, and differently** (all conditions, year 6, "both" against "existing"):

   | Calling | Existing | Both |
   |---|---|---|
   | water | farm 85% | fisher 51%, farm 35% |
   | loom | farm 88% | herder 48%, farm 36% |
   | forest | woodcutter 66% | hunter 53%, woodcutter 33% |
   | shield | farm 65% | hunter 45% |
   | soil | farm 98% | farm 80% |
   | forge | toolmaker 74% | toolmaker 59% |
   | hearth (no material calling) | farm 92% | farm 83% |

   Temperament still sets the pace of improvement (cautious families improved 95% of their hand work by year 6, daring ones 100%).

## The Owner's Town (day-82 autosave, replayed)

A copy of the autosave was replayed for two years under each mode (`tests/sim/autosave_replay.gd`). The town was replayed alone: no neighbours or trade routes. Every work decision was traced with its reasons, and with the priority's ask taken out.

**At the start (day 82):**
- **Stores:** 8 tools, with six proper workplaces about to need upkeep (17 tools of use in the coming season), so the shortage stands at 0.53.
- **The priority:** Productive investment, under the "priorities first" stores rule.
- **The families:** families 0–5 work five farms and a woodcutter. None has the forge calling. Newcomer family 6 (deep_earth/soil) is free.
- **Who sees the danger:**
  - **Without recognition:** no one.
  - **With it:** every working family has the shortage among its reasons to look again (`essential_shortage`), and each is due for an early look at day 112, after 30 days at its work.

**What happened:**

| Mode | First tool work | Who, and why |
|---|---|---|
| Existing | day 687 (605 days later) | A newcomer. Tools stayed at 0–2 for a year and a half. Around day 200 every family looked again at its work (food oversupplied) and stayed. The closest was family 2 (loom), margin 1.99 against the 2.0 needed, with the priority's ask +2.4. |
| Occupations only | day 687 | As existing. In addition, the newcomer took up a grazing pen (its calling: herder 3.99 against farm 3.43), and family 2 (loom) left its farm for herding on day 202 (its calling, margin 5.0). |
| Shortage only | day 85 | The newcomer took up tool mending: toolmaker 3.76 (not its calling −2, tools running out +2.5, the season's danger +2.1, the gathering's ask +1.6) against farm 3.43. **Tipped by the priority:** without the ask it would have farmed. |
| Shortage only, priority cleared | day 112 | The newcomer farmed. On day 112 family 0 (muse calling, so no calling for farming), in an early review, left its farm for tool mending, margin 2.77. **No priority involved.** It gave up "it has built up its farm" and "its farm would stand idle". |
| Both | day 112 | The newcomer took up a grazing pen (calling). Family 0 left its farm for tool mending on day 112, margin 4.77. The priority added 2.0, but without it the margin was still 2.77, so it was not decisive. Family 2 (loom) moved to herding on day 202. |
| Both, priority cleared | day 112 | As both. |

**Answers to the owner's questions:**
- **Does any family recognise the approaching shortage?**
  - **Without recognition:** no. The tool terms appeared only in families' first choices ("tools are running out" +2.5), and no working family could look again before day 202.
  - **With it:** all six working families had the danger as a reason. Only the one with no stake in its farm (no calling for it, little skill) acted.
  - **Families of the soil:** with farming's calling, skill and a proper farm, they weighed the danger (+2.1) and stayed. That is the intended behaviour, not a failure to see it.
- **What reasons does it consider?**
  - **For changing:** "the town will run out of tools within the season, and no one here makes any", "tools are running out", and the gathering's ask.
  - **For staying:** "it has built up its farm", "its farm would stand idle", its calling, and "it knows the work".
- **Does the Investment priority meaningfully influence the choice?**
  - **Yes, at the margin.** It decided the newcomer's first choice in "shortage only".
  - **No when the danger is serious.** It added +2.0 to family 0's review, but family 0 changed without it.
  - **Not enough alone.** In "existing" it brought family 2 to within 0.01 of changing, but no further.
  - **It starts nothing.** It started no review in any mode.
- **Two years on (day 802):**
  - **Without the new trades** (existing, occupations only, shortage only): 37 people.
  - **With them** ("both"): 33 people and 23 days of food in store. Two families herd rather than farm.
  - **The priority-cleared replays** end lower (31). With the "priorities first" stores rule and no priority, the stores fund no improvement (6 proper workplaces instead of 10). Compare their decisions, not their outcomes.

### Broad or narrow shortage recognition

The measured runs used the broad shortage: a good running out within the season, counting what the town holds and makes, so a food deficit counts too. The narrow version counts only a good no one in the town makes, the tool gap the brief described (meta `shortage_missing_trade_only`). It was run on the same towns.

| Year 6, shortage only | Existing | Broad | Narrow |
|---|---|---|---|
| ordinary: people / towns never making tools / days out of tools | 57.8 / 1 / 168 | 59.6 / 0 / 132 | 56.1 / 0 / 167 |
| stressed | 63.2 / 1 / 236 | 52.3 / 0 / 379 | 59.7 / 0 / 235 |
| difficult: people (towns kept) / never / days out | 42.8 (7) / 2 / 818 | 37.4 (8) / 1 / 557 | **46.3 (8)** / 1 / 557 |

- **Same effect on the tool gap:** both close it equally.
- **Broad costs the stressed towns:** families pulled to food after the lost winter leave tools short later. It also costs 9 people on difficult sites against narrow.
- **With the new trades** ("both" against "both, narrow"), the two hardly differ: ordinary 35.4 / 36.5 people, stressed 33.7 / 39.2, difficult 29.2 / 30.6.
- **Recommendation: narrow.** It does what was asked and nothing that costs towns. The branch still defaults to broad, as measured; changing that is one line in `FamilyInitiative.get_shortage`.

## For the owner

1. **Merge shortage recognition, the new trades, both, or neither?** They are independent: each part switches off on its own (`no_shortage_recognition`, `occupations_first_three`).
   - **Recognition alone:**
     - closes the tool gap (no ordinary or stressed town left without tool work);
     - answers nearly every tool shortage;
     - helps difficult towns (narrow: +3.5 people, one more town kept, 260 fewer days without tools);
     - costs ordinary and stressed towns 2–4 people.
   - **The new trades:** they work as designed (callings now lead families to fishing, herding and hunting), but cost a quarter to over half of towns' people under today's economy.
2. **Broad or narrow shortage?** Narrow is recommended (above).
3. **If the new trades are wanted, what should carry their cost?** Options, none built:
   - **a. Accept it.** It is what calling and skill deciding means in a founding year with no slack. Towns differ more, and many fail.
   - **b. Food before comfort.** No family takes up a trade that makes no food (herding today) while the town grows less food than it eats. A rule, not a weight. This would remove the herding part of the cost (about 4 people per ordinary town in the two-year diagnostic).
   - **c. The founding year:** founders weigh the town's hunger more than their calling until the first harvest. This changes today's behaviour too.
   - **d. The land trades' hand-work yields.** A snare line makes a third of a lodge's 3.5 food, under a garden's third of 4. Economy numbers were out of scope this time.
   - **e. Proficiency** (open decision 1 in the handoff). The novice penalty and "it knows the work" (+2) pull families toward their calling's trades. Softening it would weaken the pull as well.
4. **Clothing.** Herding halves the months clothing goes unmet (69 → 35). Nothing else makes wool yet.

## Remaining Limitations

- **New hand work has no art of its own:** it draws as its proper building, washed toward earth.
- **What families count as the town's output is optimistic:** standing and planned workplaces at base yield on their land, empty ones included, without proficiency or travel.
- **Mending families do for themselves is not counted** in the shortage. Families judge by the store they see, so they may see danger a little early.
- **A family's work history** (`Household.work_history`) records goods, as it did before (saves and tests depend on it). A family moving from farming to fishing records food twice.
- **Hunting:** several lodges in the same woods each count the whole woods.
- **Fishing is rare:** only one of the 12 ordinary sites has water in reach.
- **Saves:** no new saved fields. Old saves load unchanged, and families in them may now choose the new trades.
- **Tests:** 43 headless scripts (with the wrapped expanded-goods test) pass on the branch. The new rules are covered by `tests/autonomous_occupations_validation.gd`. `tests/town_sidebar_validation.gd` is flaky on `develop` as well (its town is founded at random; it failed 2 of 4 runs there, 4 of 7 on the branch; see `docs/HANDOFF.md`).
