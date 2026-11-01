# Emergent Recognition and Community Leadership

**Status: audit and proposal for owner review (2026-11-01). Nothing implemented.** Branch `feature/emergent-recognition`, from `feature/occupation-reconsideration`, so it stays separate from the household-economy work. Not merged.

Core goal (owner, 2026-11-01): a family can become powerful without the player's approval, and the player decides which of the community's emerging interests to empower.

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
