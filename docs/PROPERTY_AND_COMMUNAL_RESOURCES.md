# Property, Contributions and the Town Treasury

**Status: design audit only (2026-11-01). Nothing is built.** Branch `docs/property-and-communal-resources`, from `develop`. No code, weights or simulations changed.

**Kept apart from Priority 5.** The occupations work (`feature/autonomous-occupations`, `docs/AUTONOMOUS_OCCUPATIONS.md` on that branch) is not touched, and none of its runs are affected. Its files overlap with the later phases here, so implementation waits for it (see Dependencies).

## The Owner's Brief (2026-11-01)

A designation-driven civilization simulation, not command and control. The player shapes conditions, opportunities and communal investments; households decide their own responses.

1. **Household and communal property.** Expedition supplies start communal. Families keep personal possessions and household assets. Homes, workplaces and accumulated resources develop recognised ownership or usage rights. Where a good is stored does not decide whose it is. The player controls only what legitimately belongs to the community.
2. **Communal contributions.** A founding compact: households contribute some production to shared provisioning and keep the rest for their own needs and investment. It should come to reflect values, customs and institutions. No fixed percentage, no assumed universal communal ownership.
3. **The town treasury.** Communal wealth, held first as goods. The player will decide what receives support, how much, on what conditions and for how long. Committed resources cannot fund competing projects. Subsidies change real costs and opportunities; they don't compel families or add arbitrary decision bonuses.
4. **Private enterprise.** Families accumulate, invest, see opportunities, exchange goods before currency, and bear the rewards and risks. The balance between private and communal development emerges. Neither is automatically better.
5. **Economic success creates opportunity. Social standing creates reputation. Player appointment creates political authority.** Wealth or reputation never grants formal authority; only the Speaker of the Gathering, once appointed, holds delegated authority over communal decisions. The Community Gathering stays an emergent social system, not a player command.
6. **Later, not now:** property cultures, wealth and inequality, voluntary contributions then taxation, budgets and economic policy, leadership titles and government forms, disputes over communal resources.

**The goal:** two settlements founded with identical resources develop very different economic and cultural systems, and both have viable paths to success. The player's economic power is influenced by the society they helped create.

## 1. What Already Supports the Vision

| The brief asks for | What exists | Where |
|---|---|---|
| Expedition supplies are communal | The founding stores (300 food, 45 wood, 14 tools) go into the town's one store | `EconomyBalance.STARTING_*` |
| The player controls only what is held in common | The hybrid rule, already the owner's principle: "the player directly controls what the community holds in common; families decide what is their own" | `docs/FAMILY_INFLUENCE_PROTOTYPE.md` |
| Household assets | A family's larder (its own food, by choice, giftable), its mending, wood it gathers for its own building, its home, its holding and named heirs | `Household.larder`, `mending`, `HouseholdEconomy.deliver_wood`, `house_building_id`, `Building.assigned_household_id`, `preferred_successor_household_id` |
| Where a good is stored is not whose it is | The larder is not a place: a family eats its own food above its target, then from the common store, then from its reserve | `HouseholdEconomy.feed` |
| Committed resources can't fund competing projects | Materials still to be carried to every queued site are held back from new projects; a protected reserve is never spent on families' own projects | `TownConstruction.get_committed_materials`, `can_supply`, `TownInfluence.get_protected_reserve` |
| Spending rules and eligibility | The stores rule ("open" or "priorities first"), and first claim, which moves a household's project to the front of the queue | `TownInfluence.get_funding_block`, `FamilyInitiative.use_first_claim` |
| Values about property | Common Stores vs Private Holdings, Sharing vs Acquisitive, Thrifty vs Lavish, Landholding, Respect for Holdings, Deferential vs Self-Governing; the Respect What Others Build wisdom | `CultureValues.CATEGORY_VALUES`, `GuidingWisdom.QUALITIES` |
| Values that respond to experience | Lessons already exist for this: "the town's needs come first", "the gathering takes what it wants", "a family must keep something back", "what a family builds is its own" | `HouseholdMemory`, `GuidingWisdom` |
| Contributions becoming a custom | Norms move from acceptance to habit to custom by what families actually do, with sanctions | `TownSocial.observe_norm`, `update_norms` |
| How families judge the use of common goods | Trust, favouritism and desert are judged on every grant | `TownSocial.judge_distribution` |
| Barter with friction, in grain | The neutral town's trader prices in grain and pays less the more it takes | `TownTrade` |
| Appointment, not wealth, gives authority | The Elder appoints a Speaker from the three most influential households; the Speaker's first claim stays within the Elder's rules and reserves | `TownRegard.appoint`, `speaker_acts` |

