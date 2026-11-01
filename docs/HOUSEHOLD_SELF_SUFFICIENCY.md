# Household Self-Sufficiency and Occupational Skills

**Status: implemented as a prototype (2026-11-01). Branch `feature/household-self-sufficiency`, stacked on `feature/occupation-reconsideration`. Not merged: awaits owner review.**

Code: `scripts/domain/household_economy.gd` (`HouseholdEconomy`). It hooks into:
- `City`: `tick`, `consume_food`, `skips_work_today`, `get_work_time_factor`, output modifiers, upkeep;
- `TownConstruction` (hungry builders);
- `HouseholdMigration` (the monthly decision; short days);
- `TownSocial.share_in_shortage`;
- `FamilyInitiative.get_work_desire`;
- the Families page.

Tests: `tests/household_economy_validation.gd`. Comparison: `tests/sim/wisdom_check.gd` with `--no-self-sufficiency` and `--disrupt=specialist|stores`.

Objective (owner, 2026-11-01): families respond to changing economic circumstances by adapting how they spend their time, developing useful skills, and deciding how much to depend on other families, without direct orders from the player. A town's economic behaviour should emerge from the decisions and accumulated experience of its households.

Core principle (owner): a family has limited working time, and everything it does competes for that time.

## Owner Decisions (proposal review, 2026-11-01)

The architecture and directions D1 to D8 are approved, with these changes:

1. **Larders: choosing to eat, save or share.** The first proposal had a family eat its harvest first. A garden yields about an eighth of a family's food, so nothing would ever be stored. Families need a real choice between eating, saving and sharing their produce. A family may eat from the common store while saving its own harvest, and that has consequences for the store and for how others see it. Food must never be made or eaten twice. Resolved below, before larders were built.
2. **Skills: no permanent floor.** Unused proficiency decays slowly and can disappear entirely. Inherited proficiency reflects what the parent family still knows. The learning rates and 60% beginner output are accepted as prototype values, subject to the simulation.
3. **Secondary work** runs at hand-work efficiency, but a garden needs suitable land near home and follows the season. It needs no placed building, but families can't garden anywhere at all.
4. **Errands:** existing behaviour kept.
5. **Starting skills:** founders and newcomers are experienced in the trades they already know, not in unfamiliar work they happen to take up.
6. **Disruption testing is required:** both the loss of a specialist and the loss of communal stores, on matched seeds.
7. **Time:** secondary work directly reduces time for specialised work.
8. **The existing surplus** isn't rebalanced in this milestone. Its effects are reported separately.

## How It Was Built

**The larder accounting (decision 1).** A family's harvest always goes into its larder, never directly into anyone's mouth or the common store. The family decides, monthly and one step at a time, how much of its own food it keeps back: 0, 30, 60 or 90 days of its own eating.

Each day, the town's demand is counted exactly as before: one food per two people, over the whole town, rounded up. Each family then eats in this order:

1. **Its own food above its target.** This is how a family that keeps nothing back shares its harvest: every unit it eats of its own is a unit the common store keeps. What families eat this way comes off the town's demand, so total eating is unchanged.
2. **The common store.** Below its target, a family eats from here and saves its harvest. This is the choice the owner described. It costs the common store what the family would otherwise have spared it.
3. **Its larder, only when the common store falls short.**

A family whose food wasn't all met is short today. The common store's shortfall is spread across families in proportion to what they draw from it.

**Conservation:**
- A larder fills only from the family's own harvest or a gift. It never draws from the common store.
- So every unit is in exactly one place: the common store, a larder, or eaten.
- With every larder empty, the store, the town flag and every family's shortness are exactly what they were (tested).

**Consequences:**
- **Hardship and hunger:** shortage hardship and lost working days follow each family's own short days (decision D2). The town flag stays for births, arrivals and the wisdoms' sense of shortage.
- **Sharing:**
  - In a shortage, a family that is short and near leaving asks families it knows, as before.
  - A donor with food put by gives real food: 10 days of the recipient's eating, from its larder to the recipient's. It takes on no hardship for this.
  - A donor without such food shares its ration as before, as an abstract point of hardship.
  - A family that could have given from its larder and didn't is remembered for it ("kept its larder while we went hungry").
  - That is how others see a family that saves. No wider gossip or perception system was built.

**How much time (owner, 2026-11-01).** A family taking up secondary work chooses how much of its day to give: 10%, 20% or 30%, never more than its reasons call for. The choice is random among those for now, and deterministic per town, family and day. After that the share moves at most one step a month.

