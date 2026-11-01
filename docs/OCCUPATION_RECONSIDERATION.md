# Families Reconsidering Their Work

**Status: implemented (2026-11-01). Branch `feature/occupation-reconsideration`, stacked on `feature/guiding-wisdom`. Not merged: awaits owner review.**

Code: `scripts/domain/occupation_review.gd` (`OccupationReview`), with hooks in `FamilyInitiative.get_work_desire`, `HouseholdMigration.advance_month`, `City.add_building`, `TownConstruction` (claimants) and `FamilyAmbitions`. Tests: `tests/occupation_review_validation.gd`. Comparison: `tests/sim/wisdom_check.gd` with `--no-reconsider` and `--change-limit=N`.

Objective (owner, 2026-11-01): families adapt rationally but imperfectly to changing circumstances, and the player influences those decisions only indirectly.

## Owner Decisions

**Proposal review (2026-11-01):**
1. **Distance:** a family may reconsider once its home lies much farther from its work, and the cost of travel persists. Distance competes with the other reasons; it does not decide on its own.
2. **Leaving proper workplaces:** permitted, but consequential. Investment, ownership, attachment, and the prospect of leaving a productive workplace idle weigh heavily toward staying. Families are never locked in to protect production. An abandoned building is kept, not deleted.
3. **Calling:** the instant, costless calling swap is replaced by this process. Calling matters but does not dictate.
4. **Community Priority:** it weighs in a reconsideration but never starts one.
5. **Guiding Wisdom:** Take Pride in Your Work does not encourage staying at a workplace; pride in craft can survive a change of work. Persistence is explained by temperament, calling and investment. Broader craft behaviour waits until craft has consequences.
6. **Learning:** the change and its reasons are a memory. Lessons come from what follows (success, hardship, effects on others), never from changing as such.

**Requirements:**
- Reconsideration stays gradual, with real switching costs.
- No repeated switching.
- Autonomy and existing workplace ownership are kept.
- No artificial shortages.
- Guiding Wisdom and Community Priority stay as they are.
- No changes to production formulas.

## Ownership (checked before building)

A family holds a workplace by working it (`Building.assigned_household_id`); there is no separate owner. Leaving therefore means what it already means when a family leaves the town (`HouseholdMigration`, `unassign_worker(false)`): the building stands, empty, and the next family free to work may take it on. That is safe, so no workaround was needed.

One consequence of the existing rules, kept as it is: an empty proper workplace still draws tools for upkeep.

## How It Works

**Starting a review.** Monthly, where families lead, a family looks again at its work only when one of these holds:
1. **Calling:** its work is against its calling (a poor match, or its calling ambition waiting past patience), and work of its calling is among food, wood or tools.
2. **Short of tools:** its workplace has stood short of tools (worked by hand, or idle) for a season.
3. **Oversupplied:** the town has more than enough of what it makes (food ratio over 1.6, or two other producers of its wood or tools) while short of another output, for a season.
4. **Distance:** its home now lies much farther from its work, for a season. That means a quarter of its day travelling, and 15 points more than when it took the work up.

**When.** At most once a year per family, and not before it has had the work for two seasons. A priority or a wisdom never starts a review.

**Weighing.** The family weighs staying against the best other work.
- **The other work:** the same desire as a first choice of work (calling, the town's need, the priority's ask, Prepare for Hard Times), with bounded noise.
- **Staying:** the same desire for its own work, without counting itself among the producers, plus:
  - what it has built up: +3 for a proper workplace, +0.5 for hand work;
  - its years there: +0.5 a year, at most +1.5;
  - its workplace standing idle if no family is free to take it on: +1.5 proper, +0.5 hand;
  - traditionalist +0.75; reformist −0.5;
  - cautious or daring: ±0.5 a step;
  - the walk to work: −5 × the share of its day.

It changes only when the other work wins by 2 or more. These weights were set before the comparison and were not changed after it.

**Changing.**
- **New work first:** the family opens hand work on free land. It never contests land, and with no free site it stays and says so.
- **Old work until then:** it keeps its old work until the new site is built (`TownConstruction` keeps the site for it). Then it leaves.
- **The old workplace is kept:** the building stays, empty and open to others.
- **One a month:** at most one family a month in the town changes its work. A family held back by the limit looks again the next month.

