# Culture And Values Model

Draft model of what culture is, how it is held, how it changes, and what it does (2026-10-19). Sits under `docs/GAME_VISION.md` and builds on `docs/HOUSES_AND_LINEAGE_MODEL.md`.

**Status:**

- **Owner decisions:** values are grouped into categories; a family holds **1-2 values per category**; a House holds **3-4 per category**; values should reach as many systems as possible (preferred industries, how hard people work, and everything else).
- **Owner-accepted (2026-10-19):** the twelve categories and their values are the **starting pool**. Family values are held or not held (no strength yet); values are inspect-only unless relevant to a player decision; named peoples appear only in extreme divergence.
- **Still proposed:** specific effect sizes and change-rule probabilities. These are tuning values.

## Design Rules

1. **Culture lives in families.** Every value is held by a household. Houses, the commons, and settlements only aggregate.
2. **Every value has an upside and a downside.** No value is strictly good. A culture is a shape, not a score.
3. **Values reach real systems.** Each value lists the systems it changes. Flavor-only values are not allowed (`docs/household_simulation_philosophy.md`).
4. **Culture changes mostly between generations.** A family rarely changes its values in its lifetime; its children may differ. This makes slow time meaningful: reshaping a culture takes decades.
5. **Small effects, many sources.** A single value nudges an outcome (typically 5-15%). Effects on the same outcome stack but are capped (about ±30%), so culture shapes play without creating one optimal build.
6. **Opposites cannot share a family, but can share a House.** Each category contains opposing pairs. A family cannot hold both sides. A House can, and when it does, that category is a **House tension**.

## How Values Are Held

| Holder | Values per category | Form |
| --- | --- | --- |
| **Family** | 1-2 | Held or not held; no strength. No opposing pair |
| **House** | 3-4 | The most common values among its member families, each with a strength (its share of members, for example "Thrifty 60%, Lavish 25%") |
| **Commons group** | Distribution | Shares of each value across the group |
| **Settlement** | Distribution | Blend of families (small places), or Houses weighted by size plus the commons (towns and up), per the owner decision in `docs/HOUSES_AND_LINEAGE_MODEL.md` |

Strength per value is certain for Houses (above) and may be considered for families later.

**Visibility.** With 12 categories, a family holds 12-24 values. Values are **inspect-only**: the full profile lives in the household (or House) inspector, not on cards or overviews. The exception is **decisions**: when the player faces a choice that values react to (a policy, a coin decision, a call to arms), the UI shows which values approve or resist and how widely they are held. Players meet culture through its consequences and through the choices it affects.

A useful inspector aid: highlight a family's **defining values**, the ones that differ most from their town's norm. A thrifty family in a thrifty town is unremarkable; a lavish family there is the story.

House-only characteristics, derived from structure rather than held by members:

- **Old House / Upstart House** - age of the lineage.
- **United / Divided** - whether the House has tensions in any category.
- **Spread / Rooted** - how many related Houses exist in other towns.

## The Twelve Categories

Each table lists the value, what it leans toward, its upside, and its downside. `↔` marks opposing pairs.

### 1. Calling - which work a family feels drawn to

Replaces the current `agrarian / industrial / neutral` preference. A calling is what a family *values*; `family_trade` remains the specific skill it practices. Callings have no opposites; a family holds 1-2.

| Value | Industries | Upside | Downside |
| --- | --- | --- | --- |
| **Of the Soil** | farms, herding, orchards | better output and satisfaction on land work | restless when kept from the land |
| **Of the Forest** | woodcutting, hunting, charcoal | better forest output | dislikes cleared, dense settlements |
| **Of Stone** | quarry, stonecutting, masonry, brick, tile, lime | better stone and building output | slow to take other work |
| **Of the Deep Earth** | mining, ore, smelting, silver | better mining output; key for coin metal | higher hardship tolerance needed; resent poor conditions |
| **Of the Forge and Bench** | tools, smithing, joinery, carving | better craft output | demand inputs; idle without materials |
| **Of the Loom** | wool, textiles, clothing | better textile output | low output elsewhere |
| **Of the Road** | trade, caravans, carting, merchants | better trade terms and caravan reach | more likely to leave for other towns |
| **Of the Water** | fishing, boats, river and sea trade | better water output | need water access to be satisfied |
| **Of the Shield** | militia, guards, soldiers | better defense and patrols | low output in civilian work |
| **Of the Hearth** | cooking, care, upkeep, maintenance | better maintenance and household-goods support | low prestige; underrated by status-seeking Houses |
| **Of the Word** | scribes, priests, teachers, administrators | better records, schooling, administration | produce nothing material |
| **Of the Muse** | art, statues, music, festival-making | better luxury and festival goods; culture spreads faster | need a wealthy or devout patron |

