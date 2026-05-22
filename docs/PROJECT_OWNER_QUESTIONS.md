# Project Owner Questions And Answers

These answers are authoritative product direction for bounded local-agent work. They protect the household-rooted civilization simulation direction and should be consulted before gameplay implementation.

## Core Loop

1. What should the player do repeatedly in the first playable version?

The player should grow and stabilize a small settlement by placing housing and production buildings, assigning household responsibilities, managing food/housing/resource pressure, and using trade or expansion to relieve shortages.

2. Is the first loop mainly survival, growth, trade balancing, household development, or exploration?

The first loop is survival and growth, with trade as a support system. Household development is the long-term identity of the game, but the early prototype should prove that households can drive city growth without requiring full generational simulation yet.

3. What creates failure or pressure in the first playable milestone?

The first pressure should come from food shortage, housing shortage, maintenance/resource shortage, and not enough households to cover responsibilities. The city should feel strained because it lacks stable households assigned to the right responsibilities, not because generic worker points are low.

## Household Model

4. What does one household represent in the prototype?

One household represents one family or family-like social/economic unit. It is the basic unit of population, assignment, consumption, growth, and long-term cultural continuity.

5. Should one household usually contain a family-sized population, such as 3-6 people?

Yes. A household should usually represent a small family-sized population, probably around 3-6 people, though the exact number can fluctuate by household age/stage.

6. Should household labor capacity represent only adult workers, total productive ability, or an abstract family contribution?

For now, household labor capacity should represent one assignable household responsibility. It should usually stay at baseline 1. That 1 does not mean one adult worker; it means the household can be primarily responsible for one work role, building, plot, route, or civic function.

7. Should household values affect production immediately, or only later?

Later. In the first milestone, values can exist as data or placeholder traits, but they should not be required for the first playable loop. The first milestone should prove households, population, food, housing, production, and assignment pressure.

## Population And Labor

8. Should food consumption scale by population, household count, or both?

Food consumption should scale primarily by population. Household count can matter for storage, housing, and assignment structure, but mouths-to-feed should be population-based.

9. Should production scale by labor capacity, building capacity, household skill, tools, or a mixture?

For now, production should come from assigned household responsibility plus building/resource rules. Later, production can include assignment, household traits, assignment fit, tools, building quality, local conditions, and season. Household maturity or age stage should not directly equal production quality unless a specific trait or condition justifies it.

10. Is the current 4 population to 1 labor-capacity ratio intentional, provisional, or wrong?

It is acceptable as a provisional baseline if correctly interpreted: 1 household is several people, and 1 household is 1 primary responsibility unit. It should not mean 4 population equals 1 worker.

11. Should labor shortage feel like lack of workers, lack of capable households, poor tools, instability, or poor assignment?

In the first milestone, labor shortage should feel like not enough households to cover all responsibilities. Later, labor inefficiency can come from poor assignment fit, bad tools, household instability, illness, low prosperity, cultural reluctance, and seasonal pressure.

## Player Control

12. Does the player directly assign households to work?

For the prototype, yes. The player can assign households to responsibilities directly because that makes the model legible. Long term, this can evolve into priorities, incentives, household preferences, and partial autonomy.

13. Does the player set priorities and allow households to choose?

Eventually yes, but not required first. Recommended staging: direct assignment, then assignment with fit/preference indicators, then player priorities plus household choice/resistance.

14. Should households ever refuse, prefer, or perform poorly at assigned work?

Eventually yes. In the first milestone, performing poorly is enough; refusal can wait. Early behavior can show the wrong household for a role through lower efficiency or warnings. Later behavior can include refusal, migration, instability, or social pressure.

15. Should visible walkers represent individuals or household activity?

Visible walkers should represent household activity, not fully simulated individuals. The simulation unit remains the household. Individuals can become expressive later, but the economy should not depend on individually simulated citizens.

## Settlement And Economy

