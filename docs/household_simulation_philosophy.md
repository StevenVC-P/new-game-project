# Household Simulation Philosophy

This project is not a city builder about anonymous worker slots. It is a civilization simulation where households are the basic social, economic, and cultural unit.

A house is not simply population storage, and it is not just worker capacity. A house anchors a productive family or social unit. The household is the place where labor, values, survival pressure, prosperity, and cultural continuity meet.

## Core Idea

Households are the DNA of society.

Households shape labor behavior. Labor behavior shapes the economy. Economic pressure shapes settlement structure. Settlement structure shapes culture. Culture shapes politics, expansion, conflict, and long-term civilization identity.

The long-term goal is to show how lived values and household conditions affect economies, and how those effects scale up into regional and eventually world-shaping patterns.

## Population And Labor

Population should not equal workers.

Population represents mouths to feed, shelter demand, demographics, family size, future growth, military potential, and cultural continuity.

Labor should emerge from household capability. Labor capacity should represent the household's real productive ability, eventually influenced by:

- working adults
- adolescents and helpers
- dependents
- elders
- health
- tools
- values
- prosperity
- season
- household stability
- cultural expectations

Prototype versions can use abstract values, but the intended direction is:

```text
household structure -> effective labor capacity
```

not:

```text
house = fixed worker slot
population = raw workers
```

## Households As Productive Cultural Organisms

A household should eventually:

- consume resources
- produce or contribute labor
- reproduce and raise children
- pass on values
- accumulate wealth or fall into hardship
- prefer certain work types
- migrate or stay based on pressure
- become more or less stable over time

Values should not be flavor text. Values should influence real outcomes, including:

- productivity
- resilience
- fertility and family size
- migration willingness
- risk tolerance
- preferred industries
- reaction to shortages
- willingness to fight
- openness to trade or innovation
- social instability
- regional identity over generations

## Design Target

The long-term design target combines:

- Manor Lords-style grounded settlement economy
- Dwarf Fortress-style values, personality, and emergent culture
- regional, state, and nation scaling where local household behavior aggregates upward

Individuals may appear as walkers or expressive city life, but households are the main economic and social simulation unit.

## Scaling Principle

Simulate households deeply enough to create meaningful behavior. Represent individuals expressively, but do not require every visible citizen to be a full economic simulation entity.

Layering should work like this:

```text
Individuals express households.
Households aggregate into cities.
Cities aggregate into regions.
Regions aggregate into states.
States aggregate into nations.
```

Each higher layer should inherit patterns from lower layers instead of inventing behavior independently.

## Player Agency

The player should not simply assign anonymous labor tokens. The player guides a living society by:

- shaping settlement layout
- assigning or encouraging household labor
- supporting industries
- managing shortages
- deciding what gets priority
- creating conditions where certain values and household types thrive

The player does not control everything. They influence conditions and priorities.

Assignments can exist, but they should connect to households, their values, their capacity, and their lived situation.

## Important Distinction

Avoid designing labor only as a scarce strategic abstraction like generic worker points or mana.

Labor should represent household capability. If a system needs a worker number, that number should usually be derived from household state rather than attached directly to a house or raw population total.

## Current Known Tension

The latest household and labor refactor exposed a mismatch:

- one household currently represents about 4 population
- each household currently provides only 1 labor capacity
- food consumption scales by population
- production scales by labor capacity

That mismatch is useful because it shows where the prototype still needs a clearer answer to what a household represents and how much productive capacity a household should realistically provide.

Do not solve this by reverting houses to raw worker slots. Future work should evaluate the code against this philosophy and redesign formulas so households remain meaningful social units.

## Acceptable Prototype Simplifications

Short-term abstractions are acceptable when they point in the right direction:

- a household may have a single abstract preference
- a household may have a simple labor capacity value
- visible walkers may represent household activity rather than individual people
- production can remain simple while the model is being shaped
- city-level resources can stand in for household inventories temporarily

These shortcuts are dangerous if they become permanent design anchors:

- houses directly granting generic workers
- population being assignable as raw labor
- household values affecting only text or colors
- city behavior ignoring household behavior
- higher-level regional systems inventing culture/economy without household roots
- tuning numbers to hide conceptual mismatches instead of clarifying the model

## Agent Implementation Warning

Local agents may be used for real implementation work when explicitly assigned bounded objectives.

Feature branches and checkpoint commits are required for reviewable progress.

Agents must not reinterpret the game as a conventional worker-slot city builder.

Baseline household labor capacity is one responsibility unit by default. Household population is demographic weight, consumption pressure, growth potential, and family continuity, not directly assignable labor.

Household maturity means age/stage, such as young, middle, and old, and should mainly affect family growth, dependents, succession, and new household formation.

Formula changes involving household population, labor capacity, food consumption, production, reproduction, values, migration, prosperity, or maturity are product-design changes unless explicitly scoped.

Short-term abstraction is acceptable only when it points toward household-derived behavior.
