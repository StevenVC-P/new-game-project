# Agent Working Rules

Binding rules for any agent working in this Godot 4.6 project. Current status and open decisions are in `docs/HANDOFF.md`; design authority is `docs/GAME_VISION.md`.

## Godot

- Main scene `scenes/app.tscn` (menus, saves), which runs `scenes/main.tscn`. Forward Plus, Jolt Physics.
- Never hard-code the Godot path. Scripts read `GODOT_BIN`, and locally it is in the untracked `.godot-exe`.

## Design North Star

- A household-rooted civilization simulation, not a worker-slot city builder. Households are the social, economic and cultural unit. Towns aggregate households, and regions aggregate towns.
- **The player controls what the community holds in common; families decide what is their own.** Families choose and improve their own work, and the player leads through the commons, priorities, appeals and wisdoms.
- A household is about 3–6 people with one primary responsibility. Food scales with population. Labor comes from household capability.
- Don't tune away household, population or labor tensions without an owner decision.

## High-Risk Files

`scripts/main.gd`, `scenes/main.tscn`, `scenes/app.tscn`, `scripts/persistence/`, `project.godot`, `scripts/domain/city.gd`, `scripts/domain/household.gd`, and anything touching the calendar, production formulas, trade, map generation, or save/load.

High-risk means: change it only for the assigned goal, avoid unrelated rewrites, validate afterwards, and say why it changed.

## Branches and Commits

- `main` is stable. Never work on it directly, and never merge into it without the owner's review.
- `develop` is the integration branch. Branch from it as `feature/`, `fix/`, `chore/` or `docs/<short-name>`.
- Commit logical units with clear messages. Keep `.godot/`, `.godot-exe` and other machine state out of commits.
- No force-push, reset, rebase or history rewrites unless the owner asks.
- Don't delete files without instruction. Retire outdated docs to `docs/archive/`.
- Don't change gameplay scripts for documentation-only tasks.

## Validation

`scripts/validate_project.ps1` (or `.sh`) runs a headless import pass. It is the pre-commit gate: it catches load, import and parse errors, not gameplay bugs. Tests and balance checks are listed in `docs/TESTING.md`.
