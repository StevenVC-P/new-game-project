# S7: Contributions by Category (design, before building)

Proposed 2026-11-05, for the owner at the S4 review point. The card (roadmap §7) sets the rules; this is how they would be built, and one sequencing risk.

## Proposed design

- **Categories** (five, so the player's choice is readable):
  - food;
  - wood;
  - stone and clay (stone blocks, cut stone, bricks, lime);
  - tools;
  - crafted goods (everything else a workshop makes).
- **The split:** each day a holding's output goes the rate's share to the community and the rest to the family's share (`TownLedger.credit`). Side work (gardens, gathering) stays wholly the family's, as now.
- **Giving more:** monthly, a family may give part of its share beyond its own needs to the community. The amount is a weighed decision with reasons, using the terms the property doc listed:
  - more from Common Stores, Sharing, Communal Labor, Deferential, and trust in the gathering;
  - less from Private Holdings, Acquisitive, Thrifty, Self-Governing, and distrust.
  - This is the one new value-driven decision. It doesn't touch occupation scoring.
- **Eating:**
  1. the family's own food above its larder target;
  2. then its share in the store;
  3. then the common table (the community's food);
  4. then its larder reserve.
  - The table still feeds everyone; no exclusion (property doc §4.3's "giving little is judged, not punished" stays).
- **Building and improving:** paid from the family's share first, then the community's goods within today's store rule (S6's payer path).
- **Reading the family's own goods:** "can it pay" and the improvement cost read the share first (property doc C3).
  - Occupation choice changes only through these existing cost terms. No new weights on values.
- **Founding choice:** a new game asks for the initial rates. This would be one card beside the site survey shown when a founding site is picked on the world map, before Found, with three presets (communal 100%, shared 60%, private 20%) and the five sliders.
  - The pending choice would be held on the pending site and applied in `found_player_city_at_pending_site`. That is a small, focused change to the high-risk `main.gd` (Q4), checked by screenshot.
  - Old saves and comparison runs stay at 100% (D1).
- **Player control afterwards:** the same five rates on the Community page, under Shared resources, beside the Treasury card.
- **No mood term** for the rate itself (card): families respond to what they actually hold and receive.

## The sequencing risk

**Low rates can't yet show their viable path in S7 alone.**
- In a private town, a specialist (toolmaker, quarrier) keeps its tools or stone but needs food from others. Before S8 (asking the commons and neighbours) and S9 (the market day), the only routes are the thin common table and the existing sharing in shortage.
- So S7's matched runs at 30% and 10% will likely show specialists hungrier than at 100%. That is the absence of exchange, not a verdict on private towns.

**Proposal:**
- Build S7, S8 and S9 in order, each with its own report.
- Judge "both high and low rates have a viable path" at S9's review point (◆), not at S7's.
- S7's report would state the low-rate cost plainly and label it as expected until S9.
- The alternative is to bring a minimal food exchange forward into S7. That would blur S9's scope, so I don't recommend it.

## Validation (as the card)

- **Matched runs:** towns at 100/60/30/10% on ordinary, stressed and difficult sites, 6 years.
- **Measures:**
  - treasury size;
  - families' own wealth and its spread;
  - who funds improvements;
  - hunger and deaths by trade;
  - departures.
- **Neutrality:** at 100% the runs must equal S6's.
