# Warfare And Conflict Model

Owner decisions on who fights, how war is supplied and resolved, and how people react to it (2026-10-19). Sits under `docs/GAME_VISION.md` and builds on `docs/SIMULATION_SCALE_MODEL.md` (strategic battles, armies as map agents), `docs/HOUSES_AND_LINEAGE_MODEL.md`, `docs/CULTURE_AND_VALUES_MODEL.md`, and `docs/ECONOMY_MODEL.md`.

Items marked **Default** were set during planning to complete the model; the owner can change them without reopening the rest.

## Principle

**Soldiers are families.** War is fought by households, supplied by the settlement's shared stores, and paid for in lives that belong to specific lineages. Every battle report is also a family story.

## Who Fights

- **Soldier families.** Dedicated households whose responsibility is soldiering. They fit the **Of the Shield** calling and are the settlement's standing force.
- **Militia when called upon.** Ordinary families can be called up in an emergency. They leave their work while serving, so a call-up costs production; calling up farmers at harvest is a real sacrifice.
- **House contributions.** At town scale and above, Houses contribute to defense according to their **culture** and/or **local laws and policies**. A Martial House offers more fighters willingly; a Peaceable House gives the minimum the law requires. Laws such as levies can set that minimum.

**Default:** a call-up takes the household's primary responsibility for its duration (the same one-responsibility labor unit as other work), so household labor stays consistent with `docs/PROJECT_OWNER_QUESTIONS.md`.

## Supply

- **Soldier families are supplied from communal stores:** food, and tools or arms. A standing force is an ongoing cost the settlement must produce or trade for.
- In-kind tithes (`docs/ECONOMY_MODEL.md`) are the natural early source of that supply.
- **Default:** armies away from home draw on supply carried with them and on stores sent after them. Long distances strain supply, and supply shortage lowers morale and strength. This makes distance, roads, and safe routes matter for war as well as trade.
- **Default:** Mercenary-valued families fight well when paid and their loyalty follows payment, which gives coin a military use once it exists.

## Armies And Capture

- **Armies are formed and sent.** The player gathers soldier families, militia, and House contributions into an army, which travels the map as an agent (`docs/SIMULATION_SCALE_MODEL.md`).
- **Battles are resolved strategically,** from strength, terrain, supply, morale, and leadership, plus culture (for example Defenders fighting at home, Martial and Honor-Bound fighting hard, Pragmatic breaking sooner). Each battle produces a readable report.
- **Capturing a city is a resolved battle,** not a separate siege or tactical mode.
- **Default - after capture:** the city's Houses and commons join the player's realm with their own culture. Loyalty starts low; Adaptable cultures integrate faster, Proud ones resist longer. A captured city's culture becomes part of the realm's blend, and in extreme divergence can become a named people pressing against unity (`docs/CULTURE_AND_VALUES_MODEL.md`).

## Casualties

- **Losses fall on households.** A soldier killed is a working adult removed from a specific family. Households can be left shrunken or broken, and lineages can lose heirs.
- **Default:** heavy losses can push a lineage below the House threshold or end a line entirely, using the decline and extinction rules in `docs/HOUSES_AND_LINEAGE_MODEL.md`.
- This keeps the attachment pillar honest: war costs the families the player cares about.

## How People React To War

Reactions depend on **culture** and **trade relationships**.

**People expect to be protected.**

- Raids, bandit attacks, and enemy armies on the player's land, or lost caravans, reduce trust and loyalty when the player fails to defend them.
- Repeated failure to protect raises departures and weakens trust in the player's coin, since coin trust rests partly on military strength (`docs/ECONOMY_MODEL.md`).
- Clearing bandits and keeping roads safe builds trust.

**People hate losing their own.**

- Casualties create grief and war weariness, felt most by the families and Houses that lost members.
- **Default:** war weariness builds with losses and with time at war, scaled by culture.

**Culture shapes tolerance:**

| Values | Reaction |
| --- | --- |
| Martial, Conquerors, Honor-Bound | support war; tolerate losses longer; Conquerors grow restless in long peace |
| Defenders | fierce in defensive war; reluctant in offensive war |
| Peaceable, Pragmatic | low war tolerance; push for peace and treaties |
| Lawful | strongly support action against bandits |
| Leisurely, Industrious (as militia) | resent call-ups that pull them from rest or work |
| Mercenary | support war while paid |
| Omen-Watchers | read defeats as bad omens; extra unrest |

**Trade relationships shape it too:**

- War with a trade partner disrupts trade. Merchant families (Of the Road, Cosmopolitan, Coin-Minded) object, and goods that depended on that partner become scarce.
- War with the issuer of a coin the settlement uses is especially costly: it threatens household savings and the dependency that coin created.
- Trading entities can refuse trade during or after war (`docs/ECONOMY_MODEL.md`).

## Bandits

- Bandits are present from the start, with danger set by region (`docs/GAME_VISION.md`).
- Soldier families and militia patrol, protect caravans, and clear bandit groups.
- **Default:** cleared regions stay safer over time but can relapse if left unpatrolled, so safety is maintained, not bought once.

## Build Order

1. **Defense first (village scale):** soldier families as a household responsibility supplied from stores; militia call-up; bandit raids on stores and caravans; protection expectations affecting trust.
2. **Patrols and clearing:** bandits as map agents; patrols; cleared regions.
3. **Armies and capture:** forming and sending armies; strategic battle resolution with reports; capture and integration of cities.
4. **Houses at war:** House contributions by culture and law; levies; casualties affecting lineages; war weariness by culture and trade.

## Open Questions

- How are leaders chosen for an army: a soldier family, a House head, or abstract?
- Can armies be raised from captured cities, and how loyal are they?
- What do fortifications look like at hamlet, village, and town scale?
- How do established powers decide to go to war with the player or each other?
