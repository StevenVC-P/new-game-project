# Identify Main Script Extraction Candidates

## Goal

Find safe candidates for future modular extraction from `main.gd` without performing the extraction yet.

## Scope

- Inspect function groups in `main.gd`.
- Propose small, additive extraction candidates such as input handling, drawing helpers, inspector panels, or trade UI coordination.
- Do not edit gameplay code.

## Files Likely Involved

- `main.gd`
- `ARCHITECTURE.md`
- `docs/`

## Risk Level

Low. Analysis/documentation-only.

## Acceptance Criteria

- A short technical-debt note lists candidate extraction areas.
- Each candidate includes expected risk, likely files, and suggested validation.
- No gameplay code is modified.

## Validation Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

## Rollback Notes

Revert the technical-debt note or related documentation update.
