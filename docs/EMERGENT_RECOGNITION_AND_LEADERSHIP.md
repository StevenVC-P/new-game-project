# Emergent Recognition and Community Leadership

**Status: implemented as a prototype (2026-11-01). Branch `feature/emergent-recognition`, from `feature/occupation-reconsideration`, so it stays separate from the household-economy work. Not merged: awaits owner review.**

Code: `scripts/domain/town_regard.gd` (`TownRegard`). It hooks into:
- `TownSocial`: the monthly review, the weekly stance, dispute mediation, the Speaker's grants judged in `judge_distribution`, and the voices;
- `CommunityPriority.get_view` and `FamilyInitiative.get_receptiveness` (the Speaker's lead);
- `TownInfluence.get_funding_block` (first claim stays within the Elder's rule);
- the Community page;
- `main.gd` (`appoint_speaker`).

Tests: `tests/town_regard_validation.gd`. Comparison: `tests/sim/speaker_check.gd`.

Core goal (owner, 2026-11-01): a family can become powerful without the player's approval, and the player decides which of the community's emerging interests to empower.

Guiding principle (owner): families create the community's politics. The player influences who receives authority, but can't dictate what those families believe or how everyone responds.

## Owner Decisions (proposal review, 2026-11-01)

1. **Emergent recognition** replaces the manual Honour and Reward helping controls.
   - Contributions are recognised when they happen, without awarding standing again and again for the same achievement.
   - Influence reflects economic importance, relationships, supporters, detractors and contributions.
   - Disagreement is preserved.
2. **The office is called Speaker of the Gathering**, chosen at Village from the three most influential households.
   - **The player stays the Elder,** with authority over guiding wisdom, the community priority, the stores rules and land planning.
   - **The Speaker's limited influence:**
     - it shapes how families take the priority, positively or negatively, by its own convictions;
     - it decides preferential access to the stores within the player's rules and protected reserves;
     - it tries to settle disputes through its relationships;
     - it keeps making its own household decisions.
   - **Families judge the Speaker's actions.**
3. **Replacing a Speaker** is allowed. The consequences emerge from the circumstances (the former Speaker's temperament, ambition, supporters and reputation). There is no automatic resentment and no fixed ban on reappointment.
4. **Not yet:** preparedness contributions come with household reserves. No formal government, laws, factions or individual characters yet. The work stays separate from the household-economy branch.
5. **Validation:**
   - Matched simulations compare the existing system against emergent recognition, the same towns with each of their three candidates appointed, and different replacement circumstances.
   - Weights are fixed before evaluation.
   - Political divergence, not population, is the main measure of success.

## As Built

Following the proposal below, with these specifics:
- **Noticing:**
  - Monthly, not seasonal, so a contribution is recognised close to when it happens.
  - Service (weeks helped and food shared) and civic acts (amends, land given up) are noticed at 2, then at each doubling.
  - A holding or craft is noticed at each new level from 2 up.
  - The highest level noticed is kept per household (`noticed_merit`), so the same achievement never counts twice.
- **Thresholds:** admired at a score of at least 1.0, resented at -1.5 or below. Standing changes by +0.25 per admirer (at most +1 per achievement) and -0.25 per resenter (at most -0.5). The deed is real, so desert and favouritism terms don't apply.
- **Voices:** the gathering's voices become the most influential households with influence of at least 2, replacing standing of at least 2.
- **First claim** that the Speaker gives keeps its place at the front of the building queue, but no longer passes the Elder's priorities rule. This keeps the Speaker inside the Elder's rules (owner decision 2). Protected reserves always held.
- **The Speaker's lead:**
  - A family that backs the Speaker (by its tie, or by its view when the Speaker was appointed) takes the priority as the Speaker does, +/-0.5 in its view and +/-0.2 in how readily it heeds appeals.
  - A family that opposes the Speaker leans the other way, at half the strength.
- **The Speaker's stores policy:** chosen every season by its values and ties:
  - families who help (the old incentive);
  - families in hardship;
  - its own kin and friends;
  - nothing beyond the Elder's rules.

  It grants first claim to up to two households a season. The town judges each grant (`judge_distribution`), and holds the result for or against the Speaker.
- **Mediation:** a Speaker that doesn't think little of civic work urges amends in field disputes that don't involve it. A crossing family that backs it is moved toward amends (+0.8); one that opposes it, away (-0.4); one with no view, a little (+0.2).
- **Replacement:**
  - **The former Speaker** weighs its ambition, its temperament, its following and regard, whether it had lost the town's confidence, and its view of its successor. It steps down, resents the removal, or won't forgive it.
  - **Each family** weighs its tie to the former Speaker, whether its trust rose or fell during the term, and whether it ever wanted that Speaker. It approves, minds, or doesn't care.
- **Vacancy:** a Speaker whose family leaves or passes on leaves the office empty, and the Elder appoints again.
- **Weights:** fixed before the comparison. One 2-town smoke run of the harness was looked at, to check the harness worked, before the comparison was launched.

## Validation Results (2026-11-01)

**Setup:**
- **Towns:** 12 per condition, on ordinary and difficult land, for six years. They are the wisdom check's towns, with families leading and the social model on. The stand-in player never honours anyone.
- **Three cultures,** each a community priority with its wisdoms: the food priority alone; We Endure Together + Respect What Others Build with the cooperation priority; Prepare for Hard Times + Take Pride in Your Work with the investment priority.
- **Eight branches of each town,** identical until Village:
  - the existing system;
  - emergent recognition with no Speaker;
  - the first, second or third candidate appointed at Village;
  - each candidate replaced by the next 540 days later.
- **Weights** stayed as fixed before the runs.

**Measurement caveats:**
- **Towns that never reach Village** (26–75% of them, depending on the land) have no Speaker.
- **Vacancies:** Speakers are often old couples, and the office falls vacant when their family passes on. The stand-in player never appoints again, so some branches spend part of their time with no Speaker.

### 1. Existing system against emergent recognition

| Measure (per town at year 6) | Existing | Emergent |
|---|---|---|
| Achievements noticed | 0 | 29–63 |
| Admirations / resentments | 0 / 0 | 93–257 / 9–27 |
| Achievements both admired and resented | 0 | 4.5–7.8 |
| Positive / negative ties | 22–69 / 0–0.8 | 50–101 / 2.4–8.1 |
| Value changes | 4.5–36 | 21–68 (2–4×) |
| Different households ever among the three most influential | – | 5.8–8.2 |
| Changes in the top three | – | 10–13 |
| People | as existing | −5 to +0.3 |

**Recognition now happens without the player.**
- **It divides families:** every town has achievements that some families admire and others resent.
- **Influence moves:** six to eight different households pass through the top three in a town's life.
- **Cultures develop faster.** The town's political values (egalitarian, hierarchical, communal, private and so on) end up 0.55–1.22 apart (L1 over value shares) from the same town without it.
- **Population** is little changed.

**Who becomes influential:**
- **Mostly farming families:** 10–24 of each culture's candidates. They are the most common work, with the most kin.
- **Also toolmakers and woodcutters:** in every culture.
- **Their values follow the culture:**
  - communal and mutual-aid families lead in the cooperative culture;
  - private-holdings, acquisitive and keepers-of-craft families are common among candidates in the food and investment cultures.
- **Likely policies in office:**
  - **Cooperative culture:** "helpers" almost everywhere (28 of 33 candidates).
  - **Other cultures:** split between "helpers" (15) and "its own" (9–11).

### 2. The same towns with each of their three candidates appointed

Means over towns that reached Village, at year 6:

| Culture, land | Trust (none / 1st / 2nd / 3rd Speaker) | Wary families | Negative ties | Trust range across the three, per town | Towns where the Speakers' main policy differs |
|---|---|---|---|---|---|
| Food, ordinary | +0.93 / −0.45 / +0.53 / +0.33 | 0 / 6.3 / 2.8 / 4.3 | 7.8 / 23 / 15 / 20 | 2.2 | 6 of 9 |
| Prepare+Pride, ordinary | +0.97 / −0.07 / +0.53 / +0.08 | 0 / 5.0 / 2.6 / 4.5 | 9.5 / 18 / 14 / 19 | 2.4 | 6 of 10 |
| Endure+Respect, ordinary | +1.25 / +1.28 / +1.25 / +0.70 | 0 / 0.1 / 0.1 / 2.8 | 5 / 5 / 6 / 10 | 0.8 | 2 of 11 |
| Food, difficult | +0.92 / +0.27 / +0.59 / −0.18 | 0 / 4.2 / 3.4 / 6.4 | 7 / 14 / 11 / 23 | 2.2 | 2 of 5 |
| Prepare+Pride, difficult | +0.90 / −0.92 / −0.46 / −0.52 | 0 / 8.8 / 6.2 / 6.0 | 7 / 21 / 18 / 19 | 2.3 | 2 of 5 |
| Endure+Respect, difficult | +1.42 / +1.44 / +0.98 / +0.88 | 0 / 0.1 / 2.9 / 3.1 | 4 / 4 / 8 / 10 | 0.7 | 1 of 7 |

**Political divergence is real, and depends on the culture.**
- **The food and Prepare+Pride cultures:**
  - **Trust spread:** which candidate leads moves the town's trust by more than 2 points on a −3 to 3 scale.
  - **Policy:** the Speakers' main policy differs in most towns.
  - **Grants:** a Speaker who favours its own gives 6–8 grants a town, and leaves 5–9 families wary of the gathering.
- **The cooperative culture:** every candidate holds similar communal values and rewards helpers, so the choice matters little.
- **No Speaker at all** keeps trust highest everywhere. An office brings favouritism and opposition that the town didn't have.

**Other effects:**
- **Population:** almost unchanged by the choice (within about 1 person on average). The consequences are political, not demographic, as the owner asked.
- **Disputes:** in the cooperative culture, Speakers urge settlement in 3–7 disputes a town, and nearly all are settled.
- **Appointments are rarely opposed at first:**
  - **The first reaction:** families support or don't mind (no family opposed an appointment; at most 3 doubted it). Opposition grows from what the Speaker does.
  - **Weights:** a stronger first reaction would need different weights. That is a judgment call left to the owner.

### 3. Replacing a Speaker

In 71 replacements of a sitting Speaker, the circumstances decided the outcome:

- **Replacing a Speaker that had lost the town** (more detractors than supporters at the time, e.g. 3 for and 7 against, or 2 for and 10 against):
  - **The town's reaction:** most families approved (approved ≥ opposed in every such case).
  - **Trust at year 6:** recovered by 1.5–3.5 points against keeping that Speaker. For example −1.68 → +1.39, −3.31 → +0.10, −3.13 → −0.42.
- **Replacing a respected Speaker** (supporters far outnumbering detractors):
  - **The town's reaction:** most families opposed (5–14 a town). The immediate trust cost was small (−0.0 to −0.3).
  - **What follows:** depends on the successor. Where it favoured its own, trust fell 2–3.5 points by year 6 (e.g. +2.09 → −1.42, +1.06 → −2.14, +0.77 → −2.52). Where it didn't, nothing much changed.
- **How the former Speaker took it:** 85% stepped down, 7 resented it, 2 wouldn't forgive it. All of these were ambitious, assertive or well-backed families. Nothing was imposed.

### Not yet measured

- **Long-term reappointment** after vacancies (the stand-in player never reappoints).
- **The player's own reading of the candidate cards.** This needs playtesting.

## 1. Audit

### What the player controls today (Community page)

- **Reward helping** (`TownSocial.incentive`, a toggle). While it is on, a family that helps a neighbour build or shares food in a shortage gets first claim on the stores for 120 days (`grant_first_claim`). Using that claim is a promise kept (+trust). Being held back while holding it is a promise broken (−trust).
- **Honour a family** (`TownSocial.recognize`, four kinds: service, holding, craft, civic). It is also on the Families page. Its effects:
  - The honoured family gains a point of standing and some trust, and remembers the honour.
  - Every other family judges the honour (`judge_recognition`), weighing:
    - whether it was deserved (`get_merit` against the town's middle);
    - what the observer prizes (`get_esteem`, from its values and temperament);
    - favouritism;
    - whether its own work was overlooked;
    - levelling values against the already prosperous;
    - service-minded families against success that serves only the family itself;
    - kinship and the tie between them.
  - **Consequences:**
    - **Deserved:** trust in the gathering rises, and ambitious families that prize the work want to match it (`inspired_by`).
    - **Undeserved:** trust falls, and families resent the favoured household (a tie of −1, "was favoured over us").

  The judgment is already emergent. Only the trigger is the player's.

### What already works without the player

- **Standing** (−3 to 3, one number per household): the town's regard.
  - Raised by helping others build (+0.25 a week), sharing food (+0.5), and keeping or giving up land in a contest (±0.5).
  - Lowered by leaving a trampled-field claim unsettled (−1) and by pressing a claim on land and losing (−0.5).
  - Read by disputes and land contests ("the other family is better regarded").
- **Respected voices** (`get_respected_voices`): the up-to-three households with standing of at least 2. They make an appeal land better with families on good terms with them (`FamilyInitiative.get_receptiveness`). This is the start of informal leadership. It is earned, never granted.
- **Ties** (`HouseholdMemory`, up to 8 per household): disposition −3 to 3, with reasons, debts owed, grievances, and kin.
  - These are per-pair opinions, so different families can already think differently of the same household.
  - Sources include help returned or unreturned, shared or refused food, disputes, land, and honours seen as favouritism.
- **Trust** (−3 to 3): confidence in how the gathering decides. It is the main channel between community decisions and families' readiness to heed them.
- **Memories and lessons:** honours already teach lessons ("service is noticed here", `RECOGNITION_LESSONS`) that move values.
- **Guiding wisdom:**
  - Each family's view of each held wisdom is "supports", "does not much mind" or "has reservations" (`GuidingWisdom.get_view`).
  - Families' conduct toward the wisdoms is recorded.
  - The player's title is Expedition Leader, then Elder from Village (`GuidingWisdom.get_title`, a third wisdom slot).
- **Community priority:** each family's view of each priority (`CommunityPriority.get_view`), and the town's backing of it.

### The gaps

1. **Recognition happens only when the player presses a button.** Nothing notices a family's good work unless the player honours it, or it happens to help or share.
2. **Standing is one public number.** Admiration and resentment exist only as ties, mostly from help and disputes. A family can't be admired by some families and disliked by others for the same success, except through a player-made honour.
3. **Influence is standing alone.** A family's economic weight (the town's only toolmaker), its kin, and how many families think well of it don't count toward its voice.
4. **The town has no leader.** The respected voices are anonymous weight on appeals. Nobody holds office, and the player can't empower anyone.
5. **First claim for helpers** depends on the player's toggle, not on anyone in the town.

## 2. Proposal: the smallest coherent implementation

One new domain script, `scripts/domain/town_regard.gd` (`TownRegard`), owned by the town like `TownSocial`. It reuses `judge_recognition`, `get_merit`, `get_esteem`, ties, standing, trust and memories. Three parts.

### 2.1 Families notice each other (replaces "Honour a family")

**When:** once a season, each family looks at the households it knows (`get_known_households`: kin, ties, neighbours) and notices any that stand out in one of the four kinds of contribution.

**What counts as standing out:**
- **The kinds:** service, achievement, craft and civic, the same four the honours use.
- **Preparedness** joins them as a fifth kind, but only where Prepare for Hard Times is a held wisdom. There is nothing to measure for it on this branch without the household economy; with larders it would read the family's reserve. See decision R3.
- **The test:** the household's merit is clearly above the town's middle (`get_merit` at least the middle + 1), or it is the only family supplying something the town needs (`serves_town`).

**How the observer judges it:** with the same terms `judge_recognition` uses today, plus one new term. The honour-specific terms ("the same family is favoured again and again") fall away, since nobody granted anything. The new term covers the town's wisdoms:
- If the deed is what a held wisdom asks and the observer supports that wisdom: +0.5, "it lives by what we hold to".
- If the observer has reservations about that wisdom: −0.25.

**What follows:**
- **Admired** (score at least 1):
  - The observer's tie to the household rises by one ("admires its craft").
  - The household gains a little standing (+0.25 per admirer a season, capped).
  - An ambitious observer that prizes the work is inspired by it (the existing `inspired_by`).
  - The observer remembers it, and the existing lesson ("good craft is honoured here") can grow the value.
- **Resented** (score at most −2, mostly levelling or overlooked families):
  - A tie of −1 ("thinks itself above us").
  - A small loss of standing (−0.25), so regard is contested, not one-way.
- **In between:** nothing.

There is no trust change, since the gathering didn't act. Trust stays tied to what the gathering and its leader do.

**Limits:**
- One notice per family per season.
- The household is noticed at most once a year by the same observer.
- Ties are capped at 8 per household as today, so opinions stay local.

### 2.2 Influence and the three candidates

**A household's influence** is computed when needed and shown with its parts, never as a single unexplained score. It is the sum of four parts, so no one part decides it:
- **Regard:** its standing (−3 to 3).
- **Following:** families with a positive tie to it, minus those with a negative tie. Up to ±3, at 0.5 per family.
- **Weight in the town's work:** +1 for a proper holding; +1 if it is the only family supplying something (`serves_town`); +0.5 for each kin household in town, up to +1.5.
- **Contribution:** service and civic merit (help given, food shared, peace kept), up to +2.

**The three candidates** are the three households of highest influence, with ties broken by household number.

**Each card shows:**
- the family's values (`describe_convictions`);
- its supporters and detractors (families by tie);
- its likely priorities (`CommunityPriority.get_view` for each priority, and its view of each held wisdom);
- what it would do in office (2.3).

The respected voices of today become "the households of highest influence" for the appeal-weight term in `get_receptiveness`. It is the same idea with fuller inputs.

### 2.3 The community leader (from Village)

When the town becomes a Village (the player becomes its Elder), the Community page offers the three candidates. The player appoints one. The player stays the Elder, the guiding authority (wisdoms, the priority, the stores, land). The appointed household is the gathering's leader, the actual leadership of the community. It remains an ordinary household that makes its own choices.

**What appointment does** (influence, not control):

1. **Every family judges the appointment.** It is the same kind of judgment as an honour, by:
   - its tie to the leader;
   - shared values;
   - whether the leader's likely priorities match its own views;
   - deference against self-government;
   - egalitarian unease at power gathering in an already-regarded family.

   **Consequences:**
   - **Supporters:** trust +0.5 ("our voice was heard").
   - **Detractors:** trust −0.5 to −1, and a −1 tie to the leader ("was raised over us").
   - **Passed-over candidates:** they remember being passed over, with a −1 tie if they are ambitious.
2. **The leader's voice carries.**
   - In `get_receptiveness`, the leader counts as a voice of double weight.
   - When it supports the community priority, families on good terms with it heed the priority more readily; families at odds with it, less.
   - Its stance on the priority moves the town's backing (`CommunityPriority.get_town_backing`) by a weighted share.
3. **The leader acts by its own values.** This is where the removed Reward helping control goes. Once a season, the leader household decides, through the usual desire, terms and noise machinery, whether the gathering:
   - **gives first claim to those who helped** (the old incentive): wanted by leaders who prize service and reciprocity;
   - **gives first claim to a family in need** (`grant`): wanted by charitable and empathetic leaders;
   - **favours its own kin or friends** with first claim: what a self-interested or acquisitive leader with strong kin ties may do, which the town then judges as favouritism (`judge_distribution`).

   These are the leader's likely priorities on its card. The player sees what they are choosing before they choose.
4. **Settling disputes.** When a field claim is settled, a leader in good standing with both parties makes settlement likelier. A leader on bad terms with one party makes it less likely. This reuses `judge_settlement` and procedure regard.

**Succession and removal:**
- If the leader household leaves or passes on, the office is vacant and the player appoints again from the current three.
- Whether the player may remove a sitting leader is decision R2.

**Before Village:** there is no office. Recognition and influence still emerge, and the three most influential families show on the Community page, so the player can watch interests form before they can empower one.

### 2.4 The Community page

**Removed:** Reward helping, Honour a family (and the Families page's honour buttons).

**Added:**
- **Regard in town:** the families most admired and most resented, each with its strongest reason.
- **Most influential:** the top three, with how each one's influence is made up.
- **From Village:** the leader card (or "appoint a leader"), the three candidates, and what each would do.

The page stays the place where the important decisions are made (owner note, 2026-11-01).

**Saves:** existing saves keep their `incentive` setting until a leader is appointed. After that, the leader decides. Old honours stay in memories and standing.

## 3. Decisions for the owner

- **R1. The office's name.** The player is Expedition Leader, then Elder. Suggestions for the appointed household: "Headman", "Speaker of the Gathering", "Reeve". Recommended: Speaker, as it says what the household does without implying a government.
- **R2. Can the player replace a sitting leader?** Recommended: yes, but at a cost. The deposed household and its supporters lose trust and form a grievance, and a household turned out once can't be appointed again for a year. This is the seed of political opposition, without building it now.
- **R3. Preparedness as a fifth kind of contribution.** It needs household reserves, which exist only on the household-economy branch. Recommended: build the four existing kinds here, and add preparedness when the two branches meet.
- **R4. What the leader may decide.** The proposal gives it first claim on the stores (for helpers, the needy, or its own) and a voice in disputes and in the priority's backing. It doesn't set the priority, the stores rule or wisdoms; those stay the Elder's. Is that the right line?
- **R5. Tuning before evidence.** The weights above (influence parts, admiration thresholds, the leader's double voice) are first guesses. As with earlier milestones, I'd fix them before the comparison and change them only on evidence.

## 4. Validation plan (not run yet, per the owner)

Matched runs on the same seeds:
- with the new system against the current one, where the stand-in player never honours anyone;
- over six years, on ordinary, stressed and difficult sites;
- with several wisdom pairs.

**Measures:**
- which families become most influential and why: the parts of their influence, their values and trades;
- how often the top three change;
- whether different families come to lead in different cultures;
- admiration and resentment, and how often families disagree about the same household;
- trust and departures.

**Leadership:** at Village, the same town is replayed with each of the three candidates appointed. It compares:
- trust;
- the priority's backing and how families respond to it;
- who gets first claim;
- favouritism resentment;
- disputes settled;
- departures and growth.

The question is whether the choice of leader matters, and differently for each candidate.

## 5. Phases (after approval)

1. **Noticing and influence:** `TownRegard`, the seasonal notices, influence and the top three, and removing the honour controls. Tests:
   - a craft family admired by craft-minded neighbours and resented by levelling ones;
   - influence from different sources;
   - no player action needed.
2. **The leader:** the appointment, the town's judgment of it, the leader's voice, and its seasonal decisions on first claim and disputes. Then vacancy and replacement (per R2). Tests for each.
3. **The Community page and saves.**
4. **Validation** (section 4), when the owner asks for it.
