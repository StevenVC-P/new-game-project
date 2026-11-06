# E13 Local Value: Proposal

The design as the owner reviewed it on 2026-11-06, added to the roadmap by the owner the same day. A proposal: nothing here is built or tested, and the formula is a direction, not an approved final form. **No V0 until the owner authorizes it.**

Owner's terms: V0 helps decide the timing and scope of V1 and V2, so V2 isn't committed before S10 without evidence. Private-versus-communal conclusions stay provisional wherever missing market-aware behaviour could affect them. Food's hidden value may float; numbers stay hidden from players; value informs family decisions and never dictates them. Good and bad years wait for about S11. The long-term direction includes metal and paper currencies, which conflicts with older metal-only docs; resolution deferred.

## 1. Recommended formula

```
Local value = Anchor × Scarcity adjustment

Available by t = starting stock + expected production + expected imports
                 − expected losses, all accumulated to t
R(t)     = available by t ÷ claims by t
R'(t)    = R(t) if at least 1;  otherwise 1 − nearness(t) × (1 − R(t))
Coverage = lowest R'(t) across the year
Scarcity adjustment = (target ÷ coverage)^k, within limits
```

- **Scale:** coverage of 1 means every claim can just be met on time.
- **Nearness:** a distant shortfall counts partly, because families still have time to respond. A surplus counts in full.
- **Target:** this is the buffer a town wants above 1. It's also where good and bad years can act once S11 adds them.
- **`k`:** this follows the most urgent claim that can't be met. Wood short for hearths should move value far more than wood short for building.
- **Forecast:** it assumes current work continues, so it shows the pressure before anyone responds.
- **Imports and losses:** these stay in the formula but start near zero, because trader visits are irregular and spoilage doesn't exist until S10.

### The anchor: what makes goods comparable

**Your distinction holds: cost shouldn't set value directly.** Supply and demand set exchange value. Cost acts on producers, deciding whether work is worth doing. Over time, families moving towards better-paying work pulls value towards cost. Geography, callings and slow switching can hold it away from cost for a long time, and that's what produces specialised towns.

**The gap is comparability.** Scarcity alone can't say what one tool is worth in wood when no trade has happened. Pooled towns never trade, and private towns trade thinly (58–877 units per town in the S9 review). So the anchor needs an estimate to fall back on:

```
Anchor moves slowly towards the evidence:
  thin or no exchange:  local work value
  regular exchange:     traded price with its scarcity removed
```

- **Local work value** is the labour to make one unit here, plus inputs and upkeep. It comes from actual conditions like thin woods, deposit grade and skill, so it's derived rather than hand-assigned.
- **Removing scarcity before learning** is essential. Otherwise a long shortage raises the price, the anchor follows, and values climb without limit.
- **Input loops** such as tools needing wood and wood work needing tools use last month's values.
- **`VALUE_IN_GRAIN`** remains the comparison baseline in V0, then retires for town values if V0 supports that.

**This matters already.** A farm makes 4 food a day and a woodcutter 6 wood. At equal labour, wood is worth about 0.67 food, but the table says 1.5. So a woodcutter's day counts as 9 grain against a farm's 4, before upkeep, seasons and walking. That may partly explain why woodcutters look so rich, which is another reason to keep that finding provisional.

**Remaining limit:** this removes the per-good price list, but a few general settings remain: target, `k`, nearness and learning speed. In a pooled town, a value is an internal estimate with no exchange to correct it.

## 2. Physical stock, accessible stock and market offers

**Keep three separate signals rather than blending them.** Each answers a different question.

| Signal | Question | Measured by | Used for |
|---|---|---|---|
| Physical coverage | Is there enough in town? | Same formula, all stock including larders | Whether the town must produce or import more |
| Accessible coverage | Can those who need it reach it? | Same formula, counting only what each claimant owns, is entitled to, or can find on offer | The town reference value |
| Exchange | What actually changed hands? | Offers, wants people can pay for, and prices | Evidence for the anchor; what players see |

**The town reference should use accessible coverage.** Value is economic, so unreachable food shouldn't make food cheap. Physical coverage is kept beside it as its own signal.

The important detail is that **claims are netted household by household**. Comparing all claims against market offers would be wrong, because a self-sufficient farm needs no market. Each claim is met first from what that household holds, then its entitlement to the commons, then what's offered. Reserves count only for families who may draw on them.

| Town (illustrative) | Physical | Accessible | Reading |
|---|---|---|---|
| Pooled, 1,000 food, 1,000 claims | 1.0 | 1.0 | Same by construction |
| Private, food spread evenly | 1.0 | 1.0 | Everyone has enough, so no false alarm |
| Private, food held by a few who won't sell | 1.0 | 0.5 | Hunger amid plenty |
| Any town, truly short | 0.5 | 0.5 | Real shortage |

**The gap between the two coverages becomes a measure in its own right.** More production fixes the last row, while the third needs exchange, sharing or policy. Those call for very different responses, and the gap also gives you plain-language messages without showing a number.

