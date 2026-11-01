# Families Reconsidering Their Work

**Status: proposal for owner review (2026-10-31). Nothing here is implemented.** Branch `feature/occupation-reconsideration`, stacked on `feature/guiding-wisdom` (which stays unmerged).

Owner brief (2026-10-31): the smallest implementation that lets families recognise when their current work no longer suits their needs, values or economic circumstances. Preserve autonomy: reconsidering must not mean chasing whichever occupation scores highest today. Show how it would interact with Community Priorities and Guiding Wisdom. Earlier direction (`docs/COMMUNITY_PRIORITIES.md`, after the combined evaluation): weighed by the economy, values, calling, opportunity and the cost of changing; no weekly switching; no immediate compliance with the player.

## Audit: What Exists

**A family chooses its work once.** `FamilyInitiative.take_up_work` runs weekly for a family with no holding. It weighs food, wood and tools (`get_work_desire`): its calling (+3 good, −2 poor), what the town lacks (food ratio, producers, wood under 20, tools under 10), the priority's ask, and Prepare for Hard Times; adds bounded noise; and opens hand work near home. After that the only work decision is whether to improve that hand work (`consider_improving`). Families choose again only when they have no holding: new households (grown children), land given up in a contest.

**One narrow change of work already exists.** `FamilyAmbitions.take_calling_work` runs monthly for a family whose ambition is its calling. It swaps holdings with a family that is not drawn to that work, or takes a vacant workplace of its calling when another family is free to take its old one. It is instant and costless: both families keep the other's tier. It covers callings only. It never weighs the town's needs, the family's investment or its temperament.

**A family's work pays it nothing directly.** All output goes to the common stores, and there is no household income. Economic circumstances reach a family through two channels:
- the town's needs, which are already terms in its decisions;
- its own workplace: standing idle or worked by hand for want of tools, travel time, trampling, the season, wolves.

**Signals that already exist:**

| Signal | Where | Meaning for the family |
|---|---|---|
| Calling match (good, neutral, poor) | `Household.get_match_quality`; fixed founding values, not changed by lessons | values |
| Calling ambition waiting past patience (12 months) | `FamilyAmbitions`; costs hardship tolerance | needs, values |
| The town grows plenty (food ratio over 1.6), or others already do the work | `get_work_desire` | economy |
| The town is short of an output | `get_waiting_risk`, `GuidingWisdom.is_short_of` | economy |
| Workplace short of tools, idle | `Building.maintenance_level`, `can_produce` | economy, its own work |
| Travel share | `TownLogistics.get_travel_share` | needs |
| What it has built up (hand work or proper) | `Building.is_tier0` | cost of changing |
| Temperament and convictions: risk, tradition, reform, Keepers of Craft, Expedient, Self-Governing, Hopeful | `HouseholdCharacter` | values |

**What the towns look like.** A temporary probe, not in the code: 12 ordinary towns, no wisdom, families lead, 6 years, sampled each season.

| | Year 1 | Year 3 | Year 6 |
|---|---|---|---|
| Families with work | 96 | 128 | 218 |
| On proper workplaces | 92 | 124 | 215 |
| Working against their calling | 16 (17%) | 20 (16%) | 51 (23%) |
| Wanting calling work (ambition) | 27 | 46 | 82 (37%) |
| Workplace short of tools | 6 | 1 | 0 |
| Towns short of food, wood or tools | 4/12 | 3/12 | 2/12 |
| Families in an oversupplied trade while another is short | 3 | 4 | 6 |
| Stores (per town): tools / wood / food ratio | 257 / 2,192 / 1.4 | 895 / 9,397 / 2.6 | 2,666 / 21,710 / 2.6 |

Read with care:
- **Calling is the common mismatch; the economy rarely is.** After the first year, ordinary towns are short of nothing. Wood and tools pile into the thousands, the known material surplus noted in `COMMUNITY_PRIORITIES.md`. A family that reconsiders has almost nowhere to go for economic reasons. Families lead only food, wood and tools, so many callings (water, forest hunting, loom, stone) point to work families cannot take up themselves; the harness also never builds fisher, hunter or herder.
- **Where the economy does turn**, it does so early and on hard land: the first winter, the tool cliff, difficult sites. That is exactly when a cautious design would hold families still.
- **Almost every family is on proper work by year 1**, so changing work nearly always means giving up a proper workplace and starting again by hand.

