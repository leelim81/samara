# Terra Battle — Progression, Economy, Gacha, Luck

Source: Terra Battle Wiki (fandom), researched 2026-06-11. For personal fan-recreation reference only.
Primary wiki pages: `Chapters`, `Stamina`, `Energy`, `Coins`, `Levels`, `Luck`, `Pact of Truth`, `Pact of Fellowship`, `Pact of Fate`, `Companions`, `Items`, `Recode DNA`, `Metal Zone`, `Power Leveling`, `Monster Farming`, `Daily Quests`.

---

## 1. Story structure

- **42 chapters**: Part 1 = ch. 1–30, Part 1.5 = ch. 31–34, Part 2 = ch. 35–42. Chapter names (first ten): 1 Borderlands, 2 To the Capital, 3 Melting Pot, 4 Into the Tower, 5 Descent, 6 The City Below, 7 Molten Menace, 8 Labyrinth, 9 In Utero, 10 Living Rock.
- Each chapter holds several **stages** (named `chapter-stage`, e.g. 2-3). Chapter 1 has 5 stages of 3 battles each; Chapter 2 has 5 stages of 5 battles each; later chapters typically have 10 stages with up to 10 battles ("floors") per stage (20-1 has 20 floors).
- Each stage shows a **stamina cost** and **difficulty level** (recommended level, 1–90 scale) on its pre-battle info screen.
- **First-time chapter clear**: +1 Energy, max stamina increases, stamina fully refilled. Moving to the next chapter requires clearing all stages of the current one.
- Side/optional content unlocks on the world map (Cryptid Forest after ch. 4, Orbling Cavern after ch. 5, "Another World" chapters after ch. 19/25, Λ quests after ch. 34).
- Battles within a stage flow continuously: clear a floor → next enemy wave loads → final floor usually holds the boss → results screen.

## 2. Stamina

- Starting max **25**; +2 to +4 per chapter cleared; **167** after Chapter 42. Mid-game milestones: 58 after ch. 10, 93 after ch. 20, 127 after ch. 30.
- Formula (server-tunable `Bias` = 1.25): `N<30: floor(floor(20 + 80×(N/29)) × Bias)`, else `floor(floor(100 + 80×((N−29)/30)) × Bias)`.
- Regenerates **1 per 2 minutes** (1 per 5 minutes before v4.5.0). 1 Energy = full refill (overflow carries since v4.0.0).
- Early stages cost 1 stamina (ch. 1–2; reduced from 5 in v4.0.0); late-game stages cost 18–25+.

## 3. Energy (premium currency)

- Costs: Pact of Truth pull 5; Pact of Fate (energy) pull 5; Companions of Truth pull 3; full stamina refill 1; continue after game over 1.
- Income: login bonuses (consecutive 8-day cycle: 2 on day 5, 3 on day 8; lifetime bonuses incl. 5 on day 1 and every 50 days past 100), 1/day for watching an ad, 1 per chapter first-clear (42 total), achievements (~24 total), gifts/events.
- IAP (USD): 1 = $0.99; 4+2 = $3.99; 8+6 = $7.99; 16+14 = $15.99; 32+30 = $31.99; 43+57 = $42.99 (purchased+bonus).

## 4. Coins

- Income: battle drops (each enemy has a coin value, ~10–18 in ch. 1–2; whole early stages yield 30–300), login bonuses (500–3,000), coin-farm quests (Attack of the Coin Creeps; 5-8 ≈ 589 coins per 1 stamina), selling companions (class-based: Z 450×level … D 100×level; Metal Minions 500 / 3,000 / 20,000 / 40,000), Luck chests.
- Boosters: Money Bags +15/+30% (stack to +50%), Coin Bonus (combo-scaled), steals (Pickpocket/Mug, 30% for 15–25% of enemy base coins, ≤4 per enemy), Coin Boost item +50%.
- Spending: gacha pulls (3,000 / 2,000), Add Jobs (8k–28k), Recode DNA (20k/30k), companion evolve (6k–20k), companion upgrade (`50 × base level × number of fused components`).

## 5. EXP and leveling economy

- Stage EXP totals scale with enemy values (ch. 1 stages: 720–1,772; 5-8 ≈ 14,600 per 1 stamina is the famous early grind spot; Metal Zones give the highest EXP but no coins/items).
- **Combo bonus**: 2nd kill in one turn = 110% of its base EXP, 3rd = 120%, 4th = 130%, etc. Only kills during your own turn combo; counter/trap/friendly-fire kills give base EXP only; enemy-summoned units count for combos but yield 1 base EXP.
- EXP skills stack additively to +130% (Primordial Dragon Z +100%, several +15%, +10% units); EXP Boost item +50% applies on top.
- Metal Zones are level-banded (1: levels 1–19 … 7: 70–89); characters above the band gain nothing; runners flee after ~2 turns; their ailment vulnerabilities rotate per zone (sleep → paralysis → confusion → petrify → shadowbind → icebind).

## 6. The gacha ("Pacts")

All from Tavern > Recruit; new recruits arrive at **level 10, 0% SB** (and 0 Luck where applicable). Multi-pull ×10 supported. An unopened pact envelope can still be cancelled; envelope color telegraphs rarity: **Rainbow = Z, Gold = SS/S, Silver = A/B/C, Bronze = D**.

