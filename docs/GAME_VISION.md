# Game Vision

Owner-confirmed direction for objectives, pace, and player experience (2026-10-19). This sits above the system models in `docs/`: when a model or sprint conflicts with this document, this document wins unless the owner changes it. It complements `docs/household_simulation_philosophy.md` (how the simulation works) and `docs/PROJECT_OWNER_QUESTIONS.md` (prototype-level answers).

## Vision

A slow, open-ended civilization sandbox in which culture and economics build on each other. Founding families become hamlets, villages, towns, cities, and eventually nation and global structures. What the player builds is theirs, and the society that grows inside it is partly theirs and partly its own.

## Experience Pillars

A good session should leave the player with:

1. **Attachment to families** - they remember specific households, lineages, and what happened to them.
2. **Economic mastery** - they solved production and supply problems and understand why the economy works.
3. **Watching a society emerge** - values and culture grew out of how families lived, in ways the player shaped but did not fully control.
4. **Pride in what they built** - the settlement, and later the nation, looks and feels like theirs.
5. **The long climb** - the sense of going from a few families to a civilization.

The defining overlap is **culture x economics**: how families live shapes the economy, and the economy shapes how families live and what they value. That loop should be visible at every scale, from one household up to nation and global structures.

## Objectives

- **Open-ended sandbox.** There is no enforced win state.
- **Player-chosen ambitions.** The player can pursue, among others:
  - conquering the map
  - controlling the global economy
  - following where their society's values and culture lead
- Taking the whole map should be possible, but long and drawn-out, in the spirit of Risk.
- Settlement stages (hamlet, village, town, ...) are markers of the journey, not goals the game imposes.

## What Pulls The Player Forward

- **Family ambitions** - households want things (a better home, a workshop for their trade, a future for their children) and the player helps or doesn't.
- **Pressures and crises** - winters, shortages, deaths, departures, and other problems worth solving.
- **Neighbors and rivals** - other settlements and cultures to trade with, compete with, or absorb.
- **The player's own chosen ambition** - conquest, economic dominance, or cultural legacy.

## Pace

- **Slow and contemplative.** Long stretches of watching families live, occasional decisions, frequent pausing to inspect.
- **Fixed clock; the player controls speed.** One simulation calendar for the whole game, with pause and speed controls. Time does not automatically compress as scale grows.
- **Long-to-endless arc.** A full climb to nation and global structures should take a long time. The journey is the point.

## Failure

**Real but recoverable.** Families can leave, decline, or die, and a settlement can shrink badly. Collapse is rare and should be telegraphed. Mistakes cost time, people, and stories, but rarely the whole save.

## Culture

**Mostly emergent, with player nudges.** Values and culture grow from the conditions families live under: work, prosperity, shortages, layout, neighbors. The player can nudge them through priorities, institutions, festivals, laws, and which families or trades they favor.

## Implications For Current Work

These follow from the vision and should guide upcoming sprints:

1. **Culture must affect economics early.** Values are currently placeholders (`agrarian` / `industrial` / `neutral` preference). Real effects on output, preference, migration, and resilience belong in the village stage, not "much later."
2. **Recoverable failure needs failure states.** Today shortages only block growth. Families leaving, falling into hardship, and settlement decline need to exist.
3. **Family ambitions are a core system, not polish.** They are a main source of motivation in an open sandbox.
4. **Neighbors and rivals are in scope.** The inert neutral town should eventually become a living neighbor. Conflict and military are in scope for the long arc; population already counts as military potential.
5. **A world-scale map is required eventually.** The current regional map reads as one valley (see `docs/map_and_settlement_scale_audit.md`).
6. **A fixed clock has costs at scale.** At 6 minutes per game year at 1x, centuries of history need higher speed options later, and household-by-household simulation must give way to grouped simulation as the audit describes, or late-game ticks will be too slow.

## Open Questions

- Should the game recognize when a player achieves a chosen ambition (a chronicle entry, an epilogue), or stay silent?
- What do rivals look like early: other founding settlements, the neutral town waking up, or regional cultures?
- What is the first value or cultural trait that should have a real economic effect?
- How long, in game years, should the climb from founding to the first nation-level structure take?
