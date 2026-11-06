# S8: The Commons and Asking for Help

## Implementation

- **Objective:** survival first under a compact. A family in danger turns to the commons and to the families it knows before hunger falls, and the player's rules decide how the commons answers (roadmap S8 card; owner's Track B guidance, 2026-11-05). Pooled towns are untouched.
- **Built (`TownCommons`):**
  - **The table's reserve (player):** none, or 30, 60 or 90 days of the town's food.
    - The community's food above the reserve feeds every family alike: with no reserve, exactly S7's table.
    - The reserve feeds only families in danger: in severe hunger or cold (S3b), or near leaving.
    - So a reserve protects the commons against a bad season at the cost of ordinary families' meals now, and the player sees both.
  - **Asking for help, any day (D2: the calendar never blocks it):** a family the table and its larder leave short asks the households it knows (ties, kin, neighbours), the warmest first.
    - Each with food beyond a month of its own eating decides by the existing share desire (`SocialDecisions.get_share_desire`): empathy, Charitable, Sharing, Mutual Aid against Acquisitive, Each to Their Own and Thrifty, its own margin, kinship and feeling, the help norm, and the town's wisdoms.
    - A giver gives from its share in the store, then its larder.
    - Once a month for each pair the help counts as the shortage's sharing does: a warmer tie both ways, standing and a memory. Daily help doesn't flood memories.
  - **Grants (player, monthly):** none, to families in need (short this month, in danger, or in need as `TownSocial` reads it), or to every family alike.
    - 25% of the community's food and wood beyond the reserve and two months of the town's need passes into the recipients' own goods.
    - Every other family judges each grant for fairness (`TownSocial.judge_distribution`, the existing favouritism and desert judgment).
  - **Community page, Shared resources:** a **The commons** card (compact towns only) with the reserve and grant buttons, how often hungry families asked and what was given, and what was granted.
- **Unchanged:** the monthly sharing in a shortage (`TownSocial.share_in_shortage`) still runs as before; daily asking comes first.
- **Limits:** only food is asked for (fuel help is not built); grants are food and wood only; commitments and offers (property doc Phase 3) are not in S8.
- **Files:** `town_commons.gd` (new), `household_economy.gd`, `household_migration.gd`, `city.gd`, `economy_balance.gd`, `community_page.gd`, `main.gd` (two action lines); `tests/sim/divergence_check.gd` (`--commons=days:rule`, measures).

## Verification

- `tests/town_commons_validation.gd`:
  - pooled is untouched;
  - with no reserve every family eats alike;
  - the reserve feeds only the family in danger;
  - a hungry family is fed by a neighbour who will give, counted once a month per pair, and the giver keeps its own month;
  - an acquisitive, each-to-their-own family that isn't kin gives nothing;
  - grants follow the rule and keep the town's two months and reserve;
  - saves.
- **Neutrality:** pooled S8 against S6 on the matched towns: 45 lines identical. **Suite:** 56/56 (before the danger fix below).
- **Defect found by the first smoke run, fixed:** danger was read only from hardship and severe months, which are counted monthly. A family could go from below the departure warning straight to leaving in one month without ever counting as in danger, while the reserve held food.
  - Danger now also includes a family short on 5 days this month (`DANGER_SHORT_DAYS`), before the month's hardship falls at 10.
- **Smoke runs:** forested start 0, private compact, attentive player, 2 years (one town each, indicative only):

  | Commons | Families left | Departed | Hunger deaths | Family-days short | Short while the commons held food |
  |---|---|---|---|---|---|
  | no reserve, no grants | 5 | 1 | 3 | 844 | 595 |
  | 30 days, grants to those in need | 2 | 4 | 2 | 755 | 544 |

  - **Traced** (`tests/sim/compact_trace.gd --commons=30:in_need`):
    - with a reserve larger than the commons holds, the table feeds only families in danger, so every family goes short 5 days a month first;
    - a private community gets 20% of the farms' food, so the founding stock runs out by month 3, and the families without farms go hungry;
    - later the farm families hold hundreds of days of their own food, while the woodcutter and quarry families hold none and live on the reserve and their neighbours;
    - year 2's departures follow cold (13–21 cold days a month): the woodcutter family keeps 80% of the wood, and asking for fuel is not built (a limit above).
  - That is the player's reserve doing what it says, and the private compact's dependence on exchange, which S9 is for. The commons card now warns when the commons holds no more than the reserve.

## Measures (tracked, not yet judged)

Under a compact each divergence town also reports:
- `short_beside_commons`: hungry family-days while the commons held food;
- `short_beside_spare`: hungry family-days while some family had food to spare;
- `help_asked` and `help_given`;
- `granted`.

These are the S8 card's "deaths and departures where goods existed", measured as the hunger that leads to them.
