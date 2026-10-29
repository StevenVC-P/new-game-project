# Household Social Model

How families think, relate, and change, and how the player shapes their conduct. **Owner design directive, 2026-10-28: approved design direction.** **Owner review of the prototype, 2026-10-28: the direction approved, with four decisions and further verification (Owner Review, below).** It sits under `docs/GAME_VISION.md` (which wins on any conflict) and extends `docs/CULTURE_AND_VALUES_MODEL.md` (the twelve value categories), `docs/FAMILY_INFLUENCE_PROTOTYPE.md` (families developing their own work), and `docs/household_simulation_philosophy.md`. Where this document and an older model disagree, this one supersedes it only where it says so (Superseded Decisions, below).

**The game in one line:** a civilization simulation in which the player shapes the behavior, institutions, and culture of an autonomous population. The player decides what behavior to encourage, reward, discourage, and eventually require, and watches families respond according to their personalities, values, circumstances, and relationships.

## 1. Architecture (Nonnegotiable)

- **One household, one will.** A household (about 3-6 people) is one agent: one personality, one set of values, ambitions, circumstances, relationships, memories, and one decision process. No individual family-member minds. New households derive their character from their originating households, local culture, and the conditions they formed in. Births, aging, illness, and deaths are aggregate demographic events.
- **Built for populations in the millions.** Small settlements simulate named households in detail; larger towns aggregate some social activity; cities represent distributions; civilizations emerge from regional patterns. The aggregation system is not built now, but every rule here must be expressible over a distribution of household profiles: decisions are functions of a profile and a context, never of "every household looking at every other".
- **Personality, values, circumstances, behavior are separate.** Personality is how a household approaches decisions (stable). Values are what it believes matters (more changeable). Circumstances are what it is living through (fast). Behavior is what it decides, from competing reasons. No trait maps to an action by lookup.

## 2. Personality

Seven axes, signed integers -2 to +2; 0 is balanced. Neither end is good or bad. A relevant trait contributes about ±1-2 to a decision's desire. Personality is used in decisions, reactions, relationships, and interpretation, **never as a production bonus**.

| Axis | -2 | +2 | Typical pulls |
| --- | --- | --- | --- |
| Risk tolerance | Cautious | Daring | ventures, reserves, untried methods |
| Ambition | Content | Aspiring | improving, new holdings, honor |
| Sociability | Private | Outgoing | helping, organizing, conformity |
| Diligence | Leisure-oriented | Industrious | long days, volunteering, extra projects (never output) |
| Openness | Familiarity-seeking | Experimental | unfamiliar techniques |
| Empathic sensitivity | Detached | Attuned | sharing, sheltering, impartiality |
| Assertiveness | Accommodating | Forceful | pressing claims, yielding |

**Migration.** The values *industrious/leisurely* and *cautious/daring* move to diligence and risk tolerance: a household holding one starts with that axis at ±1 or ±2, and decisions read the axis, not the value. Convictions such as communal labor, traditional authority, independence, and respect for holdings stay values.

**Change.** Stable through ordinary play; only major, repeated experiences move it, rarely. Not built in the prototype.

## 3. Values With Strength

The twelve categories stay. Each held value has a strength: **0 not held, 1 mild preference, 2 strong conviction, 3 defining conviction.** A household typically has 3-5 strong convictions across its profile and 1-2 defining ones (targets, not caps). Strength separates background preferences from convictions that drive behavior.

- Values act mainly on decisions and reactions. Their existing effects on output (5-15%, capped at ±30%) are unchanged and separate from desire weights, **except industrious and leisurely, whose ±10% is removed (owner decision 1)**: diligence decides how much a family chooses to work, not what its work yields.
- **Conduct values** added to existing categories: *honesty, negotiation, forgiveness, vindication* (Conflict and Honor; forgiveness and vindication oppose); *respect for holdings, stewardship* (Home and Place); *mutual aid* (Community). They are assigned to households when the social model is on; they never enter the original random draw, so existing towns, seeds, and balance runs are unchanged.
- **Household independence** reads as self-governing (Authority), solitary (Work Ethic), and private holdings (Wealth).
- **Emotions are not values.** Envy, gratitude, and grudges arise from experiences and live in relationships and memories, not in the profile. A strong conviction can lead a household into behavior that costs it; otherwise values are optimization bonuses.

