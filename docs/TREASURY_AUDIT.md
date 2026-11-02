# Town Treasury: Audit and Proposed Foundation

**Status: audit and proposal only (2026-11-01). Nothing here is built.** Requested in the owner's brief "Decisions on Priority 4 / The Town Treasury": audit the common stores, reserves, household ownership, construction funding and resource flows, then propose the smallest coherent foundation, including save compatibility and how committed resources are kept from being counted or spent twice.

## The owner's direction (summary)

- The player controls **communal resources** through a town treasury, distinct from what households privately own.
- **What the player decides:** what to support, how much to commit, how it may be spent, and on what conditions.
- **The allocation is binding**: committed goods are reserved and used only for their purpose until spent or released. The outcome is not: families judge the opportunity for themselves.
- **Unused commitments have an opportunity cost.**
- **The four forms of player influence:**
  - land designations (binding);
  - Guiding Wisdom (culture);
  - Community Priority (direction);
  - treasury allocations (tangible opportunity).

  The Community Gathering is an emergent social system, not a command.

## What exists today

### Who owns what

| Holder | What it holds | Where |
|---|---|---|
| **The town (common store)** | All food, wood, tools, wool, clothing and other goods any workplace makes; founding stock; trade and raid gains and losses | `city.resources` |
| **A family** | **A larder:** food from its own garden (secondary work), eaten first above its target, drawn on when the store runs short, given as gifts | `Household.larder` |
| | **Mending credits:** stand in for a tool at upkeep, its own workplace only | `Household.mending` |
| | **Gathered wood:** under one unit, then carried to its own site or the store | `Household.gathered_wood` |
| **A construction site** | Materials already carried there (returned to the store if the site is cancelled) | `ConstructionProject.materials_delivered` |

**Everything a family's workplace makes goes to the common store.** Families own almost nothing but their garden food. The common store is, in effect, already the treasury. The treasury needs no second pile of goods; it needs a way to **set part of the common store aside**.

### Flows out of the common store

| Flow | Code | Respects reserves or commitments? |
|---|---|---|
| Eating | `HouseholdEconomy.feed` → `City.consume_need_bucket` | No |
| Other needs (clothing etc.) | `City.consume_need_bucket` | No |
| Workplace inputs | `City` production (`resources[input] -= …`) | No |
| Tool upkeep | `City` maintenance (`resources["tools"] -= cost`) | No |
| Carrying materials to a site | `TownConstruction.apply_labor` (`remove_resource`, one unit at a time) | **No: any site takes any unit in the store** |
| Starting a family's own project | `TownInfluence.get_funding_block` → `TownConstruction.can_supply` | Yes: the store, minus what queued sites still need, minus the protected reserve |
| Families' homes | `FamilyDevelopment` → `can_supply(…, STORE_RESERVE)` | Yes, the same way |
| The player's legacy upgrade | `City.pay_cost` | No |
| Trader lots | `TownTrade` | No |
| Trade routes | `TradeRoute` | No |
| Raids | `TownDefense` | No (keeps some food) |

### Reserves and commitments today

1. **Committed materials** (`TownConstruction.get_committed_materials`): what queued sites still need.
   - **Soft:** they only stop *new* family projects from starting.
   - **No unit is held for any site:** carrying, upkeep and eating take whatever is in the store.
2. **The protected reserve** (`TownInfluence.get_protected_reserve`): wood for homes and workshops, and tools for upkeep. It is kept back from families' own projects only.
3. **The stores rule** (open, or priorities first): which family projects may start.
4. **First claim** (`Household.first_claim_until`, from help and the Speaker): passes the stores rule, never the reserve.

**What this means for a treasury:** today the town has **one** binding commitment, kept woods. Every "reserve" of goods is a gate on *starting* a project, not a claim on the goods themselves. **A real allocation would be new in kind:** the first claim on specific units of goods that other uses may not take.

### Where double counting or double spending could happen

1. **A site counted twice.** A site funded by an allocation, counted both as the allocation's goods and as committed materials, makes the store look poorer than it is.
2. **The same goods set aside twice.** Two allocations, or an allocation and the protected reserve, could claim the same 6 tools, which the store holds only once.
3. **Goods taken from under an allocation.** Upkeep, eating, trade or another site take set-aside tools, and the allocation then promises goods that are gone.
4. **A family's reckoning off.** A family weighing the "free" store (`FamilyInitiative.get_spending_risk`) counts set-aside goods as free.
5. **Released goods counted again.** Goods released, or returned from a cancelled site, are credited both to the store and back to the allocation.

## Proposed smallest foundation

### One ledger over the common store

**`TownTreasury`** (`city.treasury`; static helpers, state on the city):
- **Allocations:** a list of plain dictionaries, each:
  - `id`;
  - `purpose`: one kind at first, **"establish work for a good"** (tools, food, wood, wool), spent on building and improving workplaces that make it;
  - `goods`: what is still set aside, e.g. `{"wood": 20, "tools": 6}`;
  - `spent`: what has gone to its purpose;
  - `made`, `ends` (day, or none);
  - `per_family` limit (optional).

  No goods move into it. The store's numbers stay true, and **the ledger only says who may draw them**.
- **One function every discretionary draw goes through:** `get_free(good) = store - Σ allocations' goods - what unfunded sites still need`.

### Rules that prevent the double counting

