# S6: The Ownership Ledger

## Implementation

- **Objective:** whose the goods are, without changing play (audit F7; `PROPERTY_AND_COMMUNAL_RESOURCES.md` §4.1–4.2 under owner decision D1). The foundation for contributions (S7), redistribution (S8) and the market day (S9).
- **Built (`TownLedger`):**
  - `city.resources` stays the one physical store. Each family holds a share in it (`Household.stores_share`). The community's goods are the stock less every share, computed and never stored, so they can't drift.
  - A family draws on its own share and the community's goods, never another family's (`get_available`).
  - A family's own project is paid from its share first, then the community's goods. The player's and the town's projects are paid from the community's goods (`TownConstruction.get_payer`, `TownLedger.charge`). The project, then the building, records who paid each good (`funded`). A building with no record, meaning everything built before S6, was the common store's. An upgrade of one records the original cost as the community's before adding its own.
  - A cancelled project gives the materials back to whoever paid; anything unrecorded goes to the community.
  - Raids fall on every owner in proportion (`lose`). Goods taken without a payer (eating, workshop inputs, fuel) are settled each day, so shares never exceed the stock (`settle`).
  - The player trades only the community's goods (`TownTrade.get_lots`).
  - Community page, Shared resources: a read-only **Treasury** card. It shows the community's goods, families' own goods, and what building sites still wait for.
- **Placeholder, to revisit in S7/S8:** a family that leaves or dies out takes nothing; its share becomes the community's.
- **Not in S6:** production still goes wholly to the community. Rates, the founding choice and families' answers to the policy are S7.
- **Files:** `town_ledger.gd` (new), `household.gd`, `building.gd`, `construction_project.gd`, `town_construction.gd`, `town_defense.gd`, `town_trade.gd`, `city.gd`, `community_page.gd`.

## Verification

- `tests/town_ledger_validation.gd`: pooled is the whole store; shares and the community; no family draws on another's share; shares never exceed the stock; raids in proportion; a family pays for its own project first, and the building records it; the player's project leaves families' goods alone; cancelling gives back; buildings from before are communal; saves.
- **Neutrality:** the same towns were played on the base build (`110a128`, the same code as `4bac31f`) and on S6: forested and marginal land, ordinary and stressed conditions, the attentive and guided players, 3 years. All 45 `[DIV]` lines are identical once timing and process memory are removed: every snapshot's people, buildings, materials, hunger, deaths and goods flows. No invariant failed. These towns built (the construction payer path ran every day) but had no trade or raid, so those two paths are covered by the rules test instead (the trader's lots and a raid with families' shares); pooled, both reduce to the old arithmetic.
