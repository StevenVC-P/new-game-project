# Inventory Resource And Trade Model

## Goal

Document the current resource, production, maintenance, and trade route model before changing any economy behavior.

## Scope

- Inspect `city.gd`, `building_placement.gd`, `trade_route.gd`, `trade_menu.gd`, and related display code.
- Create a concise resource/trade model note under `docs/`.
- Do not change resource values, production formulas, or trade behavior.

## Files Likely Involved

- `city.gd`
- `building_placement.gd`
- `trade_route.gd`
- `trade_menu.gd`
- `docs/`

## Risk Level

Low. Documentation-only if implemented as scoped.

## Acceptance Criteria

- A resource/trade model document exists under `docs/`.
- It lists known resources, production sources, consumption/upkeep paths, trade transfer behavior, and open questions.
- No gameplay code is modified.

## Validation Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

## Rollback Notes

Delete or revert the added resource/trade documentation file.