**In short:** the decision machinery (scored terms with reasons and seeded noise), the values, the norms and the judgment of fairness are all in place. What is missing is the property itself.

## 2. Conflicts, Duplication and Missing Foundations

### Conflicts with the brief

- **C1. In practice, the town is a full commons.** Every workplace's output goes into the one store (`City.apply_input_output_production`), and every family eats from it. The only private production is side work (a garden into the larder, mending, gathered wood). A family's primary work is, in effect, a 100% contribution. This is the universal communal ownership the brief says not to assume.
- **C2. A family's "own" buildings are paid for by the community, and nothing records it.**
  - Improvements are funded from the common store (`FamilyInitiative` through `get_funding_block`); homes too (`FamilyDevelopment`, with its own 10-wood reserve).
  - A building records only who works or lives in it. A family that leaves its work leaves the building to whoever takes it next (`OccupationReview`, `workplaces_left_empty`). That is communal property with a right of use, not ownership.
- **C3. A family weighs the town's stores as its own cost.** "It would spend scarce wood and tools" (`FamilyInitiative.get_spending_risk`) reads the community's free stores. Under ownership, a family's cost is what it pays itself; the community's share is support.
- **C4. `docs/ECONOMY_MODEL.md` rules out transactions between households** ("Deliberate Simplifications": flows are aggregated per settlement). The brief's exchange before currency needs that relaxed (decision P4).
- **C5. Roadmap M7, "Household Wealth And Tithes"** (`docs/IMPLEMENTATION_ROADMAP.md`) puts a state storehouse and a tithe rate first, as the first policy. The brief puts customary contributions first and taxation later. M7 should give way to the phases below if they are approved (decision P9).
- **C6. The player trades, and bandits raid, the whole store** (`TownTrade`, `TownDefense`). Once households hold goods in the store, the player may trade only the community's share, and a raid's loss must fall on the owners.
- **C7. Respected voices blur reputation and authority.** See section 3.

`docs/ECONOMY_MODEL.md` decision 4 ("Hamlet: the player assigns families directly") is already superseded in play by families leading (owner, 2026-10-30) but not yet rewritten. It's listed among the conflicts in `docs/FAMILY_INFLUENCE_PROTOTYPE.md`; nothing new here.

### Duplication to avoid

- **D1. Food already lives in two inventories:** the store (`city.resources["food"]`) and each larder. It isn't counted twice (a larder fills only from a family's own harvest or a gift), and it matches the brief if the larder is food kept at home. But wood and tools must not grow a third inventory per good.
- **D2. Two reserves and two "can it be paid for" paths:** `TownInfluence.get_protected_reserve` (workplaces) and `FamilyDevelopment.STORE_RESERVE` (homes, outside the stores rule).
- **D3. Commitment is implicit in three places:** the queue's remaining materials, first claim's place in the queue, and the priorities rule. A treasury needs one record of what is committed, to what, and on what terms.
- **D4. `city.resources` mixes goods with computed state** (consumption rate, housing capacity, shortage flags, counts). The treasury can't simply be `city.resources`; it should be a view over its goods.

### Missing foundations

1. Whose a good in the store is.
2. Whose a building is, and on what terms (who paid, who may use it, what happens when the family leaves or dies out).
3. A rule for what of a family's work goes to the community.
4. Explicit commitments: purpose, goods, conditions, duration, who made them.
5. Exchange between households without coin.
6. Household wealth as a readable level (`docs/ECONOMY_MODEL.md` already wants it).

## 3. Political Influence: Do the Respected Voices Blur the Line?

**Yes, in two places.** Recognition, the town's backing and the Speaker are on the right side of it. Nothing below was changed.

