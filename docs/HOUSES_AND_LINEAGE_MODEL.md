# Houses And Lineage Model

Firm owner decisions on what families become as society scales (2026-10-19). Sits under `docs/GAME_VISION.md`. This model is the foundation that wealth, culture, and influence attach to at town scale and above, and it defines the Grouped simulation level in `docs/SIMULATION_SCALE_MODEL.md`.

Items marked **Default** were set during planning to complete the model; the owner can change them without reopening the rest.

## Core Idea

**Families stay families. Lineages that grow large collapse into Houses.**

- A founding family has children. Those children form households, and their children form more. Together they are a **lineage**.
- When a lineage is large enough, and the settlement is large enough, its member households **collapse into a House**: one entity that carries the lineage's name, its families' combined values, trades, and wealth.
- A House is both the social idea and the simulation shortcut. Collapsing lineages is how a growing settlement stays inside the household budget measured in `docs/HOUSEHOLD_SIM_BENCHMARK.md`.

Houses rise mainly through **procreation**: families that have many children, whose children found families of their own. Wealth does not decide whether a House exists; it decides how strong the House is. A large, poor farming clan and a small, rich merchant House can exist side by side.

Because values should affect family size (`docs/household_simulation_philosophy.md`), cultures that favor large families will produce more Houses. Culture shapes who holds power through demography, without a special rule.

## When Collapse Happens

**Lineage size plus settlement size.** Both must be true:

- the lineage has reached a size threshold, and
- the settlement is past village scale.

In hamlets and villages every family stays visible and named. Collapse begins only when the town needs it.

**Default (provisional thresholds):** a lineage of 5 or more living households, in a settlement of 30 or more households (Early Town in `docs/SETTLEMENT_GROWTH_SCALE_MODEL.md`). Tune from play and benchmarks.

## What A House Is

- **Belongs to one town.** A House is distinct to the town it is in.
- **Still a family:** name, lineage, values, family trades, and continuity across generations.
- **Default:** a **head household** stays a full named household as the House's face, so the player always has a family to look at. The rest are collapsed.
- **Members in aggregate:** counts of member households by life stage, total population, labor, and needs. Births and family formation run as rates over these counts at the Grouped cadence (monthly).
- **Culture as a blend:** a House's culture is the distribution of its member families' values, not a single value. A House can be internally divided, for example mostly traditional with a restless younger branch. This is why House culture is richer than a single family's.
- **Wealth and holdings:** the House pools the wealth of its collapsed families and holds concrete assets (workshops, land, caravans, coin).
- **Houses employ families (owner decision 2026-10-20).** A family runs one holding, so larger operations (an estate of several farmsteads, a set of workshops) exist only when a House holds them and dependent families from the commons work them. This is how wealth, labor, and influence connect at town scale.
- **Loyal by default.** Houses generally follow the player's direction. Friction comes from culture: policies a House's values oppose still carry the consequences described in `docs/GAME_VISION.md`.
- **Kin ties:** related Houses in other towns (see Branches) remember their shared lineage. Kinship is how soft influence travels between towns.

## The Commons

Families that are not part of a collapsed lineage (migrants, small families, lines that never grew) aggregate into **the commons** at town scale and above.

- The commons are grouped simply, by family trade and culture.
- Commons families can marry into a House, or grow into a lineage of their own over time.

## Marriage And Lineage Membership

**Set by culture.** When two lineages join through marriage, culture decides which lineage the new household belongs to: the father's line, the mother's line, or the stronger House. Inheritance rules are therefore a cultural trait with real consequences for which Houses grow.

**Implemented in M3 (2026-10-19):** grown children of two different households marry, the lineage rule picks the lineage, and a grown child with no partner in town marries an outsider after 6 months. Details in `docs/IMPLEMENTATION_ROADMAP.md`, M3.

## How Houses Change

- **Branches split off.** A branch that grows large in another town becomes its own House there, related to the parent House by kinship.
- **Decline dissolves.** A House that shrinks below the threshold dissolves back into ordinary families. **Default:** into the commons at town scale and above, or back into named families if the settlement is small again.
- **Extinction.** A House whose line dies out disappears. **Default:** its holdings pass to related Houses by the culture's inheritance rule, otherwise to the commons or the state.
- **Not now: succession splits.** A disputed inheritance splitting one House into rivals is a possible future feature. It would need to be designed as a distinct feature, not added in passing.

## Culture By Scale

- **Small places (hamlet, village):** culture is the families.
- **Larger places (town and up):** culture is mainly the Houses, plus the commons. Settlement culture is the blend of its Houses' internal distributions and the commons.

This gives the culture model its first hard requirement: values must be data that can be held per family and combined into a distribution per House and per settlement.

## Consequences For Other Models

- **Simulation scale:** the Grouped level's unit is **Houses plus the commons**, not generic trade/class buckets.
- **Economy:** wealth has three holders: ordinary families (a wealth level), Houses (pooled wealth and holdings), and the state (treasury).
- **Influence:** kinship influence travels through related Houses in different towns.
- **Continuity:** the late-game Houses of the player's nation descend from the first founding families, which pays off the attachment pillar.

## Open Questions

- How does a new lineage rise out of the commons, given that the commons are aggregated?
- What makes a House strong beyond size and wealth: offices, reputation, holdings, age?
- What levers does the player have over Houses: offices, monopolies, taxes, favor?
- Do AI civilizations use the same House model? (Likely yes, for the same reasons as the shared Grouped model.)