1. **Every unit is counted once.** An allocation holds goods only as numbers against the store. Making one checks `get_free` and fails (or makes it smaller, the player choosing) if the free store cannot cover it. So the sum of allocations never exceeds the store when made, and no two allocations hold the same unit.
2. **Funded sites are counted once.** A site begun with an allocation's support carries `ConstructionProject.allocation_id`. Its remaining materials come out of that allocation as they are carried. It is left out of `get_committed_materials`, so its need is counted in the allocation alone.
3. **Only eligible draws reach set-aside goods.** Carrying to a site takes from its allocation first, then from the free store. Every other draw takes from the free store only: unfunded sites, upkeep, workplace inputs, trader lots and the legacy upgrade. These are the five places in the flows table that today take any unit.
4. **Eating, and losses the town cannot refuse (raids):** an owner decision (below).
   - **Recommended:** eating may not touch set-aside food, so a food allocation really holds. Raids and any forced loss shrink the allocations in proportion.
   - **Then the invariant** "allocations never exceed the store" holds after every day. A test checks it.
5. **Release and expiry** delete the ledger entry; nothing moves. A cancelled funded site returns its carried materials to the store **and** to its allocation (if still open), else only to the store. That is the one place goods re-enter, written once.
6. **Families see the free store.**
   - **Spending risk:** `get_spending_risk` and the reserve checks use `get_free`.
   - **An allocation for their trade:** a project of that trade weighs its cost against the allocation, so the improvement is affordable and risk-free to the stores.

### How families respond (no hidden command)

**Version 1 adds no new reason to families' choices.** An allocation changes only real circumstances:
- **Stores rule and reserve:** an improvement in the supported trade is funded even under the priorities rule, and even when the free store is thin.
- **Spending risk:** it no longer weighs against that improvement.
- **The improvement itself:** hand work becomes a proper workplace (three times the output) sooner and surely.

Families already weigh all of these (`FamilyInitiative.get_work_desire`, the improvement decision), so they respond through their existing reasoning, and only as far as the opportunity is real to them.

**Whether this is enough to move a first choice of work is unknown.** It should be measured on the same seeds before any term is added. If a term is added later, it should be computed from the real gain (the output a funded workplace adds, sooner), not a flat weight like an appeal's.

### What the player sees (smallest)

- **Set aside for:** a card on the Planning page. It has a good to support, amounts of wood, tools and food (bounded by the free store), and an optional end.
- **What it shows:**
  - what is set aside;
  - what has been spent and on what;
  - what is left;
  - which families might take the opportunity, and why (reasons computed as `FocusedAppeal.get_responses` does, from real state).
- **Release** at any time.
- **The stores readout:** "Free / set aside".

### Saves

- **New state:** `TownTreasury` is a new object on `City`, so `GameState` needs one capture and one restore line (as for woodland and farmland). Its allocations are plain dictionaries of strings and integers. `ConstructionProject.allocation_id` (default −1) saves automatically.
- **Old saves:** they load with no allocations and every site unfunded, and play exactly as before. No format bump.

### Tests (before any balance work)

- **The ledger:**
  - the free store never goes below zero;
  - allocations never exceed the store after any day of a played town;
  - set-aside goods are never taken by upkeep, eating (if decided), an ineligible site, inputs or trade.
- **A funded site:** it draws from its allocation and is not also counted as committed. Cancelling it returns goods once.
- **Release and expiry** free the goods.
- **Saving and loading** keep the ledger and funded sites. An old save loads unchanged.
- **Determinism:** with no allocation, the branch plays as before (snapshot comparison, as for the other metas).

### Validation (same seeds as Priority 5)

- **The players:**
  - none;
  - **a sensible allocator:** supports tool production when the tools card shows and food work in a founding famine, with amounts it can spare;
  - **a poor allocator:** sets aside most of the wood for a trade the land cannot carry, early.
- **What to measure:** people, families who took the opportunity and why, how much was spent or left idle, and the opportunity cost (projects held back by the smaller free store).
- **Not to be tuned:** a poor allocation should be able to waste goods and hurt the town.

## Decisions for the owner

1. **How binding is "binding"?** Recommended: set-aside goods are untouchable by eating, upkeep, other sites, inputs and trade. Raids shrink allocations in proportion. The alternatives:
   - eating can draw set-aside food in a famine (softer, and safer for the player);
   - allocations of food are not allowed at first.
2. **The first purpose only:** "establish work for a good" (building and improving its workplaces). Later purposes need their own rules:
   - homes;
   - public works;
   - operating support (food for a family while it starts a trade);
   - household assistance.
3. **No new family reason in version 1:** families respond only through affordability. Add a computed term only if measurement shows the opportunity is real but unseen.
4. **The existing protected reserve and stores rule stay** beside the treasury for now. Later they could become standing allocations ("upkeep tools", "home wood") the player can see and change.
5. **Focused appeals:** keep them as a comparison only (as decided). The treasury replaces their role as the player's tangible lever.
6. **Private household ownership** stays as today (larders, mending). The treasury design does not assume it; a later split of workplace output between family and town (the basis of taxation) would change `get_free` only.

## Size of the change (estimate)

- **The ledger:** one new domain file (about 150 lines).
- **Draws through `get_free`:** small edits at the five draw sites listed above, plus the cancelled-site return.
- **Families and saves:** `ConstructionProject.allocation_id`; the improvement decision's funding check; one `GameState` line.
- **Interface:** one Planning card and the stores readout.
- **Checks:** a rules test file and a harness policy.

A milestone of about the size of the kept-woods and focused-appeals work together.