**Need and ability to pay are also separate.** A family with nothing to trade has a real claim but no market demand, so high need can sit beside weak trading. Accessible coverage records the need, and exchange records what could be paid. That difference is a real outcome, so it shouldn't be smoothed away.

The S9 demand-to-supply ratio may now double-count, since offers already feed accessible coverage. V0 should test whether it adds anything.

## 3. Continuous and intermittent demand

Because `R(t)` compares accumulated supply with accumulated claims, one measure handles both. For steady use it behaves much like days of cover, and for lumpy demand it tests whether each claim can be met when it falls due.

| Claim type | Examples | Timing |
|---|---|---|
| Continuous | Eating, heating, running workshops | Daily, by season |
| Periodic | Tool upkeep | Interval timers, already modelled |
| Committed | Materials for queued building | Known amount, estimated date |
| Latent | Stone homes families would build if they could | Uncertain, needs estimating |

**Latent demand is the trap.** Family material choice only considers what stores can supply. So with no stone in town, nobody plans a stone home, demand looks like zero, and value hits the floor. That's exactly when stone should matter. V0 should estimate latent demand from choices made with supply ignored (`MaterialChoice` already has this option), plus use over the past year.

**Two safeguards for lumpy goods:**
- Treat at least one typical project as a claim when latent demand exists, so coverage isn't measured against nothing.
- Smooth value more for lumpy goods, so one purchase doesn't swing it.

After S10, claims for food should be counted across food goods as one need, since one can replace another.

## 4. What V0 must measure

V0 stays in the harness, and gameplay logs must be byte-identical with it on or off. It should log the monthly raw inputs, not just results, so formula variants can be tested on saved logs without repeating runs that take hours.

| # | Question | Measure | Supports |
|---|---|---|---|
| 1 | Is a year's forecast believable? | Predicted against actual stock at 1, 3, 6 and 12 months | The horizon and nearness |
| 2 | Does it warn in time? | Lead time and false alarms for shortages, against existing family signals | Whether V1 is worth building; it must beat those signals |
| 3 | What causes hunger? | Hunger days split into true shortage and access failure, by compact | The private-versus-communal question |
| 4 | Does the access signal behave? | Physical and accessible identical in pooled towns; how large the gap gets in private towns | Section 2's design |
| 5 | Does intermittent demand work? | Share of demand by claim type; goods at the floor that were later wanted | Claim handling |
| 6 | Which anchor works? | `VALUE_IN_GRAIN`, work value and learned value against S9 prices; wealth and inequality under each | Retiring the table |
| 7 | Is it stable and meaningful? | Monthly swings, time at limits, sensitivity to settings, differences by land with traced reasons | Settings, and whether results read sensibly |
| 8 | What does it cost? | Monthly pass at 10, 100 and 250 households | Scale |

**V0 can't test feedback.** Nothing reacts to the values, so boom-and-bust behaviour only appears once families respond. V2 needs its own stability gate.

## 5. Proposed roadmap entry (draft, not added)

> **E13 Local Value.** A town-specific value for each good, from projected scarcity and an anchor that emerges from the economy. It informs decisions and never dictates them. Numbers stay hidden from players. No new goods or categories.

| Stage | Depends on | Scope | Gate to proceed |
|---|---|---|---|
| **V0 Observe** | S9b reviewed, owner authorizes | Harness only | Gameplay identical; the section 4 report reviewed |
| **V1 Town Reference** | V0 | Local values in market and wealth; signals preserved; food floats | Pooled towns identical day for day; saves and determinism hold; owner reviews how far exchange diverges from values |
| **V2 Work Decisions** | V1; timing set by V0 | One reasoned term; old scarcity terms retired one at a time | Fixed weights; matched on/off runs; no boom-and-bust cycle; callings, values and survival remain meaningful |
| **V3 Household Valuation** | V1, likely V2; Track C and S18 | Different exchange terms by household | Differences explained by need, values or expectations |
| **V4 Regional Valuation** | A second economy, merchant families | Value gaps drive trade | Separate design |

**Links to other work:**
- **S10:** needs a decision on how several food goods relate to the grain display. This could pull V1 ahead of S10.
- **S11:** good and bad years feed target and forecast confidence, and aren't added before then.
- **V2 timing:** I'd bring it before S10 only if V0 shows access failures and missing work signals materially shape private results. Otherwise it follows S11.
- **Private-versus-communal conclusions:** provisional until V2 has been tested, wherever missing market-aware behaviour could affect them.

**Recorded and deferred:**
- **Currency docs:** the metal-and-paper direction conflicts with `ECONOMY_MODEL.md` §1 and §7, and the conflict stays open for now.
- **Currency value:** this formula can't price money. Coin and paper have little or no use demand, so they'd sit at the floor. They'll need a value source based on acceptance, which should be designed with currency.

## Decisions for later

These can wait until you've reviewed S9b:
1. Does accessible coverage set the town reference, with physical coverage kept as a separate signal? I recommend yes.
2. Should a family's keep-back count as unavailable? It's the simplest reading of "unwilling to exchange", but it makes a fixed 60-day rule shape value until V3.
3. Is a small set of general settings acceptable, given it can't be eliminated entirely?

