# P1-5: Scale Check and Scale Benchmark

Branch `feature/p1-scale`. This replaces `docs/HOUSEHOLD_SIM_BENCHMARK.md`, which measured a classic-rules town with no map and is retired. It answers master roadmap decision 6: can the architecture hold millions of inhabitants, concentrated or distributed? It reports measurements in full, with no target to hit. Timings were taken alongside three simulation processes on an i9-12900K, so absolute times are pessimistic and the trend with size is what counts.

## S19: a day of today's game by town size

`tests/benchmarks/scale_check.gd`: family-led towns on a 64×44 map, social life on, a private compact with market and commons, plenty in store, 60 days each.

| Households | People | Ordinary day | Month's turn | Memory | Growth exponent (day) |
|---|---|---|---|---|---|
| 10 | 36 | 8 ms | 51 ms | 3.8 MB | |
| 25 | 88 | 53 ms | 53 ms | 4.2 MB | 2.0 |
| 50 | 180 | 61 ms | 57 ms | 4.7 MB | 0.18 |
| 100 | 358 | 68 ms | 81 ms | 5.8 MB | 0.17 |
| 200 | 706 | 90 ms | 142 ms | 8.0 MB | 0.40 |
| 400 | 1,402 | 157 ms | 173 ms | 12.4 MB | 0.74 |
| 800 | 2,822 | 365 ms | 375 ms | 21.2 MB | **1.22** |

- **A fixed cost of about 50 ms a day** appears once a town has more than a handful of families. It doesn't grow with size, and it is most likely the town map's routes and paths. The first day costs about 1.5–2.3 s, when routes and caches are built.
- **Per-household cost turns superlinear at 400–800 households** (exponent 1.22 for the day, 1.12 for the month's turn). Some daily systems compare households with each other: social ties, sharing, and the market's buyers. **Full household detail stops scaling at about a thousand households a town.** That is the limit Phase 4's grouping is for.
- At 1x speed (2 s a game day), 800 households fit. At higher speeds they don't.

## The synthetic benchmark: millions of inhabitants

`tests/benchmarks/population_scale_benchmark.gd` uses packed family records (weight, settlement, occupation, life stage, values as a bitmask, people, food). Each month it runs production and eating by occupation, splits off a group's hungry part by a seeded draw, founds new families whose values are inherited with variation, and merges identical records. Twelve months per scenario.

| Scenario | Records, start → after a year | Memory | Monthly pass | Merge | Save |
|---|---|---|---|---|---|
| 1M concentrated, weight 1 | 222k → 228k | 7.7 MB | 34 ms | — | 5.6 MB |
| 1M concentrated, weighted | 16k → 14k | 0.5 MB | 5 ms | 11 ms | 0.3 MB |
| 1M distributed (400 towns), weight 1 | 222k → 227k | 7.7 MB | 34 ms | — | 5.6 MB |
| 1M distributed, weighted | 194k → 184k | 5.1 MB | 35 ms | 130 ms | 4.6 MB |
| 10M concentrated, weighted | 169k → 142k | 5.1 MB | 45 ms | 119 ms | 3.5 MB |
| 10M distributed (2,000 towns), weighted | 1.74M → 1.59M | 59 MB | 334 ms | 1,325 ms | 39.5 MB |
| 10M distributed, weight 1 | 2.22M → 2.28M | 59 MB | 351 ms | — | 56 MB |

**Today's `Household` object** measures 13.1 KB with its values and nothing else (memories and ties add more in play). As objects, 1M people would take 2.9 GB and 10M about 28 GB.

**Land-use record:** about 10,400 regional tiles of built land per million people at Edo-like density. That is 0.13 MB packed against 3.1 MB as today's Dictionary of Arrays, and 1.3 MB against 30 MB at 10M.

## Findings: dead ends and what avoids them

1. **One `Household` object per family is a dead end at a million people.** 13 KB or more each, against about 25 bytes for a packed record. Phase 4's weighted records must be packed data, with `Household` objects kept only for families represented individually (founders, prominent lineages, irreplaceable suppliers). No reading of "core or metropolitan million" escapes this, so it doesn't lock in that decision.
2. **Today's daily systems stop scaling at about a thousand households a town** (exponent above 1). Larger towns need Phase 4's monthly forms and grouping, and the comparisons between households (social life, the market) need indexing by group, not all against all.
3. **Exact-key grouping barely compresses small, distributed towns.** With 400–2,000 towns, almost every household's combination of occupation, stage and values is unique within its town. Weighting needs a record budget with coarsening that keeps rare combinations (Phase 4's budget decision). Concentrated cities compress well (16k records for 1M).
4. **Merging with Array keys in a Dictionary is slow at millions** (1.3 s a month at 1.7M records). Packed integer keys or a sort-based merge are needed. This is an implementation note, not a dead end.
5. **Packed records are cheap at 10M even at weight 1:** 59 MB, a 351 ms monthly pass in GDScript, and a 56 MB save. Save size will need compression or deltas at 10M, but it's within reach.
6. **Land-use record storage should be packed, not a Dictionary of Arrays,** before satellites and Summary towns make it world-sized (Phase 5).

## Rendering at a million

This uses the map proving test's renderer (`tests/spike/shared_state_render.gd` on `experiment/map-scale-proving-tests`), with 1,000,000 people on 3072×3072 town tiles: 262,211 buildings (240,000 homes, 12,211 farms), 693,976 instances. It ran on an RTX 3070 Ti, off screen. The layout is placeholder load, not a growth design.

| Measure | 1080p | 4K |
|---|---|---|
| Frame, whole city | 1.41 ms | 4.38 ms |
| Frame, districts / street (with 50,000 walkers) | 1.40 / 1.40 ms | — |
| Opening the city | 33.6 s (ground textures 30.3 s, instances 3.2 s) | 33.6 s |
| Video memory | 754 MB | 840 MB |
| Save beyond the seed | 4.9 MB (against 1,980 MB for the land at today's 220 bytes a tile) | |
| Drawing the record on the regional map | 0.54 s | |

- **Frame time doesn't limit a million on this GPU.** It is flat from the whole city to the street, and 50,000 walkers cost nothing measurable.
- **Opening time is the dead end to fix:** 33.6 s, against 15 s at 500k, so it grows linearly with land area. It is per-tile script work on ground textures, so it needs to be saved, threaded or built by sector (roadmap Phase 6, and the map report's first risk). At 10M concentrated in a few cities it would reach minutes.
- **Video memory at about 0.8 GB** for one million-person city fits mid-range hardware, but not integrated GPUs (minimum hardware is deferred to Phase 6).
- Real growth, simulation cost at this size and weak hardware were not tested here.
