# Family Influence Prototype

A small, reversible experiment to answer one question (owner, 2026-10-28):

> **Can the player experience meaningful agency and satisfaction by influencing families to develop a settlement rather than directly constructing everything?**

**Status:** the owner approved the hybrid model for prototyping on 2026-10-28, with the refinements below. This is a **development configuration**, not a game mode: off by default, the game plays exactly as before. `docs/GAME_VISION.md` and `docs/FIRST_STAGE_LOOP.md` remain the baseline until the owner resolves the conflicts listed at the end. Branch: `feature/family-influence-prototype` (not merged to `develop` without review).

## The Principle

**The player shapes the direction of civilization through encouragement, incentives, and authority. Families respond according to their individual personalities, values, needs, and experiences. Over time, these interactions influence the families themselves, their shared culture, and the civilization they create** (owner, 2026-10-28).

The working rule for the hybrid model: **the player directly controls what the community holds in common; families decide what is their own.** Stores, roads, public works, and which land is open for what belong to the player. Homes and workplaces belong to the families.

## Owner Refinements (2026-10-28)

These hold for the prototype and for whatever follows it.

1. **Personality is relatively stable, not fixed.** It generally changes slowly. Values and convictions respond more readily to experience and social influence. Significant events can change more, but understandably. Culture emerges from changes across families and generations. No classification permanently prevents a trait from changing. Value strengths (not only held or not held) are approved where practical.
2. **Families respond to both what was achieved and how.** The same event can be read differently: a compelled granary that saves the town can teach one family that strong leadership protects, another that cooperation matters, a third to resent being forced, a fourth that it should have been voluntary. A family's interpretation weighs the outcome, whether taking part was voluntary or compulsory, how fair the process was, its own costs and benefits, and its existing values, personality, relationships, and experiences. **No hardcoded ideological transformations.**
3. **Understandable, not perfectly predictable.** Before a decision the player sees a reasonable prediction per family (likely to cooperate, uncertain, likely to resist, strongly opposed), grounded in what can be observed and explained. Actual behavior may differ, within bounds. Afterwards the player can inspect why a family cooperated, resisted, or changed its position.
4. **Direct action is permitted, never required.** A player may encourage families to develop on their own from the first day. A settlement's stage decides which forms of influence and authority exist, not a mandatory style, and growing never removes a power the player had. **Authority changes through explicit decisions, social agreements, institutions, or understandable consequences, not population thresholds.** The player keeps meaningful ways to interact with every settlement throughout the campaign.
5. **Four different interactions,** and only the last is compulsion: (1) encouraging a family to establish a workplace; (2) offering communal resources to support it; (3) commissioning a workplace and seeking a willing family to run it; (4) requiring a particular family to build or run it. A family answers the substance of what is asked of it, not the category: a self-governing family may welcome a publicly funded workplace it is free to take; a deferential family may resist an assignment that threatens its welfare. No automatic trust penalties by category.
6. **Desire and ability stay separate.** Desire: what a family wants, from personality, values, ambitions, and circumstances. Ability: whether the land, resources, labor, and opportunity exist. The player's communal stores priorities decide which wishes become practical. **Protected survival reserves** keep families' own projects from causing the tool shortages and collapses the first stage worked to remove. An improved building that runs short of tools keeps its building and falls back to the primitive method.
7. **Direct and indirect are testing configurations,** not permanent modes. In the long run a player chooses how much to encourage, intervene, or compel, may treat two settlements differently, and may change style as circumstances change.
8. **Pacing targets are unchanged** (below).

## What The Prototype Builds

Deliberately small: three representative industries (food from fields, wood, tools), the families a town already has, and the existing household, construction, and simulation systems. No government, no cultural drift, no enforcement system: those stay architectural considerations until the core interaction proves enjoyable.

| Piece | Where | What it does |
| --- | --- | --- |
| Families take up work | `FamilyInitiative` | Weekly, a family with no holding chooses food, wood, or tools and opens it as hand work (tier 0) at a site it picks, through the normal construction pipeline (`requested_by` household) |
| Families improve their work | `FamilyInitiative` | Weekly, a family on hand work weighs improving it into a proper holding (tier 1) |
| Reasons and predictions | `FamilyInitiative.get_reasons`, `predict_improvement` | Every decision keeps the reasons it was made for; before asking for better work the player sees each family's outlook and why |
| Encouragement | `TownInfluence.encouraged` | The community asks for food, wood, tools, or better work |
| Stores rule | `TownInfluence.store_rule` | Open: families' projects may draw on stores above the protected reserve. Priorities first: only projects serving what the community asks for may draw |
| Protected reserve | `TownInfluence.get_protected_reserve` | 10 wood, and tools for every proper workplace's upkeep (2 each, at least 4), never spent on families' own projects (`EconomyBalance`, Influence prototype) |
| Work ground | `TownInfluence.mark_work_ground` (K) | Optional: once any ground is marked, families open workplaces only there |
| Hand method fallback | `Building.works_by_hand_without_tools`, `City.set_hand_method_fallback` | A proper workplace below half upkeep keeps its building and works at hand work's pace (a third) until tools return, instead of standing idle |

