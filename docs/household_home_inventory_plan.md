# Household and Home Inventory Plan

This document plans a future household/home inventory layer for the household economy. It is a planning document only. It does not implement code, add inventory fields, change consumption, add routing, or alter prosperity.

## Purpose

Current need consumption is city-stockpile based. Households generate demand, the city aggregates that demand, and city resources satisfy need buckets.

This plan defines a later ownership and storage layer where households and homes can hold goods. The goal is to make family stability, reserves, comfort, inheritance, and local identity more legible without prematurely replacing the current city-stockpile economy.

Household inventory should be added only when it helps explain the household-first simulation. It should not become hidden micromanagement.

## Current Foundation

The current implemented model:

- households generate demand through population, housing state, and home-life needs
- the city aggregates demand
- city stockpiles currently satisfy needs
- food is a hard consuming need bucket
- household goods and clothing are soft consuming need buckets
- soft needs consume from city resources
- soft-need results record satisfaction ratios and statuses
- selected-house Family Demand display is read-only
- household prosperity is display-only
- household inventory does not exist
- UI reads model state and does not consume resources

No money, prices, credit, debt, markets, household ownership, exact household recipes, climate effects, or textile production exist yet.

## Definitions

- `city stockpile`: shared city-level resources stored in `city.resources`.
- `household inventory`: goods that belong to a family and may move with that family.
- `home inventory`: goods stored in or attached to a dwelling.
- `owned goods`: goods associated with a family, lineage, or household status.
- `stored goods`: goods held in a home or future storage location.
- `reserve`: stock held back for future need rather than immediate consumption.
- `buffer`: reserve that can soften shortage or instability.
- `shared city supply`: goods available for aggregate city-level consumption.
- `household consumption`: a future pass where a family satisfies need from owned or allocated goods.
- `household satisfaction`: per-household record of how well needs were met.
- `emergency reserve`: food, clothing, tools, or supplies that help during shortage.
- `heirloom/tool/property goods`: identity or continuity goods that may carry family history.

## Design Principles

- City stockpile first, household ownership later.
- Household inventory should explain family stability, not create hidden micromanagement.
- Do not track individual-person items.
- Do not create money, prices, debt, credit, or markets through inventory.
- Inventory effects must be visible and testable.
- UI must explain why a household is satisfied or short.
- Avoid turning every need into an exact recipe.
- Preserve household-first simulation.
- Keep early behavior deterministic.
- Avoid adding penalties before the player can inspect cause and remedy.

## What Belongs In Household Or Home Inventory

Likely inventory categories:

- food reserves
- clothing owned by the household
- household goods and domestic goods
- tools or work equipment
- heirlooms and status goods
- home improvement goods
- emergency supplies

Not every city good needs household storage. The first household inventory model should focus on goods that make family life legible: food buffers, clothing, domestic goods, and identity/status items.

## What Should Stay City-Level

These should remain city-level at first:

- bulk construction materials
- maintenance materials
- civic goods
- production inputs
- trade goods before distribution
- city-level emergency stores

Examples:

- `stone_blocks`, `bricks`, `masonry`, `lime`, and `mortar` should mostly remain city/building goods.
- `tools` can remain city/workplace maintenance supply until household work equipment is explicitly scoped.
- `statues` may be civic or household luxury depending on future allocation rules, but should not quietly disappear into household ownership without UI explanation.

## Household Inventory Vs Home Inventory

Household inventory follows the family.

Examples:

- clothing
- heirlooms
- small tools
- portable household goods
- emergency food bundles

Home inventory belongs to the dwelling.

Examples:

- furniture or domestic fixtures
- stored food reserves
- home improvements
- durable household goods
- heating or future seasonal supplies

Some goods may move when a family forms a new household. Some may remain with the house. Old-couple lifecycle completion and new family formation may eventually transfer, divide, or leave goods behind, but that should not be implemented until inheritance and UI rules are clear.

## Consumption Model Options

Possible stages:

### A. City-Stockpile Only

This is the current model. City resources satisfy aggregate demand.

Strengths:

- simple
- testable
- visible at city scale
- no routing or ownership complexity

Weakness:

- individual household satisfaction is inferred rather than recorded

### B. City-Stockpile Consumption With Household Satisfaction Records

The city still consumes aggregate stockpiles, but households receive read-only satisfaction snapshots.

Strengths:

- makes family experience visible
- does not require routing
- does not require physical inventory
- preserves current economy

Weakness:

- does not yet track owned goods

### C. Household Reserves Filled From City Stockpile Periodically

The city allocates goods into household reserves on a schedule.

Strengths:

- introduces buffers
- supports household-specific stability

Weaknesses:

- requires allocation rules
- can create fairness questions
- can obscure why city stockpiles changed

### D. Household Consumes From Own Reserves First, Then City Stockpile

