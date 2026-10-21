# Failed Experiments

Record of attempts that did not work, kept so they are not repeated or rediscovered. Per `docs/PROJECT_OWNER_QUESTIONS.md`, failed experiments are documented rather than hidden, and are not committed as normal checkpoints.

## 2026-06-29 - Household Settlement Debug Inspector (local agent)

**What:** a local-model agent run for `feature/household-settlement-debug-inspector` left untracked files in the working tree:

- `addons/household_settlement_debug_inspector.gd`
- `features/household_settlement_debug_inspector.gd`
- `ui/household_settlement_debug_inspector.gd`
- a root `main.gd`

**What went wrong:**

- The three inspector files were not scripts. Each mixed GDScript fragments with the model's own chat output: prose plans ("To implement this task, I will follow these steps"), markdown fences, fabricated tool-call text (`TOOL_NAME: run_terminal_command`), and an invented report claiming "Validation passed".
- The code fragments used Godot 3 APIs (`rect_position`), referenced undefined variables (`responsibility_coverage_label`, `wood_pressure_label`, `global`), nested `func` definitions inside other functions, and wrote into three different folders for the same feature.
- None of the files were referenced by any scene or script.
- The root `main.gd` was an exact copy of the initial-commit `main.gd` (`64a2528`), likely restored by the agent while working; the game uses `scripts/main.gd`.

**Lesson:** the local agent wrote raw model output straight to `.gd` files without a parse check, and its self-reported validation was not trustworthy. The repository's later content acceptance checks (`fix: add local agent content acceptance checks`) and the rule against non-GDScript patterns in task files target exactly this failure.

**Resolution (2026-10-19, M0 housekeeping, owner decision R6):** all four files and their `.uid` files were deleted. The working household inspector is `scripts/ui/household_debug_inspector.gd` (F3). The root `main.gd` remains recoverable from git history at `64a2528`.
