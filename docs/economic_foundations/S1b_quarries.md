# S1b: Quarries on Stone

## Implementation

- **Objective:** the first real mineral advantage (audit F1; owner decision 2026-10-25: a quarry sits on stone).
- **Built (`3ca6e31`):** `TownDeposits`: a quarry must take in stone-deposit tiles and may stand on them; its cut follows the stone's grade and the tiles underfoot; 600 blocks a tile, kept on the tile; output capped at the stone left; a worked-out quarry frees its family. Survey and building panel name the stone and what is left. Generalised to any deposit kind in S5.
- **Files:** `town_deposits.gd` (new), `building_placement.gd`, `town_land.gd`, `city.gd`, `economy_balance.gd`, `site_survey.gd`, `construction_display_helper.gd`.

## Verification

- `tests/quarry_deposit_validation.gd`: placement, grade, extraction, exhaustion, saves, no-map behaviour (and since S4c and the S4 review, families taking up stone work and the reasons that weigh on it). It caught one defect while being written: a quarry could cut one block more than its deposit held on its last day (fixed: output capped at the stone left).
- Full suite 48/48 at `3ca6e31`.
- **Comparison:** a player commissioning one quarry at the start of year 2 on its best stone, 8 starts, 3 years, against the same commission in B0 (`S1b_summary_y3.md`). No invariant failed.

## Economic outcomes

| Year 3 | Stone made, B0 (quarry anywhere) | Stone made, S1b (quarry on stone) |
|---|---|---|
| Rocky highland | 342 | 320 |
| Forested | 269 | 176 |
| Fertile valley | 368 | 84 |
| Marginal | 412 | 45 |
| Balanced | 70 | 3 |

**Stone now follows the land.** Rocky towns keep almost all their stone; marginal and balanced towns lose about 90%. People and hunger are otherwise unchanged, as expected: stone had no use until S4.

## Next steps

Done. Stone's uses came in S4 (stone homes and buildings) and families quarrying for themselves in S4c.