16. What resources matter in the first milestone?

Start with food, wood, stone or building material, housing capacity, maintenance/upkeep, and possibly wealth/goods later. Do not overbuild the economy before the household assignment loop is clear.

17. What shortage should the player feel first: food, housing, labor, maintenance, tools, or trade access?

First: food, housing, and household responsibility coverage. Second: maintenance and wood/building materials. Later: tools, trade access, specialized goods, and social/cultural pressure.

18. Should trade be a manual player tool, an automatic city behavior, or both?

Both eventually. For now, trade can be manual or semi-manual so the player understands cause and effect. Long term, the player establishes routes/priorities, cities/households generate trade pressure, and trade behavior emerges from shortages and surplus.

19. Should buildings be operated by specific households, generic labor pools, or city-level abstraction for now?

Buildings should be operated by specific households or household responsibility assignments, not generic labor pools. Temporary city-level abstraction is acceptable only when it does not erase the household model.

## Scaling

20. When should regions matter?

Regions should matter after the city/household loop is stable. Do not build complex regional systems until one settlement clearly shows households -> assignments -> production/consumption -> growth/shortage.

21. Should cities have distinct cultures before regional systems exist?

Not fully. Cities can begin accumulating simple cultural tendencies from household composition, but full culture systems should wait. Early placeholders can include dominant household values, settlement tendencies, industry identity, and migration pressure.

22. Should regional/state/nation behavior be postponed until household-city behavior is stable?

Yes. Higher-level systems should inherit from lower-level behavior. Do not let regional systems invent culture/economy without household roots.

## Protected Systems

23. Which files are protected from local-agent edits?

Protected unless explicitly scoped: `main.gd`, `main.tscn`, `project.godot`, `household.gd`, `city.gd`, calendar/time progression, production/resource formulas, trade behavior, map generation algorithms, and save/load if present. The local agent may inspect and document these, but should not alter them without a very specific task.

24. Which systems are experimental and safe for agent edits?

Safe areas: `docs/`, `tasks/`, isolated demo scenes, test scenes, read-only debug displays, non-invasive UI labels/tooltips, proof-of-work reports, and architecture notes.

25. Should `main.gd` be modularized now, or only after the core loop is clarified?

Only after the core loop is clarified. `main.gd` is already large and high-risk, so it should not be refactored casually.

## Autonomy

26. What local-agent autonomy level is allowed right now?

For now: documentation-only, isolated demo/test scenes, and small additive non-gameplay tasks. No autonomous gameplay logic changes yet.

27. Are overnight runs allowed at all?

Yes, but only for documentation-only tasks or one isolated demo/test scene. Use one branch, one commit, validation required, and stop on ambiguity or failure.

28. What is the maximum branch scope and commit count per agent run?

For now: one branch, one task, one commit.

29. What should cause the agent to stop immediately?

Stop if validation fails, a protected file must be changed, the task requires a product/design decision, the task requires renaming/deleting files, the task requires changing `main.tscn` or `project.godot`, the implementation would reinterpret households as generic worker slots, or the agent is unsure whether a change is in scope.

## Definition Of Done

30. What is the first playable milestone?

A small settlement simulation where the player can place or expand housing, create/assign production responsibilities, see household count and city population, see food consumption pressure, see housing pressure, see household responsibility coverage, see basic resource production, and survive/grow for a short calendar period.

31. What would make the prototype obviously "on direction"?

It is on direction if the player thinks, "I am shaping a settlement made of families/households," not "I am assigning generic workers to buildings." On-direction signs: households are visible in the model, population comes from households, households consume food, households hold responsibilities, settlement growth depends on household formation/migration/housing, and shortages affect household stability and growth.

32. What would make it obviously wrong?

It is wrong if houses become worker-slot generators, population becomes directly assignable labor, household traits are only flavor text, cities behave independently from households, regional systems ignore city/household roots, or labor becomes generic mana.
