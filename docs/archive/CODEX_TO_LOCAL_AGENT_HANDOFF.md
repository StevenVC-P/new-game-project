# Codex To Local Agent Handoff

This handoff prepares the project for bounded local-agent implementation. Real implementation work is allowed when explicitly assigned by the project owner or Codex, but it must happen on named feature branches with reviewable checkpoints.

## Current Design North Star

This game is a household-rooted civilization simulation. It is not a generic city builder about anonymous worker slots.

- Households are the core social, economic, and cultural unit.
- Cities aggregate household behavior.
- Regions aggregate city behavior.
- States and nations should eventually inherit patterns from the household, city, and regional layers below them.
- Labor should be one baseline responsibility unit per household, not a generic worker pool.
- Population should represent mouths to feed, shelter demand, demographics, family continuity, future household formation, military potential, and future growth, not simply assignable labor.
- Household values should eventually shape real outcomes such as productivity, resilience, reproduction, migration pressure, prosperity, cultural continuity, and higher-level regional/state/nation behavior.

## Owner Decisions Captured

The project owner has clarified the first playable direction:

- The first loop is survival and growth, with trade as a support system.
- The player should grow and stabilize a small settlement by placing housing and production buildings, assigning household responsibilities, managing pressure, and using trade or expansion to relieve shortages.
- First pressure comes from food shortage, housing shortage, maintenance/resource shortage, and not enough households to cover responsibilities.
- One household represents a family or family-like social/economic unit.
- A household usually represents about 3-6 people, but household labor capacity should usually remain baseline 1.
- That 1 labor capacity means one primary household responsibility, not one adult worker and not one quarter of a population pool.
- Food consumption should scale primarily by population.
- Production should initially come from assigned household responsibility plus building/resource rules.
- Values can exist as data or placeholder traits for now, but should not be required for the first playable loop.
- Prototype player control should use direct household assignment for legibility; later stages can add priorities, fit, preference indicators, household choice, and resistance.
- Visible walkers represent household activity, not fully simulated individuals.
- Regions, states, and nations should wait until the city/household loop is stable.
- The first playable milestone should prove households -> responsibilities -> production/consumption -> growth/shortage.

## Current Known Project State

- Branch for active development: `develop`.
- Stable baseline branch: `main`.
- Backup baseline branch: `backup/pre-agent-baseline`.
- Main Godot scene: `main.tscn`.
- Main script: `main.gd`.
- Godot project feature tag: `4.6`.
- Validation is available through `scripts/validate_project.ps1`.
- Local inference is available through LM Studio at `http://localhost:1234`.
- Tested local model: `qwen2.5-coder-7b-instruct`.

The current gameplay direction appears to be a settlement/city simulation prototype:

- Regional map generation and display.
- Local city map generation and display.
- Cities with households, buildings, resources, household-derived labor, housing pressure, and maintenance.
- Calendar and simulation clock progression.
- Trade route creation and resource transfer.
- Visual helper classes for terrain, buildings, map elements, and UI styling.

Current risk shape:

- `main.gd` is large and central. Treat it as high-touch/high-risk.
- Most support systems are `RefCounted` classes with `class_name`.
- There are no autoloads currently listed in `project.godot`.
- The roadmap is intentionally skeletal; product direction still needs owner answers before major implementation.
- Current conceptual risk: the prototype may drift toward conventional city-builder worker-slot logic.
- Known tension: one household may currently represent about 4 population while providing only 1 labor capacity; food consumption scales by population while production scales by labor capacity.
- This tension should be documented and evaluated, not hidden by quick tuning.
- The 4 population to 1 labor-capacity ratio is acceptable as a provisional baseline only if interpreted as one household of several people holding one primary responsibility.

## Protected Product Assumptions

- Do not convert houses into simple worker-slot providers.
- Do not convert population directly into assignable generic labor.
- Do not tune away household/population/labor tension by flattening the model into a conventional worker pool.
- Do not create higher-level regional or national behavior that ignores household/city roots.
- Do not make household values cosmetic only.
- Do not treat household maturity as a direct productivity multiplier by default.
- Do not solve design questions inside implementation tasks unless the owner has explicitly answered them.
- Short-term abstractions are acceptable only when they point toward household-derived behavior.
- Do not change production/resource formulas, household labor semantics, or protected files without an explicit scoped task.

## Goal-Driven Autonomy

The local agent may make real project changes, including gameplay code, UI code, scenes, tests, and documentation, when explicitly assigned a bounded objective by the project owner or Codex.

