# Home Sites

Owner brief (2026-10-31): families choose where to build their homes by their needs, values, relationships and circumstances; the player shapes development through land planning and encouragement, never by choosing a family's site. *The player controls the conditions under which families make decisions, not the decisions themselves.*

Code: `scripts/domain/home_sites.gd` (`HomeSites`), called from `FamilyDevelopment.claim_plot`. Tests: `tests/home_site_validation.gd`; comparison: `tests/sim/home_site_check.gd`.

## Land the Player Sets Aside

- **Plots** (existing, P): exact sites, as before.
- **Residential land** (new): broad areas marked on the town map (`HomeSites.mark(city, from, to, level)`, stored on each tile as `residential`, so saves carry it). Two levels: **permitted** and **preferred**. Marking a block again at the same level clears it.
- **What residential land takes** (owner, 2026-10-31, made explicit after Step 3 review): homes and huts, plots, roads, and communal infrastructure (`HomeSites.COMPATIBLE`: the storehouse); never a private workplace or field, whoever asks (`HomeSites.is_compatible`, checked in `TownConstruction.validate`: "That land is set aside for homes and shared works"). A storehouse among the homes takes the room homes would have had, as it would anywhere: putting one there is a planning trade-off. Land set aside over something already standing leaves it standing and worked. Preference and permission stay separate: preferred land takes exactly what plain land takes.
- **Nothing set aside, nothing built.** A family never builds outside plots and residential land; with none, or none left that can hold a home, it builds nothing and records why ("Household 3 cannot build a home: no land is set aside for homes"). The town's counter of families waiting for land (`families_without_plot`) still counts it.

- **Starting land** (`set_aside_starting_land`): a modest block a few tiles off the stockpile, on its roomiest side, the smallest of 5x5, 7x7 or 9x9 holding every founding family and two more. A passive player has it; it is not an optimized layout (owner, 2026-10-31). `ensure_starting_land` gives it once to a town where families lead: at founding, when a town's families are first given the lead, and when a town saved before residential land existed is loaded (`TownConstruction.starting_land_given` records it, so land the player later clears stays cleared).

## Feasibility, Then Preference

**Feasibility:** an open plot, or residential land that is not water, not occupied, passes the existing placement check (`TownConstruction.validate`: terrain, footprint, occupancy), and has a route to the family's work (`TownLogistics.effort_between`). Two families never take the same spot: a site, once planned, is occupied.

**Preference:** a sum of terms, each in tiles of walking and each a reason in the family's words (the same pattern as every family decision). Families without work weigh the walk to the stockpile, at half weight.

| Consideration | Term | Who weighs it, and how |
|---|---|---|
| Work | −route effort to work | everyone (1 per tile; 0.5 to the stockpile without work) |
| Kin | −distance to nearest kin's home × weight | 0.25 base, +0.25 per level of close-knit, clannish, traditionalist, elder reverence; −0.5 per level of leave-the-nest (negative: the family likes some distance, up to 12 tiles) |
| Friends | −0.3 × distance to nearest friend (disposition ≥ 2) | any family with friends |
| Rivals | −0.5 × closeness within 6 tiles of a rival (disposition ≤ −2) | any family at odds with another |
| Neighbours | ± homes within 5 tiles (up to 6) | +0.25 per sociability level, +0.25 per level of communal labor; −0.35 per level of solitary, −0.25 per level of self-governing |
| The town's heart | ∓1.5 × distance to the map's centre | town-loving closer, open-country farther (the old plot rule) |
| Room | open ground beside the home | 0.4 a tile for families wanting a fenced yard, prizing their own holdings, or hearth-proud; 0.1 for others |
| Calling | land for its work within 3 tiles | farming families: +0.5 a fertile tile (up to 6), −1.5 for building on fertile land itself; woodcutters woods; fishers water |
| Stores | −0.2 × distance to the nearest store | everyone |
| Road | +1 with a road at the door | everyone |
| Safety | −1.5 per caution level beside a river or lake; −0.5 per level at the woods' edge | cautious families only; daring ones ignore it |
| Preferred land | +2.0 × receptiveness | the gathering's hope (the ask weight, `FamilyInitiative.ENCOURAGE_WEIGHT`), heeded by deference, trust and respected voices, resisted by self-government |

No new personality attributes: every weight reads existing values, axes, ties, callings and ambitions.

