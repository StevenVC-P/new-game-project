# Economy Model

Firm owner decisions on money and the economy (2026-10-19). This is the authoritative economy direction. It supersedes the credit-to-currency path in `docs/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md` (see "Relationship To Earlier Docs"). It sits under `docs/GAME_VISION.md`.

Decisions marked **Default** were set during planning to make the model complete; the owner can change them without reopening the rest.

## Core Pattern

Pre-modern economies ran two systems at once, and this game does too:

- **Inside a settlement:** shared stores, in-kind contributions, and household work. Little or no coin early.
- **Between settlements:** metal. Silver is valued everywhere because it is scarce and durable. Powers stamp it into coin.

Coin spreads inward from trade as the settlement grows, because it makes life simpler and more stable.

## Decisions

### 1. Money is metal plus an issuer

- Precious metal is a **real mined good** with deposits on the map.
- A **coin** is metal stamped by an issuer. Its value is its metal content plus trust in the issuer.
- Each established civilization has its own coin at game start. There is no universal gold.
- **Debasement** (less metal per coin) is a policy: short-term treasury gain, long-term loss of trust in that coin.
- **Trust in a coin** comes from:
  - the **strength of the issuer's economy and military** - can this power keep producing, trading, and protecting what backs its coin?
  - the **value of the underlying metal** - how much real metal is in the coin, and how much that metal is worth.
  Both apply to the player's own coin and to every established power's coin.
- **Default:** silver is the only coin metal at first. Copper small change and gold high-value coin can be added later if they earn their place.

### 2. Two pockets: households and the state

- **Households** hold wealth as a level (stored goods and status first, coin once it circulates), not a transaction ledger. Household wealth drives prosperity, ambitions, resilience in bad years, and migration.
- **The state** holds a treasury used for buildings, defense, trade, and policy.
- **Taxes** connect the two pockets.
- At town scale and above, **Houses** (`docs/HOUSES_AND_LINEAGE_MODEL.md`) pool their member families' wealth and hold concrete assets such as workshops, land, caravans, and coin. Wealth then has three holders: ordinary families, Houses, and the state.

### 3. Local scarcity prices

- Each settlement has its own price for each good. It rises when stock is short versus demand and falls in surplus.
- Price gaps between settlements are what make trade worthwhile.
- There is no global market.
- **Default:** before coin, value is measured in **grain** (prices read as grain-equivalents). After coin, in the coin the settlement uses.

### 4. Direct control first, then incentives

- **Hamlet:** the player assigns families directly (current behavior).
- **Village and beyond:** the player increasingly works through priorities, wages, tax relief, and policy, and families choose their work.
- **Government type** sets how much direct control remains, from command-style to market-style. Culture reacts to that choice like any other policy (`docs/GAME_VISION.md`, Government, Laws, And Policy).

### 5. Merchant families carry trade

- Trade is a **household responsibility**. Merchant families and their caravans move goods along routes, chasing price gaps.
- The player builds routes and sets import and export policy, tariffs, and priorities.
- Caravans travel through real regions and can be raided by bandits, which ties trade to defense and to clearing bandits off the map.
- The current manual trade menu is an acceptable prototype until merchant families exist.
- **Any trading entity can always refuse** a trade: established powers, rival towns, and merchant families alike. Refusal can come from price, relations, culture, or policy.

### 6. Taxes: in kind, then coin

- **Early:** tithes of grain and goods, and labor owed to the settlement.
- **Once coin circulates:** coin taxes become possible.
- Tax rates and types are policies, and culture can resent them.

### 7. No credit or debt

- There are no loans, interest, city credit, or lending between powers.
- Village shared stores and in-kind tithes still exist. They are pooled goods and taxes, not credit.
- A settlement's **own money** comes from **minting coin from metal**, not from obligations becoming currency.
- This keeps the economy readable and avoids bookkeeping as gameplay. It can be revisited later only by explicit owner decision.

### 8. Coin is adopted because it helps, not because it unlocks

Money is not a scheduled feature. It arrives when the player chooses it, because it makes life simpler and more stable. The design therefore needs:

- **Barter with real friction, felt through outcomes rather than shown as a penalty:**
  - a trade only happens if the partner wants what you have
  - what you get is set by supply and demand on both sides; there is no fixed "barter loss" number, but goods the partner does not need fetch little
  - in-kind wealth is bulky to store, and food wealth spoils
  - in-kind taxes need storage and handling
- **Coin that removes that friction:**
  - coin trades with anyone who accepts that issuer
  - coin does not spoil and stores compactly
  - household savings in coin carry families through bad harvests, which is the "more stable life"
  - merchants with coin can reach farther markets

The player then has two paths:

| Path | Requires | Gains | Costs |
| --- | --- | --- | --- |
| **Use a neighbor's coin** | sell goods to that power to earn it | easy, immediate access to their markets | economic dependency; the issuer gains influence over you; their debasement or collapse hits your households' savings |
| **Mint your own coin** | a metal source (mine or trade), a mint, and enough trust (stability, reputation, influence) | independence; seigniorage for the treasury; your coin can spread as influence | slower and harder; a weak or debased coin is discounted by others |

If the player's coin becomes widely used by others, that is a path to economic dominance.

## Deliberate Simplifications

What the game does not simulate, so the economy stays readable at a slow, contemplative pace:

- individual transactions between households (flows are aggregated per settlement)
- banking, interest, or credit of any kind
- exchange-rate markets (a coin's value comes from metal content and issuer trust)
- a global price board
- per-person wallets (wealth belongs to households)

## Build Order

The economy grows in the same order the player experiences it:

1. **Current loop:** food, shelter, labor, tools, maintenance. No prices or money.
2. **Barter with the neutral town:** the first trade reason, with real barter friction. Grain-measured local prices can appear here as a readable value scale.
3. **Household wealth and in-kind taxes:** households accumulate stored-goods wealth; the state collects tithes.
4. **Merchant families and routes:** trade becomes a household responsibility with caravans.
5. **Foreign coin:** established powers' coin can be earned and used; dependency and influence effects begin.
6. **Minting:** metal deposits, a mint, debasement policy, and the player's own coin.

Each step should only start when the step before is stable and fun, consistent with the household-first rule that money must never replace the survival economy.

## Relationship To Earlier Docs

`docs/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md` remains useful for:

- the early Subsistence and Storehouse modes
- the principle that money must not replace the survival economy
- player-facing language guidance (concrete settlement terms over finance jargon)

It is superseded on:

- obligation ledgers, city credit, credit trust, default risk, and transferable credit as currency
- its implementation phases 3-7

## Open Questions

None currently. Resolved 2026-10-19: trust in a coin comes from economic and military strength plus metal value; barter friction is felt through supply and demand outcomes, not shown; any trading entity can refuse.