The local agent may edit scripts, scenes, UI, documentation, tests, resources, and project wiring as needed to complete the assigned goal, as long as the work stays on a named feature branch and does not merge to `main` without human review.

The project has backup points and version-control checkpoints. The local agent should use those checkpoints to work productively rather than stopping every time a change touches an important file.

The agent should not stop merely because a task touches a central file. Instead, it should proceed carefully on a feature branch, commit reviewable checkpoints, and report the risk.

The local agent may work for extended sessions, including multi-hour sessions, when asked, but only inside a named feature branch with clear checkpoints.

The agent may modify any files reasonably necessary to complete an explicitly assigned goal, as long as it works on a feature branch, keeps the work scoped to the goal, uses clean checkpoints, validates when practical, and reports changes clearly.

Important files are not forbidden by default. They are high-risk and should be changed deliberately, with checkpoint commits and clear reporting.

## Feature Branch Requirement

- The agent must never work directly on `main`.
- The agent should normally start from `develop` unless instructed otherwise.
- The agent must create a named feature branch for each assigned goal.
- All work intended for `main` must pass through feature branches and human review.
- No automatic merge to `main` is allowed.
- The owner reviews feature branches and decides whether to merge, redirect, or revert.
- Real implementation authority comes from explicit task scope, not from general access to the repo.
- The agent should make real progress toward the assigned objective.
- The agent should avoid unnecessary rewrites, renames, deletions, or broad refactors unless they are clearly useful for the assigned goal.
- If a refactor is needed, it should be done in a checkpointed way.
- The agent must preserve the household-rooted simulation direction.
- The agent must report what changed, what worked, what failed, and what remains.

## Checkpoint Workflow

A checkpoint is a commit that represents a reviewable state of the project.

A checkpoint is a clean, reviewable commit.

Every meaningful version should be committed so the owner can review it, revert it, compare it, or redirect the next task.

Use milestone-based checkpoints with a 30-45 minute maximum gap. The agent should commit whenever a reviewable unit of progress exists, and should not continue accumulating broad uncommitted changes for more than roughly 45 minutes.

For extended sessions, the agent should commit at natural milestones, such as:

- After adding a new system skeleton.
- After a visible or testable feature appears.
- After wiring UI.
- After passing validation.
- After completing a vertical slice.
- Before attempting a risky refactor.
- After fixing a validation failure.
- Before switching subsystems.
- Before ending the session.

Each checkpoint report should include:

- Branch name.
- Commit hash.
- Changed files.
- Validation command and result.
- Summary of behavior changed.
- Assumptions made.
- Open questions.
- Known risks.

## Failure And Rollback Policy

Checkpoint commits are only for reviewable progress. A checkpoint commit means a clean, reviewable state.

If the project is in a system-error state, validation is failing, imports are broken, or the feature cannot run, the agent should not create a checkpoint commit merely because the time limit was reached.

If the agent spends roughly 45 minutes without producing a working/reviewable state, it should roll back to the previous clean commit, preserve a written note of what was attempted, and report the blocker.

A failed experiment may be documented, but should not be committed as a normal checkpoint unless explicitly requested.

Rollback means returning code to the previous clean commit/state before the failing attempt, while preserving a written summary of the failure in the final report or an approved docs note.

The agent should not hide failed attempts. It should report them clearly.

If rollback itself is unsafe or ambiguous, the agent should stop immediately and report instead of trying more changes.

### Three-Attempt Stop Rule

If the agent makes three attempts to solve the same issue without meaningful progress, it must stop, roll back to the previous clean commit if needed, and write a note explaining:

- What it attempted.
- What failed.
- Current suspected cause.
- Files touched during the attempts.
- Recommended next human/Codex decision.

## Tiered Autonomy Levels

### Level 0: Read-Only Analysis

- Inspect files.
- Summarize architecture.
- Identify risks.
- No file edits.

### Level 1: Documentation-Only

- Docs, task files, checklists, and reports.
- No gameplay code.

### Level 2: Isolated Demos/Tests

- Demo scenes.
- Test scenes.
- Validation helpers.
- No main scene or main project flow changes unless explicitly scoped.

### Level 3: Small Implementation Task

- Bounded gameplay/UI/code changes.
- Specific files or systems allowed.
- Validation required.
- Checkpoint commit required.

### Level 4: Extended Feature-Branch Implementation Session

