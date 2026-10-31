# Town Interface

The town view's interface after the redesign of 2026-10-30 (owner brief: make the household simulation understandable without hiding it). The map stays the centre; a top bar says where and when; a sidebar with four pages answers what is happening, why, what families are doing and why, and what the player can do about it.

## Layout

- **Top bar:** Back, the town and its stage, the date, the clock (the active button is the state: "Paused", 1x, 3x, 10x), the town's status chips (people, food in days, free homes, labor; alerts while they matter), Menu. Groups are divided by thin rules; the old "Speed:" label is gone because the buttons say it.
- **Map:** unchanged: pan, zoom, select, place. Selecting a house still opens its card on the map, now short; the family's details open in the sidebar.
- **Sidebar:** docked right, a fifth of the window between 320 and 400 pixels (384 at 1920x1080, 320 at 1366x768). Tabs at the top, a scrolling page (wheel, or drag the thin bar), and a footer: the tool in hand (what, cost, whether the ground under the cursor takes it, Stop and Catalog buttons) or, with no tool, the ground under the cursor in words.

## Pages

| Page | Answers | Reads |
|---|---|---|
| **Overview** (default) | Is the town all right? What needs me? What is everyone doing? | `SettlementStage`, `City.get_pressure_summary` and `get_need_pressure_summary`, `TownDefense`, `TownTrade`, `TownConstruction`, households' `initiative_note`/`social_note`, notices from land, ambitions, trade, defense |
| **Families** | Who are they, what are they doing, what do they want, and why did they decide that? | `FamilyAmbitions`, `FamilyInitiative` (holding, notes, `predict_improvement`), `HouseholdRosterHelper.get_card_lines`, `HouseholdCharacter`, `HouseholdMigration`, lifecycle helper |
| **Planning** | Where may things go, what can the community pay for, what is being built? | `HomeSites` (residential land, room, families waiting), `BuildMenuHelper` catalog, `EconomyBalance.get_build_cost`, `TownConstruction.can_supply`, plots, marked woods and fields, work ground |
| **Community** | How do I lead families who decide for themselves? | `CommunityPriority` (families' views, backing, warnings, decisions tipped), `TownInfluence` (priority, stores rule, reserve, counters), `TownSocial` (norms, incentive, honours, voices, trust, disputes) |

- **Overview:** the stage card (what still stands between this stage and the next); status rows for food, shelter, work, tools, upkeep, wanted goods, building, newcomers, each with a word and a glyph; **Needs attention**, cards sorted most pressing first, each with the cause in words and a suggested action that is a real tool or appeal (hunger, bandits, families leaving, a trader's lots, housing and plots, falling food, tools, upkeep, empty workplaces, quarrels over land, clothing); **Current activity** (sites, recent completions, recent family decisions grouped when alike, notices); collapsed **Stores and figures** (every stock, every pressure's raw detail, every need bucket, shelter counts) and **Chronicle**.
- **Families:** families in trouble first, then by arrival. A card: calling and what it does today, its home (and, while it has no site, why it cannot build), what it wants or that it is content, temperament, and the last decision in its own words. Clicking a card (or selecting its house on the map) opens it: the decision with its date, why it chose its home site, how it would answer investment being put first and how it takes the current priority, with reasons, temperament, convictions, standing and trust, ties, memories, value changes, lifecycle; buttons to show it on the map and to honour it.
- **Planning:** **Designate** (residential land while families lead: set aside, preferred, clear; home plots, work ground while families lead, clear woods, till land), **Commission** (the catalog by category with cost, shortcut, and a dot when the stores can supply it now or a triangle when it waits for materials), **Encourage** (a pointer to Community), **Underway** (every site, who asked, who pays), and the keyboard shortcuts.
- **Community:** **Community priority** (one of no priority, food security, permanent housing, productive investment, cooperation, with what it asks; how many times the community changed its mind lately; the warnings for it under the current stores rule; how the town takes it: backing, who supports, does not mind or opposes, and the decisions it has tipped; each family's stance with its reasons; how the town would take each of the others; asks left from a town saved under the four work asks), **Shared resources** (the stores rule as two choices, what is always kept back, how often it held a family back), **Social expectations** (helping neighbours, respecting claims: status and acceptance), **Recognition and incentives** (reward helping; honour the selected family in four kinds), **The gathering** (respected voices, trust, how often the community changed its mind). Under the classic rules the page says how to let families lead.

## Information Levels

1. **Immediate:** top bar chips, the Overview's status rows and attention cards.
2. **Contextual:** the Families card in focus, the Planning catalog and footer, the map's building cards.
3. **Advanced:** the collapsed sections ("Stores and figures", "Chronicle", "How each family sees it", "How the town would take the others", "Keyboard shortcuts"), status tooltips in the top bar, and the developer panels F4 (town pressures) and F3 (household inspector), unchanged.

Status is never colour alone: good is a dot, caution a triangle, alert a diamond, information a ring, neutral a dash, and the words say it too. Toggles show a ticked box.

## Components

All in `scripts/ui/town_sidebar/`:

- `town_sidebar.gd` (`TownSidebar`, a clipped `Control` under `main.gd`, drawn below main.gd's own drawing so tooltips and popups stay on top): tabs, scroll, open sections, the family in focus, the footer. `main.gd` calls `update(context, footer)` each frame, forwards mouse buttons and motion, and carries out the action a click returns (`apply_city_action`). The panel handles its own actions (page, sections, focus).
- `*_page.gd` (`SidebarOverviewPage`, `SidebarFamiliesPage`, `SidebarPlanningPage`, `SidebarCommunityPage`): `static func build(context) -> Array` of plain blocks. Pages read the town and never change it (tested), caches included: the Community page works the backing out afresh rather than through `get_town_backing`, whose weekly cache families act on.
- `sidebar_painter.gd` (`SidebarPainter`): lays blocks out into drawing primitives once and draws them each frame; block kinds are listed at the top of the file.

Pages are rebuilt when the day changes, after a click, and otherwise twice a second, not every frame (a family's outlook prediction is a full desire evaluation).

**Growing with the settlement:** a new page is a script with `build` and a line in `TownSidebar.TABS`. Later stages are expected to add pages (districts, institutions, regional view) and to aggregate the Families page (by lineage, House, or district) once a town has more families than a list reads well; the components need no change for either.

## Decisions And Judgment Calls (open to veto)

- **L opens the Families page** (and back) instead of the roster overlay over the map; **Tab / Shift+Tab** change pages. Every other key is unchanged; `tests/town_sidebar_validation.gd` presses each shortcut the Planning page lists.
- **The house card on the map is short** (temperament and a pointer to Families); its social lines moved to the sidebar, which opens on the family whose house is selected.
- **A click on the sidebar no longer clears the map's selection**; Esc and right click still do.
- **Nothing in hand at the start** (2026-10-31): the game used to open with the House tool picked up, so a stray click on the town planned a house; now the player picks a tool first.
- **Short priority and land buttons** ("Food", "Housing", "Mark", "Prefer"): the full names did not fit the 320-pixel sidebar; the card's tag and text give them in full.
- **Food in the top bar** as days at today's rate, coloured by the town's own food pressure.
- **Status words** follow the simulation's own pressure states (food "Growing / Steady / Declining / Run out" from `get_food_pressure`); no new thresholds were invented for the interface.
- **Trading and the militia** moved into Needs attention, because both are time-bound decisions; the militia key (M) is unchanged.

## Missing Simulation Data

What the interface would show if the simulation recorded it:

- **Family names.** Households are "Household N"; there are no surnames or House names yet.
- **A history of decisions.** Each family keeps only its latest initiative note and social note; a log would let the Families page show how its choices changed.
- **Who answered an appeal.** The priority counts the decisions it tipped by kind (improvements, help, long days) and a family remembers its first sacrifice in a while, but a family's choice of work is not counted as swayed, and norms keep only acceptance; results are mostly aggregate.
- **Current intention outside the influence model.** Under the classic rules families record no decisions, and families' wants are limited to the three ambitions.
- **Town events.** Beyond the chronicle's firsts and recent completions, there is no event log (arrivals, departures by name, quarrels settled), so Current activity draws on notes and notices.
- **A food forecast.** Days of food is today's stock over today's consumption; the season's harvest to come is not projected.

## Remaining Work

1. Owner playtest of the layout and wording, especially Needs attention's choices and the Families page's length.
2. Hover tooltips inside the sidebar (status rows explaining their figures without opening Stores and figures).
3. A statistics view with history (resource trends over seasons) for Level 3.
4. Selected workplaces and sites in the sidebar beside the map card, so the card can shrink further.
5. Filters and grouping on the Families page for large towns.
6. Interface scale for small or very large windows, and keyboard navigation inside the sidebar.
