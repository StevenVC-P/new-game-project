# Document Core Loop Hypothesis

## Goal

Turn the placeholder Core Loop roadmap section into a concrete hypothesis based on the current simulation systems.

## Scope

- Inspect `scripts/main.gd`, `scripts/domain/city.gd`, `scripts/domain/household.gd`, `scripts/domain/trade_route.gd`, and `ROADMAP.md`.
- Draft a short core-loop note covering map generation, city inspection, building placement, time progression, and trade.
- Do not implement new mechanics.

## Files Likely Involved

- `ROADMAP.md`
- `docs/`
- `scripts/main.gd`
- `scripts/domain/city.gd`
- `scripts/domain/household.gd`
- `scripts/domain/trade_route.gd`

## Risk Level

Low. Documentation-only.

## Acceptance Criteria

- The core-loop hypothesis is documented in `ROADMAP.md` or a dedicated docs file.
- The note separates observed current behavior from proposed future direction.
- No gameplay code is modified.

## Validation Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

## Rollback Notes

Revert the roadmap/docs change.
