# Project Owner Questions

Use these questions before authorizing gameplay implementation. They protect the household-rooted civilization simulation direction and help keep local-agent tasks bounded.

## Core Loop

1. What should the player do repeatedly in the first playable version?
2. Is the first loop mainly survival, growth, trade balancing, household development, or exploration?
3. What creates failure or pressure in the first playable milestone?

## Household Model

4. What does one household represent in the prototype?
5. Should one household usually contain a family-sized population, such as 3-6 people?
6. Should household labor capacity represent only adult workers, total productive ability, or an abstract family contribution?
7. Should household values affect production immediately, or only later?

## Population And Labor

8. Should food consumption scale by population, household count, or both?
9. Should production scale by labor capacity, building capacity, household skill, tools, or a mixture?
10. Is the current 4 population to 1 labor-capacity ratio intentional, provisional, or wrong?
11. Should labor shortage feel like lack of workers, lack of capable households, poor tools, instability, or poor assignment?

## Player Control

12. Does the player directly assign households to work?
13. Does the player set priorities and allow households to choose?
14. Should households ever refuse, prefer, or perform poorly at assigned work?
15. Should visible walkers represent individuals or household activity?

## Settlement And Economy

16. What resources matter in the first milestone?
17. What shortage should the player feel first: food, housing, labor, maintenance, tools, or trade access?
18. Should trade be a manual player tool, an automatic city behavior, or both?
19. Should buildings be operated by specific households, generic labor pools, or city-level abstraction for now?

## Scaling

20. When should regions matter?
21. Should cities have distinct cultures before regional systems exist?
22. Should regional/state/nation behavior be postponed until household-city behavior is stable?

## Protected Systems

23. Which files are protected from local-agent edits?
24. Which systems are experimental and safe for agent edits?
25. Should `main.gd` be modularized now, or only after the core loop is clarified?

## Autonomy

26. What local-agent autonomy level is allowed right now?
27. Are overnight runs allowed at all?
28. What is the maximum branch scope and commit count per agent run?
29. What should cause the agent to stop immediately?

## Definition Of Done

30. What is the first playable milestone?
31. What would make the prototype obviously "on direction"?
32. What would make it obviously wrong?
