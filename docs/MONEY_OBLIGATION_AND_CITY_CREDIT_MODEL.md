# Money, Obligation, and City Credit Model

This document is a future-facing design model. It does not describe current implementation unless explicitly stated. The current first-playable loop remains focused on food, shelter, labor, tools, maintenance, production buildings, pressure management, and action guidance.

The economic north star is household-rooted civilization simulation. Households are social and economic units, not generic worker slots or anonymous account rows. Any later money, credit, or obligation system must preserve that foundation.

## Design Vision

Money is not a starting resource. Early settlements should begin with households, needs, goods, work, trust, storehouses, and promises. Currency should emerge as a social and economic institution after people believe obligations can be honored.

Core principle:

> Debt becomes currency when a recognized obligation becomes redeemable, transferable, and trusted.

In the early game, households need food, shelter, useful goods, and meaningful responsibilities. They may contribute to common stores, receive rations, trust city leadership, or become strained by unmet promises. Those pressures should come before abstract finance.

Money is a mature form of trusted obligation. It should not replace the survival economy; it should grow out of surplus, backing, trust, recordkeeping, and exchange.

## Economy Progression

### Subsistence

- Needs: handled directly through household work, local gathering, production, and immediate consumption.
- Exchange: mostly direct goods and responsibilities; households care about concrete needs.
- City tracks: food, shelter, labor, tools, maintenance, buildings, and immediate pressure.
- Households experience: survival pressure, shelter strain, assignment fit, and reliance on direct goods.
- Player sees: resources, pressures, production, housing, and action hints.
- Push to next mode: stable production, storage capacity, and enough surplus to ration intentionally.

### Storehouse

- Needs: handled through shared storage, contribution, and rationing.
- Exchange: households contribute goods or labor and receive access to stored goods.
- City tracks: storehouse capacity, stored food/tools/materials, ration pressure, and contribution reliability.
- Households experience: trust or distrust in whether stored goods will meet future needs.
- Player sees: "Economy: Storehouse", stored backing, shortage pressure, and rationing clarity.
- Push to next mode: repeated contribution and ration promises create recognizable obligations.

### Obligation Ledger

- Needs: still grounded in goods and labor, but promises become tracked.
- Exchange: the city recognizes who has contributed, who is owed support, and which promises are pending.
- City tracks: aggregate obligation pressure, promised goods/labor, missed obligations, and trust strain.
- Households experience: a sense that contribution creates claims, but not yet freely spendable money.
- Player sees: "Obligation pressure is rising" or "Storehouse promises are stable."
- Push to next mode: obligations become regular, recognized, and backed by storehouse reliability.

### City Credit

- Needs: handled by goods, production, and storehouse backing, with city credit as a trusted claim.
- Exchange: households may accept city credit because they believe it can be redeemed later.
- City tracks: city_credit_issued, credit_trust, storehouse_backing, obligation_pressure, and default_risk.
- Households experience: partial willingness to accept credit instead of immediate goods when trust is high.
- Player sees: "City credit is strained by weak food backing" or "City credit is trusted."
- Push to next mode: credit becomes transferable between households and reliably redeemable.

### Accepted Currency

- Needs: still require real goods and production, but credit circulates more easily.
- Exchange: households accept transferable city credit in place of direct barter in many situations.
- City tracks: acceptance, backing, credit strain, scarcity, and trust stability.
- Households experience: credit as useful, but not magical; shortages still make direct goods more attractive.
- Player sees: "Households prefer direct goods during shortage" or "City credit is widely accepted."
- Push to next mode: other cities begin accepting, discounting, or rejecting local credit.

### Trade Currency / Regional Currency

- Needs: local survival remains concrete, while regional exchange uses recognized credit or currency.
- Exchange: cities trade through accepted claims, discounted credit, or regional currency.
- City tracks: trade_credit_discount, external trust, trade reputation, and default risk.
- Households experience: local prices or access may be affected by outside acceptance and scarcity.
- Player sees: "Traders discount your credit" or "Regional merchants accept city credit."
- Push forward: stable multi-city trust networks and transferable obligations.

## City-Level Concepts

These are design concepts, not current code unless explicitly implemented later.

- `economy_mode`: the city's current economic organization, such as Subsistence, Storehouse, or City Credit.
- `storehouse_backing`: how strongly real goods and capacity support promises or credit.
- `obligation_pressure`: aggregate strain from promises, ration expectations, and unmet claims.
- `city_credit_issued`: how much city-recognized credit exists.
- `credit_trust`: household and trader confidence that credit can be redeemed.
- `household_credit_acceptance`: aggregate willingness of households to accept credit.
- `trade_credit_discount`: how much outside cities or traders discount local credit.
- `default_risk`: likelihood that the city cannot honor obligations or redeem credit.

The first implementation should be aggregate city-level pressure, not household-to-household debt webs. The city can summarize whether promises are backed, strained, or breaking before individual household ledgers exist.

## Household-Level Concepts

Possible future household concepts:

- `credit_balance`: credit held by a household.
- `obligation_balance`: obligations owed to or by a household.
- `trust_in_city_credit`: household confidence in city-backed credit.
- `accepts_credit`: whether a household will accept credit in place of direct goods.
- `direct_goods_preference`: tendency to prefer food, tools, shelter, or material goods over abstract claims.
- `contribution_history`: remembered pattern of household contribution to storehouse, labor, or defense.

Household-level credit/debt is future scope. It should not be implemented before aggregate city-level obligation pressure is useful and understandable.

Households should remain readable social and economic units. Credit systems must not flatten them into anonymous account rows. Differences in preference, contribution, trust, household stage, and need should remain meaningful to the player.

## Debt Becoming Currency

The transformation should be gradual:

1. Personal obligation: one household or actor owes another a concrete favor, good, or support.
2. Recognized city obligation: the city records or recognizes that a claim exists.
3. Redeemable storehouse claim: the claim can be exchanged for goods or support from city stores.
4. Transferable city credit: the claim can move between households because others trust redemption.
5. Widely accepted currency: the credit circulates because many households accept it.
6. Externally accepted trade credit: other cities accept it at full value, discount it, or reject it.

Four requirements define the shift from debt to currency:

- Recognized: the claim is legible to the city or community.
- Redeemable: the claim can be exchanged for goods, services, or obligations.
- Transferable: the claim can be passed to another party.
- Trusted: enough people believe the claim will be honored.

If any of these fail, the system should drift back toward direct goods, storehouse rationing, or obligation pressure.

## Player-Facing Language

Prefer concrete language over financial abstraction. The player should understand what is strained and why.

Good examples:

- "Economy: Storehouse"
- "City credit is not established."
- "Households prefer direct goods during shortage."
- "City credit is strained by weak food backing."
- "Traders discount your credit."
- "Obligation pressure is rising."
- "Storehouse backing is strong."
- "Credit trust is falling."

Avoid starting with abstract terms like monetary base, liquidity, fiat, bond market, or bilateral clearing. Those ideas may inspire systems, but the interface should speak in settlement terms.

## Strengths and Weaknesses

Strengths:

- Creates a distinctive household-first economy.
- Lets money emerge naturally from trust, surplus, backing, and transferability.
- Supports progression from city manager to civilization leader.
- Allows separate but interconnected local economies.
- Makes debt and credit meaningful without generic universal gold.
- Keeps early survival pressure centered on food, shelter, labor, tools, and maintenance.

Risks:

- The system can become too complex.
- Debt can become bookkeeping instead of gameplay.
- Fluctuating value may be hard to explain.
- Hidden credit penalties can feel unfair.
- Trade and credit can explode in scope.
- Money could accidentally replace the survival economy if introduced too early.

## What Is Acceptable

Acceptable future directions:

- Early no-money economies.
- Storehouse contribution and rationing.
- Aggregate obligation pressure.
- City credit as trusted claims.
- Fluctuating credit value based on backing, trust, scarcity, and trade reputation.
- External cities accepting, discounting, or rejecting credit.
- Different cities having different economy modes.

## What Is Not Acceptable

Not acceptable:

- Universal fixed-value gold as the default economy.
- Currency before the needs economy is fun.
- Full bilateral household debt ledgers early.
- Households reduced to generic worker slots.
- Hidden credit penalties without explanation.
- Money replacing food, shelter, labor, tools, and maintenance as the early core.
- UI or docs implying the current code already has money, household credit balances, city credit, defaults, or trade currency.

## Implementation Roadmap

### Phase 0: Design Doc Only

Record the model and guardrails. No gameplay implementation.

### Phase 1: First Playable Core

Keep the first playable focused on food, shelter, labor, tools, production, maintenance, and action hints. Make pressure and consequences readable before adding money.

### Phase 2: Read-Only Economy Mode Display

Add a descriptive economy mode such as "Subsistence" or "Storehouse" based on existing state. This should be display-only and should not change formulas.

### Phase 3: Aggregate Obligation Pressure

Introduce a city-level pressure that summarizes unmet promises, ration strain, or storehouse expectation. Keep it aggregate and explainable.

### Phase 4: Storehouse Backing and City Credit Trust

Let storehouse reliability and resource backing affect city credit trust. Do not issue transferable currency yet.

### Phase 5: Household Acceptance Summaries

Summarize household willingness to accept credit without implementing detailed bilateral ledgers. Keep household differences readable.

### Phase 6: City-to-City Credit Discounting

Let external cities accept, discount, or reject city credit based on trust, backing, scarcity, and reputation.

### Phase 7: Transferable City Credit / Accepted Currency

Only after the above systems are legible should city credit become broadly transferable and behave like accepted currency.

## Open Questions

- What counts as backing?
- Is credit backed by food, tools, labor promises, trade reputation, or all of them?
- When does storehouse contribution become formal obligation?
- Do households individually hold balances?
- When does credit become transferable?
- Can cities default?
- How punitive should trust collapse be?
- Should different cultures or cities prefer different economy modes?
- How much of this should be player-facing versus summarized?
- How should shortages change household willingness to accept credit?
- Can outside traders arbitrage between cities with different credit trust?