- Multi-hour work allowed.
- Clear objective required.
- Acceptance criteria required.
- Checkpoint cadence required.
- Failure checkpoint policy required.
- Stop conditions required.
- Final proof-of-work report required.
- No merge to `main`.

## Extended Session Requirements

An extended local-agent task must include:

- Clear objective.
- Expected outcome.
- Allowed files or systems.
- Out-of-scope or high-risk files/systems.
- Acceptance criteria.
- Validation command.
- Checkpoint cadence.
- Failure checkpoint policy.
- Stop conditions.
- Final report requirements.

## Stop Conditions

The local agent must stop if:

- Validation fails and cannot be fixed within the assigned scope.
- The project is not in a clean/reviewable state when the checkpoint time limit is reached.
- The agent makes three attempts to solve the same issue without meaningful progress.
- Rollback to the previous clean state is unsafe or ambiguous.
- The task requires an unresolved product/design decision.
- The agent needs to make high-risk or out-of-scope changes not reasonably tied to the assigned goal.
- Changes drift beyond the assigned feature purpose.
- Implementation violates the household simulation philosophy.
- Implementation converts households into generic worker-slot providers.
- Implementation treats population as directly assignable raw labor.
- The agent needs to rename or delete files without explicit permission.
- The agent would need to merge to `main`.
- The agent is unsure whether a change is in scope.

## High-Risk Systems

High-risk systems:

- `main.gd`
- `main.tscn`
- `project.godot`
- `household.gd`
- `city.gd`
- Calendar/time progression
- Production/resource formulas
- Trade behavior
- Map generation algorithms
- Save/load, if present

High-risk does not mean forbidden. It means:

- Change only when relevant to the assigned goal.
- Avoid unrelated rewrites.
- Checkpoint before and after meaningful edits.
- Validate afterward when practical.
- Report the reason for the change clearly.

Lower-risk local-agent areas:

- `docs/`
- `tasks/`
- Isolated demo scenes
- Test scenes
- Read-only debug displays
- Non-invasive UI labels/tooltips
- Proof-of-work reports
- Architecture notes

Important files are not forbidden by default. They are high-risk and should be changed deliberately, with checkpoint commits and clear reporting.

## Current Safety Rules

- Do not edit `main` directly.
- Work from `develop` or a named feature branch.
- Do not rename scenes, scripts, nodes, folders, resources, or project files without explicit instruction.
- Do not delete files without explicit instruction.
- Do not refactor gameplay code unless the task specifically asks for it.
- Prefer additive, modular changes.
- Add isolated demo/test scenes for new features when practical.
- Run validation before committing.
- Commit every meaningful change with a clear message.
- Stop if the task requires a product decision that is not documented.

## Current Validation Command

Preferred Windows command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

If Godot is not on `PATH`, set `GODOT_BIN` first:

```powershell
$env:GODOT_BIN = "C:\Path\To\Godot.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

Validation mode:

```text
Godot --headless --import --path <project>
```

This validates project loading and import without entering the main scene or gameplay loop. It is not a full gameplay test.

## Local LM Studio Details

- Runtime: LM Studio local server.
- Endpoint: `http://localhost:1234`.
- OpenAI-compatible base URL: `http://localhost:1234/v1`.
- Tested model: `qwen2.5-coder-7b-instruct`.
- Intended use: bounded implementation tasks, small documentation edits, low-risk additive scripts/scenes, and local code assistance.

Local model limitations:

- The model is only useful as a coding agent when connected to a wrapper that can read files, edit files, run validation, and commit changes.
- It may miss broad architecture implications. Keep tasks small.
- It should not run open-ended loops.

## Codex Role vs Local Agent Role

Codex should be used for:

- Planning and architecture.
- Asking owner questions.
- Turning vague goals into bounded task files.
- Reviewing local-agent diffs.
- Identifying risk and missing acceptance criteria.

The local LM Studio agent should be used for:

- Bounded implementation from explicit prompts.
- Documentation tasks.
- Isolated demo/test scenes.
- Real feature work, including gameplay/UI/code/scene/test changes, when explicitly scoped.
- Checkpointed extended sessions when the owner or Codex provides objective, acceptance criteria, allowed files/systems, checkpoint cadence, and stop conditions.

## Project Owner Answers

The owner answered the main product questions in `docs/PROJECT_OWNER_QUESTIONS.md`. Treat that file as the source of truth for:

- First playable core loop.
- Household, population, and labor interpretation.
- Player control staging.
- First milestone resource and shortage priorities.
- High-risk systems.
- Local-agent autonomy limits.
- Definition of done.

