# Community Priorities

The owner's brief (2026-10-30): founding families each judge what the community should put first; the player proposes one primary priority, sees who supports it and why, and the choice carries real benefits, opportunity costs and risks. No voting, government, scripted disasters, or tuning to make guidance look good.

## Owner Decisions (2026-10-31)

1. Families do not reconsider their work in the first pass; investigate that separately later.
2. One primary priority replaces the four work asks (food, wood, tools, better work). Norms, honours and their controls stay separate.
3. Evaluate under both the test-only first-winter store loss and naturally difficult sites, reported separately.
4. Reuse existing decision weights; no tuning to make guidance win.
5. Simulation work on a branch from `develop`; the Community tab interface later, on top of the town UI branch once reviewed.
6. Test deliberately destructive strategies with the player's real controls, distinct from reasonable but risky ones; control for the number of policy changes when comparing informed and uninformed play.
7. Step 1 only (harness and existing-lever comparison) before new behaviour. No changes to survival difficulty or production formulas.

### Step 2 decisions (owner, 2026-10-31)

1. Housing is approved: tied to families' weekly building and helping decisions, with home sites first for communal materials; families keep their autonomy.
2. No automatic protection against bad economic choices: clear warnings instead. The priority stays separate from the stores rule, so the player chooses whether to enforce a restriction.
3. Trust's gameplay effects stay as they are for now; households' experiences and trust changes keep being recorded.
4. Test every priority under both stores rules, to tell persuasion from restriction. Keep comparing passive, informed, uninformed and destructive play, and measure whether informed guidance beats doing nothing. Bad decisions must still be able to ruin a town. No rebalancing of production or survival.

### After the combined evaluation (owner, 2026-10-31)

1. Residential land is reserved for homes (`docs/HOME_SITES.md`).
2. Families reconsidering their work when circumstances materially change is approved as a direction, as its own simulation milestone after the interface: weighed by the economy, values, calling, opportunity and the cost of changing; no weekly switching, no immediate compliance with the player.
3. Step 3 integrates the priority and residential land into the playable interface (below).

## Step 2: The Priority (`CommunityPriority`)

`TownInfluence.priority` holds one of food, housing, investment, cooperation, or none; `set_priority` sets the asks it makes (`encouraged`) and records every family's view. `store_rule` is untouched by it. Every effect is an added, explained term in a decision families already make, with an existing weight:

| Priority | Decisions it enters | Weight reused |
|---|---|---|
| Food | improving food work; taking up food work (newcomers) | the ask weight (2.0 × receptiveness) |
| Housing | helping on a home site; working long days on one; home sites first in the day's builders and the materials they carry | the norm appeal (1.5 × receptiveness); a promise of help (0.5) for long days |
| Investment | improving any hand work; taking up tool work | the ask weight |
| Cooperation | helping on any neighbour's or the town's site | the norm appeal |

- **Receptiveness by request** (`FamilyInitiative.get_receptiveness(..., kind)`): food, housing and investment direct a family's own work, so self-government weighs against them and communal or solitary leanings do not count; cooperation asks for time freely given, so self-government does not count against it and communal or solitary leanings do. The norms' appeals pass no kind and are unchanged.
- **Families' views** (`get_view`, `get_views`): each family supports, does not much mind, or opposes each priority, from its home, security, work, temperament, convictions and trust, in its own words. This is the preview's data.
- **The town's backing** (`get_backing`): supporters 1, the indifferent a half, opponents nothing; respected voices count double. It pulls on every decision the priority enters exactly as a norm's acceptance does (`(backing - 0.5) × 2 × (1 + 0.25 × sociability)`). There is no vote: the player's priority stands whatever the town backs.
- **Warnings** (`get_warnings(priority, store_rule)`): which improvements the stores will not fund and what that risks (food grown by hand, no toolmaker with tools running down), no plots for unhoused families, the hardship of long days, investment spent before winter, the cost of time given to others. They never prevent anything.
- **Recorded responses:** every family's stance and reasons when a priority is set (`responses`, last 60); every decision the priority tipped over the line (`swayed`, by priority and decision); a memory, at most once a season, when a family worked long days on a home or gave its spare time because of the priority. No new trust consequences.
- **Saves:** the new fields are domain fields and save with the town (tested).
- **Interface:** `main.gd` still shows the old four ask buttons on `develop`; they now sit beside the priority until the Community tab replaces them (step 3).

