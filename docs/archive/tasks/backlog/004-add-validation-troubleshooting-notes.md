# Add Validation Troubleshooting Notes

## Goal

Make validation failures easier for future agents and contributors to diagnose.

## Scope

- Document common validation setup issues such as missing `GODOT_BIN`, PowerShell execution policy, Godot path spaces, and import-pass limitations.
- Keep notes focused on local development.
- Do not change validation scripts unless a small documentation comment is clearly needed.

## Files Likely Involved

- `AGENTS.md`
- `README.md`
- `docs/`
- `scripts/validate_project.ps1`
- `scripts/validate_project.sh`

## Risk Level

Low. Documentation-first tooling task.

## Acceptance Criteria

- Validation troubleshooting guidance exists and is discoverable.
- Guidance includes Windows PowerShell and shell examples.
- Existing validation scripts still run or fail with clear messages.

## Validation Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

## Rollback Notes

Revert the documentation update. If script comments were changed, revert only those comments.