| Mechanic | Before or after appointment | What it does | Judgment |
|---|---|---|---|
| **Voices in how families heed asks** (`FamilyInitiative.get_receptiveness`) | Before and after | A family heeds the gathering's asks 0.1 more readily for each voice it likes and 0.15 less for each it is at odds with (±0.3 at most). **The voice's own view of the ask is never read.** A family is told "families it respects speak for it" even when that voice opposes the priority. | **Conflict.** Reputation becomes an automatic amplifier of the Elder's directive. A respected household carries the gathering's ask whether or not it agrees, and a family at odds with a voice that opposes the priority heeds the priority less. The Speaker's lead, by contrast, does read its stance. |
| **Economic weight in influence** (`TownRegard.get_influence`) | Before and after | Influence adds +1 for a proper holding, +1 for being the only supplier, and up to +1.5 for kin, without anyone's regard. Influence decides the voices and the three candidates. | **Blur.** Economic position becomes voice weight directly. It's also counted twice: holdings and craft are already noticed as achievements and admired or resented. The brief lets wealth make a family "a strong leadership candidate", so keeping it for candidacy is defensible; for the voices it isn't. |
| **Voices count double in the town's backing** (`CommunityPriority.get_backing`) | Before and after | Each voice's own stance on the priority counts twice; the backing then pulls only on time given freely (since 2026-10-31). | Compatible: reputation swaying opinion, with no vote, and the Elder's priority stands whatever the backing. |
| **The Speaker's lead** (`TownRegard.add_lead_to_view`, `get_lead_receptiveness`) | After | Families that back the Speaker take the priority as it does (±0.5 in their view, ±0.2 in how readily they heed); opponents lean the other way at half strength. | Compatible: authority from appointment, exercised by persuasion. |
| **First claim and the helpers' incentive** (`TownRegard.speaker_acts`) | After | Up to two households a season go to the front of the building queue, within the Elder's stores rule and reserves. | Compatible today: delegated authority over communal resources. Once property exists, it must reach only the community's share (Phase 3). |
| **Patronage** | After | A grant adds a friendly tie from the recipient to the Speaker; ties make following, following makes influence and candidacy. | Not a blur in itself: it's how disputes over communal resources begin (brief §6). But authority partly turns itself into reputation, so it's worth measuring. |
| **Mediation, the Gathering** | After / always | Only the Speaker urges amends; the Gathering adds no player command. | Compatible. |

**Recommended direction (not built; decisions P6–P7):**
- weigh each voice by its own view of the ask, as the Speaker's lead already does, so a respected household lends weight only to what it actually supports;
- let economic success reach the voices only through how others judge it (admiration and resentment), and keep or drop it for candidacy by the owner's choice.

Both are small and independent of property. They could be Phase 1b.

## 4. The Proposed Early-Game Model

**The idea in one line:** one physical store with an ownership ledger over it; a founding compact that sends a share of each family's work to the community, the share coming from the families; a treasury that is the community's share, with explicit commitments; and a market day for what families keep.

### 4.1 Goods: a ledger, not new inventories

- **`city.resources` stays the town's physical store**, the only inventory of each good there. Carrying, building, upkeep, trade and raids keep working as they do; only who may draw changes.
- **Each household gets a share in the store** (`Household.stores_share`, good → amount). Its larder stays its food at home.
- **The community's goods are what remains:** the physical total minus every household's share. Computed, never stored, so it can't drift. A test holds the invariant: shares never exceed the physical total.
- **Losses** (a raid; spoilage later) fall on everyone with goods in the store, in proportion. **The player trades** only the community's goods.

**Why a ledger and not separate household inventories:** every system that moves goods reads `city.resources`. Separate inventories would have to be carried, raided and built from separately, which is the duplication the brief warns against. The larder already shows the pattern: whose a good is doesn't depend on where it is.

### 4.2 Buildings: who paid, and what that gives

- **A building records who paid for it**, by the materials carried to it: the community's share and each household's (`Building.funded`).
- **Rights, first version:**
  - **Mostly the family's:** it is the family's holding. No one else is put to work there while it is theirs, it passes to its heirs by the existing succession, and if the family leaves the town it goes to the community (no selling yet).
  - **Mostly the community's:** a communal workplace with a right of use for the family working it. When they leave it, the community may offer it to another family, as today.
- **Existing towns:** everything built so far was paid from the common store, so it is communal, with today's rights of use. Old saves load into exactly today's game.
- **Land is unchanged:** the player sets land aside; families hold it by use (gardens, fenced fields, home sites), and disputes stay as they are. Property in land comes later.

### 4.3 The founding compact

**What it promises:**
- **The common table:** the community's food feeds every household, as now. That is what makes specialisation possible before exchange: a toolmaker eats at the table and gives tools to it.
- **The order of eating stays:** a family's own food above its larder's target first, then the table, then its own reserve (`HouseholdEconomy.feed`).