## Recommended Next Local-Agent Tasks

### Task 0: Clean Agent Proof-of-Work Documentation

Goal:

Normalize proof-of-work docs so the checklist and actual proof report agree.

Scope:

- Review `docs/AGENT_PROOF_OF_WORK.md` and `docs/AGENT_RUNTIME_CHECKLIST.md`.
- Clarify whether validation-script changes were intentionally approved.
- Add a note that future proof tasks should only modify `docs/AGENT_PROOF_OF_WORK.md` unless explicitly scoped otherwise.
- If `docs/AGENT_PROOF_OF_WORK.md` reports changes to `AGENTS.md` or validation scripts, mark them as requiring human review before trusting the proof run.

Branch name:

```text
docs/clean-agent-proof-work-docs
```

Files likely involved:

- `docs/AGENT_PROOF_OF_WORK.md`
- `docs/AGENT_RUNTIME_CHECKLIST.md`

Allowed changes:

- Documentation updates only.

Forbidden changes:

- Do not modify scripts.
- Do not modify gameplay code.
- Do not modify scenes, resources, project settings, or import settings.

Definition of done:

- Docs clearly distinguish proof-of-work verification from toolchain changes.
- Any non-doc changes in the proof branch are called out as review-required.
- Validation passes or the exact validation failure is reported.

Validation command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

Stop conditions:

- Stop if proof cleanup appears to require script changes.
- Stop if the proof branch history cannot be understood from docs alone.

Expected local-agent prompt:

```text
You are the local LM Studio coding agent for this Godot project. Work only on branch docs/clean-agent-proof-work-docs. Read AGENTS.md, docs/AGENT_PROOF_OF_WORK.md, and docs/AGENT_RUNTIME_CHECKLIST.md. Update documentation only so proof-of-work verification is clearly separated from toolchain changes. Do not modify scripts, gameplay code, scenes, resources, project.godot, or import settings. Run powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1. Commit with message "docs: clarify agent proof-of-work scope". Stop if any script change seems necessary.
```

### Task 1: Document Current Controls

Goal:

Create a player-facing and developer-facing controls reference from existing input behavior.

Scope:

- Inspect `main.gd` and `trade_menu.gd`.
- Create `docs/CONTROLS.md`.
- Document observed controls only.
- Mark ambiguous behavior as assumptions.

Branch name:

```text
docs/current-controls-reference
```

Files likely involved:

- `main.gd`
- `trade_menu.gd`
- `docs/CONTROLS.md`

Allowed changes:

- Add `docs/CONTROLS.md`.
- Optionally add a link from `README.md` only if the task explicitly permits it.

Forbidden changes:

- Do not modify `main.gd`.
- Do not modify `trade_menu.gd`.
- Do not change controls.
- Do not rename files.

Definition of done:

- `docs/CONTROLS.md` covers region view, city view, building placement, trade menu, selection clearing, and time controls where discoverable.
- Unclear controls are marked as assumptions.
- Validation passes.
- Commit includes only documentation changes.

Validation command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

Stop conditions:

- Stop if documenting controls requires changing code.
- Stop if key behavior cannot be determined from current files.

Expected local-agent prompt:

```text
You are the local LM Studio coding agent for this Godot project. Work only on branch docs/current-controls-reference. Read AGENTS.md, ARCHITECTURE.md, tasks/README.md, main.gd, and trade_menu.gd. Add docs/CONTROLS.md documenting existing controls only. Do not modify gameplay code. Run powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1. Commit with message "docs: document current controls". Stop and report if any behavior is ambiguous.
```

### Task 2: Document Resource, Household, Labor, And Trade Model

Goal:

Create a concise reference for resources, households, labor capacity, population pressure, maintenance, and trade behavior, then compare observed behavior against `docs/household_simulation_philosophy.md`.

Scope:

- Inspect `household.gd`, `city.gd`, `building.gd`, `building_placement.gd`, `trade_route.gd`, `trade_menu.gd`, and any resource/production scripts.
- Create `docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md`.
- Compare observed behavior against `docs/household_simulation_philosophy.md`.
- Separate observed behavior, design tension, assumptions, and open questions.

Branch name:

```text
docs/resource-household-labor-trade-model
```

Files likely involved:

- `household.gd`
- `city.gd`
- `building.gd`
- `building_placement.gd`
- `household.gd`
- `trade_route.gd`
- `trade_menu.gd`
- `docs/household_simulation_philosophy.md`
- `docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md`

