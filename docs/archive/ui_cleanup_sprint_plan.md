# UI Cleanup Sprint Plan

This document plans a UI cleanup sprint for the current economy and household demand surfaces. It is a planning document only. It does not implement UI changes, gameplay mechanics, goods, production chains, or economy rules.

## Sprint Purpose

The demand and soft-need consumption sprint made the household economy more legible at the model layer:

- category-based need buckets
- household/family-driven demand visibility
- household goods pressure
- selected-house Family Demand display
- unsheltered workplace warning
- household prosperity status
- clothing pressure
- final `clothing` good scaffold
- soft-need consumption for household goods and clothing
- satisfaction ratios and statuses

The next sprint should make that information readable in the UI before adding more mechanics. The goal is to preserve the model exactly as it is while improving presentation, text fit, and manual retest confidence.

## Current UI Problems Observed

Manual owner testing found that the model mostly works, but several UI rows are cramped:

- City Overview Need Pressure rows can truncate demand text, such as `9 dema`.
- Household Goods and Clothing rows can truncate available/demand text.
- Action Hints can truncate action verbs or important nouns, such as `prod` or `food pr`.
- Selected house panel is readable but dense.
- Family Demand and Household Status need clearer formatting.
- Inactive readiness buckets compete visually with active consuming buckets.
- Clothing needs must remain visible without suggesting an immediate textile-production solution that does not exist yet.

The cleanup should replace accidental truncation with intentional compact labels, wrapping, or multi-line formatting.

## Branch Plan

### 1. `feature/city-overview-need-pressure-layout-v0`

Goal: Make City Overview Need Pressure rows readable.

Expected work:

- shorten or restructure Need Pressure row text
- prevent important demand/available quantities from truncating
- distinguish hard needs, soft consuming needs, and inactive readiness buckets
- keep Food visually prominent
- keep Household Goods and Clothing readable
- avoid hiding inactive buckets if they still serve readiness/debug value

Possible display direction:

- `Food: Met`
- `Avail 12 / Demand 3`
- `Household Goods: Low`
- `Supplied 1 / Demand 3`
- `Clothing: Unmet`
- `Supplied 0 / Demand 12`

Do not change demand calculations or consumption behavior.

### 2. `feature/action-hints-readability-v0`

Goal: Make action hints readable and avoid truncated commands.

Expected work:

- allow hints to wrap or use intentionally shorter wording
- preserve important action verbs
- avoid duplicate/noisy hints
- keep hard-need hints higher priority than soft-need hints
- keep clothing hinting gentle or absent while textile production does not exist

Possible direction:

- prefer shorter hints over clipped long strings
- split long hints into two lines if the existing drawing helpers support it safely
- keep fallback hint readable

Do not add new hints for mechanics that do not exist.

### 3. `feature/selected-household-panel-readability-v0`

Goal: Improve selected house/household panel readability.

Expected work:

- make Family Demand easier to scan
- make Household Prosperity/Status easier to scan
- keep lifecycle/lineage readable
- avoid panel overflow
- preserve selected production-building warning behavior

Possible direction:

- use clearer section spacing
- use shorter labels
- group Family Demand and Prosperity consistently
- increase panel height only if needed
- keep selected house details compact

Do not add household inventory, new status rules, or new prosperity effects.

### 4. `feature/ui-manual-retest-checklist-v0`

Goal: Add a focused manual UI retest checklist after layout cleanup.

Expected work:

- document City Overview retest steps
- document selected house retest steps
- document selected production-building warning retest steps
- document no-regression checks for soft-need consumption
- document no-truncation checks across expected panel states

This may be docs-only or include a small test note file, depending on repository convention.

## Definition Of Done

The sprint is done when:

- City Overview Need Pressure rows no longer truncate important quantities or labels.
- Food, Household Goods, and Clothing need rows are readable.
- Inactive readiness buckets are visually less urgent than active consuming buckets.
- Action Hints do not truncate important action verbs or nouns.
- Selected house panel remains readable with lifecycle, lineage, Family Demand, and Prosperity visible.
- Selected production-building workplace warning remains readable.
- UI remains read-only and does not consume or mutate resources.
- Existing focused validations still pass.
- Manual owner retest checklist is updated and usable.

## Non-Goals

- Do not add new mechanics.
- Do not add new goods.
- Do not add clothing or textile production.
- Do not add household inventory.
- Do not add markets, money, prices, credit, or debt.
- Do not change food, household goods, clothing, prosperity, production, lifecycle, shelter, assignment, maintenance, or trade formulas.
- Do not make UI consume or mutate resources.
- Do not perform broad refactors.
- Do not introduce a new design system unless the existing drawing helpers cannot support readable text.

## UI Principles

- UI should read model state, not calculate or mutate it.
- Hard needs should be visually prioritized over soft needs.
- Active consuming buckets should be distinguishable from inactive readiness buckets.
- Text should not truncate important quantities or action verbs.
- If space is limited, prefer shorter intentional labels or multi-line formatting over accidental truncation.
- Clothing should not create an unsolvable production hint because textile production does not exist yet.
- City Overview should summarize; selected panels should explain.
- Preserve the household-first framing.

## Manual Owner Retest Checklist

After the UI cleanup branches are implemented, retest:

1. Open City Overview.
2. Confirm Need Pressure is readable.
3. Confirm Food shows status and demand/available values without truncation.
4. Confirm Household Goods shows status and demand/supply values without truncation.
5. Confirm Clothing shows status and demand/supply values without truncation.
6. Confirm inactive readiness buckets are not framed as urgent shortages.
7. Confirm Action Hints show complete action verbs and important nouns.
8. Confirm clothing does not suggest textile production as an available immediate action.
9. Select a house with a resident household.
10. Confirm Family Demand is readable.
11. Confirm Household Prosperity/Status is readable.
12. Confirm lifecycle and lineage lines remain readable.
13. Select a production building with a temporarily sheltered or unsheltered assigned household if practical.
14. Confirm workplace stability warning is readable.
15. Let time pass and confirm UI updates without truncating new demand values.
16. Confirm no resources are consumed by UI reads.
17. Confirm no formula, production, assignment, lifecycle, shelter, trade, prosperity, or inventory behavior changed.

## Validation Expectations

For this planning branch:

- run `git diff --check`
- no Godot validation is required because this branch is docs-only

For implementation branches:

- run `git diff --check`
- run Godot project validation
- run focused validation scripts affected by UI display:
  - `tests/need_pressure_display_validation.gd`
  - `tests/family_demand_display_validation.gd`
  - `tests/household_prosperity_status_validation.gd`
  - `tests/soft_need_consumption_validation.gd`
  - `tests/unsheltered_workplace_warning_validation.gd`
- perform manual owner retest for truncation/readability

Known follow-up:

- `tests/expanded_goods_production_validation.gd` is not directly runnable with `--script` because it extends `RefCounted`, not `SceneTree` or `MainLoop`. Do not fix this in the UI cleanup sprint unless explicitly scoped.