Effects: a family working its calling gets an output bonus, higher satisfaction, and faster skill growth. A family kept from its calling for years grows dissatisfied, becomes more likely to leave, and its children may drift to a new calling.

### 2. Work Ethic - how hard and how families work

| Value | Upside | Downside |
| --- | --- | --- |
| **Industrious** ↔ **Leisurely** | more output | resent idleness; unhappy when unassigned or short of inputs |
| **Leisurely** | higher satisfaction from rest and festivals; endure hardship without unrest | less output |
| **Steady** ↔ **Surging** | consistent output, few bad days | no extra effort in a crisis |
| **Surging** | big effort at harvest and in emergencies | lulls in ordinary times |
| **Perfectionist** ↔ **Expedient** | higher goods quality | slower output |
| **Expedient** | faster output | lower quality; buildings wear faster |
| **Communal Labor** ↔ **Solitary** | bonus when several families share a project (construction, harvest) | weaker working alone |
| **Solitary** | steady alone | no group bonus; resent labor owed to the settlement |

### 3. Kin and Lineage - family size, marriage, and succession

| Value | Upside | Downside |
| --- | --- | --- |
| **Father's Line** / **Mother's Line** / **Strongest Line** | decides which lineage a new household joins at marriage (mutually exclusive; families without one follow the settlement's dominant rule) | each rule concentrates or spreads Houses differently |
| **Many Children** ↔ **Few Children** | higher fertility; lineages grow into Houses faster | more mouths; food and housing strain |
| **Few Children** | children start with more skill; more wealth per child | lineage grows slowly |
| **Close-Knit** ↔ **Leave the Nest** | families stay together; strong House cohesion | fewer branches; slow to settle new towns |
| **Leave the Nest** | children form families earlier; more branches and new-town settlers | weaker House cohesion |
| **Elder Reverence** ↔ **Youth Ascendant** | elders keep authority; smooth succession; old couples add knowledge | slow to change |
| **Youth Ascendant** | faster adoption of new ways | succession friction; elders' knowledge is lost |

### 4. Wealth and Property - saving, spending, and owning

| Value | Upside | Downside |
| --- | --- | --- |
| **Thrifty** ↔ **Lavish** | save more; ride out bad harvests | low demand for crafted and luxury goods |
| **Lavish** | high demand for luxury goods (drives crafts); prestige | savings drain; hit hard by bad years |
| **Sharing** ↔ **Acquisitive** | share with kin and neighbors; hardship spreads thin instead of breaking families | slow wealth accumulation |
| **Acquisitive** | accumulate wealth; strong Houses | inequality grows; resentment from Egalitarian neighbors |
| **Common Stores** ↔ **Private Holdings** | support shared storehouses and in-kind tithes | resist coin and private property |
| **Private Holdings** | invest in their own workshops and land | resent shared stores and heavy tithes |
| **Landholding** | value land above coin; stable farms | refuse to sell land; slow coin adoption |

### 5. Trade and Coin - exchange, money, and foreigners' goods

| Value | Upside | Downside |
| --- | --- | --- |
| **Old Ways** ↔ **Coin-Minded** | resilient to foreign coin troubles | barter friction persists; slow to adopt coin |
| **Coin-Minded** | adopt coin quickly; trade flows easily | savings exposed to debasement and collapse of the coin's issuer |
| **Hard Money** | trust only metal weight; your coin is trusted more if they mint it | very sensitive to debasement, at home and abroad |
| **Hagglers** ↔ **Fair Dealers** | better trade terms | lower trade reputation |
| **Fair Dealers** | trade reputation and influence grow | accept worse terms; refuse exploitative trades |
| **Insular** ↔ **Cosmopolitan** | resist foreign coin and influence | fewer trade partners; refuse more trades |
| **Cosmopolitan** | welcome foreign goods, coin, and ideas | open to foreign cultural influence, in both directions |

### 6. Authority and Law - reactions to government and policy

| Value | Upside | Downside |
| --- | --- | --- |
| **Traditionalist** ↔ **Reformist** | stable under existing laws | resist any policy change |
| **Reformist** | welcome change | restless when nothing changes |
| **Deferential** ↔ **Self-Governing** | accept authority; high loyalty | low initiative; follow bad orders too |
| **Self-Governing** | thrive under councils and assemblies; initiative | resent autocracy and decrees |
| **Lawful** ↔ **Free-Spirited** | support patrols and courts; push bandits out | rigid; resent disorder strongly |
| **Free-Spirited** | low cost to govern lightly; inventive | resent taxes and rules; leave under heavy policy |
| **Hierarchical** ↔ **Egalitarian** | accept powerful Houses and inequality | resentment builds silently in the commons |
| **Egalitarian** | cohesion and sharing | resist House dominance; unrest under inequality |

### 7. Change and Risk - novelty, danger, and the unknown

| Value | Upside | Downside |
| --- | --- | --- |
| **Cautious** ↔ **Daring** | resilient; few disasters | slow to adopt techniques or found new towns |
| **Daring** | adopt new techniques fast; volunteer to found towns and lead caravans | volatile outcomes; more losses |
| **Rooted** ↔ **Wanderlust** | rarely leave, even in hardship | won't settle new towns |
| **Wanderlust** | settle new towns, join caravans, spread kin influence | leave when bored or pressured |
| **Hopeful** ↔ **Fatalistic** | endure shortages and keep working | disappointment turns to anger if hope fails for long |
| **Fatalistic** | calm in disaster; little unrest | low drive to improve; slow recovery |

### 8. Craft and Learning - how skill and knowledge move

| Value | Upside | Downside |
| --- | --- | --- |
| **Keepers of Craft** ↔ **Teachers** | skill passes strongly within the family; House advantage | techniques spread slowly to others |
| **Teachers** | techniques spread through the settlement | family loses its edge |
| **Lettered** ↔ **Hands-On** | records, schooling, administration; learn from contact and books | slower skill from practice alone |
| **Hands-On** | skill grows fastest through practice | slow to learn from records or foreigners |
| **Curious** ↔ **Self-Reliant** | learn from trade partners and migrants | open to foreign influence |
| **Self-Reliant** | resist dependency; trust their own methods | ignore better foreign techniques |

### 9. Conflict and Honor - violence, defense, and grievance

| Value | Upside | Downside |
| --- | --- | --- |
| **Martial** ↔ **Peaceable** | strong militia and soldiers; tolerate war | low tolerance for long peace with rivals; prefer force |
| **Peaceable** | better trade relations; less unrest | low war tolerance; weak militia |
| **Honor-Bound** ↔ **Pragmatic** | fierce response to raids and insults; fight hard | long grudges; hard to make peace |
| **Pragmatic** | accept treaties and deals | morale breaks sooner |
| **Defenders** ↔ **Conquerors** | very strong defending home | reluctant in offensive war |
| **Conquerors** | eager for expansion and glory | restless without campaigns; costly peace |
| **Mercenary** | fight well when paid | loyalty follows coin |

### 10. Faith and Ritual - meaning, festivals, and the dead

| Value | Upside | Downside |
| --- | --- | --- |
| **Devout** ↔ **Worldly** | shrines and temples bring stability; endure hardship | resist policies against faith; temples cost |
| **Worldly** | few ritual needs; pragmatic | weaker comfort in disaster |
| **Festive** ↔ **Austere** | festivals bring large satisfaction and cohesion | festivals consume food and goods |
| **Austere** | low consumption; dislike luxury | low demand for Muse and luxury goods |
| **Ancestral** | strong lineage and House cohesion; old-town landmarks matter | resist moving graves, sites, or old buildings |
| **Omen-Watchers** | sense of meaning in events | disasters and eclipses trigger unrest or departures |

### 11. Community and Outsiders - newcomers and identity

| Value | Upside | Downside |
| --- | --- | --- |
| **Welcoming** ↔ **Clannish** | migrants arrive and integrate fast | culture changes faster with newcomers |
| **Clannish** | strong lineage loyalty; marry within lineage | friction with newcomers; fewer migrants |
| **Charitable** ↔ **Each to Their Own** | care for the unsheltered and poor; fewer hardship departures | strain shared stores |
| **Each to Their Own** | low obligations | hardship hits families alone |
| **Proud** ↔ **Adaptable** | strong identity; resist foreign culture; fuel independence | rigid toward neighbors |
| **Adaptable** | absorb neighbors' customs; conquered towns integrate faster | identity erodes under strong neighbors |

### 12. Home and Place - homes, layout, and land

| Value | Upside | Downside |
| --- | --- | --- |
| **Hearth-Proud** ↔ **Simple Living** | better homes raise satisfaction; demand building goods | unhappy in poor housing |
| **Simple Living** | satisfied with basic homes | low demand for building goods |
| **Open Country** ↔ **Town-Loving** | thrive in farmsteads and space | resist dense neighborhoods |
| **Town-Loving** | tolerate crowding; love markets and streets | unhappy on remote land |
| **Monument-Makers** | pride and cohesion from stone buildings and landmarks | demand costly projects |

## What Values Change

Every value feeds a shared set of outcome hooks. Coverage, so no system is left without cultural input:

| System | Hooks | Main categories |
| --- | --- | --- |
| Work | output, reliability, quality, group bonus, crisis surge | Calling, Work Ethic |
| Industry | preferred work, assignment fit, skill growth | Calling, Craft and Learning |
| Demography | fertility, family formation age, lineage rule | Kin and Lineage |
| Houses | cohesion, branching, rise speed | Kin and Lineage, Faith and Ritual, Wealth |
| Needs | luxury demand, housing expectations, festival and faith needs | Wealth, Faith, Home and Place |
| Wealth | savings, sharing, accumulation, inequality tolerance | Wealth and Property, Authority |
| Money | coin adoption, debasement sensitivity, trust in foreign coin | Trade and Coin, Wealth |
| Trade | terms, reputation, refusals, foreign contact | Trade and Coin, Community |
| Migration | arrival attraction, departure threshold, settler willingness | Change and Risk, Community, Calling |
| Policy | approval or resistance per policy | Authority and Law, plus any category a policy touches |
| Stability | unrest, loyalty, reaction to shortages and disasters | Change and Risk, Faith, Authority |
| Knowledge | technique adoption, spread, learning from contact | Craft and Learning, Change and Risk |
| Military | militia strength, war tolerance, offense versus defense | Conflict and Honor |
| Influence | cultural pull on neighbors, susceptibility to theirs | Community, Trade and Coin, Faith |
| Layout | density tolerance, monument demand, landmark attachment | Home and Place, Faith |

### Policy Reactions

Each policy carries tags that values react to. Reaction is the weighted response of the settlement's families (small places) or Houses and commons (larger places). Examples:

| Policy | Approve | Resist |
| --- | --- | --- |
| Raise grain tithes | Common Stores, Deferential | Private Holdings, Free-Spirited, Acquisitive |
| Adopt a neighbor's coin | Coin-Minded, Cosmopolitan | Old Ways, Insular, Proud, Self-Reliant |
| Mint our own coin | Proud, Hard Money, Self-Reliant | Old Ways |
| Debase the coin | (nobody, openly) | Hard Money most, Coin-Minded, Thrifty |
| Call up the militia | Martial, Honor-Bound, Lawful | Peaceable, Leisurely |
| Open the town to migrants | Welcoming, Charitable | Clannish, Proud |
| Grant a House a monopoly | Hierarchical, Acquisitive (that House) | Egalitarian, Self-Governing |
| Form a council | Self-Governing, Reformist | Deferential, Hierarchical, Traditionalist |
| Build a temple | Devout, Ancestral, Monument-Makers | Worldly, Thrifty |
| Cancel a festival | Austere, Thrifty | Festive, Leisurely |

## How Culture Changes

1. **Inheritance at family formation.** A new household inherits each of its parents' values with high probability (about 70-85%). Gaps are filled by drawing from the settlement's distribution, nudged by conditions.
2. **Marriage between lineages.** The new household draws from both parents' values. The lineage rule decides which lineage it joins, not which values it keeps.
3. **Formative conditions.** Children growing up in certain conditions lean toward certain values: famine years lean Thrifty and Cautious; prosperity leans Lavish and Daring; raids lean Martial and Lawful; a temple-centered town leans Devout.
4. **Formative shocks.** Rarely, a severe event changes a living family: survivors of a famine may become Thrifty, a raided family may become Honor-Bound. This is the only common way values change within a lifetime.
5. **Patronage.** Families that depend on a House (as workers or tenants) drift toward that House's values over generations.
6. **Contact.** Trade partners, migrants, and foreign coin carry culture. Cosmopolitan and Curious families absorb it; Insular and Proud families resist.
7. **Player nudges.** Institutions (temple, school, guildhall, barracks, market), festivals, laws, and which Houses or callings the player favors shift the odds at family formation. The player shapes the next generation more than the current one.

## Settlement Identity

Each settlement gets a generated identity line from its strongest values, shown in its inspect view (consistent with values being inspect-only). For example:

> *A thrifty, devout farming folk who distrust coin and keep to their own.*

Identity lines let the player watch culture drift. The same town might read differently three generations later:

> *A prosperous, coin-minded people of the road, proud of their stone halls.*

Towns in the same nation can diverge, and conquered towns bring their own identity.

### Named Peoples

Only in **extreme** cases does a region's culture diverge far enough to become a named people of its own. A named people is a **pressure against unity**: it strains a unified kingdom or region through unrest, resistance to central policy, and in the worst cases a push to break away. It is a late-game force the player must manage, not a reward. Divergence thresholds should be high, so most of a nation's towns remain recognizably one people with local flavor.

## Examples

**A family (Hamlet):** the Ashford household.

- Calling: Of the Soil
- Work Ethic: Industrious, Communal Labor
- Kin: Father's Line, Many Children
- Wealth: Thrifty
- Trade and Coin: Old Ways
- Authority: Traditionalist, Deferential
- ... one or two in every other category
- Defining values shown in their card: *Industrious, Many Children, Old Ways*

**A House (Town):** House Ashford, five generations later, 14 member households.

- Calling: Of the Soil 55%, Of the Road 30%, Of Stone 15%
- Wealth: Thrifty 50%, Acquisitive 35%, Lavish 15% - **tension** (Thrifty ↔ Lavish)
- Trade and Coin: Coin-Minded 45%, Old Ways 40%, Hagglers 15% - **tension** (Old Ways ↔ Coin-Minded)
- Characteristics: Old House, Divided, Spread (two related Houses in other towns)

The story writes itself: the old farming core distrusts coin while the merchant branch embraces it, and the player's coin policy will please one half of the House and anger the other.

## Performance

Values are small integer IDs: at most 24 per family, and 3-4 shares per category per House. The benchmark (`docs/HOUSEHOLD_SIM_BENCHMARK.md`) shows per-household work is cheap; aggregation can run monthly. Culture is not expected to be a performance concern if aggregation avoids the repeated full scans identified there.

## Build Order

Culture should arrive alongside the systems it affects, not all at once:

1. **First slice (fits current code):** values data on households with inheritance at family formation; Calling replaces `preference`; Work Ethic modifies output; Kin modifies births and family formation; full values and defining values shown in the household inspector only.
2. **With migration and needs:** Community and Change and Risk (arrivals, departures), Faith and Ritual (festival and faith needs), Wealth (savings and luxury demand).
3. **With economy and policy:** Trade and Coin, Authority and Law, Craft and Learning.
4. **With Houses, military, and larger layouts:** House aggregation and tensions, Conflict and Honor, Home and Place, settlement identity lines.

## Open Questions

None currently. Resolved 2026-10-19: twelve categories are the starting pool; family values are held or not (strength later, certain for Houses); values are inspect-only except when relevant to a decision; named peoples only in extreme divergence, as a pressure against unity.
