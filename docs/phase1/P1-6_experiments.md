# P1-6: Experiments X1 and X4

## X4: cultural transmission

`tests/sim/culture_transmission_model.gd` is a standalone model using the game's own value catalog (87 values in 12 categories) and its inheritance (`CultureValues.inherit_profile`). It runs 70 generations at 200 and 2,000 families, with 3 seeds per rule. Each generation:
- families marry assortatively (the best match of 4 by shared values);
- they have Poisson children, with three randomly chosen values giving 15% more surviving children each (the economy's selection, abstracted);
- 2% of the next generation are migrants with random profiles.

Rules compared:
- **current:** the game today, each value of either parent kept at 80%;
- **shared_persists:** a value both parents hold kept at 95%, one only one holds at 60%;
- **lineage:** the lineage parent's values kept at 90%, the other parent's at 30%.

| Rule | Families | Generation | Parent pairs a child keeps | Children keeping the parent's 3 defining values | Values present (of 87) | Families holding a favoured value |
|---|---|---|---|---|---|---|
| current | 200 | 1 / 20 / 70 | 0.55 / 0.51 / 0.61 | 0.36 / 0.25 / 0.29 | 87 / 86 / 80 | 0.55 / 0.88 / 0.97 |
| current | 2,000 | 1 / 20 / 70 | 0.54 / 0.45 / 0.50 | 0.34 / 0.18 / 0.19 | 87 / 87 / 87 | 0.61 / 0.88 / 0.94 |
| shared_persists | 200 | 1 / 20 / 70 | 0.45 / 0.59 / 0.98 | 0.28 / 0.20 / 0.95 | 87 / 83 / **65** | 0.50 / 0.92 / 0.98 |
| shared_persists | 2,000 | 1 / 20 / 70 | 0.44 / 0.48 / 0.96 | 0.23 / 0.18 / 0.82 | 87 / 87 / 87 | 0.56 / 0.96 / 0.99 |
| lineage | 200 | 1 / 20 / 70 | 0.78 / 0.78 / 0.86 | 0.66 / 0.59 / 0.62 | 87 / 86 / 77 | 0.49 / 0.94 / 0.98 |
| lineage | 2,000 | 1 / 20 / 70 | 0.78 / 0.75 / 0.78 | 0.66 / 0.56 / 0.55 | 87 / 87 / 87 | 0.56 / 0.95 / 0.98 |

**What it shows:**
1. **No whole combination survives,** under any rule: with 18–23 values a family, the founding combinations are all gone by generation 5. "How intact combinations stay" has to be measured by pairs and by a family's defining values, not by whole combinations.
2. **The current rule loses a family's identity in a generation.** A child keeps about half of its parent's pairs and only a fifth to a third keeps the parent's three defining values. Families also fill up: the union of two parents' values pushes them to 22.9 values, near every category's cap of two. Value inheritance today doesn't make lineages recognisable.
3. **Strong persistence of shared values homogenizes.** Fidelity looks high late on (0.96–0.98) only because the culture has collapsed: a 200-family town falls from 87 values to 65. This is the guardrail's "rare combinations discarded" risk.
4. **Lineage-weighted inheritance keeps both identity and variety.** Children keep 75–86% of the lineage parent's pairs and 55–66% its defining values, steady for 70 generations, while the culture keeps 77–87 values.
5. **Selection is fast under every rule.** A 15% advantage carries the favoured values from about half the families to over 90% within 20–40 generations, as the Scale Brief warned (40–70 generations in a 300–500 year game). Whether the game's real advantages are this strong is for Phase 3's matched runs to show. The model's 15% is an assumption, not a measurement.

**For Phase 3** (decided from evidence, behind switches): lineage-weighted inheritance is the candidate to build first, with the current rule kept as the comparison. The other parent's share (30% here) and the strength of shared-value persistence are the settings to test in matched runs.

## X1: today's limits and map fill

The divergence check (`--every-year`) on P1-1's land: balanced, fertile valley and forested, 3 starts each, 25 years, ordinary, no player.

| Year | Towns alive (of 9) | Largest towns (households / people) | Share of ground in use |
|---|---|---|---|
| 1 | 9 | 7 / 22 | 2–3% |
| 5 | 4 | 13 / 52 | 2–4% |
| 10 | 4 | 24 / 83 | up to 9% |
| 15 | 3 | **25** / 114 | up to 11% |
| 25 | 3 | **25** / 97, **25** / 93, 9 / 43 | up to 14% |

- **Most unattended towns fail early.** 5 of 9 were empty by year 5 and 6 by year 15, and none failed after that.
- **The survivors stop at 25 households** with 86–90% of their ground unused. The limit isn't land or food; it's homes.
  - A new family forms only into an empty house (`City.advance_new_family_formation_month`).
  - Families build homes only on land set aside for them.
  - Only the player marks that land, and the starting land is modest by design (owner, 2026-10-31).
  - With no player, every town stops there, and no card said so until Player Agency B added "Young families have no home to start in".
- **Arrivals are few:** a median of 1 household in 25 years.
- **Cost at 25 households:** the mean day is 11–480 ms by town, with the larger towns dearest.
- The household ceiling found by the scale check (S19, about a thousand households) is never reached by today's game. The home-land limit comes first.
