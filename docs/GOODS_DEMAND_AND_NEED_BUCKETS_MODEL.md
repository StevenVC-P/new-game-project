# Goods Demand and Household Need Buckets Model

This document designs a category-based demand model for household and city needs. It does not implement code or change formulas. Its purpose is to keep future demand systems aligned with the household-first economy now that births, child cohorts, succession pressure, new families, old-couple lifecycle completion, lineage, and work succession are active.

## Design Goal

Goods should not accumulate forever without household or city demand. Households create pressure through population, dependents, housing state, lifecycle stage, and family continuity. The economy should answer that pressure through need buckets rather than exact-good requirements.

The core rule:

- Households need categories first.
- Exact goods satisfy those categories.
- Exact goods can later add quality, preference, culture, prosperity, or trade modifiers.

Example: a household needs `food`, not specifically bread. Wheat, bread, fish, and other foods can satisfy that bucket with different future quality values.

## Current Goods Audit

`City.make_starting_resources()` currently initializes these material stockpile goods:

- `food`
- `wood`
- `tools`
- `stone_blocks`
- `cut_stone`
- `bricks`
- `masonry`
- `lime`
- `mortar`
- `statues`
- `carved_goods`
- `tiles`
- `paving_stones`

The same resource dictionary also contains state values such as population, labor, housing capacity, food consumption rate, food shortage, production tick count, maintenance grace, and external population pool. Those are not goods and should not be treated as need-bucket inputs.

Current production creates:

- Farms: `food`
- Woodcutters: `wood`
- Toolmakers: `tools`, from `wood`
- Quarries: `stone_blocks`
- Stonecutters: `cut_stone`, from `stone_blocks`
- Brickworks: `bricks`, from `wood`
- Lime kilns: `lime`, from `stone_blocks` and `wood`
- Mortar yards: `mortar`, from `lime` and `stone_blocks`
- Mason yards: `masonry`, from `cut_stone` and `mortar`
- Sculptors: `statues`, from `cut_stone` and `tools`
- Carvers: `carved_goods`, from `wood` and `tools`
- Tileworks: `tiles`, from `bricks` and `wood`
- Paver yards: `paving_stones`, from `stone_blocks`

Design examples such as `wheat`, `bread`, `fish`, `planks`, `clay`, `pottery`, `wool`, `clothing`, and `wooden_tools` are useful future goods, but they are not current resource keys unless a later branch adds them.

## Need Buckets

Recommended v0 bucket vocabulary:

- `food`: daily subsistence demand.
- `shelter`: whether people are housed, temporarily sheltered, or unsheltered.
- `tools`: work and upkeep capability.
- `clothing`: warmth, household stability, and later seasonal pressure.
- `household_goods`: domestic goods that improve stability and prosperity.
- `construction_materials`: materials consumed by building placement and expansion.
- `maintenance_materials`: materials consumed to keep buildings functioning.
- `civic_goods`: optional later bucket for status, religion, decoration, and public morale.

For implementation v0, start with one category-backed consumption system:

- `food` demand by category.

Then add pressure-only display for other buckets before consuming them.

## Goods to Bucket Mapping

Current goods should map into buckets like this:

| Good | Primary Buckets | Notes |
| --- | --- | --- |
| `food` | `food` | Current abstract food stockpile. Can later split into raw and prepared goods. |
| `wood` | `construction_materials`, `maintenance_materials` | Later may also satisfy fuel or crude shelter needs. |
| `tools` | `tools`, `maintenance_materials` | Current maintenance already consumes tools. |
| `stone_blocks` | `construction_materials`, `maintenance_materials` | Raw-cut stone material. |
| `cut_stone` | `construction_materials` | Higher-quality construction input. |
| `bricks` | `construction_materials`, `maintenance_materials` | Useful for housing and building upkeep. |
| `masonry` | `construction_materials`, `maintenance_materials` | Higher-quality construction bundle. |
| `lime` | `construction_materials`, `maintenance_materials` | Intermediate building material. |
| `mortar` | `construction_materials`, `maintenance_materials` | Intermediate building material. |
| `tiles` | `construction_materials`, `maintenance_materials`, `household_goods` | Roof/building material first; household finish later. |
| `paving_stones` | `construction_materials`, `civic_goods` | Civic infrastructure later. |
| `carved_goods` | `household_goods`, `civic_goods` | Domestic goods or prestige goods. |
| `statues` | `civic_goods`, `household_goods` | Mostly prestige/civic demand later. |

