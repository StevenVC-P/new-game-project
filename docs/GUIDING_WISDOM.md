# Guiding Wisdom

Owner brief (2026-10-31): the player is an unseen guiding hand; families make their own decisions, but the values a settlement promotes shape how families behave and what kind of community develops over generations. This is the founding-town foundation of a system that will later reach government, law, crime and justice; none of those is built.

Code: `scripts/domain/guiding_wisdom.gd` (`GuidingWisdom`), with hooks in `TownSocial`, `SocialDecisions`, `FamilyInitiative`, `HouseholdMemory`. Tests: `tests/guiding_wisdom_validation.gd`; comparison: `tests/sim/wisdom_check.gd`. Branch `feature/guiding-wisdom` (from the Step 3 integration branch), not merged.

## Owner Decisions (2026-10-31)

1. The wisdoms replace the Ask buttons of the social expectations; the expectations stay visible as evidence of the culture forming. No duplicate appeal weights.
2. Prepare for Hard Times works within existing decisions; no household reserves. Families choose their work once (they do not reconsider it), so only real work choices count.
3. Take Pride in Your Work: Perfectionist and Expedient output numbers unchanged; work through improvements, maintenance and effort; no flat productivity bonus; name the limitation if craft cannot matter yet.
4. Lessons that bear a held wisdom out get a modest weight, as if the family held the value at its weakest; families must still experience and do the thing to learn from it.
5. Choices are fixed in this prototype: the Expedition Leader chooses two; a Village's leader is an Elder with a third.
6. Wisdom and Community Priority may reinforce or conflict; both are tested.

### After the comparison (owner, 2026-10-31)

1. **Respect:** kept as designed; no contested home sites added for frequency. Its relevance should grow with settlement size and land scarcity.
2. **Prepare:** household reserves are the eventual direction. For now, dangerously low tools or wood count as threats to winter preparedness, as low food does; no guaranteed safety, trade-offs kept. Built (below, version 4).
3. **Pride:** craftsmanship and goods quality come later, not now. Investigate whether workplace upkeep can carry a genuine recurring household decision; if not, document the dependency (below: it cannot).
4. **Learning:** seasonal priorities should still teach only through actual experience; Guiding Wisdom should shape how families interpret and internalise lessons over time. Examined below: the split is real in the code, but the wisdom's part is small and does not grow over time.
5. **Counter-qualities:** no manufactured dissent, no faster value change; the gradual learning system stays.

## The Four Wisdoms

| Wisdom | The expectation it is | Decisions it concerns | Qualities following it tends to grow | Counter-qualities resisting it tends to grow |
|---|---|---|---|---|
| We Endure Together | helping neighbours (existing) | giving spare time to a neighbour building its first home or in hardship; sharing food in a shortage | Mutual Aid, Communal Labor | Self-Governing, Solitary |
| Respect What Others Build | respecting claims (existing) | making amends for trampling a field; pressing for land another family holds | Respect for Holdings, Private Holdings | Common Stores, Sharing |
| Prepare for Hard Times | keeping something back (new) | not giving up a ration a family could spare; holding off improving in autumn and winter, except work whose output the town is short of (food, wood under 20, tools under 10); taking up whichever of food (stores under three months), wood or tools is short | Thrifty, Fatalistic | Hopeful |
| Take Pride in Your Work | doing work well (new) | improving hand work into a proper workplace; long days on the family's own building | Perfectionist, Keepers of Craft | Expedient |

Every quality and counter-quality is read by some existing decision: Mutual Aid, Communal Labor, Self-Governing, Solitary, Sharing and Common Stores by helping, sharing and land; Respect for Holdings and Private Holdings by disputes and land; Thrifty by sharing; Fatalistic and Hopeful by improving and by how much hardship a family bears before leaving; Perfectionist and Expedient by their existing output effects (-10% and +10%, unchanged); Keepers of Craft by how families judge craft honours.

## How It Works

