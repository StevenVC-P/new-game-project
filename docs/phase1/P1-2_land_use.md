# P1-2: The Land-Use Record

Branch `feature/p1-land-use`, stacked on P1-1 (`feature/p1-land`).

## What it is

`LandUseRecord` holds, for each regional tile, the 16 town tiles under it counted by what they hold now:
- built (under buildings);
- farmland (under farms and gardens);
- street (worn paths and roads);
- cleared (woods the land had and has lost);
- wooded.

It compares the town map with the land under it before founding (`generate_base_from_terrain`), which is a pure function of position.

**Derived, never saved.** Town maps are saved whole and the land under them can always be worked out again, so the record adds nothing to saves and can't drift from the town. That is the guardrail "land state summarizes cleanly".

**Who reads it.** For now, only the continuous regional view (`RegionMapView.land_use`, rebuilt with the monthly refresh) reads it. Trees no longer stand on woods a town has felled. The regional chunks stay a pure function of position, because town maps are generated from them and a felled-wood flag there would change a neighbouring town's land.

## Results (pass criteria from `PHASE1_PLAN.md`)

| Criterion | Result |
|---|---|
| Play unchanged | No simulation code changed: the record only reads the town |
| Totals match the town's own tiles | Every wooded tile is counted once, and cleared equals the land's trees minus today's. A farm counts 9 farmland tiles and a home 4 built. No regional tile counts more than 16 |
| Survives a save | Derived from the saved map. The save tests pass unchanged |
| Cost | 2.3 ms per town per refresh, 187 regional tiles. The base land is generated once per site and cached |
| Regional view | A felled 12×12 block reads cleared, and the view keeps trees off it |

Tests: `land_use_record_validation.gd` (new), plus the regional, world-flow, community-play and save tests.

## Limits

- The regional ground tint under felled woods still shows forest, because it comes from the pure chunks. Painting the ground from the record belongs with the far-view legibility work (master roadmap Phase 6).
- Footprints are still drawn by population tier, not from the record's built share. That waits for the same work.
- No simulation reads the record yet. Satellites, Summary towns and E13 V4 are its intended readers (Phase 5).