Future goods can map like this:

| Future Good | Primary Buckets | Notes |
| --- | --- | --- |
| `wheat` | `food` | Raw food, lower satisfaction unless processed. |
| `bread` | `food` | Prepared food, higher satisfaction. |
| `fish` | `food` | Direct food, may spoil later. |
| `planks` | `construction_materials`, `maintenance_materials` | Refined wood construction input. |
| `clay` | `construction_materials` | Raw craft/construction input. |
| `pottery` | `household_goods` | Domestic goods and storage quality. |
| `wool` | `clothing` | Raw textile input. |
| `clothing` | `clothing` | Finished clothing. |
| `wooden_tools` | `tools` | Low-tier tool good. |

Goods can satisfy more than one bucket, but a consumption pass should consume a unit for only one bucket at a time. Later quality scoring can decide whether using `tiles` for household goods is better or worse than preserving them for roof maintenance.

## Category-Based Satisfaction

Need satisfaction should be category-based first.

Benefits:

- The player can reason about "food shortage" or "household goods shortage" without tracking exact recipes.
- New goods can enter the economy without rewriting every household formula.
- Trade can remain flexible: any food import can relieve food pressure.
- Exact goods can later create preferences, cultural identity, nutrition quality, preservation, or prosperity.

Exact-good demand should be deferred until the economy needs richer identity. For example, a fishing village may prefer fish and a grain town may prefer bread later, but both should first satisfy `food`.

## Household Demand Generation

Households should generate need pressure from composition and status:

- `total_population`: base mouths, shelter demand, clothing demand, and domestic goods demand.
- `young_children`: high dependency pressure; no labor contribution.
- `older_children`: still consume and occupy housing, but can support production.
- `adult_children`: consume and occupy housing until they form new households.
- `working_adults`: labor source, not the main demand source.
- `lifecycle_stage`: fertility, family growth, and lifecycle-specific needs.
- housing status: housed, temporary, or unsheltered.

Recommended demand semantics:

- Food demand scales primarily from `total_population`.
- Shelter demand is mostly capacity/status based, not stockpile consumption in v0.
- Clothing and household goods should begin as periodic pressure from population, then later become actual stockpile consumption.
- Tools and maintenance materials are city/building demand first, household demand later.

This preserves the product decision that children increase pressure before supply. Births add young children and population, but do not create labor. Older children later offset some pressure through production support. New families increase housing and goods demand. Old-couple lifecycle completion reduces population pressure and frees houses.

## V0 Consumption Recommendation

Implement only one true demand consumption bucket first:

1. `food`

Keep the current `City.consume_food()` behavior as the conceptual starting point, but route it through a goods-to-bucket helper before expanding beyond the abstract `food` key. This lets future goods such as `wheat`, `bread`, and `fish` satisfy the same food need without requiring exact household recipes.

Do not consume `household_goods`, `clothing`, or `maintenance_materials` from household need in the first slice. Instead, display pressure/readiness once the category helper exists.

Recommended first implementation sequence:

1. Add a goods category mapping helper v0.
2. Convert household/city food demand to consume by `food` category.
3. Add need pressure display v0.
4. Add clothing and household-goods demand v0.
5. Add quality and preference modifiers.
6. Add household/home-level inventory.

## City Stockpile vs Household Inventory

V0 should consume from the city stockpile by category.

Reasons:

- The current implementation already stores goods in `city.resources`.
- Food consumption and pressure are city-level.
- Household-level inventory would be a larger persistence, UI, and routing system.
- Category stockpile consumption is enough to prove that population creates demand pressure.

Future household/home inventory should let families store food, clothing, household goods, tools, and heirlooms. That should come after stockpile demand and UI pressure are understandable.

## Bucket Priority Rules

V0 should use deterministic, conservative priority within a bucket.

For `food`:

