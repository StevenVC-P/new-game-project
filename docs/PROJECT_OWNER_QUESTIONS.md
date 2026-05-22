# Project Owner Questions And Answers

These answers are authoritative product direction for bounded local-agent work. They protect the household-rooted civilization simulation direction and should be consulted before gameplay implementation.

## Core Loop

The first playable loop should be survival plus growth. The player supports a small settlement by placing housing and production, assigning household responsibilities, managing food/housing/resource pressure, and using trade or expansion to relieve shortages.

## Household Model

One household represents a family or family-like social/economic unit. It usually represents several people, such as 3-6, with population fluctuating by household age/stage.

## Labor Model

Baseline labor capacity should stay at 1 per household. That means one household responsibility unit, not one adult worker and not population converted into labor.

A household can be assigned one primary responsibility such as farming, construction, maintenance, trade, militia, craft production, or civic support.

## Maturity

Household maturity means age/stage: young, middle, old. It should eventually affect fertility, dependents, succession, and when children form new households. It should not automatically mean higher productivity.

## Population

Population should primarily drive food consumption, housing pressure, settlement size estimate, demographic growth, future household formation, and long-term civic/military potential. Population should not be directly assignable as raw labor.

## Production

For now, production can scale from assigned household responsibility plus building/resource rules.

Later, effectiveness may be modified by traits, assignment fit, tools, building quality, stability, prosperity, health, values, season, and local resource access.

## 4 Population To 1 Labor

The current ratio is acceptable as a provisional baseline if interpreted as one household of several people taking one primary responsibility. It should not be treated as 4 population equals 1 worker.

## Player Control

For the prototype, the player may directly assign households to responsibilities. Later, the model can evolve toward priorities, preferences, household choice, poor fit penalties, and possible refusal or migration pressure.

## Visible Walkers

Visible walkers should represent household activity rather than fully simulated individual economic agents.

## Settlement And Economy

Start with food, wood, stone or building material, housing capacity, maintenance/upkeep, and possibly wealth/goods later.

First shortages should be food, housing, and household responsibility coverage. Maintenance and wood/building materials come next. Tools, trade access, specialized goods, and social/cultural pressure can come later.

Trade can be manual or semi-manual in the prototype so the player understands cause and effect. Long term, trade should emerge from city/household shortages, surplus, routes, and priorities.

Buildings should be operated by specific households or household responsibility assignments, not generic labor pools. Temporary city-level abstraction is acceptable only when it does not erase the household model.

## Scaling

Regions should matter after the city/household loop is stable. Higher-level systems should inherit from lower-level behavior. Do not build complex regional/state/nation systems until one settlement clearly shows households -> assignments -> production/consumption -> growth/shortage.

## Protected Systems

Protected unless explicitly scoped:

- `main.gd`
- `main.tscn`
- `project.godot`
- `household.gd`
- `city.gd`
- Calendar/time progression
- Production/resource formulas
- Trade behavior
- Map generation algorithms
- Save/load if present

The local agent may inspect and document these, but should not alter them without a very specific task.

## Safe Agent Areas

Safe when scoped:

- `docs`
- `tasks`
- Isolated demo scenes
- Test scenes
- Read-only debug displays
- Non-invasive UI labels/tooltips
- Proof-of-work reports
- Architecture notes

## Autonomy

Real implementation is allowed when explicitly assigned. The local agent may make code, scene, UI, test, and documentation changes on feature branches.

Long-running sessions are acceptable if the task is bounded and checkpointed. The agent must never merge to `main` or work directly on `main`.

Every meaningful version should be committed so the owner can review, revert, compare, or redirect.

For now, each run should have one named branch, explicit scope, validation, checkpoint cadence, and clear stop conditions.

## Definition Of Done

The first playable milestone is a small settlement simulation where the player can place or expand housing, assign household responsibilities, see household count and city population, see food consumption pressure, see housing pressure, see responsibility coverage, see basic resource production, and survive/grow for a short calendar period.

## On Direction

The prototype is on direction if it feels like shaping a settlement made of households and families.

Good signs:

- Households are visible in the model.
- Population comes from households.
- Households consume food.
- Households hold responsibilities.
- Settlement growth depends on household formation, migration, and housing.
- Shortages affect household stability and growth.

## Wrong Direction

The prototype is wrong if houses become worker-slot generators, population becomes directly assignable labor, household traits become only flavor text, cities behave independently from households, regional systems ignore city/household roots, or labor becomes generic mana.
