# Player Agency Audit

## Round 2 (2026-11-01): after hunger is counted once, and with the new warnings

Same towns, seeds and kinds of player as round 1 (below), with two changes:
- **The informed player** also answers the two new warnings with their buttons. Families finding no land: land near their homes marked to till. Hunting grounds felled: a stand far from them marked for clearing. This replaces round 1's always-on woods-marking.
- **`informed_land`** uses only those land tools.

The players were run under two sets of rules: the recommended one (narrow recognition + survival awareness, first three trades) and "all" (the new trades too).

**People at year 6, recommended rules** (towns more than 5 people worse / better than no player):

| | None | Informed | Priority only | Commission only | Land tools only | Late | Investment from founding |
|---|---|---|---|---|---|---|---|
| ordinary | 60.0 | 59.4 (2/2) | 58.1 (2/1) | **61.1** (1/2) | 60.0 | 59.6 (2/2) | 46.2 (6/2) |
| stressed | 59.8 | 56.9 (3/1) | 55.4 (3/1) | 56.7 (2/1) | 59.8 | 56.8 (2/1) | 37.5 (6/0) |
| difficult | 60.2 | 56.2 (3/1) | 47.7 (3/0) | 55.6 (2/0) | **61.0** (0/1) | 56.6 (3/1) | 53.4 (3/1) |

**People at year 6, all rules (the new trades):**

| | None | Informed | Priority only | Commission only | Land tools only | Late | Investment from founding |
|---|---|---|---|---|---|---|---|
| ordinary | 49.3 | 47.1 | 48.2 | **54.2** | 51.2 | 47.3 | 51.7 |
| stressed | 45.6 | 47.2 | **52.3** | 50.1 | 44.4 | 46.8 | 36.2 |
| difficult | 39.6 | 35.8 | 34.0 | 37.8 | 39.4 | 40.2 | 24.8 |

### Did the improvements correct the informed player's problem?

**Mostly.**
- **Round 1:** the informed player lost 16 / 12 / 5 people against no player.
- **Now:** it loses 0.6 / 2.9 / 4.0 under the recommended rules, and −2 / +2 / −4 under all. Towns worse and towns better are near even. The large systematic harm is gone: it came from the families' double-counted hunger, which every food ask amplified, and from always-on woods-marking.

**Not yet:**
- **Informed play does not help on average.** Responding as the cards suggest is now roughly neutral, not beneficial.
- **Commissioning** is the one answer that helps somewhere: ordinary sites under both rule sets, and stressed sites under all.

### Controls whose suggested use is systematically harmful

1. **Productive investment from founding** (no warning suggests it, but players will try it): −14 / −22 / −7 people under the recommended rules, and the most "worse" towns of any player. It pulls founders from food work in the first lean year. The round-1 finding that it helped difficult sites does not survive the hunger correction.
2. **"Put food first" / "Put investment first" on the warning cards, used as suggested** (priority only): −2 / −4 / −12.5.
   - **How it harms:** each switch pulls on the town's other need. Days without tools rise from 177 to 368 on ordinary sites when food is put first as food falls, because families already on food work stay and free families go to food, not tools. On difficult sites the switching costs most.
   - **When:** the food card shows when stores are already falling, usually days 35–42, and the priority then keeps pulling for months after.
3. **Not harmful, but rarely useful yet:** the land tools. The no-land warning showed in only 2 of 12 towns per condition, late (median days 1,071–1,473). The hunting-grounds warning showed in 3–4 towns, around day 650–1,550. When used, they made little difference: under "all", ordinary +1.9, stressed −1.2, difficult −0.2.

### Is the information timely?

- **Tools: yes.** "Tools are low" shows a median of 133–441 days in; "running out" 45–190 days later.
- **Food: no.**
  - **The founding famine:** "Food stores are falling" shows on day 35–42 and "Food has run out" on day 42–49, a single week of warning in the founding famine every hard town faces. The card is driven by days of food in store, not by the forward-looking view families now use, so the player learns of a famine about when the families are already going hungry.
  - **Food shortages later** show earlier (median lead before the first family leaves: 54–144 days for half the towns, a year or more for the rest).
- **Livelihoods and land: now visible,** where before they were not at all, but the conditions arise late.

### Remaining gaps (for priorities 4–6 and the owner)

