# S2: Living Forests

## Implementation

- **Objective:** timber as a finite, regrowing stock (audit finding F2: a woodcutter's output didn't depend on the trees).
- **Built:**
  - Every wooded tile holds timber (`timber` on the tile; an older map's tile is mature, 135). A woodcutter's wood is cut from the trees it fells (`TownWoodland.take_timber`), so a tile falls when its timber is gone; at full work that is about 16 tiles a year, the pace the owner set on 2026-10-27.
  - Wood falls with the walk to the nearest trees it may fell (full within 6 tiles of its middle, then 6/distance, floor 25%), and is nothing with none (`get_felling_factor`). This replaces the kept-woods-only factor.
  - Woods that spread grow in young (15) and gain 12 each spring to maturity, about ten years (`grow_timber`).
  - Families' wood gathering cuts the trees nearest their homes; with none it may cut, the gathering comes to nothing.
  - Woodcutters have their own land kind, `timber`, in `TownLand` (not shared reach: woodcutters compete by felling the same trees). So every place that reads a workplace's land (a family's first choice, its expected output, a holding's worth, site choice) sees the trees left.
  - `OccupationReview`: wood work at half its best cut or less for a season, or with no trees at all (at once), gives the family reason to reconsider.
  - Winter felling (M1): wood by season 0.8 / 0.8 / 0.8 / 1.6, the year's total unchanged.
  - Interface: a "Timber is running out" card among the failing-livelihood cards; the woodcutter's panel shows its cut and how far the trees are.
- **Files:** `town_woodland.gd`, `town_land.gd`, `city.gd`, `household_economy.gd`, `family_initiative.gd`, `occupation_review.gd`, `economy_balance.gd`, `overview_page.gd`, `construction_display_helper.gd`.

## Verification

- `tests/living_forests_validation.gd`: wood equals timber lost; the agreed pace; no trees, no wood; distance; kept woods untouched; young woods mature in about ten years; gathering; felling still thins a lodge's woods; a woodcutter without trees reconsiders at once; timber survives a save.
- **Suite, first run: 3 of 49 failed, each investigated.**
  - `first_stage_validation` (felling faster in winter) and `hunting_grounds_validation` (its helper felled marked woods only): tests of the old mechanism. Winter felling kept as a seasonal shape; the helper now runs the woodcutters' day.
  - `founded_town_regression`: the pinned failing town (seed 20261101) **no longer failed**: one family left, not three. Traced (`--probe --trace`, a new option): its forest family's near tie (woodcutting 4.27, hunting 4.23 under S1b) went to hunting (woodcutting 3.45: the trees at its second camp's site are a long walk off), and the hunting fed the town. That is the mechanic working, so a new failing seed was chosen by probe: **20261116** (hungry from day 47; families leave on days 269, 299, 329, 359; two families left). The viable seed 20261102 plays identically under S1b and S2.

## Economic outcomes

Pending: the divergence check against B0 and the review between sprints (test plan 10b).
