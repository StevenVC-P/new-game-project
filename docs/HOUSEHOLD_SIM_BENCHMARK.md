# Household Simulation Benchmark

Measured cost of the current Full-level household simulation (2026-10-19). Replaces the estimates in `docs/SIMULATION_SCALE_MODEL.md`.

## Setup

- Script: `tests/benchmarks/household_sim_benchmark.gd`
- Command: `<godot> --headless --path . --script res://tests/benchmarks/household_sim_benchmark.gd` (filter output for `[BENCH]`)
- Godot 4.6.2-stable, headless, Windows 11
- CPU: Intel Core i9-12900K, 32 GB RAM. This is a fast desktop CPU; typical player machines will be slower.
- One city with N housed households, N houses, and N workplaces (half farms, half woodcutters), auto-assigned. Food, wood, and tools set high so no shortage path runs. Lifecycle logging left on, as in the game.

## Results

| Households | Setup (auto-assign) | Daily tick | Monthly lifecycle | Household-only monthly work |
| --- | --- | --- | --- | --- |
| 10 | 0.9 ms | 0.26 ms | 0.26 ms | 0.009 ms |
| 100 | 72 ms | 2.2 ms | 2.6 ms | 0.08 ms |
| 250 | 0.7 s | 9.4 ms | 8.6 ms | 0.21 ms |
| 500 | 4.6 s | 31 ms | 24 ms | 0.39 ms |
| 1,000 | 33 s | 117 ms | 75 ms | 0.81 ms |
| 2,000 | 265 s | 485 ms | 276 ms | 1.6 ms |

## Findings

1. **The cost is the algorithms, not the households.** Each household's own monthly work costs about **0.8 microseconds** and scales linearly: 2,000 households take 1.6 ms. The household model itself is cheap.
2. **The city-level daily tick is quadratic.** Doubling households roughly quadruples daily cost (500 -> 1,000: 31 -> 117 ms). The cause is repeated full scans: `update_shelter_counts()` runs several times per tick, and `get_empty_house_building_ids()` scans every household for every house via `get_household_for_building_id()`.
3. **Auto-assignment is worse than quadratic.** Assigning workplaces at 1,000 households took 33 seconds, and 265 seconds at 2,000. Any event that triggers a mass reassignment would freeze the game at those sizes.
4. **Today's practical ceiling is about 250 households in one city.** The budget at 10x speed is about 20-25 ms per game day for the whole world. 250 households already use about 9 ms; 500 use 31 ms.
5. **Days run inside a single frame,** so a 117 ms tick at 1,000 households is a visible stutter even at 1x speed.
6. **GDScript is not the bottleneck yet.** The fix is lookup tables instead of repeated scans (for example a house-id -> household map, and cached shelter counts updated on change), not a language switch.

## Implications For The Scale Model

- The Full-level threshold in `docs/SIMULATION_SCALE_MODEL.md` (about 60-250 households) is achievable with the current code, at the top of today's limit.
- With quadratic scans removed, the inherent per-household cost suggests Full simulation could cover more households across the world. This is a projection from the household-only column and must be re-measured after the fix.
- The Grouped level is still required for towns and cities. Even linear costs grow with every household, and the world also has to fund AI settlements and map agents.

## Recommended Follow-Up

`chore/household-sim-lookup-tables` (when scale work begins, not urgent for the hamlet loop):

- replace per-house household scans with an indexed lookup
- recompute shelter counts once per tick, or on change, instead of several times
- make auto-assignment linear or near-linear
- re-run this benchmark and update this document

This follows the rule to optimize only demonstrated bottlenecks: these three are now demonstrated.
