# S7: The Founding Compact

## Implementation

- **Objective:** families own part of their work. The player sets, at founding, the share of each kind of work the families agree to give the community (D1; owner's Track B guidance, 2026-11-05, in the roadmap §2). The design is in `S7_design.md`, approved with S8 and S9 in order.
- **Built (`TownCompact`; ledger from S6):**
  - **Rates:** five categories (food, wood, stone and clay, tools, crafted goods), each the community's share of a holding's work. Presets: communal 100%, shared 60%, private 20%. `city.compact` is empty while pooled (old saves and comparison runs), and play then is S6's.
  - **Holdings:** a workplace's output enters the store. The community takes the rate's share and the working family keeps the rest as its own (`deliver_output`). A workplace nobody works gives everything to the community.
  - **Production chains (the owner's point):** a workshop draws its inputs from its family's own goods first, then the community's. Its output is divided by worth in grain:
    - the worth of the inputs goes back to whoever owned them;
    - only the worth the work added is shared at the rate.
    - So a good is never claimed twice along a chain. At 100%, tools made of the family's own wood still give it back its wood's worth. A family working the community's wood gains only its share of the work's added worth, never a claim on the wood itself.
    - Goods the trader never deals in got worths for this division only (`WORKED_VALUE_IN_GRAIN`). Adding them to the trade table would have changed the stores' temptation to bandits.
  - **Eating:**
    1. the family's own larder above its target;
    2. its share in the store;
    3. the common table (the community's food, which still feeds everyone);
    4. its larder reserve.
    - A family fed from its own goods isn't short when the table is bare.
  - **Fuel:** each hearth burns its family's own wood first; the community's wood warms the rest; only hearths it can't warm go cold.
  - **Side work:** gathered wood is the family's own under any compact. Wood a family carries to its own site is recorded as its payment.
  - **Sharing in a shortage (existing, `TownSocial`):** a donor gives real food from what it owns: its larder and, under a compact, its food in the store (passed from its share to the recipient's).
    - Found while building: with larders only, a farm family's surplus held in the store could never be shared, which would have been an artificial disadvantage to private towns, not an emergent one.
    - Who asks and who gives is unchanged (S8 extends asking).
  - **Building and "can it pay":** a family's own project is paid from its share first (S6). The checks families use (`can_supply`, `get_spending_risk`) count its own goods and the community's free goods. The player's checks count only the community's. Occupation scoring changes only through these existing cost terms; no new value weights.
  - **Upkeep:** a workplace its family mostly paid for (§4.2) is kept up from the family's own tools first; any other from the community's.
  - **Giving more:** monthly, a family leaning toward the community gives a share of what it holds beyond its own needs (90 days of food and winter fuel, and what its own sites wait for).
    - Lean: Common Stores, Sharing, Communal Labor and Deferential count for it, by strength; Private Holdings, Acquisitive, Thrifty and Self-Governing against; trust adds half a point a step.
    - 5% of the spare a point, at most 30%.
    - The goods stay in the store; only whose they are changes.
  - **Founding (`main.gd`, narrow):**
    - The founding panel lists the three compacts under the site survey, and "Found Town" waits for a choice.
    - Founding called directly (tests, sims) keeps the pooled store, so existing founding is unchanged.
    - Two action lines let the Community page change rates later.
  - **Community page, Shared resources:**
    - a **Founding compact** card: rates, presets, and a step down or up for each category;
    - the **Treasury** card shows families' own goods and what they gave beyond the compact.
- **Placeholders and limits, recorded for S8 and later:**
  - acceptance and compliance by values and trust are later work (owner);
  - fences are still paid by the community (their requests carry no family; changing that would move gathered wood in today's game);
  - clothing and household goods are drawn town-wide and settled from owners in proportion;
  - sites' outstanding needs count against the community's goods;
  - a family that leaves takes nothing.
- **Files:** `town_compact.gd` (new), `city.gd`, `household.gd`, `building.gd`, `household_economy.gd`, `town_fuel.gd`, `town_construction.gd`, `family_initiative.gd`, `family_development.gd`, `material_choice.gd`, `community_priority.gd`, `town_influence.gd`, `household_migration.gd`, `economy_balance.gd`, `main.gd`, `community_page.gd`; `tests/sim/divergence_check.gd` (`--compact=`, compact measures), `tests/sim/economy_invariants.gd` (I15).

## Verification

- `tests/town_compact_validation.gd`:
  - pooled is unchanged;
  - presets and rates;
  - a holding shared at the rate;
  - the chain rule (three cases, plus a workshop drawing the family's own wood first);
  - eating and hearths from a family's own first;
  - side work;
  - "can it pay";
  - upkeep of a family holding;
  - values leaning families to give, never their own food;
  - saves.
- **Invariant I15:** shares are never negative and never exceed the stock, checked daily in every divergence run.
- **Neutrality:** pooled S7 against S6 on the same matched towns as S6's check: all 45 lines identical (timing and memory aside), before and after the sharing fix.
- **Suite:** 55/55.
- **Founding, in the real flow** (`tests/visual/region_flow_capture.gd`, shots f4 and f4b): Found Town with no compact founds nothing; choosing Shared and founding gives the town 60% in every category; the town view opens as before.

## Measures (tracked, not yet judged)

Per the owner, S7 and S8 record and S9 judges. Each divergence town under a compact reports:
- `community_worth` and `family_worth` (grain);
- `holding_gini` (how unevenly families hold);
- `given` (beyond the compact);
- `short_by_trade` (household hunger days by trade).
