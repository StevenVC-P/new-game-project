# Create UI Overlay Demo Scene

## Goal

Add an isolated demo scene for UI overlays and visual helpers so UI polish can be validated without altering core gameplay flow.

## Scope

- Create a demo scene that exercises visual helper classes with sample data.
- Keep all demo data local to the demo.
- Prefer not to alter `main.gd` UI behavior. If minimal wiring into a central file is reasonably necessary for the demo scene to function, make the smallest useful change, checkpoint it, validate, and report why it was needed.

## Files Likely Involved

- `demos/` or `test_scenes/`
- `visual_style.gd`
- `map_element_visuals.gd`
- `terrain_visuals.gd`
- `building_visuals.gd`
- `city_building_overlay.gd`
- New demo scene/script files

## Risk Level

Medium-low. Additive scene/script work.

## Acceptance Criteria

- A new isolated demo scene renders representative UI/overlay elements.
- No existing scene is renamed or replaced.
- Validation import pass succeeds.

## Validation Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

## Rollback Notes

Delete the added demo scene/script files and revert any documentation that referenced them.
