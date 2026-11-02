---
id: document-resource-household-labor-trade-model
title: Document Resource Household Labor Trade Model
base_branch: develop
branch_name: docs/resource-household-labor-trade-model
edit_mode: json_file_ops
allowed_paths:
  - docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md
required_paths:
  - docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md
blocked_paths:
  - scripts/
  - scenes/
  - project.godot
max_files_changed: 1
max_lines_added: 300
max_lines_deleted: 0
allow_new_files: true
allow_replacements: false
allow_deletes: false
allow_renames: false
required_content:
  - "# Resource, Household, Labor, and Trade Model"
  - "## Observed Behavior"
  - "## Household-First Labor Semantics"
  - "## Resources"
  - "## Production"
  - "## Food and Housing Pressure"
  - "## Trade"
  - "## Design Intent"
  - "## Open Questions"
  - "Observed Behavior"
  - "Design Intent"
  - "Open Questions"
  - "household"
  - "labor"
  - "trade"
blocked_content:
  - "TODO only"
  - "placeholder only"
min_lines:
  docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md: 60
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "docs: document household labor and trade model"
---

# Goal

Draft a documentation-only model reference for the current resource, household, labor, building, production, housing, food, maintenance, and trade behavior.

# Scope

Create `docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md`.

Use a `create` JSON edit for `docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md`. The target document does not exist yet, so do not use `replace_entire_file`.

Inspect the current code and docs as source material, especially:

- `AGENTS.md`
- `ARCHITECTURE.md`
- `ROADMAP.md`
- `docs/PROJECT_OWNER_QUESTIONS.md`
- `docs/household_simulation_philosophy.md`
- `scripts/domain/city.gd`
- `scripts/domain/household.gd`
- `scripts/domain/building.gd`
- `scripts/domain/trade_route.gd`
- `scripts/ui/building_placement.gd`
- `scripts/ui/trade_menu.gd`
- relevant display code in `scripts/main.gd`

# Required Content

The document must:

- Use these headings exactly:
  - `# Resource, Household, Labor, and Trade Model`
  - `## Observed Behavior`
  - `## Household-First Labor Semantics`
  - `## Resources`
  - `## Production`
  - `## Food and Housing Pressure`
  - `## Trade`
  - `## Design Intent`
  - `## Open Questions`
- List current resources and what they appear to represent.
- Document household-first labor semantics.
- Explain that a household is not a generic worker slot.
- Document known `City` resources, fields, and methods relevant to labor, resources, production, pressure, and trade.
- Document household fields relevant to population, labor capacity, residence, preference, and assignment.
- Document building production behavior when visible from current code.
- Document food consumption, housing pressure, maintenance, and trade transfer behavior when visible from current code.
- Separate observed behavior from design intent.
- Include open questions and design tensions.
- Explicitly preserve the owner decision that one household represents a family-like unit and one baseline labor capacity means one primary responsibility, not one generic worker.

Quality is section completeness and accuracy, not verbosity. It is acceptable for the document to be concise if every required section is present and grounded in the current code.

Avoid inventing mechanics not visible in the code. For example, do not claim:

- trade happens directly between households unless the code shows that
- overpopulation directly reduces productivity unless the code shows that
- maintenance consumes labor unless the code shows that
- seasonal effects change production unless the code shows that

If a behavior is design intent or future direction rather than current code, put it under `## Design Intent` or `## Open Questions`, not under `## Observed Behavior`.

# Forbidden

- Do not modify gameplay code.
- Do not modify scripts.
- Do not modify scenes.
- Do not modify `project.godot`.
- Do not change resource values, formulas, household labor semantics, production, consumption, housing, maintenance, or trade behavior.
- Do not reinterpret population as generic labor.
- Do not describe houses as worker-slot generators.

# Definition of Done

- `docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md` exists.
- The document is based on observed code and authoritative design docs.
- Observed behavior, design intent, assumptions, tensions, and open questions are clearly separated.
- No gameplay files are changed.
- Validation passes.
