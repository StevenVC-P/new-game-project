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

## Step 1: Existing Levers (`tests/sim/priority_check.gd`)

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