Households use home/owned stores before drawing from the city.

Strengths:

- strong family-level simulation
- makes reserves meaningful

Weaknesses:

- requires careful UI
- risks hidden shortages
- requires persistence and routing rules

### E. Full Routing, Trade, Or Market Distribution

Goods move through markets, households, obligations, or trade systems.

Strength:

- rich economy later

Weakness:

- too early for the current model

Recommended first implementation later: option B.

## Suggested First Future Implementation

Recommended first code branch:

- `feature/household-satisfaction-records-v0`

This branch would:

- record per-household satisfaction snapshots
- keep physical goods in the city stockpile
- avoid routing
- avoid markets
- avoid changing consumption
- make it clear which households are satisfied or short

Possible snapshot fields:

- `food_status`
- `shelter_status`
- `household_goods_status`
- `clothing_status`
- `last_satisfaction_ratio`
- `shortage_reason`

Alternative later branch:

- `feature/home-inventory-scaffold-v0`

That branch would:

- add inventory dictionaries to home/house records
- avoid consuming from them at first
- avoid routing
- expose read-only debug display

The safer first path is `feature/household-satisfaction-records-v0`, because it improves visibility without adding storage and distribution rules.

## Interaction With Soft Needs

Household goods and clothing can eventually move from aggregate city consumption to household-level satisfaction.

Future direction:

1. Each household emits demand.
2. The city aggregates demand.
3. The city distributes or allocates goods.
4. Each household records satisfaction.
5. Unmet household goods or clothing remain soft pressure.

Missing soft needs should not create survival penalties by default. They can explain comfort, stability, and future prosperity.

## Interaction With Food

Food is a hard need, so household reserves are more sensitive.

Current rule:

- city food supply remains canonical
- city-level food shortage remains serious

Future home food reserves could:

- buffer brief city shortages
- explain why some families remain stable longer
- create readable emergency preparation

Do not add spoilage yet. Do not create hidden starvation mechanics. Any future household food reserve must make shortage and reserve use visible to the player.

## Interaction With Prosperity

Current prosperity is display-only.

Future household inventory may help explain comfortable or prosperous states:

- stocked food reserves can support stability
- owned clothing can support comfort
- household goods can support domestic well-being
- heirlooms or luxury goods can support status

Missing soft inventory should not immediately make families `struggling`. Avoid hidden penalties. Prosperity should explain visible conditions, not silently punish the player for goods they cannot inspect.

## Interaction With Lifecycle

Future lifecycle links:

- new families may receive starter goods
- old households may leave goods behind
- lineage or heirlooms may carry identity
- adult children and new family formation may create inventory pressure
- home turnover may preserve some home goods

Do not implement inheritance mechanics yet. Inventory transfer touches lineage, prosperity, housing, and family formation, so it should be its own scoped branch.

## Interaction With Quality And Preference

The goods quality and preference plan becomes more meaningful once households can own or be allocated goods.

Future possibilities:

- household-specific preferences apply to owned goods
- family trade affects preferred tools or domestic goods
- local identity affects valued goods
- exact-good satisfaction becomes explainable per household

The first inventory layer should avoid complex preference allocation. Start by recording satisfaction, then add ownership, then add exact-good preference effects.

## UI And Debug Requirements

Needed visibility before mechanics deepen:

- selected household satisfaction display
- selected home inventory or debug panel
- city summary remains readable
- shortage source is clear: city-wide or household-specific
- inventory changes are testable and not hidden

Avoid cluttering City Overview. City Overview should summarize pressure; selected homes and households should explain local detail.

## Explicit Non-Goals

- no code changes in this planning branch
- no household inventory implementation yet
- no routing or distribution
- no markets
- no prices, money, credit, or debt
- no individual-person inventory
- no exact recipes
- no spoilage
- no climate or winter effects
- no penalties
- no automatic inheritance
- no production formula changes
- no household prosperity changes

## Open Questions

- Should inventory belong to households, homes, or both?
- How should goods transfer when a new family forms?
- Should food reserves buffer city shortage?
- How should household goods be distributed fairly?
- Should high-prosperity families accumulate more?
- Should lineage or heirlooms matter mechanically?
- How much inventory detail can the UI support?
- Should home improvements stay with the house or follow the family?
- Should household satisfaction snapshots be stored historically or only for the last tick?
- Should distribution be equal, priority-based, or tied to proximity/workplace/status later?

## Suggested Branch Sequence

Recommended order:

1. `feature/household-home-inventory-plan`
2. `feature/household-satisfaction-records-v0`
3. `feature/home-inventory-scaffold-v0`
4. `feature/need-satisfaction-breakdown-display-v0`
5. `feature/household-inventory-consumption-v0`

The first implementation should improve household legibility before adding physical inventory, routing, or ownership consequences.