**What families give:**
- **A share of their primary work's output** goes to the community; the rest goes to the family's share in the store. Side work stays wholly the family's, as now.
- **Each family's share is its own,** weighed like any other decision, with reasons:
  - more from Common Stores, Sharing, Communal Labor, Deferential, and trust in the gathering;
  - less from Private Holdings, Acquisitive, Thrifty, Self-Governing, and distrust;
  - pulled toward the town's custom.
- **The town's custom:**
  - begins as the founders' own shares at founding, so two expeditions with different families start differently;
  - moves with what families actually give, through the norm machinery (acceptance, habit, custom, sanctions).
- **Giving little is judged, not punished:** v1 excludes no one from the table. Families who see a household take from the table and give little think less of it (ties, standing) and may give less themselves. Excluding anyone is a rule, and rules come later.
- **The player sets no share early.** They influence it as they influence everything else: the wisdoms (We Endure Together, Respect What Others Build), keeping promises (trust), and how the treasury is used (fair or favoured). A tithe floor is taxation, a later policy.
- **Bounds:** none are proposed as design. The first version will need placeholder bounds so a family neither gives nothing nor everything; those are numbers for decision P3, not a fixed percentage.

### 4.4 The treasury

- **What it is:** the community's goods, less what is committed, less the protected reserve. Not a new inventory.
- **A commitment:** purpose (a project, or an offer), goods and amounts, who is eligible (any family, a trade, homes), how long it stands, and who made it (the Elder, or the Speaker within what the Elder allows). One record replaces the three implicit ones (D3).
- **The reserves merge:** the workplace reserve and the homes reserve become the treasury's protected reserve.
- **The stores rule becomes eligibility:** "priorities first" means only commitments that serve the priority may be made.
- **Offers are the subsidy.** For example: "up to 20 wood and 6 tools toward a toolmaker's workshop, for a family that takes it up, for 180 days."
  - **It changes the real cost.** A family's cost term reads what it would pay from its own share; the offer pays part of it. No bonus term is added.
  - **A family may still say no:** its calling, its values (a self-governing family may not want to owe the community its workshop) and the terms (a workshop mostly paid by the community is communal, and the family is told so before accepting).
- **The Speaker** draws only on what the Elder's rules and commitments leave; first claim is priority among eligible families.

**Where the player's economic power comes from:** the treasury is what families give. What they give comes from their values, their trust and the town's custom. A town that trusts the gathering and holds Common Stores gives its Elder a large treasury. A town of self-governing, private families gives a small one.

### 4.5 Private enterprise before currency

- **Accumulate:** the family's share in the store, and its larder.
- **Invest:** improvements are paid from the family's own share first, then any offer. "Can it pay?" reads its own share.
- **See opportunities:** the existing terms (the town's need, neighbours' work paying, calling), plus what the work would fetch at the market day once it exists.
- **Exchange: a market day,** once a month.
  - Families offer what they hold beyond their own needs and seek what they lack.
  - Prices are in grain, from the town's own scarcity, with the trader's supply-and-demand friction (`TownTrade`).
  - It is cleared in aggregate: each family's net change is recorded, and nothing is owed afterwards. No credit, no debts, no bilateral ledgers.
  - Families may refuse; Hagglers and Fair Dealers, and Insular and Cosmopolitan, deal differently. The player may take part with the community's goods.
- **Rewards and risks:** a family whose work sells grows its share. One whose market dries up (others now make the good) loses. One that spent its stock and kept a thin larder goes hungry first in a bad year.
- **Wealth:** the grain value of a family's share and larder, a level, not a ledger. It feeds what already reads prosperity (`TownSocial.is_prosperous`, levelling and admiration).

### 4.6 Why neither path is automatically better

| | Communal town (high shares) | Private town (low shares) |
|---|---|---|
| Strength | A large treasury: the Elder can fund tools and workshops where the town needs them, and the table carries everyone through a bad year | Families fund their own improvements as soon as they can; exchange spreads goods without anyone allocating them |
| Weakness | Families hold little of their own, so development waits on the Elder and the Speaker; disputes over who gets what; favouritism | A thin table: specialists depend on the market and poor families on their larders; inequality and resentment; the Elder has few levers |
| What the player does | Allocates | Makes offers, keeps the table, watches the market |

The validation (Phase 2) must show both viable on the same sites before either is tuned.

## 5. Phased Implementation Proposal

Summarised in `docs/IMPLEMENTATION_ROADMAP.md` ("Property, Contributions And The Treasury"). Each phase is its own branch from `develop`, with matched simulations and an honest report, merged only on the owner's word.

