# UI Manual Retest Checklist

This checklist covers the current demand, soft-need, and UI readability systems. Use it for owner retests after the UI cleanup sprint and before merging or starting the next mechanics sprint.

## Setup / Test Conditions

- Start the project normally.
- Use a clean city or a known test city.
- Open the City Overview.
- Select at least one house with a resident household.
- Select at least one production building with an assigned household.
- If running scripted tests while the Godot editor is open, prefer explicit `.godot/*.log` paths because the live editor may hold the default user log path.

## City Overview: Need Pressure

Verify:

- Need Pressure appears after City Health.
- Food appears as an active hard consuming bucket.
- Household Goods appears as an active soft consuming bucket.
- Clothing appears as an active soft consuming bucket.
- Active rows are readable and do not truncate key values.
- Inactive readiness buckets remain compact and understandable.
- Available and demand values are readable.

Notes:

- Food, Household Goods, and Clothing should be easy to scan first.
- Inactive buckets should not look like urgent failures.

## Food Behavior

Verify:

- Food shows stable or met when supply covers demand.
- Food shows low or shortage when supply is insufficient.
- Food shortage action hints are readable.
- Food still behaves as the hard survival pressure.
- Food shortage can affect household prosperity as previously intended.

## Household Goods Behavior

Verify:

- Housed households contribute household goods demand.
- Temporary and unsheltered households do not create full home-life household goods demand.
- Stocked household goods can be consumed.
- Zero stock reports unmet.
- Partial supply reports low.
- Full supply reports met.
- Household goods hints are readable and concise.
- Household goods do not create survival penalties.

## Clothing Behavior

Verify:

- Clothing demand comes from total household population.
- Housed, temporary, and unsheltered households all contribute clothing pressure.
- Zero clothing stockpile reports unmet.
- Partial clothing stockpile reports low.
- Full clothing stockpile reports met.
- Stocked clothing is consumed without going negative.
- Clothing unmet alone does not make households struggling.
- No wool or textile production exists.
- No clothing production hint is spammed.

## Selected House / Household Panel

Verify:

- Family Demand section is readable.
- Food line shows population pressure.
- House Goods line uses concise wording such as `+1 home demand`.
- Clothing line uses concise wording such as `Clothing: N population`.
- Shelter line is readable.
- Prosperity / Household Status is readable.
- Reason line is concise.
- Lifecycle, lineage, and succession info remain readable if present.

## Selected Production Building Panel

Verify:

- Assigned household display remains readable.
- Workplace instability warning appears for temporary or unsheltered assigned households.
- Warning remains display-only.
- Production assignment remains valid.
- No output, cadence, maintenance, or labor behavior changes from this UI warning.

## Action Hints

Verify:

- Hints do not truncate important verbs or nouns.
- Food shortage hints are prioritized and readable.
- Shelter, labor, tool, and maintenance hints remain readable.
- Household goods hints are readable.
- Clothing does not produce an unsolvable textile-production hint.
- Hints are not noisy or spammy.

## Non-Regression Checks

Verify:

- UI does not consume resources.
- UI does not mutate city, household, or building state.
- Soft needs do not affect survival.
- Clothing does not affect prosperity.
- No household inventory exists.
- No markets, money, prices, credit, or debt exist.
- No textile production exists.
- Resources never go negative during normal ticking.

## Pass / Fail Notes

- Result: Passed / Failed / Needs cleanup
- Screenshot or reference:
- Notes:

## Sprint Closeout Reminder

After this checklist branch, run a full owner manual retest of the UI cleanup sprint before merging or starting the next sprint.
