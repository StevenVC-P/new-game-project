# Household Social Model

How families think, relate, and change, and how the player shapes their conduct. **Owner design directive, 2026-10-28: approved design direction.** It sits under `docs/GAME_VISION.md` (which wins on any conflict) and extends `docs/CULTURE_AND_VALUES_MODEL.md` (the twelve value categories), `docs/FAMILY_INFLUENCE_PROTOTYPE.md` (families developing their own work), and `docs/household_simulation_philosophy.md`. Where this document and an older model disagree, this one supersedes it only where it says so (Superseded Decisions, below).

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
| Diligence | Leisure-oriented | Industrious | extra labor, improvements |
| Openness | Familiarity-seeking | Experimental | unfamiliar techniques |
| Empathic sensitivity | Detached | Attuned | sharing, sheltering, impartiality |
| Assertiveness | Accommodating | Forceful | pressing claims, yielding |

**Migration.** The values *industrious/leisurely* and *cautious/daring* move to diligence and risk tolerance: a household holding one starts with that axis at ±1 or ±2, and decisions read the axis, not the value. Convictions such as communal labor, traditional authority, independence, and respect for holdings stay values.

**Change.** Stable through ordinary play; only major, repeated experiences move it, rarely. Not built in the prototype.

## 3. Values With Strength

The twelve categories stay. Each held value has a strength: **0 not held, 1 mild preference, 2 strong conviction, 3 defining conviction.** A household typically has 3-5 strong convictions across its profile and 1-2 defining ones (targets, not caps). Strength separates background preferences from convictions that drive behavior.

- Values act mainly on decisions and reactions. Their existing effects on output (5-15%, capped at ±30%) are unchanged and separate from desire weights.
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
| Trust in leadership | Persisted, -3 to +3 |
| Social standing | Persisted, -3 to +3 |
| Perceived fairness | Recorded per experience; drives trust |
| Ambition satisfaction | Existing (`FamilyAmbitions`, contentment) |
| Health, grief, security of home | Later |

**Trust** is confidence in the community's leadership, customs, agreements, and institutions (never a supernatural player the families know). It affects willingness to heed appeals, accept promises, and later to comply. **Standing** is reputation among households: it affects imitation, credibility in disputes, and neighbours' willingness to cooperate. They are independent: a household can be respected and distrustful, or loyal and disliked.

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

1. **Help with another household's construction** (weekly). A family on a holding chooses whether to give its spare time to a neighbour's project or a communal one, or keep its whole day for its own work. Empathy, sociability, communal labor, diligence, the relationship, kinship, help owed, the norm, incentives, and its own security weigh in; independence weighs against communal (player) projects. The helper's holding makes less that day; the recipient gains labor and owes a favour; repeated one-way help breeds resentment.
2. **Food sharing in a shortage** (monthly, in a month of shortage). A household the shortage would push toward leaving asks for help; a donor gives up part of its ration, taking on the hardship it spares the other. Empathy, charity, sharing, mutual aid, the relationship, help owed, the norm, and above all the donor's own security decide it: a charitable family that lacks reserves refuses.
3. **Disputes over a field** (weekly). A family whose field another family's walking tramples decides whether to let it pass or press its claim (assertiveness, vindication or forgiveness, respect for holdings, the loss, the relationship, kinship, the norm). The other family decides whether to make restitution by fencing the field with its own labor, or refuse (respect for holdings, honesty, negotiation, assertiveness, its own spare labor, what the town expects). Unresolved disputes leave grievances, harden into feuds if repeated, cost the refuser standing where the norm is accepted, and count as **pressure for agreed rules** (the seed of justice; Section 10).

**Later** (same framework): lending tools, sheltering a displaced family, welcoming newcomers, mediating, taking more than an accepted allocation, volunteering for scheduled common work.

## 8. Norms

A norm is an expectation of how households ought to behave. **A norm, a communal resource policy, and a law are different things:** a norm changes expectations; a resource policy changes distribution (`TownInfluence` store rules); a law is an enforceable obligation through a recognized institution (later). Clicking never changes beliefs directly.

Each norm has a **community acceptance** (0-1) that moves only with observed behavior: every opportunity to follow or break it (a neighbour building a home, a shortage, a trampled field) nudges acceptance toward what households actually did. Its **status**: unformed; a **habit** (most opportunities followed); a **custom** (widely followed for a season, and violations have drawn reactions); a **tradition** (a custom carried across generations; later). A household's norm term combines conformity (what it sees others do, scaled by sociability) and, when promoted, the community's appeal (scaled by receptiveness and trust). A household may approve of a norm, see neighbours ignore it, and stop following it.

**Prototype norms:** *help neighbours in need* and *respect household land claims*.

## 9. Player Influence

Four interactions, only the last coercive: **encourage; offer resources; commission a willing household; require a particular household** (requirements need real enforcement; none in this stage). Households distinguish what was wanted, what was offered, whether taking part was voluntary, whether it was fair, whether promises were kept, and whether it worked.

The ladder: appeals (founding onward); material incentives (founding onward); recognition and honor (once socially meaningful); emerging customs (from repeated behavior); voluntary agreements (once households can negotiate); enforceable rules (only with legitimate institutions and enforcement); specific requirements (only when leadership can credibly compel). **Authority never unlocks by population.** Neither voluntary nor coercive leadership is universally better.

**Prototype levers:** promote either norm (appeal); material incentive (families who help or share get first claim on the stores for their own projects, a promise that, when kept, builds trust); the stores rule (existing); recognition of a household (standing for it, imitation, and a fairness judgment by everyone else); a direct grant of first claim to one household (distribution). No coercion.

**Recognition** is social, not a production bonus: it raises standing, invites imitation, and is judged for fairness. An ambitious family values honor; a private one barely cares; an egalitarian one resents disproportionate honors; households whose own contribution was overlooked may envy the honored family and distrust the leadership.

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
| Industrious / leisurely, cautious / daring | Personality-like values. Industrious/leisurely give ±10% output (`CultureEffects`); cautious/daring are read only by `FamilyInitiative` | Decisions read the new axes. **Open:** the ±10% output of industrious/leisurely is a productivity effect of what is now temperament; kept unchanged pending an owner decision (removing it changes every balance run) |
| `FamilyInitiative` scoring | Weighted reasons, bounded noise, predictions: the framework the directive asks to extend | Reused by every interaction; its fixed daring/cautious terms replaced by context-dependent risk |
| Family construction (`TownConstruction` spare time) | Every working family gives 20% of its day to the first site with room: automatic, unexplained helping | With the social model on, spare time goes only to the family's own project or the project it chose to help. A measured risk: the earlier judgment call found towns stall without helpers |
| Communal access (`TownInfluence`) | Stores rule and reserves apply to household projects; player projects draw freely | Kept; material incentives and grants give first claim within the rule; reserves always hold |
| Satisfaction (`FamilyAmbitions`, contentment) | Ambition fulfilment drives contentment | Kept; the roster reads it |
| Hardship and departure | Food shortage gives every family the same hardship | Sharing moves shortage hardship between two families (`Household.shortage_hardship_adjust`) |
| Trampling (`TownLogistics`) | Counted per field, not per walker | Now also per walking household, for disputes |
| Five-year prototype bottlenecks | Homes only on plots explain most slower growth; one free builder speeds the first homes | Not changed here: plot supply is a separate decision |

## Prototype (Directive Section 16)

PROTOTYPE_PLACEHOLDER

## Judgment Calls

JUDGMENT_PLACEHOLDER

## Open Questions For The Owner

OPEN_PLACEHOLDER
