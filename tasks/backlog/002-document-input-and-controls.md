# Document Input And Controls

## Goal

Create a clear reference for current player inputs, mouse interactions, view switching, building placement, trade controls, and time controls.

## Scope

- Inspect input handling in `scripts/main.gd` and helper classes such as `scripts/ui/trade_menu.gd`.
- Document existing controls in a new or existing docs file.
- Do not change input behavior.

## Files Likely Involved

- `scripts/main.gd`
- `scripts/ui/trade_menu.gd`
- `docs/`

## Risk Level

Low. Documentation-only if implemented as scoped.

## Acceptance Criteria

- A controls reference exists under `docs/`.
- The reference names region-view controls, city-view controls, trade menu controls, building placement controls, and time controls where discoverable.
- Unknown or ambiguous controls are marked as assumptions.
- No gameplay code is modified.

## Validation Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

## Rollback Notes

Delete or revert the added controls documentation file.