**Cost:** every candidate is ranked by its distance terms alone (`get_rough_score`, kept equal to those terms by a test); the best 64 get every term; down that ranking the first 8 that pass the placement check get a route. Measured on a real town map: 14 ms a decision with 81 tiles set aside, 16 ms with 441, 36 ms with 1,681. Only a family without a home decides, at most two new homes a week. Ties go to the earlier tile, row by row.

## Explanations

The family's note compares the chosen site with the others it weighed (the shortlist): the two considerations where it gains most, and the one where it gives up most. "Household 2 chose a site near its kin, despite being farther from its work." "Household 1 chose a site close to its work and where the gathering hopes homes will go." It is stored as `Household.home_site_note` (with `home_site_day`) and as the family's latest decision (`initiative_note`), so the Families tab can show it. A family building for a grown child's new household records the choice under its own name.

## Consequences (existing mechanics only)

No new bonus or penalty was added. A home's site already matters through:

- **Travel:** the walk to work comes out of the working day (`TownLogistics.get_commute`, travel share); routes wear paths and trample unfenced fields.
- **Building it:** materials are carried from the nearest store to the site; farther sites take longer to build.
- **Neighbours:** the household social model finds neighbours within 10 tiles (help, ties, disputes, kin help); a scattered town has fewer neighbours to help or quarrel with.
- **Errands:** water, firewood and visits to kin walk from the home.

Hazards do not reach homes yet: high water affects fields and wolves affect camps. Cautious families' aversion is a preference only; if homes should flood, that is a new mechanic for the owner to decide.

**First comparison** (2026-10-31, unequal capacity: compact had 81 tiles, dispersed 64, poor 36): compact 41.5 people, dispersed 39.8, poor 29.1, plots 36.0. Owner review: compact may have won on housing available sooner, not on geography. Superseded by:

**Equal-capacity comparison** (`home_site_check`, 12 real town maps, 3 years, same seeds, families leading; every layout but plots offers about 24 spots a home can stand on from the first day; `tests/sim/residential_layouts.gd`). Rerun 2026-10-31 with residential land reserved for homes; the first run's figures, before the rule, in brackets:

| Land set aside | Towns off the ground | People | Founders housed (median day) | Travel, share of the day | Families blocked at the end | Residential tiles under other buildings |
|---|---|---|---|---|---|---|
| Starting land (passive) | 11/12 | 40.4 (39.9) | 96 | 5.1% | 0.0 (0.3) | 0.0 (6.2) |
| Plots (stand-in, two ahead; reference) | 11/12 | 36.0 (36.0) | 160 | 4.5% | 0.6 | – |
| Compact, around the stockpile | 10/12 (9/12) | **39.0 (28.7)** | 101 | 4.5% | **0.0 (2.2)** | **0.0 (14.1)** |
| Dispersed, four blocks 12 tiles out | 10/12 | 38.8 (38.8) | 94 | 6.7% | 0.3 | 0.0 (0.8) |
| Poor, the far corner | 9/12 | 33.6 (33.3) | 96 | **11.3%** | 0.8 | 0.0 (2.9) |
| Far only, 12 tiles out on the roomiest side | 11/12 | 41.0 (41.2) | 96 | 6.3% | 0.0 | 0.0 (2.6) |
| Preferred far (compact permitted + far preferred, 47 spots) | 10/12 (11/12) | 38.9 (41.0) | 101 | 4.9% | 0.0 | – |

A difference of about 3 people a town is within the spread between towns.

- **Reserving the land fixed the interaction it was meant to.** Before the rule, families opened workplaces on residential land; compact land around the stockpile, the ground families want for work too, lost 14 of its 24 tiles and left 2.2 families a town unable to build (28.7 people). Now no residential tile is taken by work, nobody is blocked, and compact land does as well as the starting land (39.0).
- **Geography decides only at the extremes.** With equal capacity from the first day, founders are housed at the same time everywhere (day 94-101). Among sensible places (starting, compact, dispersed, far: 38.8-41.0 people) there is no difference beyond the spread; land in the far corner still costs (11.3% of the day walking, 33.6 people, three towns lost). Planning can hurt a town; on this evidence it cannot make a sensible town better.
- **Plots, set two at a time, house founders two months later** (day 160) than any land set aside at once: the first comparison's compact advantage was mostly that.
- **Preferred land against a much better site loses, as intended.** With compact land permitted and a far block preferred, 1 of 16 deferential families, 23 of 90 others and 4 of 20 self-governing ones ended on the preferred land (before the rule: 7 of 17, 37 of 91, 13 of 26). The far block is twelve tiles farther from work; the preference is worth about two (below), and must not override a family's strong interests (owner).

