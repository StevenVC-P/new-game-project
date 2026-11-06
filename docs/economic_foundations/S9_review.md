# S9 Review: Can Different Arrangements Succeed?

- **Build:** `852fc6a` (S9, **before S5b**). The wood-oversupply defect that S5b fixes is present in every run here; see §4.
- **Runs:** compacts communal (100%), shared (60%) and private (20%), each without a commons reserve. Shared and private also ran with a 30-day reserve and grants to families in need (`-commons` labels).
- **Setting:** ordinary condition, no player, 8 starts per land, 6 years.
- **Against:** `F`, the pooled Track A build, on the same founder sets (start k is founder set k).
- **Tables:** `S9_summary_y6.md`.
- **"ok"** is strict: all founding families kept, all housed, fed this past month.

The owner's question: not whether every arrangement performs equally, but whether different arrangements can succeed under appropriate circumstances.

## 1. Short answer: yes, and none dominates

Towns ok at year 6, of 8 per land:

| Arrangement | Balanced | Fertile | Forested | Marginal | Rocky | Total of 40 |
|---|---|---|---|---|---|---|
| Pooled (F) | 6 | 6 | 4 | 3 | 2 | 21 |
| Communal | 6 | 6 | 3 | 3 | 2 | 20 |
| Shared | 6 | 5 | **5** | 3 | 1 | 20 |
| Private | 6 | 4 | 3 | 2 | 0 | 15 |
| Shared + reserve | 4 | 4 | 4 | 3 | 1 | 16 |
| Private + reserve | 1 | 1 | 1 | 0 | 0 | 3 |

- **Communal behaves like the pooled game**, as it should, though it isn't identical: families keep their side work and larders under any compact. Forested is the one real difference: 3 ok against 4, and a median of 5 people against 22.
- **Shared does best on forested land:**
  - 5 of 8 ok, a median of 45 people, 112 hunger days against 308;
  - 917 stone quarried and the most stone homes.
  - It does worst on rocky land: 1 of 8, 391 hunger days.
- **Private holds towns together but hungrier:**
  - on balanced land 6 of 8 are ok (as many as communal), with four times the hunger days (629 against 147);
  - fewer hunger deaths (7 against 13 on balanced land);
  - fewer towns ok on poor land.
- **The commons reserve, as set here, hurts both compacts** (§4b).

## 2. By founder set: circumstances decide

The same families on the same land succeed under one arrangement and fail under another. Full matrix in `S9_summary_y6.md`.

| Land | Founder set | Pooled / communal | Succeeds under |
|---|---|---|---|
| Fertile valley | 0 and 1 | empty | shared (both); shared with reserve (set 1) |
| Forested | 2, 4, 5 | empty or not ok | shared (all three); private (2 and 4); shared with reserve (4 and 5) |
| Forested | 1 | ok under pooled, empty under communal | — |
| Marginal | 1 | alive, not ok | shared only |
| Marginal | 7 | empty | private only |
| Balanced | 3 | empty | shared only |

- **Some founder sets fail everywhere:** balanced set 1, and most rocky sets (2–7) under every arrangement.
- **Rocky land:** only sets 0 and 1 survive. Private keeps three towns alive (none ok) where the others keep two.

## 3. Ownership, help and the market

- **Holdings follow the compact:**
  - private families together hold more than the community (about 6,000–7,500 food-worth against the community's 2,000–4,000, on balanced, fertile and forested land);
  - holdings are less unequal under private than under shared (gini 0.5–0.6 against 0.75–0.8): more is in families' hands, so the woodcutter's lead is a smaller share.
- **Help rises as the rate falls:**
  - families give more to the community the less it takes (private 925–3,400 given per town on all but rocky land; communal 0);
  - neighbours' help is almost only under private (about 300–1,000 food a town, less on rocky land).
- **The market works and is uneven:**
  - 58–877 units change hands per town under private;
  - **woodcutting families end far richer than farm families under every compact** (private balanced: 1,813 against 631 food-worth);
  - yet woodcutting families go hungry most often: under private, about 11,000 short family-days across the 39 woodcutting families still there at year 6, against about 10,000 across 148 farm families (the same holds under the other compacts). Their wealth is mostly wood no one needs, and food is what they lack.
- **Wood piles up under compacts:** a median 325–860 wood in store at year 6, against 105 pooled.
  - Families keep their own wood gathering under a compact, and before S5b nothing weighed wood beyond the winter.
  - Much of the woodcutters' "wealth" is this unsellable wood.

## 4. Caveats and open questions

a. **These runs predate S5b.** Wood oversupply is the defect S5b fixes, and it is larger under compacts than pooled. It likely bears on woodcutter wealth, farm hunger and the market's prices. **I recommend repeating these five comparisons once S5b is in the stack.** Owner's call.

b. **The reserve's danger gate (question for the owner):**
  - The reserve feeds only families "in danger": five short days this month, a severe month, or considering departure (`TownCommons.is_in_danger`, S8).
  - The month's count starts again each month, so a family not yet severe goes short up to five days every month before the reserve opens to it.
  - In private towns the community's share is small and mostly below a 30-day reserve, so the open table is nearly always closed. Private with reserve is the worst arrangement everywhere: about 1,000 hunger days per town, 3 of 40 ok.
  - Is that the intended price of a cautious reserve, or should danger carry over from the month before?

c. **"Short beside the commons" overcounts.** It is measured at the end of the day, after the day's harvest has come in. Communal towns with no reserve give its floor (about 350–780 family-days), so compare against that, not zero.

d. **Not modelled yet:**
  - acceptance and compliance with the compact;
  - fuel asking;
  - grants of goods other than food and wood;
  - fences are community-paid.

## 5. My reading of viability (S9's judgment; the owner decides)

- **Each arrangement has circumstances where it succeeds.** Shared suits forested and fertile land with these founders. Private keeps towns standing on balanced land at the cost of hunger, and saves one marginal founder set. Communal matches the pooled game.
- **No arrangement makes cold or poor land safe.**
- **The founding choice changes outcomes** for the same families on the same land, so the player's decision matters.
- **Viability isn't tuned.** The one thing I'd act on before judging further is §4a. §4b is a design question.

## Proposal still waiting: market worth in choosing work

From the S9 report:
- **What it would add:** families weighing what their work would fetch at market when they choose or change work (property doc §4.5).
- **Why it is held back:** it is a new term in occupation scoring, the kind of change the owner asked to see before it is built.
- **What it would do here:** families would see that wood fetches little and food a lot, and might lean toward food work under private compacts.
- It is not built, and waits for the owner's approval.