**Recorded.**
- **Memory:** a memory (`changed_work`) with its reasons, but no lesson.
- **Families page:** the latest review in the family's words, for example "Thought of a tool mender (it is the family's calling), but keeps its farm (it has built up its farm; its farm would stand idle)".
- **Priority:** a change the priority tipped counts as "work" in the priority's decisions tipped.
- **Prepare:** a change while something is short counts as conduct toward Prepare for Hard Times.

**Calling swap retired.** `FamilyAmbitions.take_calling_work` no longer runs where families lead; the classic rules keep it. `TownInfluence.reconsider_work` (default on) switches all of this off, for comparison only.

## Validation (2026-11-01)

**Tests.** `occupation_review_validation.gd` covers eight cases:
1. No reason, no review.
2. Hand work against its calling changes, keeping its old work until the new is built. The garden still stands, empty and open. A memory without a lesson, and no value moved.
3. Leaving a proper workplace is weighed heavily but not forbidden. A family of the forge on a proper farm stays where another family already makes tools, and leaves where no one does and food is plentiful.
4. A priority never starts a review, but weighs in both ways.
5. Reasons must last a season.
6. Once a year, one family a month.
7. The calling swap is retired where families lead and kept under the classic rules.
8. Off switch and saves.

All pass. The full suite (39 scripts) is reported below.

**Comparison.** `wisdom_check`, 12 towns per condition, same seeds and founders, 6 years, reconsideration on against off. Six strategies:
- no wisdom or priority;
- the Food priority;
- the Investment priority;
- Endure + Prepare;
- Prepare + Pride;
- Prepare + Pride with Investment.

Also no wisdom with the monthly limit lifted. With reconsideration off, the code reproduces the previous baseline exactly (12/12 towns identical).

### How often families reconsider and change

| | Reviews | Changes | Share of reviews | Near misses (margin 0-2) |
|---|---|---|---|---|
| Ordinary (6 strategies) | 571 | 8 | 1% | 51 |
| Stressed | 483 | 13 | 3% | 37 |
| Difficult | 344 | 22 | 6% | 44 |

- **Scale:** about 1.3 reviews per town per year on ordinary land (1.1 stressed, 0.8 difficult). Over six years, 6 of about 1,330 ordinary families changed their work, 12 of 1,260 stressed and 11 of 850 on difficult land: about one family in a hundred or fewer.
- **No repeated switching:** no family changed twice, and none changed back.
- **Most changes leave a proper workplace:** 34 of the 43 changes had completed by year 6, every one leaving a proper workplace.
- **What starts reviews:** calling (53% of reasons), oversupply (35%), tools short (12%). Distance never triggered: no family's home moved far enough.

**Why families change** (a change usually has two or three reasons):
- their calling (26 of 43);
- the town's food only just enough, or short (16);
- tools running out (10);
- Prepare's ask to take up what is short (9);
- no one cutting wood, or wood short (14);
- a priority's ask (4).

**Why families stay** (1,355 stays):
- "it has built up its work" (1,342);
- "its work would stand idle" (506);
- its calling, when it already works its calling and only the town's need pulls it elsewhere (294);
- the priority's ask for its current work (238);
- Prepare's ask (86);
- its years there (about 100).

Most stays are clear: the margin is below zero in 4 of 5 reviews.

### Is essential work abandoned?

No. Seven families left toolmaking, all in towns with two or three other toolmakers and 1,500–4,700 tools in store. No town lost its toolmaking through a change of work. Towns with no one making tools at year 6 (one to two a condition, on and off alike) are towns dying for other reasons, down to one family.

Vacant workplaces at year 6 are about as many on as off. Of the 34 completed changes, no family took on the workplace left behind in any of them (no family was free to). All are kept standing.

### Do towns recover from tool shortages better?

Only where a shortage comes from the families' own choice of work, which in these runs means under Prepare for Hard Times:

| Months with tools short, per town | On | Off |
|---|---|---|
| Ordinary, Endure + Prepare | 13.0 | 18.3 |
| Ordinary, Prepare + Pride | 12.7 | 17.8 |
| Difficult, Endure + Prepare | 26.3 | 28.3 |
| No wisdom, any condition | unchanged | unchanged |

