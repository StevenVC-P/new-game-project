# Create Map Generation Demo Scene

## Goal

Add an isolated demo scene for regional and local map generation so future map changes can be validated without relying on the full main scene.

## Scope

- Create a new demo scene under a dedicated demo/test folder.
- Use existing generator classes without changing their behavior.
- Keep the demo additive and separate from `main.tscn`.
- Do not modify gameplay systems except for minimal scene script glue if needed.

## Files Likely Involved

- `demos/` or `test_scenes/`
- `region_map_generator.gd`
- `local_city_map_generator.gd`
- `settlement_site_profile.gd`
- `terrain_visuals.gd`
- New demo scene/script files

## Risk Level

Medium-low. Additive scene/script work, but it touches generator usage.

## Acceptance Criteria

- A new isolated demo scene opens without replacing `main.tscn`.
- The demo can generate and display representative map output.
- Existing main scene behavior is unchanged.
- Validation import pass succeeds.

## Validation Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

## Rollback Notes

Delete the added demo scene/script files and revert any documentation that referenced them.
