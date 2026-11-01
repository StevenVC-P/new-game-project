# Investigation: Why Families Don't Build a Toolmaker or a Herder's Fold

**Status: findings only (2026-11-01). Nothing in the game was changed.** Branch `investigate/workplace-choices`, from `feature/household-self-sufficiency` (the build the owner played). Not merged.

**Evidence:**
- **Traced runs:** `tests/sim/workplace_choice_check.gd` traces every family decision about work. It ran 12 towns × 3 years on ordinary, stressed (first winter's stores lost) and difficult land, each with and without the investment priority, and with and without the household economy: 144 town-runs in all.
- **Each decision recorded:** the day before every weekly decision it scores each free family's options, with that week's same random term, then reads the decision the family made.
- **The owner's own town:** a copy of the playtest autosave (day 82) was loaded and its families' options scored.

## Answers

### 1. Do families consider toolmaking and herding?

**Toolmaking: yes, but almost only families of the forge calling take it up.**
- **Rejecting it:** a family of another material calling (soil, forest, stone…) scores tools −2 ("it is not the family's calling"). Every family scores −2.5 for each household already making tools ("others already make tools"). Together these are the two reasons in every rejection.
- **Choosing it:**
  - **Who:** about 80% of forge-called families later free to choose work picked tools (12 of 15 on ordinary land).
  - **Other takers:** families with no material calling, when no one makes tools.
- **Rank:** in 65% of decisions without a priority, tools was the family's last choice of three.

**Herding: never considered.** A family chooses only among food, wood and tools (`FamilyInitiative.ACTIVITIES`). Herding has no hand-work stage, so there is nothing to improve into a fold. Fishing and hunting are missing in the same way.

### 2. Do families take up hand work and never improve it?

**Tools: usually they do improve it.**
- **The usual case:** in 9 of 12 ordinary towns, the first tool mender was improved into a toolmaker within 1–8 months (days 40–250).
- **The slow towns:** in two towns it took 2–3 years. The one tool-mending family was cautious, unhurried or traditional, and lost the improvement decision in 130–150 weeks out of 133–151 ("the method is untried here", "the family is unhurried", "very cautious").

**Herding:** there is no hand work to take up.

### 3. Economic incentives

**Toolmaking has little economic pull, because tools are rarely short.**
- **The arithmetic:** a tool mender (hand work) makes about 120 tools a year, against 80–140 a year of upkeep in a town's first years. So the stores fill: median 120–180 tools at year 1 and 600–900 at year 3 on ordinary land.
- **The urgency terms** ("tools are running out", "the town needs tools") appear only under 10 tools. That held at 3–6 of 36 year-ends on ordinary land.
- **So it comes down to temperament:** whether a tool mender improves depends on the family's own nature far more than on the town's needs.

**Herding:** wool meets the clothing need, which went unmet at year 3 in nearly every town (wool 0 everywhere). It is a real need with no producer.

### 4. Construction constraints

- **Toolmaker: wanting it but not able, often for a while.** A toolmaker costs 10 wood. Families who wanted to improve were held back by the stores many times:

  | Conditions | Weeks over the threshold | Weeks held back |
  |---|---|---|
  | Ordinary, investment priority | 341 | 324 |
  | Difficult | 112 | 102 |
  | Ordinary, no priority | 56 | 43 |

  The cause was the wood reserve and wood committed to other sites, mostly homes. These improvements still came, later.
- **Herder's fold:**
  - **Land:** suits it. A fold site was found in 7–12 of 12 towns, at 58–72% of full pasture.
  - **No builder:** no family will build it, and the player can place it only through the folded "Commission a building (optional)" list on the Planning page.

### 5. Values

- **Calling** decides take-up (+3 for, −2 against).
- **The household economy** adds "it knows the work" (up to +2), which pulls further toward known work.
- **Personality** (risk, diligence, ambition, openness, tradition) decides improvement.
- **The community priority** (investment) moves tools: it was chosen first in 30–38% of decisions, against 13–17% without it.

### 6. Availability

- **A fold** can reasonably be built in most towns. Some sites lack pasture.
- **Toolmaking** has no terrain needs. It is unavailable only when no family is free to choose it.

## The Owner's Town (autosave, day 82)

- **The families:** seven families, none with the forge calling. All six founders took food or wood work in the first two weeks, when the town grew less food than it ate, and have since improved it (5 farms, 1 woodcutter).
- **Tools:** 8 left, with six proper workplaces about to need upkeep.
- **The newcomer:** family 6, the only free family, scores food 2.17 against tools 1.50 this week. On the food side: its farming calling (+3) and "it knows the work" (+1.27). On the tools side: "not the family's calling" (−2) outweighs "tools are running out" (+2.5) and the gathering's ask (+2.0). It will take up a garden.
- **No one can switch:** the families already working are under the occupation review's 180-day tenure, so none of them can move to tools yet.
- **Herding is wanted:** family 2 (loom calling) wishes for exactly one thing, a herder's fold. No family can build one, so the wish waits.

## Diagnosis

**Herder's fold: a decision-making gap**, not balance and not a bug in a rule.
- **Families want it but can't build it.** Herding isn't an option in families' own choice of work. The calling wish that points at it ("work the player answers") can only be answered through the folded commission list.
- **The scale:** 8–14 families per 12 towns wished for it for 175–300 family-months, while the clothing need went unmet.
- **The same gap** affects the fisher's hut and the hunter's lodge.

**Toolmaker: mostly expected situational behaviour, with one gap.**
- **Expected:**
  - Tool work is chosen by the families it suits.
  - One family is enough (hand work oversupplies tools early).
  - A cautious family improves slowly when the town has tools.
- **The gap:**
  - **When it happens:** if no forge-called family is free when the town is founded, the town gets no tool work until a free family arrives and happens to choose it. Families already at work can't reconsider before 180 days.
  - **An example:** in one ordinary town (seed 1668705218), all six founders took food and wood work, no one ever made tools, and the town sat at 0 tools for three years with every proper workplace short of upkeep.
  - **The owner's town** is heading the same way.
  - **The skill term:** the household economy's "it knows the work" makes this more likely, since free families are pulled further toward known work.

## Smallest Corrections (recommendations; none made)

1. **Herding (and fishing and hunting) as a family's own choice.**
   - **What:** a family whose calling is drawn to work that has no hand-work stage could ask for that proper workplace itself, through the same pipeline and stores rule as an improvement. Its reasons would be its calling, the town's need (the clothing need for wool), and the land in reach.
   - **The simplest form:** answer the calling wish families already form (`FamilyAmbitions`), with the family building it rather than the player.
   - **Not forced:** towns without pasture or loom/soil families wouldn't get folds.
2. **The tool gap: let a working family respond when the town has no tool work at all.**
   - **What:** for example, the occupation review could start before the 180-day tenure when the town has no toolmaking, its tools are under 10, and its proper workplaces need upkeep. The family would still weigh it with its usual reasons, so calling and temperament keep deciding who goes.
   - **The alternative:** recognise that the household economy's mending (secondary work) already lets families keep their own workplaces, and leave the gap.
3. **No change to production numbers.**
   - Tools are abundant once anyone makes them.
   - The slow improvement by cautious families is the diversity the design wants.
4. **For decision, not correction:** whether the "it knows the work" pull (household economy, up to +2) should weigh less in a family's first choice when the town lacks a whole trade.
