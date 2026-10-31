# Home Sites

Owner brief (2026-10-31): families choose where to build their homes by their needs, values, relationships and circumstances; the player shapes development through land planning and encouragement, never by choosing a family's site. *The player controls the conditions under which families make decisions, not the decisions themselves.*

Code: `scripts/domain/home_sites.gd` (`HomeSites`), called from `FamilyDevelopment.claim_plot`. Tests: `tests/home_site_validation.gd`; comparison: `tests/sim/home_site_check.gd`.

## Land the Player Sets Aside

- **Plots** (existing, P): exact sites, as before.
- **Residential land** (new): broad areas marked on the town map (`HomeSites.mark(city, from, to, level)`, stored on each tile as `residential`, so saves carry it). Two levels: **permitted** and **preferred**. Marking a block again at the same level clears it.
- **Nothing set aside, nothing built.** A family never builds outside plots and residential land; with none, or none left that can hold a home, it builds nothing and records why ("Household 3 cannot build a home: no land is set aside for homes"). The town's counter of families waiting for land (`families_without_plot`) still counts it.

- **Starting land** (`set_aside_starting_land`): a modest block a few tiles off the stockpile, on its roomiest side, the smallest of 5x5, 7x7 or 9x9 holding every founding family and two more. A passive player has it; it is not an optimized layout (owner, 2026-10-31). The comparisons use it; the game should set it aside at founding when the Planning tool lands (a one-line call where `main.gd` founds a town under families-lead rules).

There is no game control for residential land yet: the Planning tab is on the unmerged town UI branch, so the tool is a domain call for now (see Integration).

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

**Equal-capacity comparison** (`home_site_check`, 12 real town maps, 3 years, same seeds, families leading; every layout but plots offers about 24 spots a home can stand on from the first day; `tests/sim/residential_layouts.gd`):

| Land set aside | Towns off the ground | People | Founders housed (median day) | Travel, share of the day | Families blocked at the end | Residential tiles under other buildings |
|---|---|---|---|---|---|---|
| Starting land (passive) | 11/12 | 39.9 | 97 | 5.1% | 0.3 | 6.2 |
| Plots (stand-in, two ahead; reference) | 11/12 | 36.0 | 160 | 4.5% | 0.6 | – |
| Compact, around the stockpile | 9/12 | **28.7** | 107 | 4.4% | **2.2** | **14.1** |
| Dispersed, four blocks 12 tiles out | 10/12 | 38.8 | 94 | 6.8% | 0.3 | 0.8 |
| Poor, the far corner | 9/12 | 33.3 | 94 | **11.4%** | 0.8 | 2.9 |
| Far only, 12 tiles out on the roomiest side | 11/12 | 41.2 | 96 | 6.3% | 0.0 | 2.6 |
| Preferred far (compact permitted + far preferred, 47 spots) | 11/12 | 41.0 | 96 | 4.9% | 0.0 | – |

- **Geography, not timing, decides at equal capacity, but not the way the first comparison suggested.** With the same capacity from the first day, founders are housed at the same time everywhere (day 94-107); the differences come from where the land is. Poor land costs the most travel (11.4% of the day) and loses towns; land well out from the centre does as well as anything.
- **Unintended interaction: residential land is permitted, not reserved.** Families open workplaces and fields wherever the land allows, residential land included. Compact land around the stockpile, the ground families want for work too, loses 14 of its 24 tiles to other buildings; families run out of room (2.2 a town left unable to build) and towns shrink. Land away from the centre keeps its room. So the "obvious" good layout is the worst one today. Whether designated land should be kept for homes is an owner decision; nothing was changed.
- **Plots, set two at a time, house founders two months later** (day 160) than any land set aside at once: the first comparison's compact advantage was mostly that.
- **Preferred land does not measurably persuade.** With compact land permitted and a far block preferred, 41% of deferential families, 41% of others and 50% of self-governing families ended on the preferred land: no difference by temperament. Families settle where room is left: the near land fills (and is eaten by work), and the rest go to the far block whatever its label. The preferred term (2.0 × receptiveness) is worth two to five tiles of walk; the far block is twelve tiles farther from work.
- **Families' values shape individual sites** (`tests/home_site_validation.gd`: kin, solitude, callings, caution, the heart), but at town scale the differences are swamped by room and distance to work.

## Integration

- **Planning tab:** a residential land tool (drag a block; permitted or preferred; drag again to clear), shown as a tint on the town map; the status line already counts families waiting for land. Keys: P stays the plot tool; residential land needs a key of its own.
- **Families tab:** show `home_site_note` with the family's home ("Why it lives here"), and the obstacle while it cannot build.
- **Overview, Needs attention:** "N families cannot build a home: no land is set aside" from `families_without_plot`, pointing to the Planning tool.
- **Community tab:** none needed. Preferred land is persuasion, but it is a place on the map; it belongs with Planning.
- **Community Priorities branch:** that branch currently lets families with no plot build anywhere near their work (commit `ff611b9`, made when laying out the town was taken out of play). This feature replaces that rule; merging both needs that change dropped from the priorities branch, and its comparison rerun with residential land set aside.

## Owner Decisions (2026-10-31)

1. Residential land is part of play: the player designates broad areas, families choose their sites.
2. Plots stay, as an optional targeted tool; they are not needed for every home under families-lead rules.
3. Passive play gets a modest, reasonably placed starting area (above): inaction is not fatal for want of land.
4. Homes face hazards only where they exist and have real consequences; none reach homes yet, and none are added here.
5. Comparisons should give layouts equal housing capacity at the same time, and test preferred land against families' own preference (`home_site_check`: compact, dispersed, poor, far only, preferred far, each 24 spots from the first day).

## Still Open

- **Preferred land's strength** reuses the ask weight (2.0 × receptiveness).
- **Does a family ever move?** A family chooses its site once, when it builds; it never relocates.
- **Starting land in the game** needs the founding call in `main.gd` (above), best made with the Planning tool.