**Garden land (decision 3).**
- **Within reach:** a garden takes two tiles of free ground within 3 tiles of the family's home. Free means open ground, no trees, no road, nothing built or reserved.
- **Ground quality:** fertile land yields in full; plain ground yields half.
- **No sharing tiles:** families claim their tiles in turn each month, by family number, so no two families garden the same tile.
- **No home:** a family without a home has no garden.
- **Season:** output follows the farming year (`FARM_SEASON_YIELD`), and the season is one of the family's reasons.
- **Gathering wood** needs woods within 4 tiles of home, scaled by the number of wooded tiles there, up to 6.
- **Mending** needs the family's own proper workplace.
- **Unit tests:** in tests without a town map, the land doesn't constrain anything.

**Skills (decisions 2 and 5).**
- **Decay:** unused proficiency decays toward nothing at a quarter of the learning rate, and is forgotten below 0.02.
- **Inheritance:** a new family inherits 60% of what its parents know at the moment it is first counted.
- **Founders and newcomers:** established (0.7) in the trades their calling draws them to. Nothing else.
- **A town already going** when the system first runs (an older save) knows the work it has been doing.

## 1. Audit

### Time allocation

A family's working day is one unit, and only its holding's output is computed from it (`City.get_work_time_factor`):

`holding share = 1 - travel share - spare time given to building today`

- **Travel** (`TownLogistics.get_travel`): hauling the holding's goods to the nearest store, plus walking from home. It is capped at 60% of the day.
- **Spare time** (`TownConstruction.project_add_spare`): 20% of the day given to the family's own project or the one it chose to help (`TownSocial.choose_help`).
  - A family working long days (`TownSocial.choose_hours`) gives that 20% out of its rest instead. Its holding loses nothing, and three long weeks in a month are a point of hardship.
- **Families without a holding** are the town's full-time builders.
- **Errands** (`TownErrands`): fetching water, firewood and stores, and visiting kin. They are the household's own time outside the working day. They produce nothing; they only wear paths.
- **Hauling** is computed from a holding's full base output, whatever share of the day the family works. This already holds for spare-time building. It is a small existing simplification, left as it is: changing it would change a production formula.

**What this means here:** the time budget already exists and is respected by building. Secondary work fits as a third claim on the same day, with no new accounting model. Errands produce nothing, so leaving them outside the working day double-counts no labour.

### Tier 0 production

Hand work (forager's garden, gatherer's camp, tool mender: `BuildingTiers`) is a building:
- a whole family's single holding;
- one third of its proper counterpart's output (`TIER0_OUTPUT_FRACTION`);
- no tool upkeep.

A proper workplace short of tools can fall back to working by hand at the same pace (`Building.works_by_hand_without_tools`).

**What this means here:** there is a ready-made, already-balanced number for "much less efficient than specialised work". A family's day of hand work yields a third of a proper day's output. Secondary work can reuse that rate, so no new production constants are needed.

### Household consumption and stores

Everything is communal:
- **Food.** `City.consume_food` draws the town's whole demand from `City.resources`: one food per two people, rounded up over the whole town. Households have no goods of their own.
- **The shortage flag.** It is town-wide (`resources.food_shortage`), and it drives:
  - **hardship:** every household gets the same shortage points once the town has 10 short days in a month (`HouseholdMigration`);
  - **lost working days:** hungry families lose about a quarter of their working days, by town-wide tick (`should_skip_for_food_shortage`);
  - births, arrivals, and Prepare's sense of shortage.
- **Sharing in a shortage** (`TownSocial.share_in_shortage`) moves a point of hardship from recipient to donor. It is an abstraction of a shared ration, with no goods moved.
- **Wood:** households don't use it. It is only for building and toolmaking.
- **Tools:** households don't use them. Workplace upkeep uses them (1 tool every 16 to 24 days per proper workplace).

**What this means here:** "self-sufficiency benefits the producing household first" has nothing to attach to. Every gain goes straight into the common pool, and every shortage is shared equally. This is the one real architectural gap (decision D1).

### Skills

None. `Household.family_trade` is a label (farming, woodcraft, toolmaking…):
- inherited with chances by new families (`City.get_inherited_family_trade`);
- with a small related-trades table (`City.get_related_family_trades`);
- used only to rank work successors.

The design sources anticipate skills:
- `GAME_VISION.md` item 11: "skill and technique are household data… extending today's `family_trade` inheritance".
- `CULTURE_AND_VALUES_MODEL.md` names Hands-On, Keepers of Craft and Teachers as shaping skill growth. They aren't wired yet.

Culture values that bear on self-reliance are held today, but none of them affects anything economic yet:
- Self-Reliant
- Thrifty
- Private Holdings and Common Stores
- Communal Labor and Solitary