1. Consume lower-quality/raw abstract goods first when the goal is survival.
2. Preserve higher-quality/prepared goods for later satisfaction bonuses once quality exists.
3. If only an abstract `food` key exists, consume it directly.

When specific food goods are added, a simple priority could be:

1. `food`
2. `wheat`
3. `fish`
4. `bread`

This is intentionally not a realism claim. It preserves prepared goods until the game can reward them with satisfaction, health, or prosperity. If spoilage is added later, perishable goods such as fish may move earlier in priority.

For `construction_materials` and `maintenance_materials`, preserve higher-tier goods unless a building or repair explicitly requires them. For example, consume `wood` or `stone_blocks` before `masonry` when either can satisfy generic maintenance.

## Shortage Representation

V0 shortage should be visible at city level before household-level inventories exist.

Recommended pressure states:

- `Met`: need is covered this tick/period.
- `Low`: less than a safe reserve remains.
- `Shortage`: demand could not be fully satisfied.
- `Blocked`: no known goods can satisfy this bucket.

Existing pressure UI can continue to show food, shelter, labor, tools, and maintenance. A later Need Pressure section can add:

- Food need: X demand, Y days stored.
- Household goods: unmet or not implemented.
- Clothing: unmet or not implemented.
- Maintenance materials: covered by tools/materials.

Action hints should stay concise:

- "Food demand rising: increase food production or trade for food."
- "Household goods demand unmet: produce domestic goods."
- "Clothing demand unmet: add textile production."
- "Maintenance materials low: produce tools or building materials."

## Lifecycle Tie-In

The household lifecycle system should be the main source of changing demand:

- Births increase `young_children` and `total_population`, creating food and housing pressure without labor.
- Young families carry high demand and low support.
- Older children continue consuming but add family production support.
- Adult children increase household pressure until housing allows new family formation.
- New families create new household demand and future birth potential.
- Old couples occupy housing with lower population and may block turnover until lifecycle completion.
- Old-couple completion reduces demand and frees houses for future families.
- Lineage and family trade can later shape preferred goods, work succession, and household prosperity.

The important design boundary: demand pressure should not erase household tensions. Children should not be tuned into immediate productivity. New families should be opportunities and demands, not free labor.

## Implementation Roadmap

### 1. Goods Category Mapping Helper v0

Add a read-only helper that maps goods to need buckets:

- `get_need_buckets_for_good(good_id)`
- `get_goods_for_need_bucket(bucket_id)`
- `is_good_in_need_bucket(good_id, bucket_id)`

This now lives in `scripts/domain/goods_need_bucket_helper.gd` as `GoodsNeedBucketHelper`. It is read-only and does not mutate resources.

### 2. Household Food Demand by Category v0

Food consumption now keeps the existing population-based demand formula, but consumes from any current resource goods in the `food` bucket through `City.consume_need_bucket()`. With current resources, this still consumes only the abstract `food` stockpile. Future goods can be added to `GoodsNeedBucketHelper` and the resource dictionary without changing the demand formula.

`City.get_available_need_bucket_amount()` and `City.consume_need_bucket()` are generic bucket helpers. They iterate current goods in deterministic helper order, skip missing resource keys safely, do not mutate unmapped resources, and never drive resource values below zero.

### 3. Need Pressure Display v0

`City.get_need_pressure_summary()` exposes a city-level pressure summary for category demand:

- demand amount
- available amount
- shortage amount
- status
- active/inactive state

The City Overview sidebar displays a compact Need Pressure section. Food is the only active consuming bucket in this slice. Household goods pressure is active as display-only family/home pressure: housed households create demand, and current `household_goods` bucket stockpile counts toward availability. Tools, construction materials, maintenance materials, and civic goods show stockpile readiness as not active yet. This remains city-stockpile pressure, not household inventory.

Action hints can use food need pressure for concise guidance, such as increasing production or importing food when demand is low or in shortage.

Manual owner retest checklist:

1. Open City Overview.
2. Confirm Need Pressure appears directly after City Health.
3. Confirm Food displays the expected status and shows available stock plus demand.
4. Confirm Household Goods displays available stock plus demand from housed households.
5. Confirm inactive buckets are visibly not active and are not framed as urgent shortages.
6. Confirm low or shortage food creates helpful action hints.
7. Confirm low or unmet household goods creates one concise domestic-goods hint.
8. Confirm no duplicate or noisy inactive-bucket hints appear.

