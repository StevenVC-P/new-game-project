# S9: The Market Day

## Implementation

- **Objective:** exchange between households (D2), so specialists can live by their trade, and private compacts get the path that S7 and S8 left open (owner's Track B guidance: low-contribution towns are judged here).
- **Built (`TownMarket`; under a compact only):**
  - **Market day, monthly** (month's end, before giving and grants). Each family:
    - **wants** winter fuel for 90 days, what its own sites still wait for, and twice a holding's upkeep in tools when it keeps that holding up;
    - **offers** whatever it holds beyond those (and beyond 60 days of food).
    - **Food is the medium:** a family wanting food gets it by selling.
  - **Prices in food:** a good's worth in grain (the trader's worths, plus the S7 worked goods), scaled by the town's demand against supply (square root of their ratio), between ×0.5 and ×2. So a town short of wood pays more for it, and a town of woodcutters gets little.
  - **Clearing, in aggregate, good by good** (in a fixed order):
    - buyers' wants are capped by the food they can pay beyond their keep;
    - what changes hands is the lesser of offered and wanted, shared in proportion among buyers and among sellers, in whole units;
    - buyers pay food, which the sellers share by what each sold;
    - food a seller earns can buy its next good the same day.
    - Nothing is created, lost or owed, and the goods stay in the one store; only whose they are changes.
  - **Values:**
    - Insular families bring a quarter less to market per point of strength (at least a quarter of it);
    - Hagglers' share of the food buyers pay weighs 10% more per point, at the other sellers' expense;
    - Fair Dealers take an even share.
  - **Any day (D2):** a family still short after the table, its larder and its neighbours sells what it holds beyond its own needs for food, eaten at once.
    - Buyers are families with food to spare, at the last market price; Insular families buy only from kin.
    - The hungry family gets something for its goods, unlike help.
  - **Wealth as a level:** its larder plus its own goods at their worth in food. Under a compact a family far above the town's middle (twice the median) reads as prosperous (`TownSocial.is_prosperous`), which the existing levelling and admiration read.
  - **Community page:** a read-only **Market day** card (what changed hands last month and at what price; sales on hungry days).
- **Not in S9, proposed for the owner:** families weighing what their work would fetch at market when they choose or change work (property doc §4.5, "see opportunities"). It would add a term to occupation scoring, the kind of change the owner asked to see before it is built.
- **Limits:**
  - food changes hands at market only as payment (nobody "buys" food with goods on market day; hungry families sell any day instead);
  - the larder is not traded, only goods in the store;
  - the trader from the neutral town still deals only in the community's goods.
- **Files:** `town_market.gd` (new), `town_commons.gd`, `household_migration.gd`, `town_social.gd`, `city.gd`, `household.gd`, `economy_balance.gd`, `community_page.gd`; `tests/sim/divergence_check.gd` (`market_units`, `market_emergency`, `wealth_by_trade`).

## Verification

- `tests/town_market_validation.gd`:
  - pooled holds no market;
  - food buys what a family lacks (the farm family buys winter wood, the woodcutting family gets food);
  - nothing made or lost, goods stay in the store, nobody falls below its keep;
  - prices fall where more is offered;
  - Insular brings less; Hagglers take more of a pool that is all paid out;
  - a hungry family sells tools for a day's food;
  - wealth and prosperity;
  - saves.
- **Neutrality:** pooled S9 against S6 on the matched towns: 45 lines identical. **Suite:** 57/57.
- **Smoke runs:** the same town as S8's (forested start 0, private compact, attentive player, 2 years; one town each, indicative only):

  | Build, commons | Families left | Departed | Family-days short | Hunger deaths | Goods sold at market |
  |---|---|---|---|---|---|
  | S8, no reserve | 5 | 1 | 844 | 3 | — |
  | S9, no reserve | 5 | 1 | 380 | 0 | 147 |
  | S8, 30 days, grants in need | 2 | 4 | 755 | 2 | — |
  | S9, 30 days, grants in need | 5 | 1 | 747 | 2 | 156 |

  - **Emergent market power, recorded and not tuned:** in both S9 towns the woodcutting family ends year 2 holding 740–1,000 food-worth while the farm families hold almost nothing. Winter wood is scarce and every family wants it, so its price sits high and the farm families spend their surplus beyond their 60 days on it.
- The S9 review-point comparisons (compacts across environments and founder sets), run on the build before S5b: `S9_review.md`.
