# Inventory Resource, Household, Labor, And Trade Model

## Goal

Document the current resource, household, labor capacity, production, maintenance, and trade route model before changing any economy behavior.

## Scope

- Inspect `scripts/domain/household.gd`, `scripts/domain/city.gd`, `scripts/domain/building.gd`, `scripts/ui/building_placement.gd`, `scripts/domain/trade_route.gd`, `scripts/ui/trade_menu.gd`, and related resource/production display code.
- Compare observed behavior against `docs/household_simulation_philosophy.md` and `docs/PROJECT_OWNER_QUESTIONS.md`.
- Create a concise resource/household/labor/trade model note under `docs/`.
- Do not change resource values, household labor semantics, production formulas, consumption formulas, maintenance behavior, or trade behavior.

## Files Likely Involved

- `scripts/domain/household.gd`
- `scripts/domain/city.gd`
- `scripts/domain/building.gd`
- `scripts/ui/building_placement.gd`
- `scripts/domain/trade_route.gd`
- `scripts/ui/trade_menu.gd`
- `docs/household_simulation_philosophy.md`
- `docs/PROJECT_OWNER_QUESTIONS.md`
- `docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md`
- `docs/`

## Risk Level

Low. Documentation-only if implemented as scoped.

## Acceptance Criteria

- `docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md` exists.
- It lists known resources, household fields, household responsibility/labor meaning, production sources, consumption/upkeep paths, trade transfer behavior, design tensions, and open questions.
- It explicitly preserves the owner decision that one household represents a family-like unit and one baseline labor capacity means one primary responsibility, not one generic worker.
- No gameplay code is modified.

## Validation Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

## Rollback Notes

Delete or revert the added resource/household/labor/trade documentation file.