## 4. Circumstances, Trust, Standing, Relationships

**Circumstances** are derived where possible, persisted only when they cannot be:

| Circumstance | Prototype source |
| --- | --- |
| Material security | Derived: margin between hardship and the family's departure threshold, its own food holding, the town's food days |
| Claims and possessions | Derived: the home it lives in and the holding (and field) it works |
| Obligations | Persisted in relationship ties (help owed either way) |
| Trust in the gathering | Persisted, -3 to +3 |
| Social standing | Persisted, -3 to +3 |
| Perceived fairness | Recorded per experience; drives trust |
| Ambition satisfaction | Existing (`FamilyAmbitions`, contentment) |
| Health, grief, security of home | Later |

**Trust** is confidence in how the community decides (never a supernatural player the families know). Before institutions exist, the community's collective decisions come from **informal gatherings of its founding households**, each household one voice (owner decision 4): trust is confidence in those arrangements, and can attach to institutions as they emerge. It affects willingness to heed appeals, accept promises, and later to comply.

Trust has positive and negative sources, each judged by the household's own convictions (owner refinement); no act of the player's earns everyone's trust:

| Source | Gains | Loses |
| --- | --- | --- |
| Promises | First claim on the stores honoured when used | First claim promised, and the stores still would not fund the project |
| Allocation | A grant to a family in hardship, to households moved by need | Grants to a family that gave less, or the same family again and again |
| Predictability | A month of steady decisions, to households that value order (lawful, traditional, steady, cautious) | Three or more changes to the asks, stores rule, or reward within 90 days |
| Recognition | An honour the household judges deserved | One it judges undeserved (much more if it resents it) |
| Shared work | A communal building finished, for those who built it, and for others who prize working together | |
| Hardship | Help in a shortage that came because the gathering asked or rewards it, to the family helped | Held back by the stores rule while insecure |
| Disputes | A settlement under the custom or the gathering's appeal, to households that value lawful order, deference, holdings, or negotiation | The same settlement, to self-governing or free-spirited households that see it pressed on them |
| Land | Being asked for land, not forced (self-governing households); asked fairly and agreeing | Land taken by requirement: the family hard, and every household that holds claims dear | **Standing** is reputation among households: it affects imitation, credibility in disputes, and neighbours' willingness to cooperate. They are independent: a household can be respected and distrustful, or loyal and disliked.

**Relationships are sparse.** Each household keeps kin ties and at most 8 ties in all: who, disposition -3 to +3, kind (kin, friend, cooperation, obligation, rival, feud), up to three reasons, help owed either way, and an open grievance. Ties are created by interactions, never by scanning the town. When full, the weakest non-kin tie gives way. Repeated help strengthens a tie; unreturned help breeds resentment; broken expectations create grievances; restitution or forgiveness repairs them.

## 5. Property: Communal Origins, Emerging Claims

| Thing | Treatment |
| --- | --- |
| Food, wood, tools, supplies | Communal stores under access and reserve rules (`TownInfluence`) |
| Home | Occupancy and use claim |
| Field and workplace | Cultivation, use, and improvement claim of the family working it; not absolute ownership |
| Tools in use, possessions | Abstract; custody, not inventories (later) |
| Roads, public works | Communal |
| Undesignated land | Communal land-use decisions and emerging claims |

**Not every conflict is theft.** Whether something takes more than a fair share depends on the rules and claims in force. In the prototype, the claim that can be violated is a family's field: other families' walking tramples its harvest (`TownLogistics`), now attributed to the households whose routes cross it.

## 6. Decisions

Every household decision keeps desire and ability apart (from the influence prototype):

`Desire = need + personality + values + circumstances + relationships + norms + memories + player influence + bounded uncertainty`