1. **An early food warning from the families' own view** (the forward outlook already computed for their decisions): "The town will run out of food before the harvest: X days of food in store and coming against Y needed". It would give the player weeks, not days, at founding. Interface only.
2. **The cards suggest priorities as the answer to every shortage,** and that answer is neutral-to-harmful. Focused appeals (priority 4) are the planned alternative. Until then, the cards could suggest the specific tools (commission, till) first, with the priority's cost stated.
3. **Protected woodland** (priority 4), as approved.
4. **No fast food lever** for the founding famine (round 1's case 4) remains open.

## Round 1

**Status: findings and proposals (2026-11-01). No new control was built.** Branch `feature/autonomous-occupations`, not merged.

Rules audited: "all" from `docs/AUTONOMOUS_OCCUPATIONS.md` (the new trades, narrow shortage recognition, survival awareness, both reasoning corrections).

Evidence:
- `tests/sim/intervention_check.gd`: 12 towns × 3 conditions × 7 kinds of player, six years, identical seeds.
- Its `--trace` mode: each town's timeline of warnings, the player's acts, and every family's choice and review with reasons.
- `tests/sim/autosave_replay.gd`: the owner's day-82 town.

Brief (owner, 2026-11-01): families decide for themselves, but the player must have meaningful ways to influence the circumstances in which they decide. Use only what the player could see at the time. Propose any new control before building it.

## How the players were simulated

The player acts only on what the game shows: the sidebar's Needs attention cards, the stores, and the town map. It acts only through existing controls, and never orders a family:

| Player | What it does |
|---|---|
| none | Never intervenes. |
| informed | Answers each warning when it first shows, with the card's own buttons. Food stores falling or out: food first, and a field commissioned (one per 90 days). Tools low or running out: investment first, and a tool mender commissioned. Both quiet for a season: no priority. Once hunters and woodcutters share the woods: a small stand marked for clearing far from the hunting grounds every 60 days, so woodcutters fell there. |
| informed_priority / informed_commission / informed_woods | Each of the informed player's three answers alone. |
| late | The informed answers, only once food has run out or tools are running out. |
| inappropriate | Productive investment first from founding, kept for six years. |

## Results (six years; people, with towns kept of 12 in brackets)

| | None | Informed | Priority only | Commission only | Woods only | Late | Investment from founding |
|---|---|---|---|---|---|---|---|
| **ordinary** | **57.6 (10)** | 41.2 (7) | 52.2 (10) | 48.3 (9) | 56.1 (9) | 44.3 (9) | 43.7 (9) |
| **stressed** | **49.0 (9)** | 37.2 (8) | 45.2 (9) | 44.2 (8) | 41.4 (8) | 40.2 (8) | 46.2 (9) |
| **difficult** | 51.2 (9) | 46.3 (9) | 46.7 (9) | 43.8 (9) | 47.7 (9) | 51.8 (9) | **64.2 (11)** |

Towns more than 5 people worse / better than with no player, same seed:

| | Informed | Priority only | Commission only | Woods only | Late | Investment from founding |
|---|---|---|---|---|---|---|
| ordinary | 7 / 2 | 5 / 2 | 2 / 1 | 2 / 2 | 5 / 2 | 6 / 5 |
| stressed | 6 / 1 | 5 / 2 | 3 / 0 | 3 / 0 | 5 / 1 | 4 / 6 |
| difficult | 5 / 2 | 3 / 1 | 4 / 1 | 1 / 1 | 4 / 1 | 2 / 3 |

**The finding: the player can see danger in time, and the controls are real, but a player who answers the warnings as the cards suggest does worse than one who does nothing.**
- **Warnings come early enough.** Before a family first left a town (no player), the first warning had shown 54–1,814 days earlier. The median is about 13 months on ordinary sites, and never under 7 weeks.
- **The controls reach families.**
  - **The informed player's priorities tipped** about 22 family decisions per town.
  - **Investment from founding tipped** 106–140.
  - **The tipping point:** in the owner's town the Investment priority is what decides the first family to take up tools (below).
- **But every answer the cards suggest hurts on balance,** each on its own, and most of all together. The causes, from the traces:
  1. **A priority is one focus for the whole town.** "Put food first" when food stores fall (often while every family is already on food work) mostly pulls free and reconsidering families away from tools and wood: days without tools 328 → 567 on ordinary sites. "Put investment first" in a tool shortage pulls them away from food. The informed player switches back and forth as warnings alternate, and each switch pulls on the town's other need.
  2. **A commissioned workplace costs scarce wood, tools and builders' time, and needs a free family.** Commissioned farms and tool menders often stood empty, or went to a newcomer who would have taken up the same work anyway. Meanwhile they took materials and builders from homes and from families' own improvements.
  3. **Marking woods is a blunt tool.** Woodcutters fell marked woods at their full day (about a tile every two days) against a tenth of their day for unmarked trees. Steering felling away from hunting grounds therefore clears other woods quickly: woods the town's gatherers and errands use, and where the next hunting grounds would be. It helped in one stressed town (24 → 29 people) and cost more elsewhere.
- **Holding investment from founding is the one consistent winner on difficult sites** (64.2 people, 11 towns kept). There, early improvement and steady toolmaking matter most. On ordinary sites it costs 14 people, by pulling families from food early.

## Representative failing towns

### 1. A town lacking tool production: the owner's day-82 town (replayed)

- **Did families recognise the danger? Yes.** From day 82 every working family has the coming tool shortage among its reasons. With the investment priority cleared, they weighed it 49 times in two years ("the town will run out of tools within the season, and no one here makes any").
- **Why they stayed:** the families of the soil stay for their calling, their skill, their farms and the town's food ("only just enough"). Family 0 (muse calling, no tie to farming) comes closest: margin 1.27 against the 2.0 needed.
  - **Kind of failure:** a legitimate family decision, not a defect. Every family understands the problem, and each has its own reasons to keep its work.
- **Could the player see it? Yes.** "Tools are low" and "Tools are running out" show months ahead.
- **Did a control work? Yes, decisively.** With Productive investment set (the owner's own choice in that save), family 0 leaves its farm for tool mending on day 112, margin 3.27, the priority's part +2.0. **Without it, no family makes tools until day 687.**
- **Would acting earlier change the outcome?** Not much here. The town survives either way (37 people at day 802), but with tools at 0–2 for a year and a half without the priority.

### 2. Non-food work before food security (ordinary seed 2610263185)

- **What happened:**
  - **Founding:** the first three founders take gardens ("the town will go hungry before the next harvest is in").
  - **Day 14:** the other three take a grazing pen (loom calling, "the town goes without clothing"), a tool mender (forge calling) and a snare line. Survival weighed the gardens already claimed, and the loom and forge families followed their callings.
  - **Days 42–49:** food falls on day 42 and runs out on day 49.
- **Did families recognise the danger? Yes, later; earlier, the enterprising choice was theirs to make.** From day 90 the hungry herders, the toolmaker and later hunters review their work and choose farming, by margins of +2.5 to +8.9.
- **The gap: they cannot farm.** "It found no free land" for a garden: the fertile land within reach is taken.
  - **Kind of failure:** neither a reasoning defect nor resistance. The families decide correctly and are blocked by land, ten times over six years.
- **Could the player see it? No.** Nothing in Needs attention says families want to grow food and find no land. It is only in each family's own note.
- **Could the player have acted?** Yes, with an existing control nobody is told to use: **Till Land (F)** turns open land into farmland, and **Clear Woods (C)** opens land.
- **Would acting earlier change the outcome?** Likely: the town hovered at 0.9 of its food needs for four years. Not measured; the scripted player only uses what the cards suggest, and no card suggests tilling.
- **The prompt answer hurt here:** the informed player (food first, woods marked) lost this town entirely (0 against 25).

### 3. A hunting family whose livelihood woodcutting undermines (stressed seed 880325585)

- **What happened:**
  - **Founding:** founders take snare lines and a garden, which is sound.
  - **Years 3–4:** the town's woodcutter fells the nearest trees, the hunting woods (lodge reach 1.0 → 0.33), and food falls to 61% of what the town eats.
- **Did families recognise it? Yes.** Hungry hunters look again at their work. With the staying correction, their lodge now counts for what its woods yield ("it has built up its hunter's lodge, though its land yields little now"). Hunting is still their calling, their skill, and years of work.
  - **Kind of failure:** legitimate resistance (calling, experience) in some reviews, and blocked by land in others (no free fertile land).
- **Could the player see it? Only indirectly.**
  - **What shows:** "Food stores are falling" comes (day 105).
  - **What doesn't:** nothing says the hunting grounds are being felled. The player can see woods shrinking on the map, but not that it is the hunters' livelihood.
- **Could the player influence it? Only bluntly.** The one existing lever, marking other woods for clearing, steers woodcutters away but clears woods elsewhere quickly. It helped this town slightly (24 → 29 people, food-short days 297 → 267) and hurt others.

### 4. A town that cannot feed its first spring (ordinary seed 1668705218)

- **What happened:**
  - **Founding:** every founder takes food work (survival awareness working).
  - **Days 35–49:** with 24 days of food at founding and gardens weeks from bearing, food falls on day 35 and runs out on day 49.
  - **After:** families leave from day 63, and tools fail only after that. Today's rules lose it too (3 people).
- **Could the player see it? Yes, two weeks ahead.**
- **Could the player act? No.**
  - **Food first:** no effect, since every family already grows food.
  - **A commissioned field:** goes unworked, since no family is free.
  - **Traders:** none in a first spring.
- **Kind of failure:** a legitimate hard site, but **an agency gap: there is no fast lever for a food emergency.**

## Defects and Legitimate Decisions

| Case | Simulation defect (family fails to see an obvious problem) | Legitimate decision (family sees it and resists) | Agency gap (player cannot see or answer) |
|---|---|---|---|
| Tool shortage, owner's town | None left (fixed in earlier rounds: narrow recognition, the food judgement) | Soil families keep farms; the muse family is tipped only by the priority | None: the priority works |
| Non-food before food | None | Early herding and toolmaking by calling; later the families want to farm | **Yes:** families blocked by land, and no card tells the player, who could till land |
| Hunting undermined | Fixed this round: a lodge's worth now follows its yield | Hunters keep their calling and experience | **Yes:** no warning that hunting grounds are being felled; marking woods is too blunt |
| First-spring famine | None | All families choose food | **Yes:** no fast food lever |
| The cards' suggested answers | — | — | **Yes:** prompt answers make towns worse (a single-focus priority, costly commissions) |

## Proposals (none built; for the owner's decision)

In order of size, smallest first. None orders a family; each changes what families see or the circumstances they decide in.

1. **Tell the player when families want work they cannot find land for.** A Needs attention card, "Families want to grow food but find no land", from families' own blocked reviews and choices ("it found no free land"). Its buttons are the existing **Till Land (F)** and **Clear Woods (C)**. Interface only: no simulation change. It answers case 2 directly.
2. **Tell the player when a livelihood is failing.** A card or workplace notice, "The woods round the hunters' lodges are being felled" (or "a fisher's water is thin"), when a land-trade workplace's yield has fallen by a third or more. Interface only. It answers the visibility half of case 3.
3. **Woods kept for the town (the smallest new indirect control, as the owner suggested).** The player marks woods to keep, the opposite of clearing. Woodcutters do not fell there unless no other woods are in reach, and families judging a site see "the gathering keeps these woods". Effects:
   - **What it does:** it protects hunting grounds, and the woods gatherers and errands use, without ordering anyone, and without the blunt side effect of marking other woods for clearing.
   - **The cost** is real and visible: woodcutters walk farther, or run short of trees.
   - **Saves:** marked tiles are saved on the town map like clearing marks.
   - **How it would be tested:** the intervention check, a "keeper" player against "woods only".
4. **Make the priority's ask narrower than the town's whole focus.** Asks the gathering can make alongside the priority, and say in its words:
   - "the gathering asks someone to take up toolmaking" (only while no one makes tools);
   - "asks families to grow food" (only while the town grows less than it eats).

   Each ask fades when answered, so the player can address one need without pulling every family away from the other. This changes `CommunityPriority`, an owner-approved system, so it is the larger proposal.
5. **A fast lever for a food emergency** (case 4): "The gathering asks families to ration".
   - **What it does:** the town eats less for a season (stretching the stores) at a cost in hardship and contentment. Families judge it by their convictions (sharing, thrift), as they judge other asks.
   - **What it adds:** a new rule in how the town eats, so it needs the owner's decision on the cost.

**Recommendation:** 1 and 2 now (interface only; they make existing controls usable), then 3. 4 and 5 need the owner's design decisions.

## Limits of this audit

- **The informed player is a script.** It answers each card with the card's own buttons. A thoughtful human might do better: hold one priority for a season, till land, choose where to commission. The result shows the cards' suggestions are poor advice, not that no good play exists. "Investment from founding" on difficult sites shows one does.
- **Twelve towns per condition, and outcomes are path-dependent.** A single choice early can change a town's six years, so per-town differences are noisy. The direction (more towns worse than better for every prompt answer) is consistent across conditions.
- **Traders were not used by the scripted players**, and the stand-in player builds only homes and shared works.
