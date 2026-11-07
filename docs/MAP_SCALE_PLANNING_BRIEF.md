# Map Scale: Planning Brief

**For merging with other planning threads.** Status as of 2026-11-07. This is a reference, not a plan: nothing here is on the roadmap, and nothing is authorized beyond the proving tests, which are finished. Full reasoning and evidence: `docs/MAP_SCALE_ARCHITECTURE.md`.

## Where this lives

| What | Where | State |
| --- | --- | --- |
| This brief and the full report | Branch `docs/map-scale-architecture` (worktree `ngg-map-architecture`) | Unmerged, local |
| Test code and the off-by-default land switch | Branch `experiment/map-scale-proving-tests`, from `develop` (worktree `ngg-map-spike`) | Unmerged, local; throwaway unless the owner says otherwise |

## Owner decision (2026-11-06)

> Kinfolk & Kingdoms requires a shared geographic model, not a single continuously rendered map. City and regional views may be separate scenes with different rendering methods, provided they derive their geography, developed footprint, and major infrastructure from the same authoritative world state. Seamless zooming and scrolling between cities are not requirements. The player can switch views. A settlement's regional appearance must reflect its actual development. Opening a city should reveal the recognizable settlement depicted on the regional map.

Standing constraints from the owner's brief: autonomous households drive settlement form; fully simulated settlements stay distinct from abstract satellites, which are not explorable town maps; plan for hundreds of thousands in a settlement and millions overall.

## Direction (recommended; the owner has not yet chosen)

**One world state, separate views.** Land comes from position. Development is recorded per settlement. A compact land-use record per regional tile is what the regional and world maps read. A city view is a large window onto that land, drawn by its own scene. The simulation level follows the settlement, never the camera.

## Proving test results

### 1. Land from position alone: passed, with one cost to decide

| Measure | Result |
| --- | --- |
| Do different windows agree on the same land? | Yes: 0 differences in about 583,000 comparisons (3 worlds; up to 256x256 windows). Before: 4.1% of tiles differed |
| Towns off the ground, same seeds, today → new | 249 → 250 of 258; only one result changed (one town gained) |
| Land moved in each town | Median 73 of 2,816 tiles, worst 227. Saved games keep their land |
| What founding must record as a change | Median 8-13 tiles, worst 132 |
| Does the regional map tell the truth about the town's land? | Water 98-100%, woods 93-97%, roads 91-97%, rock about 90% |
| **Cost** | The poorest maps vary more: the least farmland on the 80 continuous-map sites fell from 118 to 71 tiles (the floor of 18 holds), and one town's room fell from 12 farms to 8. Exact shares per town are gone by design |

### 2. Two views from one state: drawing passed; opening and far-view legibility did not

Off screen on an RTX 3070 Ti, using the game's own ground shader and painters. City view at 1080p, frame time:

| People | Buildings | Instances | Street to district zoom | Whole city | Opening the city | Save size beyond the seed |
| --- | --- | --- | --- | --- | --- | --- |
| 10,000 | 3,750 | 108,816 | 1.4-1.5 ms | 1.0 ms | 1.2 s | 0.08 MB |
| 100,000 | 34,655 | 230,957 | 1.4-1.5 ms | 1.1 ms | 4.1 s | 0.7 MB |
| 500,000 | 138,376 | 473,567 | 1.4 ms | 1.3 ms | 15 s | 2.6 MB |

- **City size barely affects frame time.** Ground alone is about 1.2 of the 1.4 ms. 4K costs about 5 ms. 50,000 animated walkers cost almost nothing.
- **Weak hardware is unproven, and no integrated GPU was available.** On the Windows software renderer, a harsh stand-in, the 100,000-person city costs about the same as the regional map the game already has (about 140 ms at 1080p, 65 ms at 720p); the whole-city view is about 40% slower. The limit there is the ground shader that exists today, not the size of the city. The Compatibility renderer also runs it (tested on the same NVIDIA GPU).
- **Same geography at every scale,** by eye: rivers, coast, woods and rock line up. A town grown by the real simulation showed its fields and homes in the right place in both views.
- **Footprint agreement is moderate:** 74% at 10,000, 60% at 100,000, 88% at 500,000 (share of visibly developed areas that both views show). This scores pictures, and it comes from the placeholder drawings.