The player keeps every direct tool: any building can still be planned by hand, and the pipeline gives it to the best-suited free family as before. Commissioning that seeks a *willing* family (refinement 5.3) is not built yet; today's direct placement is the stand-in for it.

### How a family decides

Desire is a sum of terms. Each term carries the reason the family gives, so the card can say why.

| Decision | Terms (weight) |
| --- | --- |
| **Which work to take up** | its calling (+3) or not its calling (-2); what the town needs: food below what it eats (+3, x1.5 for a cautious family, which puts food first), no one cutting wood (+2.5), wood short (+1.5), tools running out (+2.5), others already doing it (negative); the community asking for it (+2 x receptiveness) |
| **Whether to improve** (acts at 2 or more) | proper work yields three times as much (+1); what it gives the town: food, wood, or tools short (+1.5); what it spends of the free stores (up to -3; x1.5 cautious, x0.5 daring); daring (+2); cautious (-1.5), and while food is under 60 days or the stores are thin (another -1.5); traditionalist (-2) or reformist (+1); industrious (+1) or leisurely (-1); acquisitive or private holdings (+1); fatalistic (-1) or hopeful (+0.5); neighbours' improved work paying (+0.75 each, at most +3) or standing short of tools (-1 each, at most -2), x1.5 for cautious and traditional families, who are moved more by what they see than by what they are told; the town hungry (-2); the community asking for better work (+2 x receptiveness) |

**Receptiveness** is persuasion, not obedience: 1, deferential 1.5 ("heeds the community"), self-governing 0.6 ("judges for itself"), communal labor +0.25, solitary -0.25. Nothing costs trust.

**Ability** comes after desire. Hand work needs no materials, so a family can always take up work. An improvement needs the stores to fund it under the rule, above the reserve; if they will not, the family says it wants to and why it cannot ("Wants to improve its forager's garden, but the stores go to the community's priorities first").

**Bounded uncertainty.** Each decision adds an unknown of at most 0.75, drawn from the town, family, week, and decision, so a loaded game decides as the original would. The prediction bands are: likely (1 or more above the threshold), uncertain (within 1), likely to resist (1 to 3 below), strongly opposed (more than 3 below). Because the unknown is smaller than the uncertain band, a family predicted likely always acts and one predicted to resist never does; only an uncertain family can surprise. (Tested.)

**Neighbours** are kin and families whose homes stand within 10 tiles. This is a circumstance, not value drift: a family's values do not change in the prototype.

**Where.** A family opens its work at the valid site nearest its home and a store (straight-line distance), pulled toward or away from the town's heart by Town-Loving or Open Country, on the work ground if any is marked. So where the player sets aside home plots shapes where work opens.

## What It Leaves Out, And Where That Would Go

| Not in the prototype | How the architecture leaves room for it |
| --- | --- |
| Value change (refinements 1-2) | Decisions already record what a family did and why. An interpretation step would read an experience's facets (outcome, voluntary or compulsory, fairness, own cost and benefit) through the family's values and personality, and nudge value strengths slowly, personality more slowly. Nothing maps an event straight to a value |
| Commissioning a workplace for a willing family (5.3) | A player request whose claimant is chosen by desire for that work rather than suitability; it may stand empty if nobody wants it |
| Requiring a family (5.4), trust, enforcement | A request with a named family; its answer weighs the demand on that family (welfare, cost) through its values; trust is a per-family number toward the community |
| Agreements and stage-based influence (refinement 4) | `TownInfluence` holds what the community has agreed; agreements are adopted by support, not unlocked by stage |
| More industries, homes under the stores rule | Families' homes still follow `FamilyDevelopment` (its own 10-wood reserve), outside the stores rule |

## Pacing (Reconciled, Not Changed)

The approved targets stand:

- `docs/SETTLEMENT_GROWTH_SCALE_MODEL.md` (Pacing Targets): Founding Camp is the first season; Hamlet spans years 1-3; Village spans years 3-10; the first playable target is to reach Village and hold it 5-10 years.
- `docs/FIRST_STAGE_LOOP.md` (Balance Targets): Hamlet by year 1-3, Village by about year 3.