`Ability = labor + land + accessible materials + legitimate access + reserves`

- Every term carries its reason in plain words. The reasons shown are the terms that decided it.
- The uncertainty is bounded (at most 0.75) and smaller than the "uncertain" band, so the prediction never secretly contradicts its explanation: likely always acts, likely to resist and strongly opposed never do (when able); only uncertain can go either way.
- No impossible action happens because desire is high. Reserves and access rules apply to player and household projects alike.
- Actions cost something, including what is forgone.
- **No invariant personality ordering.** Risk tolerance weighs the risk of acting against the risk of not acting: a cautious household improves first when doing nothing is the greater danger. A traditional household improves readily when the improvement is already the established practice around it. An ambitious household may wait for a better opportunity (work of its calling).

## 7. Interactions

A shared framework for every interaction: trigger, candidates (bounded and local: ties, kin, near neighbours), desire and ability for each side, consequences for both participants, relationship change, standing and trust change, memories, and norm observations. Families act selfishly, generously, mistakenly, or vindictively, never randomly for drama. The world generates social problems on its own.

**Built in the prototype:**

1. **Help with another household's construction** (weekly). A family on a holding chooses whether to give its spare time to a neighbour's project or a communal one, or keep its whole day for its own work. Empathy, sociability, communal labor, diligence, the relationship, kinship, help owed, the norm, incentives, and its own security weigh in; independence weighs against communal (player) projects. The helper's holding makes less that day; the recipient gains labor and owes a favour; repeated one-way help breeds resentment. **Kin** (owner decision 2) are a strong pull, never an automatic one: +2, more for close-knit and clannish families and toward the household it came from when it reveres its elders, less for families who hold that children should leave the nest. All else equal a family helps kin first; its own survival, a grievance, a falling-out, or help never returned (weighed half as heavily with kin) still decide against it. When it would have helped two projects, its note says what it passed over.
2. **Long days** (weekly; owner decision 1). A family on a holding with building to do (its own, or the project it chose to help) decides whether to give that time out of its rest instead of its holding's day. Diligence decides most (a leisure-loving family guards its rest); unfinished work of its own, a promise of help, and ambition add to it; weariness and its own security weigh against. The cost is real: a month with three long weeks is a month's hardship (`EconomyBalance.OVERWORK_*`), which a family close to leaving will not risk.
3. **Food sharing in a shortage** (monthly, in a month of shortage). A household the shortage would push toward leaving asks for help; a donor gives up part of its ration, taking on the hardship it spares the other. Empathy, charity, sharing, mutual aid, the relationship, help owed, the norm, and above all the donor's own security decide it: a charitable family that lacks reserves refuses.
4. **Disputes over a field** (weekly). A family whose field another family's walking tramples decides whether to let it pass or press its claim (assertiveness, vindication or forgiveness, respect for holdings, the loss, the relationship, kinship, the norm). The other family decides whether to make restitution by fencing the field with its own labor, or refuse (respect for holdings, honesty, negotiation, assertiveness, its own spare labor, what the town expects). Unresolved disputes leave grievances, harden into feuds if repeated, cost the refuser standing where the norm is accepted, and count as **pressure for agreed rules** (the seed of justice; Section 10).
5. **Contested land** (when land is scarce; owner verification request). A family that can open work nowhere may ask a neighbour for land it already works by hand; one whose nearest land another family has only just claimed (much nearer its home than any land still open) may ask for that (`FamilyInitiative.contest_for_land`). The claimant decides whether to ask at all (its need, assertiveness, respect for holdings, the claims norm, kinship, standing); the holder whether to make room for the claimant's labor in return (what it would give up, whether it has anywhere else to work, empathy, sharing and mutual aid against private holdings and landholding, kinship, the custom). Yielded, the land changes hands and the claimant owes the holder; refused, the claimant accepts the prior claim (it respects claims, the town expects it, or it is not forceful) or holds a grievance, losing standing where claims are expected to be respected. **The gathering's request for land** (`TownSocial.ask_for_land`): a communal building wanted on a family's claim; the family may agree (for first claim on the stores for new work), refuse, or have it required of it, which the family and every household that holds claims dear read as an arbitrary requirement. Only claims not yet built on can be given up to the town: nothing can clear a standing workplace yet.