Without Prepare, tool shortages come from early winters and failing towns, which a family changing its work a season later does not fix.

**The Prepare founding failure (revisited; Prepare unchanged).** In one of the two marginal towns (seed 1947700685), a farm family whose farm stood short of tools for a season reconsidered at day 210 and took up tool mending. The town now lives (0 → 65 people) under both Prepare pairs, on ordinary and stressed land. In the other (seed 2487541759), a family also changed to tools on ordinary land, but the town still starved: it was too late. On stressed land no family's margin reached 2.

**Outcome where families changed, and where they did not:**

| | Town-runs | People at year 6, on − off | Towns kept / lost against off |
|---|---|---|---|
| A family changed work | 37 | +6.7 | +5 / −1 |
| No family changed work | 179 | −1.5 | +1 / −9 |

Where no family changed its work, reviews alter nothing, so the only difference is the retired calling swap. **Retiring it costs some marginal towns:** the 9 lost town-runs are three towns, repeating across strategies (stressed 2610263185, difficult 1193181149, ordinary 1668705218). The old swap moved families to work of their calling instantly and at no cost, which gains the calling's output bonus at once. Overall, kept towns on/off: ordinary 64/62, stressed 58/62, difficult 43/45. People differences are within the spread except for the Prepare towns above.

### Do priorities become more consequential?

Yes, but mostly by holding families in place.

- **Pulling families away:** a priority pulled a reviewing family toward other work in 185 reviews, and tipped only 3 changes.
- **Holding families in place:** in 287 reviews the priority's ask for the family's current work was a reason to stay. In 27 of them the family would otherwise have changed. For example, the Food priority kept farm families farming while tools ran short.
- **Overall difference from no priority:**
  - Food: −3.4 people on against −4.7 off (ordinary); Food still costs two ordinary towns.
  - Investment on difficult land: +23.0 and 4 more towns, against +21.6 and 3.

### Oscillations and new failures

- **No oscillations:** no family changed twice.
- **No new kind of economic failure:** no abandoned toolmaking, and no shortage caused by changes.
- **The new costs** are the retired swap's three marginal towns. One more town (difficult 1193181149, no wisdom) declined after a farm family moved to wood in year 4, but the same town declines without that change under other strategies, so it is not clearly caused by it.

### The one-family-a-month limit

- **It never bound:** 0 deferrals in any run.
- **Lifting it changed nothing:** identical results on all three conditions.
- **No family wanted to change in the same month as another.**

Up to about 25 families a town (the largest here), the limit is harmless and unnecessary. Its job is to stop a town-wide herd (many families answering the same shortage at once), and the once-a-year interval, the margin and the investment weight already prevent that here. A town of 100+ families would review about 25 a year and might change a few; a fixed limit of one a month could then delay rather than prevent. Recommendation: keep it as a safety net and revisit it when towns that size exist; a limit scaled to town size (one per 25 families) is an option then.

## What This Shows

- **Families adapt, imperfectly and rarely.**
  - They move when their own work fails them and the town needs something else: a farm short of tools becoming a tool mender, a woodcutter of the soil moving to food when food runs thin.
  - They stay when what they have built outweighs what they would gain.
  - Some changes come too late to save a town.
- **Changes help where they happen**, but they are rare. Most of the families who would like to change have a proper workplace, and the +3 for it, the idle workplace and their years there almost always win. The weights were not changed after the comparison.
- **The player's influence stays indirect.** A priority reaches families who are reconsidering anyway, and more often keeps them where they are than moves them.

## Open Decisions

1. **The retired calling swap's cost:** three marginal towns survived on instant, costless moves to calling work.
   - Accept the cost as the price of costed decisions.
   - Or shorten the wait before a family may first reconsider: two seasons now.
   - Or lower the barrier for a family working against its calling.

   Either change is a design choice, not tuning.
2. **Rate of change:** about one family in a hundred changes its work in six years. If "adapting" should be more visible, the lever is the weight of what a family has built up (+3) or the margin (2). Both were set before the comparison.
3. **Distance never triggered.** Homes do not move far from work in these towns. The rule stays, untested in play.
4. **The monthly limit:** keep it as a safety net (recommended), and revisit it for towns of 100+ families.
5. **Contested land:** a family changing work never contests land. As land grows scarce, it will more often find no free site and stay.