### 4. Household Goods Pressure v0

Household goods pressure is active as display-only pressure. It does not consume resources, apply penalties, or create household inventory.

V0 demand is aggregated from families with stable homes:

- each housed household creates `1` household goods demand
- temporary or unsheltered households do not create full soft home-life household goods demand yet
- the city aggregates this pressure rather than inventing a direct city demand

Availability uses the `household_goods` need bucket through `GoodsNeedBucketHelper`. Current satisfying goods are:

- `carved_goods`
- `tiles`
- `statues`

Statuses are:

- `none`: no housed-household demand
- `met`: available household goods cover demand
- `low`: some household goods exist, but less than demand
- `unmet`: demand exists and no household goods are available

Action hints appear only for `low` or `unmet` household goods pressure. This is quality-of-life pressure and readiness feedback, not a survival failure.

### 5. Family Demand Status Display v0

Inspected homes/families can show a compact Family Demand section. This makes the family source of city-level pressure legible without adding mechanics.

Current display lines:

- food as population pressure, such as `Food: 5 population`
- household goods contribution for housed families, such as `Household goods: contributes 1 home-life demand`
- no full household goods home-life demand for temporary or unsheltered families
- shelter status as housed, temporary shelter, or unsheltered

This display is read-only. It does not calculate a new food formula, consume household goods, create household inventory, apply penalties, add clothing demand, or change production. The city still aggregates pressure from family/home state.

Manual owner retest checklist:

1. Select a house with a resident household.
2. Confirm the selected house popup shows Family Demand.
3. Confirm food pressure reflects household population.
4. Confirm a housed household shows `Household goods: contributes 1 home-life demand`.
5. Confirm shelter status shows housed.
6. If practical, inspect a temporary or unsheltered household state and confirm food still appears while household goods say no full home-life demand.
7. Confirm City Overview Need Pressure still works.
8. Confirm no resources are consumed and no penalties occur from this display.

### 6. Unsheltered Workplace Warning v0

Selected production buildings can show a warning when their assigned household is temporarily sheltered or unsheltered:

- `Workplace stability: assigned household is temporarily sheltered`
- `Workplace stability: assigned household is unsheltered`
- `Housing instability may reduce reliability later`

This is display-only. Temporary and unsheltered families still consume food and can still operate workplaces. The warning does not change production output, production cadence, assignment validity, labor capacity, food demand, maintenance, lifecycle, or household goods pressure.

Future mechanical effects should prefer reliability or production cadence over a raw output penalty if that better represents instability, fatigue, and irregular attendance.

Manual owner retest checklist:

1. Assign a housed household to a production building and confirm no workplace stability warning appears.
2. Assign or inspect a temporary/unsheltered household on a production building if practical.
3. Confirm the production building popup shows the workplace stability warning.
4. Confirm the selected-building action hints include housing the assigned household.
5. Confirm the building still produces and assignment remains valid.
6. Confirm no output, cadence, labor, maintenance, or demand calculation changes occur.

### 7. Clothing Demand v0

Add slow periodic demand, not daily drain:

- Clothing: population and season influenced later.

Start as pressure warnings before hard consumption penalties.

### 8. Quality and Preference Modifiers

Let exact goods matter after categories are stable:

- prepared food satisfies more or improves health/prosperity
- pottery improves storage
- clothing improves winter stability
- family trade can create preference or production affinity

### 9. Household/Home-Level Inventory

Move some needs from city stockpile to households later:

- home food reserves
- clothing owned by household
- domestic goods/prosperity
- emergency buffers during city shortages

## Deferred Systems

Do not include these in the first implementation:

- exact-good household recipes
- individual-person inventories
- markets, prices, credit, or obligation
- spoilage
- nutrition variety
- household wealth transfer
- automatic work reassignment
- penalties from missing clothing or household goods
- civic/religious prestige demand

The first goal is simple downward pressure: households and lifecycle growth consume goods by category so production, births, trade, and housing create a readable survival-and-growth loop.
