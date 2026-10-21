# Refresh Architecture Inventory

## Goal

Update `ARCHITECTURE.md` so it stays accurate as the project evolves.

## Scope

- Review `project.godot`, scenes, scripts, `docs/`, `scripts/`, and `tasks/`.
- Add missing systems or newly introduced files to the inventory.
- Do not rename, move, or refactor gameplay files.

## Files Likely Involved

- `ARCHITECTURE.md`
- `project.godot`
- `scenes/main.tscn`
- `*.gd`
- `docs/`
- `scripts/`
- `tasks/`

## Risk Level

Low. Documentation-only.

## Acceptance Criteria

- `ARCHITECTURE.md` reflects current folders, scenes, major scripts, autoloads, and known systems.
- Any uncertain interpretation is marked as an assumption.
- No gameplay files are modified.

## Validation Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

## Rollback Notes

Revert only the documentation commit or restore the previous `ARCHITECTURE.md`.