### Step 2 results (commit ff611b9; 12 towns, 3 years)

Community choices only: no plots, no placed buildings, no public works; families chose their own home sites anywhere near their work (the rule of ff611b9; `docs/HOME_SITES.md` on `feature/home-site-selection` would replace it with land the player sets aside, so these numbers need a rerun on that rule). People at the end, towns off the ground, and against "none" town by town.

| Strategy | Ordinary | First winter's stores lost | Difficult sites |
|---|---|---|---|
| none | 44.3, 11/12 | 42.0, 11/12 | 21.9, 6/12 |
| food (open / priorities first) | 25.7, 6/12 (−18.6) / 24.3, 6/12 | 24.2, 6/12 / 22.8, 6/12 | 25.3, 6/12 (+3.3) / 24.6, 6/12 |
| housing (open) | 43.8, 11/12 (−0.4) | 42.2, 11/12 | 25.2, 8/12 (+3.3, saved 2) |
| investment (open = priorities first) | 40.6, **12/12** (−3.7) | 40.7, **12/12** | **31.4, 9/12 (+9.5, saved 3)** |
| cooperation (open) | **47.4**, 11/12 (+3.2) | **44.8**, 11/12 (+2.8) | 27.5, 9/12 (+5.6, saved 3) |
| housing or cooperation, priorities first | 0.8–1.8, **0/12** | 2.2–2.3, **0/12** | 0.0, **0/12** |
| informed: preview / seasonal | 29.2 / 30.2, 7/12 | 24.8 / 24.3, 6/12 | 24.8, 6/12 / 25.8, 7/12 |
| uninformed (matched changes) | 30.2, 9/12 | 29.4, 8/12 | 32.8, 9/12 (+10.9) |
| fickle | 40.3, 11/12 | 38.9, 11/12 | 30.1, 8/12 |
| wrong-headed | 46.0, 11/12 (+1.8) | 44.7, 11/12 | 27.3, 9/12 |
| starve (destructive) | 1.4, **0/12** | 0.6, **0/12** | 0.3, **0/12** |
| unfair honours (destructive) | 41.6, 11/12 | 39.4, 11/12 | 23.7, 7/12 |

- **Player choices now move outcomes both ways through real mechanics.** Restricting the stores ruins every town (warned); the food priority loses five towns in twelve; on difficult sites, investment, cooperation and housing each save two or three towns that doing nothing loses.
- **Guidance helps where the land is hard, not where it is easy.** On ordinary sites passive play is close to the best (only cooperation beats it, by 3 people); on difficult sites every reasonable priority beats it, investment by 9.5 people and three towns.
- **Informed play does not yet beat doing nothing on ordinary sites.** Both informed strategies spend most of their time on food, because families short of food back it; following the families walks into the food trap. Uninformed play with the same number of changes does as well or better. The informed rules were not tuned to these results.
- **The food trap is a real chain, amplified by the town's backing.** Set from the founding, the food ask steers founders' first choice of work away from tools; seven of twelve towns run out of tools. Every family backs food at the founding (stores are only weeks deep), so the backing pull doubles the ask. With the backing pull switched off (a diagnostic run, not kept), food keeps 9/12 towns and 37.3 people, still below none (tools out in 4). No warning covers it under open stores: the warnings speak of tools only when the stores are kept for priorities.
- **Trust still costs little:** fickle play loses 3–4 people on ordinary sites and gains on difficult ones.
- **Future balance issue (outside this prototype, owner 2026-10-31):** towns end with 5,000–9,000 wood and hundreds of tools; materials stop being scarce after the first year.

## Combined Evaluation (2026-10-31, branch `feature/combined-evaluation`)