### Occupation switching

`OccupationReview` (on the parent branch) weighs staying against the alternative. Staying gets:
- **Built up:** +3.0 for a proper workplace, +0.5 for hand work.
- **Tenure:** +0.5 a year, up to +1.5.
- **Idle:** +1.5 if a proper workplace would stand idle.
- **Temperament and travel.**

A change needs a margin of 2.0. The +3.0 "built up" term appears in 1,342 of 1,355 decisions to stay, and it is the main source of the resistance the owner calls artificial. Learning a new trade costs a family nothing today: it works at a full family's rate from the first day.

### The surplus after year one

These are from the matched comparison towns, no strategy (`wisdom_check`), medians with maxima in brackets:

| Condition | Tools, year 3 | Tools, year 6 | Food days, year 3 | Food days, year 6 |
|---|---|---|---|---|
| Ordinary | 868 (2,299) | 2,344 (5,605) | 306 | 533 |
| Stressed | 786 (2,299) | 1,974 (5,605) | 251 | 490 |
| Difficult | 110 (1,392) | 309 (3,603) | 50 | 87 |

The cause is arithmetic, not a bug:
- A toolmaker family makes about 300 to 330 tools a year.
- A proper workplace uses about 18.
- So one toolmaker supplies about 18 workplaces, while ordinary towns run 2 to 3 toolmakers for 12 to 24 workplaces.
- Nothing slows a specialist down when the stores overflow, apart from the occupation review's oversupply trigger, which also needs the town to be short of something else.

The harness doesn't record wood yet; phase 5 adds it.

**An honest expectation:** self-sufficiency can trim this surplus. A family whose trade is oversupplied has a real reason to put some time elsewhere. But it can't remove the surplus: under this proposal secondary work takes at most 30% of a day. The surplus is a demand-side imbalance, and I won't tune it away.

## 2. Proposal: the smallest coherent implementation

One new domain script, `scripts/domain/household_economy.gd` (`HouseholdEconomy`), plus small fields on `Household`. Each part reuses an existing mechanic.

### 2.1 One working day, three claims

`City.get_work_time_factor` becomes:

`holding share = 1 - travel - spare time for building - secondary share`

- The holding takes what's left of the day (never below 0).
- Secondary work gets at most what remains after travel and building. A family can't spend time it doesn't have.
- Long days still cover building out of rest, never secondary work.
- Errands stay outside the working day (decision D5).

### 2.2 Secondary work

A family on a holding can give 0%, 10%, 20% or 30% of its day to one secondary activity. These are the same three activities families already understand (`FamilyInitiative.ACTIVITIES`):