**Later** (same framework): lending tools, sheltering a displaced family, welcoming newcomers, mediating, taking more than an accepted allocation, volunteering for scheduled common work.

## 8. Norms

A norm is an expectation of how households ought to behave. **A norm, a communal resource policy, and a law are different things:** a norm changes expectations; a resource policy changes distribution (`TownInfluence` store rules); a law is an enforceable obligation through a recognized institution (later). Clicking never changes beliefs directly.

Each norm has a **community acceptance** (0-1) that moves only with observed behavior: every opportunity to follow or break it (a neighbour building a home, a shortage, a trampled field) nudges acceptance toward what households actually did. Its **status**: unformed; a **habit** (most opportunities followed); a **custom** (widely followed for a season, and violations have drawn reactions); a **tradition** (a custom carried across generations; later). A household's norm term combines conformity (what it sees others do, scaled by sociability) and, when promoted, the community's appeal (scaled by receptiveness and trust). A household may approve of a norm, see neighbours ignore it, and stop following it.

**Prototype norms:** *help neighbours in need* and *respect household land claims*.

## 9. Player Influence

Four interactions, only the last coercive: **encourage; offer resources; commission a willing household; require a particular household** (requirements need real enforcement; none in this stage). Households distinguish what was wanted, what was offered, whether taking part was voluntary, whether it was fair, whether promises were kept, and whether it worked.

The ladder: appeals (founding onward); material incentives (founding onward); recognition and honor (once socially meaningful); emerging customs (from repeated behavior); voluntary agreements (once households can negotiate); enforceable rules (only with legitimate institutions and enforcement); specific requirements (only when leadership can credibly compel). **Authority never unlocks by population.** Neither voluntary nor coercive leadership is universally better.

**Prototype levers:** promote either norm (appeal); material incentive (families who help or share get first claim on the stores for their own projects, a promise that, when kept, builds trust); the stores rule (existing); recognition of a household for one of four kinds of contribution (standing for it, imitation, and a judgment by everyone else); a direct grant of first claim to one household (distribution); asking a family for its claimed land for the town's use, or requiring it (the one coercive lever, domain only so far). In the fiction, every appeal, reward, and honour is the **gathering's** (owner decision 4): the player remains an unseen guiding hand; there is no avatar, no political characters, and no office.

**The gathering** is each household as one voice, not a council or a democracy. Influence in it follows regard, not position: the households of highest standing (2 or more, at most three) are its **respected voices**, earned by what they did and never granted. An appeal carries further with households on good terms with them, less with those at odds with them (`FamilyInitiative.get_receptiveness`). Such influence may later become recognized authority or an institution; nothing grants it automatically.

**Recognition** (owner decision 3) is social, not a production bonus, and comes in four kinds that are not equivalent:

| Kind | What counts as having done it (`TownSocial.get_merit`) | Prized by (`get_esteem`) |
| --- | --- | --- |
| Community service | Weeks helping others build, rations shared | Communal labor, mutual aid, charity, sharing, empathy |
| Productive achievement | A proper holding, improved by its own decision, well kept | Diligence, ambition, private holdings, landholding, acquisitiveness, hierarchy |
| Craftsmanship and innovation | Work of its calling, well kept, by a method no other family here uses yet | Perfectionism, keepers of craft, hands-on, curiosity, openness, diligence |
| Civic contribution | Amends made, land given up, claims settled by agreement | Negotiation, lawfulness, forgiveness, respect for holdings, deference, honesty |