The **measurement** at milestone 6 was Hamlet at about day 35 and Village at about year 1.1-1.4. That is a measurement against the target, not a new target: `FIRST_STAGE_LOOP.md` lists it as open owner decision 1 (accept, or slow it through village conditions, founding families, or family formation). The earlier design note quoted that measurement ("Village at about year 1.3") without saying so; this section corrects it. The prototype changes neither the targets nor the stage conditions. It reports what family-driven development does to the measured timing, so the owner can decide pacing once with both results in hand.

## How To Run It

- **Rules:** `tests/family_initiative_validation.gd` (headless, synthetic town map): off by default; founders take up work of their callings within a month and say why; a daring family improves while a cautious, traditional one keeps to hand work, each giving its reasons; predictions are uncertain for a neutral family and likely once a deferential family is asked; the unknown never makes a likely family refuse; the stores rule holds back an improvement nobody asked for, and says so, and never blocks hand work; the reserve keeps the tools for upkeep; a neighbour's paying farm draws a cautious family on, one short of tools puts it off; the hand method fallback keeps the building and works at hand pace; work ground restricts sites and unmarks; a saved town keeps all of it.
- **Comparison:** `tests/sim/influence_check.gd` (`-- --years=N` to shorten). Write its output to a file and filter for `[INFL]`.
- **Playtest:** in the town view, press **I** to turn the prototype on (or off) for that town; it saves with the town. Alternatively start the game with `-- --influence` and every town founded in that session starts with it on. The sidebar's **Influence (prototype)** section has the four asks, the stores rule, and how families on hand work would answer a call for better work; **K** marks work ground (two corners; again to unmark). A family's house card shows **Decided:** (what it last decided and why) and **If asked for better work:** (its outlook and reasons). Every direct tool still works.
- **Screenshot:** `game_influence` in `tests/visual/town_map_capture.gd`.

## Measured

MEASURED_PLACEHOLDER

## Judgment Calls (Open To Veto)

- **Every workplace a family opens starts as hand work.** The first version let a family open a proper holding at once when it wanted to invest; then every founder invested in the first week, whatever its temperament, because the founding stores make a farm cheap and food is short. Opening by hand and improving as a second decision is what made temperament visible (the owner's tier 0 plan).
- **Caution means waiting while the town is precarious.** The first version made a cautious family weigh food security *more*, so cautious families improved food work as early as anyone during the founding shortage. The owner's example ("a cautious family might wait until its resources and food security are sufficient") now reads as: no change while food is under 60 days or the stores are thin, then a wary weighing like anyone else's.
- **The hand method applies below half upkeep,** not only at zero, so a workplace never makes less by hand than it did at a quarter's upkeep.
- **Reserves** (10 wood; 2 tools a proper workplace, at least 4) are first guesses.
- **Encouragement for better work also funds improvements under the priorities rule;** asking for a trade funds improvements of that trade.
- **The guided stand-in** asks for food when food runs short, wood under 25, tools under 10 with no toolmaker, and better work once the stores hold 30 wood and tools 3 above the reserve; it keeps the stores for priorities. A real player will do better or worse; it is a floor for comparison, as the planning check's stand-in is.

## Owner Playtest Brief

Play the same seed twice, about a year each: once as before (no flag), once with `--influence`, placing no workplaces yourself unless you want to.

- **Decisions:** did you have interesting things to decide without placing workplaces? Were there long stretches with nothing to do?
- **Families:** do the "Decided" lines and outlooks explain why families did what they did? Did a family surprise you, and could you see why afterwards?
- **Influence:** did asking for something, or keeping the stores for priorities, visibly change what families did?
- **Space:** does the town's layout reflect your plots and work ground, and the land?
- **Survival:** did the town hold up without constant intervention?
- **Satisfaction:** at the end of the year, did the town feel like yours?

## Conflicts To Resolve Before This Leaves Prototype

None of these changes until the owner decides. Each conflicts with an approved document if the direction is adopted:

- `docs/FIRST_STAGE_LOOP.md` red line "nothing silently takes control away from the player" and M3's "building calling work stays the player's decision".
- `docs/FIRST_STAGE_LOOP.md` Planning Pays Off is measured on player-placed layouts; with families placing work, "planning" means plots, work ground, and public works.
- `docs/CULTURE_AND_VALUES_MODEL.md`: values held or not (no strength); culture changes mostly between generations; values inspect-only (predictions now show them at decision time, which the model already allows).
- `docs/SETTLEMENT_GROWTH_SCALE_MODEL.md`: "named households, direct assignment" at stages 0-1.
- `docs/HANDOFF.md`: the tier 0 proposal ("not by the stores") becomes "desire ignores the stores; ability follows the rule".
- `docs/WARFARE_AND_CONFLICT_MODEL.md`: the militia always answers; under refinement 5 a call-up is a requirement families may resist.