**Not tested:** real growth (the city layout is placeholder load), simulation cost at these sizes, overlays, changing individual buildings, or an actual integrated GPU. The 100,000 and 500,000 cities have fewer farms than they need, because the test maps ran out of farmland (9,655 of 12,500 and 13,376 of 62,500), so those two cities are under-fed and their farm load is low.

## What this changes for planning

- **The biggest risk moved.** It was "can we draw a great city?" It is now these three, in order:
  1. Opening time: 4 s at 100,000 and 15 s at 500,000, mostly per-tile script work that could be saved, threaded or built by sector (not yet tested).
  2. Far-view legibility: from afar the city view reads less like a city than the regional view does. This is what the promise "the recognizable settlement" depends on, so it needs design and art.
  3. Grouped simulation, which is undesigned and which every large city depends on.
- **Seamless zoom is removed from scope,** including the town-to-region hand-off and any need to draw both scales at once.
- **The land-use record is now the keystone.** Economy, demographic and satellite design should assume it. It carries built land, streets, farmland, cleared woods, major roads and (later) claims and culture.
- **Regional land must read the record.** Regional trees are pure geography, so they cannot show felled woods today. The test painted over them; the real change is to have the regional chunks read the record.
- **Docs in conflict, if the direction is accepted:** `SIMULATION_SCALE_MODEL.md` (district blocks, player places districts), `map_and_settlement_scale_audit.md`, and `HANDOFF.md` ("One player settlement"). "Satellite" is still written nowhere in the repo.

## Dependencies for other threads

| Thread | What it should know |
| --- | --- |
| **Economic Foundations** (`feature/ef-*`) | The land test ran on `develop`, not this line. `add_clay_and_limestone` would need the same treatment: it reads neighbours clipped at the window's edge, and limestone is picked by each outcrop's first tile in scan order, which depends on the window. Cheap habits: no new meaning for the map's edge, small per-tile state derivable from position, rules that reach by radius |
| **E13 Local Value and demographic scaling** | Group simulation must write the same land-use record as households, and keep distributions rather than averages. No V0 work is implied |
| **Economic fragility** | Grouping must not remove what can fail. Critical contributors stay real on the map ("anchors"), chosen by actual dependency, never by label |
| **Town building and family growth** | `HomeSites`' scored terms are the intended basis for growth at scale; the test's layout is not a design |
| **Roadmap** | Unchanged. If the direction is accepted, a likely order is: position-pure land and the record, so the regional map tells the truth; then packed sectors and growth past 64x44; then road networks and satellites; then Grouped and Patterned cities; then second settlements. This depends on Economic Foundations finishing unless the owner says otherwise |

## Owner decisions needed before a roadmap

1. **Direction:** accept "one world state, separate views"? *Recommended: yes.*
2. **Arable land:** accept more variation on poor land from position-based land, or keep a stronger founding guarantee? *Recommended: accept it, with a founding floor set from what `map_luck_check` shows on arid sites.*
3. **Lowest hardware:** name a target. *Needed: a real measurement on that hardware, and possibly a cheaper ground shader.*
4. **Acceptable wait to open a city?** *Recommended: a target before design, since it sets how much must be prepared in advance.*
5. **How close can you get to a Patterned district?** *Recommended: inspect and plan, but no individual ordinary houses.*
6. **What is a satellite, and can one become a full settlement?** *Recommended: a land-use footprint with an economy and culture, no town map, and promotion only by a deliberate founding act.*
7. **Player tools at scale:** replace "player places districts"? *Recommended: yes; the player marks land use and builds infrastructure, and people decide the rest.*
8. **Rival towns:** can they be captured and opened? *No recommendation yet.*
9. **What limits land; when towns meet; whether geography changes; timing against Economic Foundations:** see `MAP_SCALE_ARCHITECTURE.md`, section 6.