Every other household judges an honour by its own lights (`TownSocial.judge_recognition`, a weighed decision like any other): did the family do much of it (against the town's middle); does it prize this kind (an honour earned pleases it, an unearned one cheapens what it prizes); is the same family favoured again and again; was its own contribution of the kind it prizes overlooked; for an achievement, was the family already prosperous (to households that value equality or sharing) and does its success serve the town (supplying what the town is short of, or what no one else supplies) or only itself (to households that prize service). Deserved: a little more trust in the gathering, a lesson for the value the honour bears out, and an ambitious household that prizes the kind is inspired to match it for a season (more willing to help, to improve its holding, or to settle). Undeserved: less trust, and resentment of the honoured family when strongly felt. Indifferent: nothing. The honoured family's own pride depends on its temperament.

## 10. Justice Emerges From Conflict

Before any government, families enforce expectations themselves: demand restitution, refuse future help, withdraw cooperation, accuse, seek mediation, take sides, exclude, retaliate, escalate. The player is not automatically the judge. Repeated unresolved conflicts create recognizable pressure for agreed standards, procedures, trusted mediators, enforcement, and eventually a justice system. **No courts now.** The prototype records claims, grievances, restitution, and unresolved-dispute pressure so that formal justice has a reason to exist later.

## 11. Experiences, Memory, Interpretation

**Families react to what was achieved and how.** No event causes a universal shift; famine does not make anyone charitable by rule.

A **memory** keeps: the day, what happened, who else was involved, its facets (benefit or harm, voluntary or not, fair or not, the household's cost), and the lesson the household drew. At most 8 are kept; the least significant fade.

**Interpretation.** Each experience offers several lessons (Section 10 of the directive's matrix: help received may mean "neighbours can be trusted", "we owe a debt", "we should help others", or "it is humiliating to depend on them"). Each lesson's support comes from the household's personality, values, relationship with the others involved, and the evidence (was it fair, voluntary, costly, did it work). The household takes the best-supported lesson, and a second when nearly as strong (several interpretations coexist). A lesson adds **evidence** for or against a value.

**Values change slowly:** ordinary experiences add 1 evidence, major ones 2. At +3 a value strengthens one level (a held value may become strong; an unheld one becomes mild); at -3 it weakens one. Evidence then resets (hysteresis), and a value moves at most one level a year. A household can change its behavior at once (circumstances, relationships, norms) without changing its beliefs. Every change is explained by the memories behind it.

**New households** take their temperament from their parents (averaged, with a step of variation), their values with strengths (each kept or moved one level), and the settlement's prevailing culture where gaps remain. **Culture** is the distribution of values and strengths, practices, customs, accepted authorities, and divides, never a single town personality.

## 12. Visibility

Descriptive by default, numbers only in diagnostics. **Roster:** name, occupation, housing and security, current want or concern, one or two defining descriptors, trust. **Card:** personality descriptors, strong values, work, key relationships, wants, recent memories, outlook on the current asks, and plain explanations of recent decisions. **Full profile:** every axis and value strength, ties, trust and standing, memories, claims, history. Observed behavior is stated as fact; motives are presented as the household's reasons, not as hidden numbers.

## 13. Scale

- No household-to-household loops over the town: candidates come from ties, kin, and neighbours found through a spatial grid, capped (at most 6 per decision).
- Event-driven and scheduled: helping and disputes weekly, sharing only in shortage months, interpretation only when something happens.
- Memories and ties bounded; most circumstances derived on demand.
- Decision functions take a household's profile and a context, so a demographic group can be evaluated with a representative profile and weighted counts later.
- Deterministic under seeds: every unknown is drawn from the town, household, week, and decision.

## Superseded Decisions

- `CULTURE_AND_VALUES_MODEL.md`: values held or not (no strength) becomes strength 0-3; "culture changes mostly between generations" stays true in tendency, but values can now move within a lifetime from interpreted experience.
- `FAMILY_INFLUENCE_PROTOTYPE.md`: improvement decisions read personality axes, and the fixed "daring / cautious" terms become a weighing of the risk of acting against the risk of waiting.

## Audit Of The Existing Implementation

What extends cleanly, and what conflicts:

| System | Finding | Action |
| --- | --- | --- |
| Values (`CultureValues`, `Household.values`) | Category -> held list; the random draw and its seeds feed every balance run | Kept untouched. Strength lives beside it (`Household.value_strengths`); conduct values are added outside the draw |
| Industrious / leisurely, cautious / daring | Personality-like values. Industrious/leisurely give ±10% output (`CultureEffects`); cautious/daring are read only by `FamilyInitiative` | Decisions read the new axes. The ±10% output of industrious/leisurely is **removed** (owner decision 1, all towns, social model on or off); diligence acts through long days and the will to help and improve |
| `FamilyInitiative` scoring | Weighted reasons, bounded noise, predictions: the framework the directive asks to extend | Reused by every interaction; its fixed daring/cautious terms replaced by context-dependent risk |
| Family construction (`TownConstruction` spare time) | Every working family gives 20% of its day to the first site with room: automatic, unexplained helping | With the social model on, spare time goes only to the family's own project or the project it chose to help. A measured risk: the earlier judgment call found towns stall without helpers |
| Communal access (`TownInfluence`) | Stores rule and reserves apply to household projects; player projects draw freely | Kept; material incentives and grants give first claim within the rule; reserves always hold |
| Satisfaction (`FamilyAmbitions`, contentment) | Ambition fulfilment drives contentment | Kept; the roster reads it |
| Hardship and departure | Food shortage gives every family the same hardship | Sharing moves shortage hardship between two families (`Household.shortage_hardship_adjust`) |
| Trampling (`TownLogistics`) | Counted per field, not per walker | Now also per walking household, for disputes |
| Five-year prototype bottlenecks | Homes only on plots explain most slower growth; one free builder speeds the first homes | Not changed here: plot supply is a separate decision |

## Prototype (Directive Section 16)

Branch `feature/household-social-prototype`, 2026-10-28. Off unless a town enables it (`TownSocial.enabled`; in the game, **I** turns on both this and the influence prototype for the town in view, or start with `-- --influence`).

| Piece | Where |
| --- | --- |
| Personality, value strengths, conduct values, inheritance | `HouseholdCharacter` |
| Ties, memories, interpretation, value change | `HouseholdMemory` |
| Desire for helping, sharing, pressing and settling claims | `SocialDecisions` |
| Weekly and monthly passes, norms, trust, standing, recognition, grants, incentive, neighbour grid | `TownSocial` (`city.social`) |
| Improvement weighing risk of acting against risk of waiting | `FamilyInitiative.get_improve_desire` |
| Trampling by household; shortage hardship moved by sharing; voluntary spare time | `TownLogistics`, `HouseholdMigration`, `TownConstruction` |
| Roster (L), the house card's Family section, sidebar norm appeals, help reward, honour | `HouseholdRosterHelper`, `CityBuildingOverlay`, `main.gd` |

### The directive's ten demonstrations

All ten pass in `tests/household_social_validation.gd`, each checking both the behavior and the reason the household gives:

1. A very cautious family improves its garden while food is short, "because waiting is the greater risk", and keeps to hand work when the town is fed.
2. An industrious, self-governing family declines to help build the storehouse ("it holds that families should choose their own work"); an industrious family that values working together helps.
3. A charitable, attuned family close to the edge itself does not share ("it lacks reserves of its own"); the hungry family, seeing that, concludes "they could not spare it" rather than blaming it. With a margin, the same family shares.
4. A family that has helped most accepts first claim on the stores, then sees a family that has given nothing favoured twice: its trust falls and it remembers accepting help while another got more.
5. Rivals become friends after four weeks of one helping the other build, and the tie says why.
6. A forceful crosser refuses amends: a grievance stands, its standing falls where the community asked that claims be respected, the pressure for agreed rules rises, the owner will not help it build, and a second refusal hardens into a feud.
7. Where helping neighbours is the custom, a family with only a mild leaning helps, though it costs part of its own day.
8. A caring family that values working together stops helping when it is itself close to having to leave, and says so; its conviction is unchanged.
9. A family helped twice helps its neighbour back because it owes them, while its values have not changed yet.
10. The same public honour: the egalitarian family reads favouritism, the ambitious hierarchical one reads "honour goes to those who seek it", and they end with different trust.

### Controlled comparison

`tests/sim/social_check.gd`: 12 real town sites, 3 years, six founding families developing their own work (three industries), the same seeds, and the same lost harvest at the start of the first winter. Only the player's approach differs.

| Approach | Off the ground | People | Helped a family in need | Shared when asked | Friends / rivals a household | Mean disposition | Trust | Standing spread | Value changes | Help norm |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| none | 11/12 | 30 | 17% | 20% | 0.16 / 0 | +0.67 | 0.00 | 0.8 | 1.2 | habit in 2 towns |
| encourage | 11/12 | 30 | 43% | 32% | 0.42 / 0 | +1.01 | 0.00 | 1.3 | 2.8 | habit in 5, custom in 1 |
| incentives | 11/12 | 30 | 42% | 23% | 0.46 / 0 | +1.12 | 0.00 | 1.6 | 2.8 | habit in 4, custom in 1 |
| restricted | 6/12 | 15 | 13% | 19% | 0.13 / 0 | +0.55 | -0.12 | 0.5 | 2.3 | habit in 2 |
| unfair | 11/12 | 30 | 18% | 20% | 0.18 / 0.56 | -1.27 | -1.10 | 2.8 | 12.0 | habit in 2 |

Course by year (help norm acceptance; trust): none 0.21, 0.22, 0.25 and 0; encourage 0.44, 0.47, 0.50 and 0; unfair 0.21, 0.25, 0.28 with trust -0.67, -1.20, -1.10.

**What it shows.**

- **Different player decisions make materially and socially different settlements from the same start.** Asking families to help neighbours, or rewarding help, more than doubles how often a family in need gets help (17% to 42-43%), roughly triples friendships, and turns the norm into a habit in five towns and a custom in one, without changing survival or size. The appeal works through receptive families, not by decree: about half the needy weeks still go unhelped.
- **Unfair honours leave the town materially the same and socially worse:** rivalries appear (0.56 a household against none), relationships turn negative, trust in the leadership falls to about -1, standing spreads widest, and values move ten times as often as with no intervention (households drawing egalitarian or hierarchical lessons from what they saw).
- **Restricting the stores to food for three years is ruinous here:** half the towns fail and they end half the size, because wood and tool work cannot be improved. That is partly the stand-in's choice (food only, never relaxed) on top of a lost harvest; it shows the policy has real teeth, not that restriction is always wrong.
- **Encouragement and incentives look alike in outcome** but differ in mechanism: incentives buy more help-weeks (22 against 16), mostly from ambitious families, and slightly fewer shares.
- **Weak spots.** Disputes almost never happen on these compact layouts (trampling is rare once routes follow field margins), so the claims norm never forms; it is tested only by the unit cases. Trust barely moves except under unfairness: the prototype has few positive sources of trust (kept promises only). Sharing requests are few (3-4 a town) because only a hard winter drives families toward leaving.

### Performance

The weekly pass costs about 0.16 ms a household in these towns (1.3 ms for 8). The scale probe (homes spread over one town map, each family on a holding, a home being built for every tenth): 50 households 6 ms, 100 16 ms, 200 44 ms, 400 136 ms a week, 119 to 340 µs a household. Growth comes from crowding more families onto one map, not from pairs: candidates are ties, kin, and a ring-searched neighbour grid that stops at 6. Two fixes found by profiling: households were looked up by scanning the whole list, and every candidate re-summed the town's population for its food days. Next steps if needed: spread the pass over the week's days, and the grouped representation for cities.

### Against the intended experience (directive D)

Watching one household, the card answers: what it wanted ("Lately", "Work"), why (the reasons), what circumstances weighed (security, food, its neighbours' example), what the player did (appeals and rewards appear among its reasons, as "the community asks families to ..."), why it accepted or refused (the strongest reasons for or against), what resulted (ties, standing, trust), and how it changed it (memories with the lesson drawn, value changes with the experience behind them). The roster gives the town at a glance. What still needs the owner's playtest: whether these words make the families feel like characters, and whether choosing between appeals, rewards, and honours feels like leading.

## Judgment Calls

Made during implementation, open to veto. Numbers are first guesses, in the scripts named.

- **Branch.** `feature/household-social-prototype` is cut from `feature/family-influence-prototype`, not `develop`: this slice extends that unmerged prototype (families developing their own work), which still awaits review. Both merge together, or not at all.
- **Spare time is a choice.** With the model on, a working family gives its spare fifth of a day only to its own project or the one it chose to help that week (`TownConstruction.get_spare_time_project`). Before, every family helped the first site in the queue. The town building model once found towns stall without automatic helpers; families' own homes and full-time builders are unaffected, and the comparison below did not show stalls, but it is the main balance risk.
- **Sharing moves hardship, not food.** Stores are communal, so a family's "ration" is its share of the shortage's hardship: a donor takes one point of it, the family helped is spared one (`Household.shortage_hardship_adjust`). A donor gives at most once a month, and only if doing so leaves it clear of considering departure itself.
- **Field claims and land claims.** Disputes arise from trampling, now attributed to the walking household (`TownLogistics.trampled_by`), and, since the owner review, from contested land (Section 7, item 5). Amends mean the crossing family fences the field with its labor (or owes the field's family a favour when no wood can be spared). A dispute rests 90 days before the same pair can quarrel again; a second unsettled one is a feud.
- **The help norm is judged per family in need,** not per family that could help: each week, a family building its first home or close to leaving either got some neighbour's help or none. Counting every non-helping family as a violation drove acceptance to nothing within weeks, because one helper is enough.
- **Material incentive = first claim on the stores** for 120 days after helping or sharing: the household's own projects pass the priorities rule (never the reserve) and go to the front of the building queue. When that happens, the promise is kept and the household's trust rises a little.
- **Fairness of grants** is judged by contribution (weeks of help given and rations shared) against the town's middle and the observer's own, or, for a family in hardship, by need (to households moved by it); repeated favour of the same household (more than two honours and grants) is favouritism whatever it has done. Resentment needs egalitarian conviction, ambition, or being clearly overlooked; hierarchical and deferential households accept it. **Honours** are judged by kind (Section 9).
- **Restricted stores cost trust** at most once a month per household, and only for households that are not secure.
- **Value evidence:** ordinary experiences 1, major ones 2; 3 moves a value a level; a year between moves of one value. A lesson for a value whose opposite the household holds weakens the opposite instead: the conduct pair forgiveness and vindication, and, since the owner review, every exclusive pair of the catalog (egalitarian and hierarchical, communal labor and solitary, ...), so a household never holds both halves of a pair.
- **Character drawing:** axes mostly balanced (40% zero, 20% each ±1, 10% each ±2); a held migrated value sets its axis to ±1 or ±2; each conduct value 45%; 3-5 strong convictions, 1-2 defining. New households: averaged temperament with a 15% chance of a step either way; parent strengths kept, 15% one weaker, 10% one stronger.
- **A town with half a year of food in store is secure** for the purpose of weighing improvements, whatever its fields grow meanwhile (`FamilyInitiative.SECURE_FOOD_DAYS`).

## Open Questions For The Owner

1. **Temperament and output.** Industrious and leisurely are now temperament, which the directive says must not be a production bonus, yet as catalog values they still give ±10% output. Remove the output effect (every balance run moves), or keep it as the effect of the underlying value?
2. **Automatic helpers.** Should spare-time helping stay purely voluntary when the model is on, or should a family still give spare time to its own kin's homes without deciding to?
3. **What contribution means.** Fairness is judged by help and food given. Should good work at a family's own holding (production) count as contribution too?
4. **Where the player's appeals come from.** In the fiction, who asks families to help their neighbours: a gathering, respected elders, the founders? It decides what trust in leadership is trust *in* before any institution exists.