| Pact | Cost | Pool | Duplicate reward |
|---|---|---|---|
| **Pact of Truth** | 5 Energy | Adventurers Z–B. Rates: Z 4%, SS 10%, S 15%, A/B 71% split evenly | +6 levels & +12% SB (Z); +5 & +10% (SS/S); +1 & +5% (A/B) |
| **Pact of Fellowship** | 3,000 coins (or Fellowship Tickets) | Monsters D–A + 10 specific adventurers; pool grows with chapter progress (start: 10 adventurers + 44 monsters; complete: 10 + 93) | same as Truth |
| **Pact of Fate (Energy)** | 5 Energy | mirrors Truth pool | +levels & **+5 Luck** instead of SB |
| **Pact of Fate (Coins)** | 3,000 coins | mirrors Fellowship pool | +levels & **+5 Luck** |
| **Companions of Truth** | 3 Energy | companions | — |
| **Companions of Fellowship** | 2,000 coins | companions | — |

- **"+" pacts** randomly appear: extra +1–5 levels and +0.5–3% SB (or +0.5–3 Luck on Fate).
- One **free Truth/Fate(energy) pull per 24h** by watching an ad.
- **Pool removal:** a character at 100% SB leaves the Truth/Fellowship pools; a character at its Luck cap leaves the Fate pools. (Pity/ceiling system by exhaustion.)

## 7. Luck system

- **Luck** is a 6th character stat (shown as "L") influencing end-of-stage drops. Caps: **100** for Λ and Z, **80** for SS/S, **70** for A and below (Λ always 100).
- Gains:
  - Recode DNA: inherits 100% of base character Luck + 20% of each material monster's Luck; re-recoding an owned Λ adds +5.
  - Pact of Fate duplicates: +5 each (+0.5–3 on a "+" pact).
  - Quest drops of an owned Λ: +1 (also SB).
  - **Battle End**: chance of +0.1–0.3 after clearing any quest costing **8+ stamina** (higher costs → better odds; works even for dead characters).
  - "Lucky" enemies: Lucky Orbling (+0.3 to the whole party when pincered correctly — guaranteed if outflanked; flees otherwise; immune to area kills), Lucky Runner (+0.1, 50% flee).
  - Luck Candy items; some companions add +5/+10/+30 Luck or double results-screen Luck gains.
- **Luck Treasure Chests** appear on the results screen of most quests; six chest types: **A, B, C, D, Luck 80, Luck 100**. Odds scale with the **team's average Luck**: A guaranteed at avg ≥40; B at ≥85; Luck 80/100 chests guaranteed at avg ≥80/≥100; a 100-avg team gets A+B+80+100 always, C at 50%, D at 25%. Chests pay coins, materials, even rare characters/companions. Several special quests (Metal Zone, Cryptid Forest, etc.) have no Luck chests.

## 8. Items

- Inventory cap 99,999 per item. Categories:
  - **Tickets**: Metal Ticket (free Metal Zone entry; farm at 6-8), Fellowship/Companion Tickets (free pulls).
  - **Power-ups** (pick one before battle): EXP Boost +50%, Coin Boost +50%, Time Extension (longer move timer), Disarmer (neutralizes floor traps), Reinforcement units.
  - **Candy**: Level/Skill/Luck Candy (+stat) and Candybox variants.
  - **Job materials**: species items (e.g. Serenity Shoot/Wisdom Flower for Human, Benevolent Fang/Tail of Insight for Lizardfolk…), weapon items (Terra Swordsteel/Spearbronze/Bowstring/Staffwood), attribute rings (Fire/Ice/Lightning/Dark/Solar/Lunar/Photon/Graviton/White/Green), **Tears** (2nd job for A/B + companion evolution: Spirit/Moon/Rainbow/Sea), **Particles** (3rd job for A/B: Spirit/Lore/Wish/Warped).
  - **Recode items**: Helixes (Deepwater/Mantle/Temporal/Flawless), Ether/Elixir/Black Hole/White Hole/Wormhole.
  - **Animata items**: Trading Post currency.
- Sources: enemy drop tables (commonly ~4%/slot in story; bosses have 10–100% special drops), Hunting Zones by category (Pudding Time = elemental, Tin Parade = weapon/tears, Puppet Show = race mats), daily quests, Luck chests, Trading Post.

## 9. Recode DNA & Λ characters

(Details in characters-jobs.md §7.) Economy summary: unlocked after Chapter 20; consumes the maxed base character + 2 specific level-50+ monsters + 5 Helixes + a rare item + 15 weapon/attribute items + 20–30k coins; outputs a higher-class single-job Λ unit at level 1 with carried-over SB/Luck. It is the long-term sink that re-monetizes duplicate-exhausted rosters (consumed units can be re-pulled).

## 10. Recruiting monsters from battle

- Most monsters can drop as **recruits** when defeated (typically ~2%; "Units" HUD counter tracks them). Negotiator/Pro Negotiator (+200%/+800%) make farming practical. A and many B-class monsters are chapter bosses recruitable only from one stage (e.g. Kraken 28-3, Marilith 28-6, Tiamat 28-9, Lich 28-10).
- Cryptid Forest implements smart drops: it grants the Dracorin character (100%) if unowned, else its job-unlock materials.

## 11. Daily / live systems

- **Login bonuses**: rolling 8-day coin/energy track + lifetime-day milestones.
- **Daily Quests**: one-attempt-per-day rotating quests (energy days, coin days, candy days, Lucky Orbling day, etc.).
- **Daily Bonus**: a rotating perk (e.g. boosted item drop rates on specific chapters).
- **Achievements**: one-time energy/item rewards (story milestones "Chronicles", weapon mastery tracks, Tower of Temptation).
- **Co-op rewards** (pre-5.5.0): host 100% / guests 20% of coins+EXP; all get full item drops; first-contact bonuses (20 Energy + 24 Metal Tickets total across 20 new partners).
