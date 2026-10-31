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

**Comparison** (`home_site_check`, 12 real town maps, 3 years, same seeds, families leading; 2026-10-31):

| Land set aside | Towns off the ground | People | Founders housed (median day) | Homes families built | Travel, share of the day | Site-days waiting for a builder |
|---|---|---|---|---|---|---|
| Plots (stand-in, two ahead) | 11/12 | 36.0 | 160 (10/12) | 31.8 | 4.5% | 431 |
| Compact (81 tiles around the stockpile) | 11/12 | **41.5** | **95** (11/12) | **36.9** | 4.6% | **389** |
| Dispersed (four 4x4 blocks, 12 tiles out) | 10/12 | 39.8 | 94 (9/12) | 33.5 | 7.2% | 432 |
| Preferred (dispersed, nearest block preferred) | 10/12 | 39.3 | 94 (9/12) | 32.9 | 6.9% | 440 |
| Poor (6x6 in the far corner) | **8/12** | **29.1** | 108 (8/12) | 27.8 | **10.6%** | 424 |

- Land planning matters through existing mechanics alone: poorly placed land more than doubles the day lost to travel and loses three more towns than compact land; compact land houses founders two months sooner than plots set two at a time.
- Compact beats dispersed on these maps because the stand-in towns' work clusters near the stockpile (families open work near their homes and the heart); dispersed land costs travel without a matching gain here. No map in this set rewards spreading out (for example, scattered fields or woods far apart); that is what a dispersed town would need to pay off.
- Preferring the nearest dispersed block changed little (39.3 against 39.8): founders choose before many homes stand, and the nearest block is already near their work.

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
