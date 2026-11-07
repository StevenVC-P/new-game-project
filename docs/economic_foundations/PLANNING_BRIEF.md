# Economic Foundations: Planning Brief

**For merging with other planning threads.** Status as of 2026-11-07. This is a reference, not a plan. Nothing here is merged into `develop` or `main`, and nothing beyond what's listed as built is authorized. Full detail: `docs/ECONOMIC_FOUNDATIONS_ROADMAP.md` and the sprint reports in this folder.

## Where this lives

| What | Where | State |
|---|---|---|
| All built sprints, S1a to S5d, plus this brief | Branch `feature/ef-s5d-wood-margin` (`origin`; worktree `ngg-economic-foundations`). Linear: it contains every earlier `feature/ef-*` branch and `develop` (44 commits ahead) | Pushed, unmerged; awaits the owner's review |
| Reserve rule experiments (S9c) | Branch `experiment/ef-reserve-rules` (`516465c`), from S5d's code | Pushed; experiment, not adopted, not for merging |
| Each sprint's own branch | `feature/ef-s1a-framework` … `feature/ef-s5c-reachable-wood` | Kept for history; superseded by the S5d branch |

## The standing intent (owner)

- The goal is believable autonomous economic decisions, not equal survival across economic arrangements.
- Cold and marginal sites stay genuinely dangerous: no survival targets and no added founding fuel. Families may choose badly from their values and callings. Nothing gets corrected without evidence of a defect.
- Separate failures caused by the arrangements themselves from limits of the occupation-choice system.
- The player controls genuinely communal goods, and households own their own goods. The simulation never silently overrides the player's reserve policy.

## What's built (on the S5d branch)

| Area | Sprints | In one line |
|---|---|---|
| Measurement | S1a | Suite runner, flow counters, invariants, divergence batches across 5 lands × 8 starts |
| Land and materials | S1b, S4, S5 | Quarries need stone. Timber and stone buildings are chosen by families. Brick needs clay, lime needs limestone |
| Forests and fuel | S2, S3, S3b | Finite, regrowing woods. Winter firewood. Sustained hunger or cold can kill |
| Wood decisions | S5b, S5c, S5d | Woodcutters weigh wood beyond the winter (S5b), only wood they can reach (S5c), and need through the next winter plus a margin (S5d) |
| Ownership and the commons | S6, S7, S8 | Ledger of household shares. A compact: the player sets contributions by category. Reserve and grant rules. Families in danger ask neighbours |
| Exchange | S9 | Monthly market day, urgent sales for food any day |

## Latest measurements (S5d, year 6, towns off the ground of 40)

| Arrangement | Before S5b | S5d | Cold deaths before → S5d |
|---|---|---|---|
| Pooled | 21 | 20 | 61 → 60 |
| Communal | 20 | 19 | 41 → 41 |
| Shared | 20 | 24 | 26 → 21 |
| Shared + reserve | 16 | 18 | 43 → 35 |
| Private | 15 | 12 | 25 → 26 |
| Private + reserve | 3 | 4 | 29 → 33 |

Stored wood stays 14–43% below the pre-S5b build, so the oversupply fix holds. Differences of 1 to 4 towns are within noise between near-identical builds.

## Reserve experiments (S9c, not adopted)

Against S5d with a 30-day reserve:
- **Reserve last in order:** hunger deaths fall under shared (67 → 23) and hold under private (31 → 28). This rule fits the owner's principle best.
- **Daily draw limited to half of need:** hunger deaths rise (67 → 107, 31 → 81), in most towns.
- **Danger read over 30 days:** small effect.

## Owner decisions open

1. Keep S5d, and its margin (half the need again, at least 100 wood, urgent review at plenty 0.5)?
2. Adopt reserve-last ordering? Limit emergency draws at all, and at what share (0.5 costs lives; untested at others)? The 30-day rule is optional.
3. Review and merge the chain to `develop` (owner only).
4. E13 V0: the roadmap still reads "not authorized." The owner's later note ("consider everything for V0 as authorized; E13 is only planning for now") was read as V0's plan being approved, not its build. Confirm.

## Known limits and risks

- **Occupation choice:** nothing prompts a family to take up missing work (toolmaking, woodcutting) once no one does it. This likely still loses marginal 0 under private, and it needs its own trace. This is a limit of the choice system, not of the arrangements.
- **Private compacts** recover less than the others (12 vs 15 before S5b).
- **Market value in choosing work** is deferred to E13 V2.
- **Single seed set per land:** towns ok swings of a few are noise. Hunger and cold deaths are steadier signals.

## Next on the roadmap

E13 Local Value (V0 observe → V1 town reference → V2 work decisions → V3 household → V4 regional), design direction approved. The planned sprints S10–S19 (food kinds, farming year, soil, fish and game, livestock, iron, tool tiers, wood species, values from experience, scale check). Fuel requests through mutual help are approved in direction and not built.

## Dependencies for other threads

| Thread | What it should know |
|---|---|
| **Map scale** (`docs/map-scale-architecture`) | This line branches from `develop`. `add_clay_and_limestone` (S5) reads neighbours clipped at the window edge and picks limestone by scan order. It would need the map thread's position-pure treatment |
| **E13 and demographic scaling** | E13 must eventually value both households and aggregated groups with one system, keeping distributions of wealth, ownership, circumstances and inherited values. No aggregation is built |
| **Scale (S19, E12)** | Tick cost at 100 households isn't measured yet on this line |
| **Saves** | New domain fields save automatically. Reserve experiment fields are behind switches and off by default |