| Activity | What it is | Output for a share *s* of the day | Where it goes |
|---|---|---|---|
| Food | a garden at home, gathering | *s* × tier 0 food rate × season × proficiency | the family's own ration first, then its larder up to its target, then the common store |
| Wood | firewood and small lumber from the nearest woods | *s* × tier 0 wood rate × proficiency, less the walk (the errand route to the woods' edge) | the family's own building project first (delivered on site), then the common store |
| Tools | mending its own workplace's tools | *s* × tier 0 tool rate × proficiency, as mending progress | its own workplace's upkeep: when upkeep falls due, a full unit of mending takes the place of a tool from the store |

A tier 0 rate is a third of the proper rate. So a 20% garden yields about 0.27 food a day, which feeds about half a person. A family of four eats two food a day, so 20% of its time feeds about an eighth of the family. Specialised work stays far more productive, as the owner requires. Nothing is free: every unit comes out of the holding's day.

Families without a holding stay builders. Old couples and one-adult families work at their labour factor, as today.

### 2.3 Families decide their time (monthly)

Once a month, each family weighs its secondary share, with the same desire, terms and noise machinery as every other household decision. Reasons are shown on the Families page ("Keeps a garden (food is short; the family is cautious)").

**Pulling toward more secondary work:**
- the town is short of the activity (`GuidingWisdom.is_short_of`, `FamilyInitiative.get_waiting_risk`);
- its own larder is below its target;
- the stores hold plenty of what its own holding makes (diminishing worth of more of it);
- its own workplace is short of tools (mending);
- a cautious temperament (the risk axis);
- the values Self-Reliant, Thrifty and Private Holdings;
- low trust in leadership or in its neighbours (its ties);
- some proficiency in the activity already;
- the season (gardens pay little in winter);
- Prepare for Hard Times.

**Pulling toward its own work:**
- its proficiency in its own work;
- its calling;
- the values Common Stores, Communal Labor and Sharing;
- high trust;
- a town well supplied;
- Take Pride in Your Work.

**Community Priority:** the gathering's priority adds appeal for its activity. It can tip a choice but never starts one, as in the occupation review.

**Gradual:** the share moves at most one step (10%) a month, so families drift rather than flip. It is recorded as conduct for the wisdoms, as other choices are. This means modest secondary work in good times for cautious or self-reliant families, and more for many families when shortage comes.

### 2.4 The household larder (food only)

The smallest accounting that lets self-sufficiency benefit the family first. See decision D1 for the options.

**The larder:**
- `Household.larder`: food, a float, saved like any domain field.
- **Its target:** set from the family's character, about 30 days of its own food by default.
  - Prepare, Thrifty and Private Holdings raise it.
  - Common Stores and We Endure Together lower it, so the surplus goes to the common store.

**Each day:**
1. The town's demand is computed exactly as today, so total consumption is unchanged.
2. Each family's share of it is met:
   - first from its own garden's produce today;
   - then from the common store;
   - then, only if the common store falls short, from its larder.
3. Garden produce beyond the ration fills the larder up to its target. The rest goes to the common store.

A larder is therefore a true reserve. It isn't eaten while the common store can feed the family, and it isn't hidden from the town once full.

**Who goes short** (decision D2):
- A family whose needs were met today is not short.
- Hardship and hungry working days follow the family's own short days, not the town flag.
- The town flag stays for everything else that reads it (births, arrivals, the wisdoms' sense of shortage).
- With every larder empty and no gardens, every family is short exactly when the town is, so the result is identical to today.

**Sharing:** the existing mechanic stays. A donor's larder counts toward whether it can afford to share, and giving moves real food: a few days of the recipient's ration from the donor's larder to the recipient's. The abstract hardship transfer stays only when the donor's larder is empty.

There are no wood or tool larders. Wood and mending serve the family's own projects and workplace directly, which is the household benefit without a stock.

There is no currency, no market, no private ownership of stored goods beyond the larder, and no spoilage (common stores don't spoil either).

### 2.5 Proficiency

**The data:** `Household.proficiency`, a dictionary from work to a level between 0 and 1. It is keyed by base production type (farm, fisher, hunter, woodcutter, toolmaker, quarry…), so it scales to every workplace, including the expanded goods.

**Learning:** practice raises it:

`level += time spent × (1 - level) / LEARN_DAYS`

- The time spent is the holding share for the primary work, or the secondary share.
- It is fast at first and slower near mastery.
- Proposed: LEARN_DAYS = 360, so a novice reaches about 0.63 in a year of full-time work and about 0.86 in two.

**Decay:** an unused skill decays toward a floor of half its peak:

`level -= (level - floor) / DECAY_DAYS`

- Proposed: DECAY_DAYS = 1,440, four times slower than learning.
- A family returning to its old work picks up where its retained skill stands.

**Transfer:** practice also teaches related work at a quarter of the rate. The table is small:
- farm, fisher, hunter and herder;
- woodcutter and toolmaker;
- toolmaker and carver;
- stonecutter, quarry and mason;
- it mirrors and extends `get_related_family_trades`.

**Starting levels:**
- Founders and arrivals: 0.7 in the work of their `family_trade` (established).
- New families: 60% of their lineage parent's levels (accumulated household knowledge across generations).
- Others: 0.

**Effect on output** (decision D3): proficiency multiplies a holding's and secondary work's output, with a floor so a novice produces something.

`factor = NOVICE + (1 - NOVICE) × min(1, level / ESTABLISHED)`

- Proposed: NOVICE = 0.6, ESTABLISHED = 0.7.
- An established family produces exactly today's output, the ceiling.
- A farmer who becomes a toolmaker starts at about 0.6 to 0.65 of an experienced toolmaker, and reaches parity after a little over a year of full-time work.

**Effect on decisions:**
- **The occupation review** gains two grounded terms. Staying gets "it knows its work" (its proficiency). The alternative gets "it already knows that work" (its proficiency there), and costs "it would have to learn it" (the output it would lose while learning).
- **The secondary choice** prefers what the family already knows.

Values shape the learning rate only as the design sources already say: Hands-On learns faster by practice, and Keepers of Craft passes more to children. This is decision D7, deferrable.

### 2.6 The wisdoms

Each wisdom shapes decisions only, never output.

- **Prepare for Hard Times.** It raises the larder target and the secondary share when supplies are thin. Conduct is recorded:
  - followed when a family keeps a reserve or mends its own;
  - declined when it could and doesn't.
- **We Endure Together.** It lowers the larder target, sending food to the common store. It makes a family readier to give from its larder when sharing. Its secondary work goes to the common store, not to its own project.
- **Take Pride in Your Work.** It keeps time in the family's own craft, lowering the secondary share. It never adds output. Proficiency grows faster only because more time goes into the craft.
- **Respect What Others Build.** Unchanged, with no new land conflicts.

### 2.7 The reconsideration weights

Unchanged in the implementation, as the owner asked. Phase 5 runs one comparison variant (not adopted) with the proficiency terms in place and the "built up" term lowered from 3.0 to 1.0, to see whether real learning cost and lost proficiency hold families about as well. The owner then decides.

## 3. Decisions for the owner

- **D1. Household reserve accounting.** Options:
  - **(A, recommended) A food larder per household, as in 2.4.** Small: one float field. The day's consumption order changes, but total consumption doesn't.
  - **(B) Eaten on the day, no larder.** Garden produce only offsets the family's draw that day; there is no reserve. It is the smallest, but Prepare has nothing to keep, and a winter shortage finds no garden in it.
  - **(C) A claims ledger.** Produce goes to the common store and the family holds a claim to draw first. It is effectively credit, close to the currency the owner excluded.
- **D2. Per-household shortage.** Hardship and lost working days follow whether a family was fed, not the town flag. Without this, a larder protects no one. It is identical to today while larders are empty.
- **D3. Proficiency changes output.** This is a production formula change, which the occupation round excluded unless approved.
  - Recommended: today's output is the ceiling for an established family, and inexperience costs up to 40%.
  - Alternative: proficiency affects decisions only, but then the farmer-turned-toolmaker isn't actually less capable.
- **D4. Secondary rates come from tier 0.** A third of the proper rate, with no land, building or tool upkeep needed (a garden at home). Proposed shares are 0%, 10%, 20% and 30%, one step a month.
- **D5. Errands stay outside the working day.** They produce nothing, so nothing is double-counted. The alternative is to charge them to the day too, which would lower every holding's output today.
- **D6. What wood and mending serve.** Wood goes to the family's own building projects first; mending keeps its own workplace only. There is no household wood or tool stock.
- **D7. Starting proficiency and values.**
  - Founders and arrivals start established in their trade; new families get 60% of their parent's levels.
  - Hands-On and Keepers of Craft can be wired now, or deferred.
- **D8. A disruption condition for validation (optional).** It tests "specialised towns are vulnerable when supply chains fail". In year 2 the town's toolmaker family leaves, or a raid takes most of the tools and wood. The shock is the same on both sides of each matched pair, so it creates no artificial shortage in the comparison.

**Expected consequences, stated before building:**
- Founding may get harder. Founders who take up work outside their trade start below today's output. This is the area of the Prepare founding failure. It will be measured, not tuned away.
- Surplus should fall somewhat in prosperous towns, through oversupplied specialists gardening, and not otherwise.
- Specialised towns (Pride, Common Stores) should produce more but suffer more in a disruption. Self-reliant towns (Prepare, Self-Reliant) should produce less and ride it out better.

## 4. Phases (after approval)

Each phase ends with deterministic tests, the full suite, and a working state. Saves: new household fields load as their defaults from older saves; `GameState` needs a line only for non-domain state (none planned).

1. **Proficiency.** The data, learning, decay, transfer, starting levels and the output factor (if D3). Tests: learning and decay curves, return to old work, transfer, inheritance, save round trip.
2. **The time budget and secondary work.** The day's three claims; the three activities and their destinations; the monthly choice with reasons; a Families page line. Tests:
   - no double-counted time;
   - a toolmaker gardening makes fewer tools;
   - mending replaces a store tool;
   - the share moves one step at a time.
3. **The larder and per-household shortage.** Tests:
   - identical to today with no larders;
   - a fed family suffers no hardship in a town shortage;
   - sharing moves food;
   - total consumption unchanged.
4. **Wisdoms, priority and the occupation review's proficiency terms.** Tests for each wisdom's pull and its recorded conduct.
5. **Validation.** Matched runs with the system on and off (`--no-self-sufficiency`), on ordinary, difficult and stressed towns (and the disruption, if D8), at years 3 and 6. The strategies: none, the wisdom pairs, a priority, and contrasting cultures. They measure:
   - time on primary and secondary work;
   - lost specialised output;
   - survival and food security;
   - shortages and stores, including wood;
   - proficiency growth and decay;
   - career changes;
   - differences between families by value;
   - whether different cultural approaches each succeed;
   - the reconsideration-weight variant (2.7).