The agreed rules (owner, 2026-10-31): families choose their home sites on land set aside (`docs/HOME_SITES.md`), every town starting with the modest starting land; the town's backing pulls only on time given freely; the food priority warns of tools whatever the stores rule. 12 towns, 3 years, identical seeds; people at the end, towns off the ground, and town by town against "none". Differences of 3 people or less are within the spread between towns (each strategy is both better and worse than "none" in several towns).

### Leadership (starting land)

| Strategy | Ordinary | First winter's stores lost | Difficult sites |
|---|---|---|---|
| none | 39.9, 11/12 | 38.3, 11/12 | 20.8, 6/12 |
| **tool-aware (informed)** | 40.7, 11/12 (+0.8) | 40.0, 11/12 (+1.7) | **35.3, 10/12 (+14.4, saved 4)** |
| uninformed, matched to tool-aware's changes | 37.7, 11/12 (−2.3) | 35.3, 9/12 (−3.1, lost 2) | 35.6, 10/12 (+14.8, saved 4) |
| cooperation | **44.6**, 11/12 (+4.7) | **42.9**, 11/12 (+4.6) | 25.5, 7/12 (+4.7) |
| housing | 42.1, 11/12 (+2.2) | 40.9, 11/12 (+2.6) | 23.3, 8/12 (+2.5, saved 2) |
| investment | 40.1, **12/12** | 40.6, **12/12** | 29.6, 9/12 (+8.8, saved 3) |
| food | 34.8, 9/12 (−5.1) | 34.1, 9/12 (−4.3) | 24.1, 6/12 (+3.3) |
| preview (follows the town's backing) | 38.2, 10/12 | 34.4, 9/12 | 27.7, 7/12 |
| seasonal (step 1's rules) | 39.8, 10/12 | 37.8, 10/12 | 27.8, 7/12 |
| wrong-headed | 42.5, 11/12 (+2.6) | 41.8, 11/12 (+3.5) | 25.3, 7/12 |
| fickle | 39.4, 11/12 | 38.4, 11/12 | 32.2, 9/12 |
| housing or cooperation, priorities first | 1.5–2.6, **0–1/12** | 1.6–2.2, **0/12** | 0.0, **0/12** |
| starve (stores closed, no priority) | 1.4, **0/12** | 0.6, **0/12** | 0.3, **0/12** |
| unfair honours | 38.0, 11/12 | 36.4, 11/12 | 22.7, 7/12 |

The tool-aware strategy (written before its results; tools first while no one makes them, food only once someone does, homes when their sites wait for hands, otherwise cooperation) spent about half its time on food and half on cooperation. Without the backing pull on work, the food priority loses two towns, not five.

### Planning and leadership together (ordinary sites)

| Residential land | none | tool-aware | starve |
|---|---|---|---|
| Starting land | 39.9, 11/12 | 40.7, 11/12 | 1.4, 0/12 |
| Compact (24 spots around the stockpile) | 28.7, 9/12 | 31.4, 10/12 | 2.0, 0/12 |
| Poor (24 spots in the far corner) | 33.3, 9/12 | 28.8, 8/12 | 0.6, 0/12 |

### The owner's five questions

1. **Can bad planning and bad leadership each cause failure?** Leadership, yes: closing the stores to improvements ruins every town on every kind of site, and the food priority loses two towns in twelve. Planning, partly: badly placed land costs 6–11 people a town and two towns in twelve, but does not by itself wipe towns out (no land at all would, and is prevented by the starting land).
2. **Can good planning and good leadership each improve outcomes?** Leadership: on ordinary sites only slightly (cooperation +4.7, within the spread; tool-aware +0.8); on difficult sites strongly (tool-aware +14.4 people and four towns saved; investment +8.8). Planning: no layout beat the modest starting land beyond the spread (far land 41.2 against 39.9); the layout that looks best, compact, is the worst because work takes its land (`docs/HOME_SITES.md`).
3. **Do they reinforce each other?** Not measurably. Tool-aware leadership added 2.7 people on compact land and lost 4.5 on poor land.
4. **Do family values make meaningful differences?** In individual decisions, yes (site choice, who answers an appeal, who resists being directed: tested). At town scale, no measurable difference: preferred land drew deferential and self-governing families alike.
5. **Can an informed player consistently do better than a passive or uninformed one?** Better than uninformed on ordinary and stressed sites (+3.0 and +4.7 people, two towns kept that uninformed play lost), equal on difficult sites. Better than passive only on difficult sites; on ordinary sites the margin is within the spread. Not yet consistent.

### What is demonstrated, what is not, and why

- **Demonstrated:** player choices can ruin a town through real mechanics, and the warnings name the cause beforehand; on hard land, guidance of almost any reasonable kind saves towns doing nothing loses; informed play avoids the mistakes uninformed play makes.
- **Not yet demonstrated:** that judgment beats sensible defaults on ordinary land, or that planning and leadership compound.
- **Why skill shows so little on ordinary land:** families already weigh the town's food, wood and tools in their own decisions, so a sensible priority mostly repeats their reasoning; work is chosen once, in the first month, and never reconsidered (owner decision 1, still deferred), so the priority reaches only improvements, newcomers and spare time; materials stop being scarce after the first year (5,000–9,000 wood), so there is little to allocate; trust, the cost of poor leadership, only scales receptiveness.
- **On difficult land almost anything helps** because passive towns there fail on tools and departures, and any priority that asks for tools, better work or help moves families who would otherwise not act; matched uninformed play does as well as informed, so this is the value of acting, not of judgment.
- **Unintended interactions:** residential land was not reserved, so compact planning backfired (fixed after this evaluation: compact land now 39.0 people, `docs/HOME_SITES.md`); asking for food at the founding draws families away from tools (now warned of); the town's backing amplified private work choices (now removed).

## Step 3: In the Game (branch `feature/step3-integration`)

The Community page's four work asks are replaced by one priority (`docs/TOWN_UI.md`, Community): the five choices with what each asks; the warnings for it under the current stores rule ("Before you lean on it": warnings only, nothing is stopped); how the town takes it (backing worked out afresh, who supports, does not mind or opposes, decisions tipped so far); each family's stance with its reasons; and how the town would take each of the other priorities, so the player can weigh them before changing (each change counts toward the trust cost of a gathering that keeps changing its mind; the page says how many changes there have been). The stores rule stays its own control; norms, rewards and honours are unchanged. The Overview's food and tool cards offer "Put food first" and "Put investment first" in place of the old asks.

A town saved under the four work asks keeps them (`TownInfluence.encouraged`) and the page names them until a priority, or none, is chosen: `set_priority` replaces asks of other kinds even when the priority itself does not change.

## Step 1: Existing Levers (`tests/sim/priority_check.gd` at commit 8fd8b39)

Each priority is mapped to today's nearest controls: **food** = ask for food work, stores to priorities first; **housing** = four homes' worth of plots ahead instead of two, stores to priorities first with nothing asked; **investment** = ask for better work and tools; **cooperation** = promote helping neighbours, first claim for helpers. Strategy rules (informed, wrong-headed) were written before any result and not tuned. The uninformed strategy changes on exactly the days the informed one changed on the same town, so change counts match (both stay under the trust penalty); "fickle" changes monthly and meets it. Difficult sites: of 48 others, the 12 where the map luck check's classic player did worst (4 of them failed); a different policy's runs, so selection shares no noise with these. Same towns and seeds throughout; two identical runs gave identical output.

### Results (12 towns, 3 years; people at the end, towns off the ground, against "none" town by town)

| Strategy | Kind | Ordinary | First winter's stores lost | Difficult sites |
|---|---|---|---|---|
| none | passive | 37.0, 11/12 | 35.9, 11/12 | 32.5, 9/12 |
| food | fixed | 33.7, 8/12 (lost 3) | 32.1, 9/12 (lost 2) | 30.3, 8/12 (lost 1) |
| housing | fixed | **0.6, 0/12** | **0.6, 0/12** | **0.0, 0/12** |
| investment | fixed | 38.9, 12/12 (saved 1) | 39.3, 12/12 | 35.4, 10/12 |
| cooperation | fixed | **42.8**, 11/12 | **40.6**, 11/12 | 34.8, 10/12 |
| informed | informed | 33.7, 8/12 | 31.8, 9/12 | 30.2, 8/12 |
| uninformed (matched changes) | uninformed | 29.2, 8/12 | 26.8, 8/12 | 27.3, 8/12 |
| fickle (35 changes) | poor | 34.6, 10/12 | 30.8, 10/12 | 38.9, 11/12 |
| wrong-headed | poor | 39.8, 11/12 | 36.3, 10/12 | 34.4, 9/12 |
| trade (sensible) | control | 37.1, 11/12 | 36.0, 11/12 | 31.5, 9/12 |
| no plots | destructive | 10.6, 0/12 | 9.3, 0/12 | 3.7, 0/12 |
| squander (≈90 storehouses) | destructive | 35.0, 10/12 | 30.3, 9/12 | 21.7, 7/12 |
| sell food | destructive | 37.3, 11/12 | 36.0, 11/12 | 31.7, 8/12 |
| unfair honours | destructive | 35.8, 11/12 | 34.7, 11/12 | 32.6, 9/12 |
| *plots ahead only* | lever | 36.5, 11/12 | | |
| *stores closed only* | lever | 0.6, 0/12 | | |

### What it shows

- **Player choices can already damage a town badly, through real mechanics.** Keeping the stores from every improvement starves it: hand work alone cannot feed six families, and they leave (0/12 in every condition). Setting no land aside for homes leaves families unhoused until they go. Squandering builders on needless works costs 11 people a town on difficult sites. These are the player's actual controls.
- **The food priority has a real opportunity cost:** with the stores kept for food, tool improvements wait, and four of twelve towns run out of tools. The trade-off is genuine, not scripted.
- **Improvement is small.** Cooperation is the best fixed priority (+5.8 people a town on ordinary sites, +4.7 under stress, +2.3 on difficult sites); investment saves the occasional town. No strategy lifts survival much above "none", and no strategy rescues the stressed winter: every town's first-winter low is about 5-7 days of food whatever the player does.
- **Informed beats uninformed with policy changes matched** (+4.5, +5.0, +2.9 people a town), so knowing what to do matters. But the informed rules, written before the results, mostly held food first and so inherited its tool cost: informed play lands below "none". The rules not knowing about the tool cliff is a fair picture of a player without the preview this prototype is meant to give.
- **Frequent changes cost trust but little else.** Fickle play ends at trust -2.5 (-12 from "decisions keep changing") yet keeps towns about as well as "none", even better on difficult sites. Trust only scales how readily families heed asks, and asks carry little weight, so losing it costs little. This is the weakest link between social state and outcomes.
- **Some destructive controls have no teeth:** selling every lot of food the trader takes, and dishonest honours, barely move outcomes. The trader takes small lots against stores of over a thousand food, and honours change trust and standing, not work.
- **Stores pile up.** Typical towns end with 7,000-9,000 wood and over 800 tools; after the first year, scarcity is labour and food timing, not materials. Squandering wood therefore hurts through builders' time, not the wood.
- **Plots ahead house founders sooner** (day 111 instead of 160) with no change in size; the stores closed to improvements is what wrecks the "housing" mapping.

### Implications for step 2 (not yet decided)

- A housing priority needs its own link (families giving spare time to home sites, homes first for the stores), not "stores to priorities with nothing asked", which is ruinous.
- The stores rule should never be able to block food improvements while the town is short of food without the preview saying so plainly; whether that is a rule or only a warning is an owner decision.
- Trust needs consequences beyond receptiveness before "changing your mind costs trust" matters.
- The stressed winter is decided by stores at the moment of loss, which no priority today changes; a food-security priority that raises stores before autumn is where guidance could show.

Raw logs from these runs are not kept in the repository; rerun with the commands in `docs/TESTING.md` (about an hour a condition).