### Why preferred land does little (investigation, 2026-10-31)

- **It is in the actual score.** The preference is a term in both the distance ranking (`get_rough_score`) and the full terms families weigh (`get_terms`, "where the gathering hopes homes will go"), at `ENCOURAGE_WEIGHT` (2.0) × the family's receptiveness. Receptiveness is about 1.0 for a family with no leaning (0.4 for a strongly self-governing one, up to 3-3.5 for a deferential one who trusts the gathering), and every other term is in tiles of walk: the preference is worth about two tiles' walk to work.
- **Between two equally good sites it decides** (`tests/home_site_validation.gd`, test 11: two sites the same walk from work, whichever is preferred is chosen, and the term carries its full weight). **Against a site much nearer work it does not** (a preferred site 13 tiles farther loses to one 3 tiles from work).
- **At town scale, between two equal places** (`home_site_check --layouts=twin,twin_preferred`: two blocks of 12 spots 8 tiles from the stockpile on opposite sides, 12 towns, 3 years), preferring one side moves about a tenth of the town's homes to it, at no cost to the town:

| | Homes on the first block | heeds the gathering | others | self-governing | People |
|---|---|---|---|---|---|
| Both plain | 74 of 132 (56%) | 8 of 17 | 48 of 90 | 18 of 25 | 40.5 |
| First block preferred | 87 of 132 (66%) | 9 of 17 | 60 of 91 | 18 of 24 | 40.2 |

- **So it is weak by design, not by a bug:** it settles ties and nudges between similar places, and gives way to a real advantage in walk, kin or room. Deferential families are not measurably more drawn at town scale (17 homes is too few to tell); their receptiveness does change the outcome in single decisions (test 2). No weight was changed.
- **Families' values shape individual sites** (`tests/home_site_validation.gd`: kin, solitude, callings, caution, the heart), but at town scale the differences are swamped by room and distance to work.

## Integration (Step 3, branch `feature/step3-integration`)

- **Planning tab:** a Residential land card with three tools: Set aside (N), Preferred, Clear. Each marks a block between two clicks, as the clearing and tilling tools do; the same block again at the same level unmarks it. The card counts tiles set aside, room left for homes, and families who found nowhere to build. Land shows on the town map as a light wash with a line along its edge (warmer for preferred land), and the ground under the cursor says "set aside for homes". Plots (P) stay as the optional exact tool.
- **Families tab:** each card says "Cannot build a home: ..." while the obstacle holds; the selected family's details show "Home site (when): <its explanation>". An obstacle is recorded apart (`Household.home_site_obstacle`) and is a present reason only while it holds (`FamilyDevelopment.is_home_site_blocked`: the family still has no home, or a grown child it builds for still waits and no home stands empty); after that it is history, shown nowhere as why the family acts (`is_note_current`, used by the Families page, the Overview's recent decisions and the map card).
- **Overview, Needs attention:** "Families cannot find a home site" (or, with families unhoused, a line in "Permanent housing needed") with the latest family's obstacle and a button to the residential land tool.
- **Founding, families given the lead, older saves:** starting land (above).

## Owner Decisions (2026-10-31)

1. Residential land is part of play: the player designates broad areas, families choose their sites.
2. Plots stay, as an optional targeted tool; they are not needed for every home under families-lead rules.
3. Passive play gets a modest, reasonably placed starting area (above): inaction is not fatal for want of land.
4. Homes face hazards only where they exist and have real consequences; none reach homes yet, and none are added here.
5. Comparisons should give layouts equal housing capacity at the same time, and test preferred land against families' own preference (`home_site_check`: compact, dispersed, poor, far only, preferred far, each 24 spots from the first day).
6. Residential land is reserved for homes: no new workplace on it; what stands stays; permission and preference stay separate; plots stay optional (after the combined evaluation).
7. Communal infrastructure, the storehouse above all, may stand among homes and takes their room; private workplaces stay out; the list is explicit. Explanations must be current. Preferred land must not override strong interests (Step 3 review).

## Still Open

- **Preferred land's strength** reuses the ask weight (2.0 × receptiveness), about two tiles of walk: it moves about a tenth of homes between equal places and none from a much better one (above). Stronger would start to override families' interests.
- **Does a family ever move?** A family chooses its site once, when it builds; it never relocates.
- **Which other shared works belong among homes.** Only the storehouse is listed; the watch post is communal too but is worked by a family, so it was left out. A well or a meeting place would be added to `HomeSites.COMPATIBLE` when it exists.