- **A wisdom is what the gathering asks.** Choosing one promotes its expectation: the existing norm appeal (1.5 × the family's receptiveness) in the decisions above, and the conformity a norm's acceptance brings. No other weight. The two new expectations are weighed only while their wisdom is held, so a town without a wisdom plays exactly as before (tested).
- **Families answer by their own lights.** Every decision still weighs the family's needs, temperament, convictions, ties and the town's state; the wisdom is one reason among them.
- **Conduct becomes experience.** Each choice a held wisdom concerns is counted for the family (kept to it, or went its own way). Decisions families retake every week (improving, their hours) count only when the wisdom was at stake: the family came close enough that the appeal could have tipped it. At most once a season, once a family has met the wisdom at least twice, its conduct becomes an experience ("It lived by 'We Endure Together'", "It went its own way rather than keep something back"), and the existing lesson system draws its lesson: by its temperament and convictions, from several readings, including ones against the wisdom ("our own work waits while we help").
- **The wisdom frames lessons.** Any lesson (from any experience) that bears out a held wisdom's quality gets +0.5 support, as if the family held that value at strength 1. In the test, the same help that a plain town's family reads as "it is humbling to depend on others" is read under We Endure Together as "we should help others in turn".
- **Values still move a level a year at most** (`HouseholdMemory.add_evidence`, unchanged).
- **Conflicting wisdoms pull one decision both ways:** sharing in a shortage under We Endure Together and Prepare for Hard Times; improving before winter under Prepare and Pride.

## Leadership

Expedition Leader: two wisdoms, chosen from founding. When the town reaches Village (the existing `SettlementStage` criteria: 10 households, a family formed in the town, a clean season, the first winter survived), the leader is an Elder with a third slot. Mayor (with a separate Law category) waits for a defined town stage; `docs/SETTLEMENT_GROWTH_SCALE_MODEL.md` has only a direction for it.

## Relation to the Other Controls

- **Community Priority:** what the town needs now; changeable; an appeal on activities (food, homes, improvement, cooperation). Stacks with a wisdom (Endure Together with Cooperation reinforce; Investment pulls against Prepare before winter).
- **Guiding Wisdom:** what the town holds to; fixed; works through the expectations and through what families learn.
- **Social Expectations:** now "Customs forming", read-only: how far families keep to each expectation (habit, custom), and which wisdom asks it.
- **Law (later):** a custom a Mayor could make enforceable.

Choosing a wisdom does not count as the gathering changing its mind (the trust cost of frequent changes); trust otherwise works as before. A switching penalty waits for cultural reform.

## Older Saves

A town saved when the gathering asked for helping or respecting claims takes those asks as its wisdoms (up to the leader's slots); the two new expectations are added.

## Comparison (2026-10-31, `wisdom_check`, 12 towns per condition, same seeds and founders, 6 years with a year-3 snapshot)

No wisdom against each pair, chosen at founding and kept (pairs stay at two: a village's third slot is not used, so pairs compare like for like); and two stacks against their priority alone. Families lead, social model on, starting residential land. People: mean per town, and the mean town-by-town difference from the same towns without a wisdom (± its spread). Culture: share of families holding a value, against the same towns without a wisdom, counting only towns that still have families in both.

**Gameplay, year 6** (towns that kept their founding families; people, difference ± spread; Prepare rows are version 3, the kept version 4 is under "four versions" below):

| | Ordinary | Stressed (first winter's stores lost) | Difficult sites |
|---|---|---|---|
| No wisdom | 11/12, 73.6 | 11/12, 68.2 | 7/12, 42.5 |
| Endure + Respect | 11/12, +4.1 ±10.9 | 10/12, +7.0 ±16.5 | 6/12, -1.8 ±5.9 |
| Endure + Pride | 11/12, +3.2 ±11.3 | 10/12, +6.2 ±15.1 | 6/12, -2.3 ±6.0 |
| Respect + Pride | 11/12, +4.0 ±10.2 | 11/12, +5.2 ±13.5 | 7/12, -0.4 ±3.0 |
| Endure + Prepare | 9/12, -5.4 ±22.2 | 9/12, -0.4 ±26.4 | 7/12, +3.6 ±9.0 |
| Respect + Prepare | 9/12, -4.0 ±22.6 | 9/12, -2.8 ±24.8 | 7/12, +2.8 ±7.4 |
| Prepare + Pride | 9/12, -4.0 ±22.6 | 9/12, -3.5 ±24.4 | 7/12, +2.7 ±7.7 |
| *Cooperation priority alone* | 11/12, +10.2 | 11/12, +15.9 | 7/12, +6.0 |
| Endure + Respect with Cooperation (against Cooperation alone) | 11/12, +0.0 | 11/12, -1.0 | 7/12, +0.6 |
| *Investment priority alone* | 12/12, +4.3 | 12/12, +7.9 | 10/12, +21.6 |
| Prepare + Pride with Investment (against Investment alone) | 11/12, -1.6 | 11/12, -3.8 | 7/12, **-19.9** |

What families did differently (year 6, against no wisdom): help weeks +38 to +49 a town with We Endure Together, trust about +0.5 in every pair; disputes raised +6 to +10 with Respect What Others Build (the claims expectation also makes wronged families readier to press; unsettled disputes unchanged); long-day weeks +24 to +32 with Take Pride, about one more improvement; Prepare: shared food withheld (shortage shares in Prepare towns fall where Endure is not held), investment deferred before winter, food in store 50-65 days lower on ordinary land, 40 days higher on difficult land.

**Culture, year 6, ordinary** (percentage points of families holding, against no wisdom): Endure pairs Mutual Aid +21 to +27, Communal Labor +9 to +14 (already +16 to +19 at year 3); Respect pairs Respect for Holdings +5; Prepare pairs Thrifty +0 to +2, Fatalistic +1 to +3; Pride pairs Perfectionist about 0, Keepers of Craft +1 to +4; counter-qualities (Self-Governing, Solitary, Common Stores, Sharing, Hopeful, Expedient) within ±4. Mean distance over the fourteen values: the Endure pairs 4-5 points from no wisdom and from the others; Respect + Pride 0.9 from no wisdom. Stressed sites alike; difficult sites noisier (few families).

**The Cooperation priority alone grows Mutual Aid as much as We Endure Together** (+22 to +23): the same helping makes the same experiences.

### Prepare for Hard Times, four versions

The first two versions defined Prepare's occasions more widely than its meaning, and were corrected (no weights changed); all three are reported:

1. Hold off improving in autumn and winter *or whenever food ran under three months*, and take up food work *while the town grew less than it ate*: every town at its founding grows nothing yet, so all founders were asked to take up food work and none tools, and food improvements were held back exactly when food was short. Ordinary: 9/12, -10 people; stressed 9/12, -8; Investment's gain on difficult sites wiped out.
2. Holding off only in autumn and winter, never for food work while food is short: still 9/12 on ordinary land.
3. Also food work only while the *stores* run low (under three months), and a town holding any wisdom counts as having decided (the steady-decisions trust Endure and Respect towns already got). Still 9/12 on ordinary and stressed land: in two marginal towns, deferring tool and wood improvements before winter brings on the tool cliff; production falls, shortages follow (18 and 31 requests to share, none without the wisdom), families withhold food and leave. On difficult land the same caution is slightly ahead (+3 people, food +40 days). Without household reserves, Prepare can only withhold and defer; nothing it asks builds up.
4. (Kept; owner, 2026-10-31.) Tools or wood dangerously low count as threats to winter as food does: no hold-off for improving work the town is short of, and the expectation asks a family choosing its work to take up the short one. Same comparison, the four Prepare strategies rerun against the same baselines:

| Year 6, people (difference from the same towns) | Ordinary | Stressed | Difficult |
|---|---|---|---|
| Endure + Prepare | 9/12, -5.4 (v3 -5.4) | 9/12, -1.1 (v3 -0.4) | 7/12, +2.8 (v3 +3.6) |
| Respect + Prepare | 10/12, +0.4 (v3 9/12, -4.0) | 10/12, +1.0 (v3 -2.8) | 7/12, +2.0 (v3 +2.8) |
| Prepare + Pride | 10/12, +0.4 (v3 9/12, -4.0) | 10/12, +0.9 (v3 -3.5) | 7/12, +1.8 (v3 +2.7) |
| Prepare + Pride with Investment (against Investment alone) | 11/12, -1.6 | 11/12, -1.8 | 7/12, **-19.6** (v3 -19.9) |

   Respect + Prepare and Prepare + Pride now keep one town that every other strategy loses; that gain, not a recovered town, is the change. **The same two marginal towns are still lost under every Prepare pair, and the cause is at the founding, not before winter** (traced day by day in one of them): every town is founded with under three months of food, so Prepare asks founders to take up food work; tools then stand at 10-11, just above "dangerously low", so they do not count as short. The founder who otherwise takes up tool mending on day 25 takes up food instead; no one ever makes tools (families never reconsider their work), the store runs out by day 150, the proper workplaces fall back to hand work, and the town starves in its second year. Adding Prepare as the Elder's third wisdom in year 2 costs nothing (below), which fits. The Investment stack on difficult sites is unchanged and was not traced. No threshold was changed to rescue these towns.

## Elder's Third Slot (2026-10-31)

Tested on the Community page (a village shows "Elder · 2 of 3" and offers exactly the two wisdoms not held) and in saves (three wisdoms kept, no slot left); and in play: Endure + Respect with a third wisdom chosen the day the town becomes a Village, against the same pair alone, 12 towns, 6 years.

- Villages: 10/12 ordinary towns, 9/12 stressed, 5/12 difficult; median in year 2 (day 720; difficult day 1,050). The third wisdom was chosen in every one.
- Pride as the third: about 300 choices at stake and 106 seasonal lessons (66 lived by it, 40 went their own way); long-day weeks +13; people and culture unchanged (within ±1).
- Prepare as the third: about 120 choices (three in four followed), 23 lessons; people -0.7 ordinary, 0 elsewhere; culture within ±2.

The slot works; a wisdom added in year 2 has four years to act and changes little in that time, like the same wisdoms chosen at founding.

## What the Comparison Shows

- **Cultural divergence: partly.** We Endure Together makes recognisably different towns: about a quarter more of their families come to believe in mutual aid and working together, visible within three years. The other three change what families do (long days, pressed claims, withheld food, deferred building) but not, within six years, what they value; and no counter-quality emerges measurably.
- **Gameplay consequences: partly.** Prepare has real ones: a cost on ordinary land (two marginal towns lost), a small advantage on hard land, and it undoes the Investment priority on difficult sites (three towns lost against Investment alone). Endure's pairs are a little stronger under stress and a little weaker on difficult land. Respect and Pride: nothing beyond the spread. The community priorities move outcomes far more than any wisdom.
- **Why the cultures stay close:** occasions. Endure meets each family almost weekly (about 75-100 choices a town over six years, 30 lessons, plus every helping and sharing experience it frames); Respect about 10 choices (disputes are rare in young towns), Pride about 50 at stake, Prepare chiefly in shortages. A value needs about three lessons in one family to move a level; most families draw one or two from these three wisdoms in six years. And the qualities they would grow weigh little in decisions (Thrifty -0.25 in sharing; Perfectionist and Expedient only their output effects).
- **Stacking:** reinforcing adds nothing measurable (Endure + Respect with Cooperation equals Cooperation alone, though fewer families grow self-governing); conflicting costs (Prepare + Pride against Investment).
- **Within three years:** Endure's culture and Prepare's losses are visible; the rest is within the spread.

## Pride and Workplace Upkeep (investigated, owner 2026-10-31)

Whether existing upkeep can carry a genuine recurring household decision: **no, not without new mechanics.** How upkeep works: after 60 days' grace, every proper workplace takes one tool from the common store every 16-24 days and returns to full condition; without one it loses a quarter (`City.update_building_maintenance`). Output falls with condition. The only control is the player's per-building upkeep switch.

- **When tools are plentiful** (every ordinary town after its first year: hundreds to thousands in store) there is nothing to decide: a workplace is kept at full condition at no cost to anyone, and condition cannot go above full. Any "care more" choice would be a flat productivity bonus, which the owner ruled out.
- **When tools are short**, keeping one's workplace up means taking a tool the town's other workplaces need. That is a real trade-off, but it is about sharing a scarce store, so it belongs to We Endure Together and Prepare for Hard Times, not to craft. Pride asking a family to take the tool would deepen the tool cliff.
- **Upkeep costs families no time**, so there is no effort for diligence or pride to give.

**Dependency:** Pride needs one of these before upkeep can carry it: upkeep that takes a family's own time and has a better result than "working" (a part of the goods-quality system), or goods that can be better made. Until then Pride reaches improving and long days on own building, and it would gain a natural recurring decision from occupational reconsideration: staying with work a family has built up through a lean spell (`docs/OCCUPATION_RECONSIDERATION.md`).

## Learning: Priority Experience and Wisdom Interpretation (examined, owner 2026-10-31)

**How it is built:** a Community Priority teaches nothing by itself. It changes what families do (more help, more building together), and only those experiences teach. A Guiding Wisdom changes interpretation: any lesson bearing out a held wisdom's quality gets +0.5 support (`HouseholdMemory.experience`), and the family's own conduct toward the wisdom becomes a seasonal experience. The distinction is in the code.

**What it amounts to:** a temporary probe (not kept) counted every experience in 12 ordinary towns over six years:

| | Experiences (other than the wisdom's own) | Where the wisdom changed the lesson drawn |
|---|---|---|
| No wisdom | 585 | - |
| Cooperation priority | 1,126 (help 727) | - |
| Endure + Respect | 1,120 (help 605) | 191 (17%; help 10%, disputes settled 32%) |
| Endure + Respect with Cooperation | 1,264 (help 773) | 193 (15%) |

The wisdom's lessons on its own conduct add about 500 experiences, 20% of them reframed.

- **The priority works by quantity:** Cooperation doubles the help families give and receive, and Mutual Aid grows as much as under We Endure Together. That is the intended "through actual experience".
- **The wisdom's interpretation is real but small:** it changes the lesson drawn in about one experience in six (one in ten for help, where "neighbours can be trusted" is usually drawn anyway). It also makes no difference to how strongly a lesson is held.
- **It does not grow over time.** The +0.5 applies in full from the day the wisdom is chosen, equally to a family that supports it and to one with reservations, and it is unchanged once the expectation has become the town's custom. "Shaping how families internalise lessons over time" is not represented.
- **Possible direction (not built; owner decision):** scale the framing by how far the wisdom's expectation has taken hold in the town (its acceptance, already tracked as "Customs forming") and by the family's own stance. A young wisdom would then barely colour lessons, and a custom would colour them for families who hold it, not for those with reservations. This changes no rate of value change and adds no lessons; it only moves when and for whom interpretation applies.

## Limitations

- **Maintenance has no family decision** (Pride and Workplace Upkeep, above).
- **Craft has no quality model.** Perfectionist families produce less (an existing rule, unchanged) and nothing of theirs is better; Keepers of Craft only changes how families judge craft honours. Pride's gameplay effect is therefore through how much families improve and how hard they work on their own building, not through better goods.
- **Respect What Others Build has few occasions early:** disputes over trampled fields and contested land are rare in young towns.

## Open Decisions

1. **Prepare at the founding:** every town is founded with under three months of food, so Prepare always asks founders to take up food work; in two marginal towns this costs the only toolmaker. Options: accept it as Prepare's real risk; have Prepare's food ask wait until the town has stood a season; or let occupational reconsideration repair it (a family whose workplace stands short of tools reconsiders, and Prepare then asks for tools). No threshold was changed.
2. **Framing over time:** scale the wisdom's interpretation of lessons by the custom's acceptance and the family's stance (Learning, above), or keep it flat.
3. **Pride's dependency:** upkeep cannot carry it until upkeep takes family effort or goods have quality; occupational reconsideration can give it a decision sooner.
4. **Mayor and Law** wait for a defined town stage.

