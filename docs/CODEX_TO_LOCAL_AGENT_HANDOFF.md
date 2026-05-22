# Codex To Local Agent Handoff

This handoff prepares the project for bounded local-agent implementation. It does not authorize gameplay changes by itself. Future implementation should happen from explicit task files or handoff prompts on feature branches.

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
- Cities with households, buildings, resources, worker assignment, housing pressure, and maintenance.
- Calendar and simulation clock progression.
- Trade route creation and resource transfer.
- Visual helper classes for terrain, buildings, map elements, and UI styling.

Current risk shape:

- `main.gd` is large and central. Treat it as high-touch/high-risk.
- Most support systems are `RefCounted` classes with `class_name`.
- There are no autoloads currently listed in `project.godot`.
- The roadmap is intentionally skeletal; product direction still needs owner answers before major implementation.

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
- Small additive code changes with validation.

## Questions For The Project Owner

Codex should ask these before approving major gameplay implementation:

1. What is the intended core loop?
2. What is the next development target: playable loop, simulation depth, UI clarity, map generation, or economy?
3. What is the definition of done for the next milestone?
4. What should not be changed under any circumstances right now?
5. What is the preferred first playable milestone?
6. What overnight autonomy level is acceptable?
   - Documentation-only
   - Demo/test scenes only
   - Small feature branches under a time limit
   - No overnight autonomous implementation
7. Which matters more first: visual clarity, simulation correctness, input feel, or progression?
8. Which systems are experimental and safe to change?
9. Which systems are protected and should only be touched after review?
10. Should `main.gd` be gradually modularized, or should gameplay direction be clarified first?
11. Should future work prioritize regional map, city view, buildings, households, trade, or save/load?
12. Should the project stay mouse-driven, keyboard-driven, or support both?

## Recommended Next 3 Local-Agent Tasks

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

### Task 2: Document Resource And Trade Model

Goal:

Create a concise reference for resources, production, maintenance, population pressure, and trade behavior.

Scope:

- Inspect current model code.
- Create `docs/RESOURCE_TRADE_MODEL.md`.
- Separate observed behavior from open questions.

Branch name:

```text
docs/resource-trade-model
```

Files likely involved:

- `city.gd`
- `building.gd`
- `building_placement.gd`
- `household.gd`
- `trade_route.gd`
- `trade_menu.gd`
- `docs/RESOURCE_TRADE_MODEL.md`

Allowed changes:

- Add documentation under `docs/`.

Forbidden changes:

- Do not alter resource values.
- Do not alter production, consumption, maintenance, or trade logic.
- Do not modify gameplay scripts.

Definition of done:

- Document lists known resources, building costs, production sources, consumption/upkeep paths, trade transfer rules, and open design questions.
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
You are the local LM Studio coding agent for this Godot project. Work only on branch docs/resource-trade-model. Read AGENTS.md, ARCHITECTURE.md, city.gd, building.gd, building_placement.gd, household.gd, trade_route.gd, and trade_menu.gd. Add docs/RESOURCE_TRADE_MODEL.md describing observed resource and trade behavior only. Do not modify gameplay code. Run powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1. Commit with message "docs: document resource and trade model". Report open questions.
```

### Task 3: Add Isolated Map Generation Demo Scene

Goal:

Create a small isolated demo scene for map generation validation without changing the main game flow.

Scope:

- Add a new demo/test scene and script under a clearly named folder.
- Use existing map generator classes.
- Do not change generator behavior.
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
You are the local LM Studio coding agent for this Godot project. Work only on branch feature/map-generation-demo-scene. Read AGENTS.md, ARCHITECTURE.md, tasks/backlog/005-create-map-generation-demo-scene.md, region_map_generator.gd, local_city_map_generator.gd, settlement_site_profile.gd, and terrain_visuals.gd. Add an isolated map generation demo scene under a new demo/test folder. Do not modify main.tscn, project.godot, or existing gameplay algorithms. Run powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1. Commit with message "feat: add map generation demo scene". Stop if any existing gameplay code change seems necessary.
```

## Project Owner Review Checklist

After the local agent completes work, the owner or Codex reviewer should check:

- The agent worked on the requested branch.
- The diff matches the task scope.
- No forbidden files were changed.
- No files, scenes, nodes, scripts, folders, or resources were renamed.
- No files were deleted.
- Validation command was run and result was reported.
- Commit message matches the task.
- New docs or demo scenes are understandable without extra context.
- Any assumptions or open questions are documented.
- The work can be reverted by reverting one commit.

## Overnight Autonomy Recommendation

Until the owner answers the product questions, overnight local-agent runs should be limited to:

- Documentation-only tasks, or
- One additive demo/test scene task,
- Maximum one branch and one commit,
- Validation required before commit,
- Stop after the first failure, ambiguity, or forbidden-file need.

No overnight run should exceed the configured task or time limit.