**A case it would repair.** Traced in `docs/GUIDING_WISDOM.md`, Prepare version 4. Under Prepare for Hard Times, one founder of a marginal town takes up food work instead of tool mending: every founding has under three months of food. No one ever makes tools. From day 150, every proper workplace falls back to hand work for want of tools, and the town starves in its second year. Its families watch it happen and cannot respond, because work is never reconsidered. This is the "its own workplace short of tools for a season" trigger below.

## Proposal: The Smallest Version

### 1. Families reconsider only when something material has changed, and rarely

Each month, a family may reconsider when at least one of these holds, and only if it has not reconsidered in the last year (and not within a year of taking up its work):

1. **Values:** it works against its calling, or its calling ambition has waited past its patience, and work of its calling is something it could take up (food, wood or tools here).
2. **Economy, its own work:** its workplace has stood short of tools (worked by hand, or idle) for a whole season.
3. **Economy, the town:** the town has more than enough of what it makes (food ratio over 1.6, or two other producers of its wood or tools) while it is short of another output.

A Community Priority or a Guiding Wisdom alone never starts a reconsideration. They weigh in once the family is reconsidering for its own reasons (below). Nothing is weekly.

### 2. Weighing staying against the best alternative

- **The alternative:** the existing `get_work_desire` for each of the other activities. That is the same reasoning as the first choice: calling, town needs, the priority's ask, Prepare, and noise.
- **Staying:** `get_work_desire` for its current activity, plus the cost of changing, each a reason in the family's words:
  - **"It has built up its work":** about +2 for a proper workplace, +0.5 for hand work. Changing means starting again by hand at a third of the output.
  - **Temperament and convictions:**
    - Traditionalist: + "it keeps to what it knows".
    - A cautious risk axis: + "it would not risk what it has".
    - Keepers of Craft: + "it keeps its craft".
    - Expedient: − "it does what pays".
    - Reformist or Hopeful: − "it is ready for something new".
- **The decision:** the family changes only when the best alternative beats staying by a margin (about 2). The noise stays below that margin, so a family predicted to stay stays.

These weights are first proposals to be set before the comparison, not tuned to it.

### 3. Changing, with real costs and no abandoned work

- **The new site comes first.** The family opens hand work for the new activity through `take_up_work`'s existing site choice and construction pipeline. It keeps its old work until that site exists. In this version it does not contest land: if there is no free site, it stays and says why.
- **The old workplace is handed on, never left empty:**
  - A family free to work (a newcomer) takes it, through the existing assignment.
  - Failing that, a family that wants it swaps with it: the calling swap, now with consent, since the swapping family must itself be reconsidering toward it.
  - Failing both, a proper workplace is not left empty and the family stays: "no one could take on its farm". Hand work it may simply leave.

  Empty proper workplaces still draw tools for upkeep, an existing rule, so this rule is what keeps reconsideration from spending the town's tools.
- **The existing calling swap is folded in.** `take_calling_work`'s instant, costless swap becomes the swap route of this decision, with costs and consent, rather than a second path.
- **At most one family changes work a month town-wide.** Each decision sees the others in progress (`count_producers` counts projects), so families do not all leave food for tools at once.

### 4. What families say

- The Families page shows "Considering other work" with its reasons for and against, and the outcome as the family's decided note: "Took up woodcutting: its calling is the forest; it gave up its farm to the Ashby family", or "Stays at its farm: it has built it up; no one could take it on".
- The change is a memory. Lessons from it can wait (see Decisions).

## Autonomy: Why Families Do Not Chase the Top Score

- **Triggers, not scores.** A family looks again only when its own situation has changed. Never because another trade scores higher today, and never because the player asked.
- **Rarely:** at most once a year per family, and one family a month town-wide.
- **Investment and temperament hold families in place.** Most families stand on proper work, and giving it up is a real loss. Cautious, traditional and craft-keeping families hold on harder; expedient, reformist and hopeful families move more readily.
- **A margin and bounded noise:** a near-tie never moves anyone.
- **Ability apart from desire:** a family that wants to move but has no site, or no one to take its workplace, stays and says so.