| Phase | Builds | Done when | Needs |
|---|---|---|---|
| **0. Decisions** | This document | The owner has answered P1–P10 | — |
| **1. The ledger, with no change in play** | Household shares in the store; who paid for each building; the treasury as a read-only view (community goods, reserve, what the queue holds); the player's trade limited to the community's goods. Every share is fixed at 100% to the community, so play is today's game. | Matched snapshots identical to `develop` (as the occupations work checked with its metas); the invariant holds; old saves load unchanged; the Treasury shows on the Community page | 0, and Priority 5 settled |
| **1b. Reputation and authority apart** (independent) | Voices weighted by their own view of the ask; economic weight only through regard (per P6–P7) | Rules tests; matched runs of the speaker check show the effect on the priority's reception and on who becomes a candidate | 0 |
| **2. The founding compact** | Each family's share and its reasons; the town's custom; the common table; homes and improvements paid from the family's own share first | Matched sims with founders seeded communal, private and mixed, on ordinary, stressed and difficult sites, six years: both extremes viable, and they diverge in treasury, wealth spread, who funds improvements, and custom | 1 |
| **3. Commitments and offers** | Explicit commitments; the stores rule as eligibility; offers that change the real cost; the Speaker within commitments; one protected reserve | The owner's day-82 town: does an offer for tools change who takes up toolmaking, against the priority's ask? No double funding in a stress test | 1 (2 for offers to matter in private towns) |
| **4. The market day** | Monthly exchange in grain; wealth as a level; prosperity read from wealth | Private towns: specialists survive through exchange; wealth spreads and narrows for reasons a family card can explain | 2 |

**Later, not now:** exclusion from the table; tithes and taxation as policy; property in land; selling or leasing holdings; Houses holding assets (`docs/HOUSES_AND_LINEAGE_MODEL.md`); coin; budgets; government forms and titles; formal disputes over communal resources.

### Dependencies and risks

- **Priority 5 first.** Phases 1–4 change `City` production, `TownConstruction`, `FamilyInitiative`'s cost and ability, `OccupationReview`'s holding worth and `EconomyBalance`, the same files as `feature/autonomous-occupations`. Implementation starts once that branch is merged or set aside. Phase 1b touches only `FamilyInitiative.get_receptiveness` and `TownRegard.get_influence`, but the occupations work's focused appeals weigh by `get_receptiveness`, so 1b would change their results too.
- **High-risk files:** `city.gd` (production, eating), `household.gd`, saves. New dictionaries on `Household` and `Building` are domain fields and save automatically; anything object-valued needs a line in `GameState`.
- **Balance:** Phase 2 changes who can pay for improvements. The influence prototype found a restrictive stores rule held back about 34 improvements per town (`docs/FAMILY_INFLUENCE_PROTOTYPE.md`); low shares could do the same to the treasury. That is a real cost to report, not tune away.
- **Materials are not scarce after the first year** (5,000–9,000 wood; `docs/COMMUNITY_PRIORITIES.md`). Until that changes, the treasury and the market matter mostly for food and tools in the first years.

## 6. Decisions for the Owner

- **P1. Ownership as a ledger over one store** (recommended), or separate household inventories?
- **P2. Building rights:** the majority-paid rule; a family's holding going to the community when the family leaves; everything built so far treated as communal. Agreed?
- **P3. What the compact asks:**
  - a share of primary output (recommended: simplest, and the natural ancestor of a tithe);
  - what is left beyond a family's own needs;
  - or days of labour owed.

  Should there be a founding obligation (a floor while the expedition supplies last)? And placeholder bounds for the first version.
- **P4. Exchange between households:** allow a monthly market day, aggregated and without credit, relaxing `docs/ECONOMY_MODEL.md`'s "no individual transactions between households"?
- **P5. The common table:** does every household eat at it in the first version whatever it gives (recommended), with free-riding judged socially only?
- **P6. Voices:** weigh each by its own view of the ask (recommended), or drop the voices from directing asks?
- **P7. Economic weight in influence:** remove it from the voices only (recommended; keep it for candidacy), or remove it entirely?
- **P8. Offers:** open to any eligible family first (recommended), or also to a named family (interaction 2 in `docs/FAMILY_INFLUENCE_PROTOTYPE.md`)?
- **P9. Roadmap M7:** replace "Household Wealth And Tithes" with these phases?
- **P10. The Speaker's reach over the treasury:** first claim only, as today, or may it make commitments up to a limit the Elder sets?