Allowed changes:

- Add documentation under `docs/`.

Forbidden changes:

- Do not alter resource values.
- Do not alter household, labor, production, consumption, maintenance, migration, values, reproduction, or trade logic.
- Do not modify gameplay scripts.
- Do not reinterpret population as generic labor.
- Do not convert houses into worker-slot providers.

Definition of done:

- Document lists known resources, household fields, labor capacity behavior, building costs, production sources, consumption/upkeep paths, trade transfer rules, and open design questions.
- Document explicitly calls out the household/population/labor tension rather than hiding it.
- Validation passes.
- Commit includes only documentation changes.

Validation command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

Stop conditions:

- Stop if the model cannot be summarized without interpreting missing product intent.
- Stop if code changes seem necessary.

Expected local-agent prompt:

```text
You are the local LM Studio coding agent for this Godot project. Work only on branch docs/resource-household-labor-trade-model. Read AGENTS.md, ARCHITECTURE.md, docs/household_simulation_philosophy.md, household.gd, city.gd, building.gd, building_placement.gd, trade_route.gd, trade_menu.gd, and any resource/production scripts. Add docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md describing observed resource, household, labor, and trade behavior only, and compare it to the household simulation philosophy. Do not modify gameplay code. Do not reinterpret population as generic labor or houses as worker slots. Run powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1. Commit with message "docs: document household labor and trade model". Report open questions.
```

### Task 3: Add Isolated Map Generation Demo Scene

Goal:

Create a small isolated demo scene for map generation validation without changing the main game flow.

Scope:

- Add a new demo/test scene and script under a clearly named folder.
- Use existing map generator classes.
- Prefer not to change generator behavior unless the assigned demo goal reasonably requires a small, clearly reported adjustment.
- Do not change `main.tscn` or `project.godot`.

Branch name:

```text
feature/map-generation-demo-scene
```

Files likely involved:

- `demos/` or `test_scenes/`
- `region_map_generator.gd`
- `local_city_map_generator.gd`
- `settlement_site_profile.gd`
- `terrain_visuals.gd`
- New demo scene/script files

Allowed changes:

- Add new isolated demo scene files.
- Add local demo script glue.
- Add documentation explaining how to open the demo scene.

Forbidden changes:

- Do not modify `main.tscn`.
- Do not modify `project.godot`.
- Do not change map generation algorithms.
- Do not rename existing files.
- Do not delete files.

Definition of done:

- New demo scene imports successfully.
- The demo can display representative regional map output using existing generators.
- Main project entry point is unchanged.
- Validation passes.
- Commit contains only additive demo/docs files unless a tiny compatibility fix is explicitly approved.

Validation command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

Stop conditions:

- Stop if existing generator code must be changed.
- Stop if adding the demo requires changing `project.godot`.
- Stop if the demo cannot validate without running gameplay.

Expected local-agent prompt:

```text
You are the local LM Studio coding agent for this Godot project. Work only on branch feature/map-generation-demo-scene. Read AGENTS.md, ARCHITECTURE.md, tasks/backlog/005-create-map-generation-demo-scene.md, region_map_generator.gd, local_city_map_generator.gd, settlement_site_profile.gd, and terrain_visuals.gd. Add an isolated map generation demo scene under a new demo/test folder. Prefer additive implementation and avoid unnecessary changes to main.tscn, project.godot, or existing gameplay algorithms. If minimal wiring into a central file is reasonably necessary for the demo to function, make the smallest useful change, checkpoint it, validate, and report why it was needed. Run powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1. Commit with message "feat: add map generation demo scene". Stop if the work drifts beyond the assigned demo goal.
```

## Project Owner Review Checklist

After the local agent completes work, the owner or Codex reviewer should check:

- The agent worked on the requested branch.
- The diff matches the task scope.
- High-risk file changes are relevant to the assigned goal and clearly reported.
- No files, scenes, nodes, scripts, folders, or resources were renamed.
- No files were deleted.
- Validation command was run and result was reported.
- Commit message matches the task.
- New docs or demo scenes are understandable without extra context.
- Any assumptions or open questions are documented.
- The work can be reverted by reverting one commit.

## Overnight Autonomy Recommendation

Extended/overnight runs are allowed only when explicitly requested, on a named feature branch, with a clear objective, acceptance criteria, validation command, checkpoint cadence, and stop conditions.

The agent may continue implementing within scope, but must produce reviewable checkpoint commits and a final proof-of-work report. No automatic merge to `main` is allowed.