## Interaction with Community Priorities

- **Priorities would reach established families, not just newcomers.** The asks are already terms in `get_work_desire`: Food in food work, Investment in tool work. The combined evaluation named "work is chosen once" as one reason a priority shows so little on ordinary land, so this widens the priority's reach, but only for families already reconsidering.
- **The risk is the food trap again.** A food priority could pull a toolmaker off tools.
  - **Guards:** the priority never starts a reconsideration; staying keeps the family's investment; the old workplace must be handed on; one change a month.
  - **Warning:** the priority's warnings should name it ("families reconsidering their work may leave tools for food").
  - **Measured:** "decisions tipped" gains a work-change entry (`CommunityPriority.record_swayed`), and the comparison counts tool-cliff towns.
- **Cooperation and Housing** do not enter work choice, so they are unaffected.
- **Trust:** unchanged. A priority that pulls families into work that fails them could later cost trust, but the evaluation does not ask for that yet.

## Interaction with Guiding Wisdom

- **Prepare for Hard Times:** its appeal is already in `get_work_desire` for whatever the town is short of: food, and since this revision, wood and tools. A reconsidering family in a Prepare town leans toward the short supply, and the choice counts as Prepare conduct. This gives Prepare occasions that grow from real shortages, not new ones made for it.
- **Take Pride in Your Work:** its expectation, doing work well, would weigh for staying with work the family has built up. Keeping one's craft through a lean spell is "followed"; leaving for what pays is "declined". This is the recurring decision Pride lacks: it costs output when the town needs the family elsewhere, and keeps the family's proper workplace and craft. Expedient families, Pride's counter-quality, would lean the other way. Pride gains occasions only where families actually reconsider: mostly the calling cases, rarely the economic ones on ordinary land.
- **We Endure Together:** no hook. Helping and sharing are its decisions; giving it one here would blur it into Prepare.
- **Respect What Others Build:** no hook while reconsidering never contests land. When land grows scarce, a family wanting land others hold would meet Respect through the existing contest, so its relevance grows with the town, as decided.
- **Lessons:** whatever lessons a change of work later teaches pass through the wisdom's framing like any other experience.

## Left Out on Purpose

- Household income or reserves.
- New occupations for families to lead: fisher, hunter, herder and stone stay the player's work.
- Contesting land to change work.
- Player commands.
- Changes to production, upkeep or survival numbers.

## How It Would Be Validated

- **Rule tests:** each trigger, and nothing without one. The margin. The cost of a proper workplace. The year between reconsiderations and the town's one a month. The old workplace handed on or the family staying. No land contests. Reasons in words. Saves.
- **The same matched-seed comparison** (`wisdom_check` conditions: ordinary, stressed, difficult; 6 years), on against off:
  - families changing work (how often, how many twice, any A-to-B-to-A swings);
  - families working against their calling;
  - calling ambitions fulfilled;
  - tool-cliff towns;
  - people.

  Then the Food and Investment priorities with it on, and the Prepare and Pride pairs.
- **Success would look like this:**
  - rare changes (most families never, few twice, no swings);
  - fewer families against their calling;
  - no new collapses;
  - the Food priority no worse than today.

  A failure would be reported as such.

## Decisions for the Owner

1. **Triggers:** calling, its own workplace short of tools, and oversupply while short. Should travel (a family whose home moved far from its work) also count?
2. **Who may change:** may a family leave a proper workplace when no one can take it on? Recommended no in this version.
3. **The existing calling swap:** fold it into this decision with costs and consent (recommended), or leave it beside it?
4. **Priorities:** confirm that a priority weighs in but never starts a reconsideration.
5. **Pride:** confirm "staying with work the family has built up" as Pride's expectation in this decision.
6. **Lessons:** should changing work, or staying against a pull, teach lessons now (for example "a family goes where it is needed", "we keep to what we know"), or only leave a memory in this version?
