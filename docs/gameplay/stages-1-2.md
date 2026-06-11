# Terra Battle — Chapter 1 "Borderlands" & Chapter 2 "To the Capital"

Source: Terra Battle Wiki (fandom), researched 2026-06-11. For personal fan-recreation reference only.
Primary wiki pages: `Borderlands`, `To the Capital`, `Borderlands/Story`, `To the Capital/Story`, `Bosses/Chapters1-5`, enemy pages (Wee Orbling, Orbling, Gorf, Dracorin (Enemy), Sabertooth, Archer, Warrior), and the wiki's `Module:Enemy/Data` Lua tables (exact stats).

Stat block key: **HP / ATK / DEF / MATK / MDEF**, `move` = enemy action counter (acts when it counts down), `vuln` = hidden status-ailment vulnerability (all ailments), EXP/coins = per-enemy rewards.

---

## Chapter 1 — Borderlands (tutorial)

- **5 stages (1-1 … 1-5), 3 battles each, 1 stamina each.** Difficulty levels 1–4. Serves as the tutorial: movement, pincers, chains, chain heals, pacts.
- Story intro (paraphrased): millennia after the primordial civilization of Gallus fell, the world is decaying — the atmosphere thinning, gravity weakening. Wondering whether the Maker sleeping underground has abandoned the world, the player's band of adventurers begins a pilgrimage into the depths.
- Units received during the chapter: the starter pair (**Bahl** *or* **Grace**, + **Healer**); **Knight** joins via the Tavern tutorial after 1-1; after 1-2 you fight and then recruit **Archer** (if your starter was Bahl) or **Warrior** (if Grace). By 1-5 a 4-unit party of level ~1–4 units is expected.
- No co-op was ever allowed in Chapter 1; its stages have Luck chests (drop pools include Terra weapon materials, species items, 50-coin bags).

### Enemy roster (exact data)

| Enemy | Weapon | Lv | HP | ATK | DEF | MATK | MDEF | move | vuln | EXP | Coins | Skills |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Wee Orbling (Sword) | Sword | 1 | 85 | 13 | 3 | 10 | 11 | 5 | 80% | 240 | 10 | Slash — Lateral (1), 30%, ×1.5 sword dmg |
| Wee Orbling (Spear) | Spear | 1 | 88 | 14 | 3 | 10 | 12 | 5 | 80% | 240 | 10 | Stab — Vertical (1), 30%, ×1.5 spear dmg |
| Wee Orbling (Bow) | Bow | 1 | 84 | 13 | 4 | 10 | 12 | 5 | 80% | 240 | 10 | Arrow — Area (1), 30%, ×1.5 bow dmg |
| Archer (1-2, Bahl route) | Bow | 1 | 88 | 26 | 6 | 12 | 15 | 4 | 70% (30% per enemy-page variant) | 240 | 10 | Arrow — Cross (1), 30% |
| Warrior (1-2, Grace route) | Sword | 1 | 87 | 25 | 6 | 12 | 15 | 5 | 80% | 240 | 10 | Slash + Sever — Lateral (1), 30% (Sever knocks back) |
| **Orbling (BOSS, 1-5)** | Sword | 3 | 101 | 21 | 4 | 12 | 15 | 5 | **0% (ailment-immune; stat debuffs work)** | 240 | 18 | Slash — Lateral (1), 30% |

The 1-5 Orbling is a **1×1 boss** (golden flame frame) — it can be corner-pincered and outflanked. It exists mainly to signal "bosses hit harder".

### Stage-by-stage composition

Flavor caption in quotes (in-game stage banner text). XP/coins = recorded full-run totals.

**1-1** — "The wild creatures of this world are on the attack." (Lv 1, ~720 XP, ~30 coins)
- B1: Wee Orbling (Sword) ×1 · B2: Wee Orbling (Sword) ×1 · B3: Wee Orbling (Sword) ×1
- Pure movement/pincer tutorial; Knight joins afterward via the Tavern tutorial.

**1-2** — "Repeated chains give strength." (Lv 2, ~1,200 XP, ~50 coins)
- B1: Wee Orbling (Sword) · B2: Wee Orbling (Sword) + Wee Orbling (Bow) · B3: Wee Orbling (Sword) + **Archer** (Bahl route) / **Warrior** (Grace route)
- Chain tutorial; the humanoid foe joins you afterward (100% recruit, first clear only).

**1-3** — "How to fight, how to survive—such arts must constantly be mastered." (Lv 3, ~960 XP, ~40 coins)
- B1: Wee Orbling (Sword) · B2: Wee Orbling (Bow) · B3: Wee Orbling (Sword) + Wee Orbling (Spear)

**1-4** — "The survival of the fittest, the battle to exist." (Lv 4, ~1,200 XP, ~50 coins)
- B1: Wee Orbling (Sword) + (Spear) · B2: Wee Orbling (Bow) · B3: Wee Orbling (Bow) + (Spear)

**1-5** — "Fight. Struggle. Resist. That is the only way to survive." (Lv 4, ~1,680–1,772 XP, ~78 coins)
- B1: Wee Orbling (Sword) + (Spear) · B2: Wee Orbling (Bow) + (Sword) · B3: Wee Orbling (Bow) + (Spear) + **Orbling boss**

Luck-chest pools recorded across ch. 1: Terra Bowstring/Staffwood/Swordsteel/Spearbronze, Serenity Shoot, Claw of Fate, Forlorn Stone, Benevolent Fang, 50-coin bundles.

---

## Chapter 2 — To the Capital

- **5 stages (2-1 … 2-5), 5 battles each, 1 stamina each** (cost reduced from 5 in v4.0.0). Difficulty levels 5–6. Co-op locked until Chapter 4 is cleared.
- Story beats (paraphrased): the party heads for the capital to gather knowledge kept by the lizardfolk and beastfolk — knowledge said to be the guidepost to the Maker, which humankind has forsaken. Narration introduces the world's races: numerous *men*; the sentient reptilian-amphibian *lizardfolk*; the feral humanoid *beastfolk*; and the mindless *predators* that exist only to devour (their gluttony and savagery framing stages 2-3/2-4). At the chapter's end the party resolves to win the locals' respect through a show of strength, and the capital's gates open to them.
- New mechanics encountered: a healing enemy (Gorf), an elemental ranged enemy (Dracorin, lightning bow), knockback spears (Sabertooth), and the first **2×2 multi-tile bosses**.

### Enemy roster (exact data)

| Enemy | Weapon/Attr | Lv | HP | ATK | DEF | MATK | MDEF | move | vuln | EXP | Coins | Skills |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Orbling | Sword | 3 | 193 | 30 | 20 | 12 | 22 | 5 | 80% | 222 | 15 | Slash — Lateral (1), 30% |
| Orbling | Sword | 8 | 281 | 30 | 33 | 17 | 35 | 5 | 80% | 242 | 15 | Slash — Lateral (1), 30% |
| Gorf | Staff / Healing | 4 | 158 | 28 | 16 | 26 | 21 | 6 | 50% | 242 | 15 | Heal — Area (1), 100% (heal power 1.5) |
| Gorf (2-2 boss aide) | Staff / Healing | 6 | 317 | 28 | 21 | 34 | 27 | 6 | 50% | 263 | 16 | Heal — All, targets Boss, 30% (heal power 5) |
| Dracorin | Bow / Lightning | 5 | 411 | 28 | 28 | 34 | 28 | 4 | 60% | 263 | 16 | Thunder Arrows — Cross (1), 30%, ×1 lightning |
| Sabertooth | Spear | 6 | 425 | 32 | 34 | 15 | 24 | 4 | 80% | 263 | 15 | Stab — Vertical (1), 30%; Thrust Away — Vertical (1), 30% (knockback) |
| **Orbling (BOSS, 2-2)** | Sword | 12 | 1,987 | 34 | 39 | 21 | 43 | **2** | 0% (immune) | 263 | 18 | Slash — 1 Row, 30%; Breath — Area (1), knockback (no damage) |
| **Spinetrich (BOSS, 2-5)** | Spear / Lightning | 9 | 3,949 | 36 | 49 | 38 | 51 | **3** | 0% (immune) | 283 | 18 | Stab — Vertical (1); Thrust Away — Vertical (1) (knockback); Discharge — Area (1), ×2 lightning; Slash — Lateral (1); Sever — Lateral (1) (knockback); all 30% |

Both Chapter 2 bosses occupy **2×2 tiles** — they cannot be corner-pincered or outflanked; pincer across the 2-wide body. Notable drops: Dracorin can drop as a **recruit (~2%)** plus Benevolent Fang / Lightning Ring / Photon Ring (~4% each); Sabertooth recruit ~2% + Serenity Shoot / Terra Spearbronze; Spinetrich drops **Rainbow Tears (10%)**, Forlorn Stone, Lightning/Photon Rings; the 2-2 boss Orbling drops Benevolent Fang / Terra Swordsteel.

### Stage-by-stage composition

**2-1** — "They keep knowledge others have forgotten." (Lv 5, ~210 coins)
- B1: Orbling Lv3 ×2 · B2: Orbling Lv3 ×3 · B3: Orbling Lv3 ×3 · B4: Orbling Lv3 + Gorf Lv3* · B5: Orbling Lv8 ×2 + Gorf Lv4 ×2
- (*battle-4 Gorf listed at Lv3 on the chapter page; the data module's standard ch. 2 Gorf is Lv4.)

**2-2** — "Many creatures roam this world." (Lv 5, ~260 coins)
- B1: Gorf Lv4 ×3 · B2: Orbling Lv3 + Orbling Lv8 + Gorf Lv4 · B3: Orbling Lv3 ×4 · B4: Gorf Lv4 ×4 · **B5: Orbling BOSS Lv12 (2×2) + Gorf Lv6 ×2** (the Gorfs heal the boss for big amounts — kill them first).

**2-3** — "Their gluttony has no bounds and knows no reason." (Lv 5, ~248 coins)
- B1: Dracorin ×2 · B2: Dracorin + Gorf ×2 · B3: Dracorin ×2 + Gorf · B4: Dracorin + Gorf ×3 · B5: Dracorin ×2 + Gorf ×2 (all Dracorin Lv5, Gorf Lv4)

**2-4** — "And savagery rule their kind." (Lv 6, ~232 coins)
- B1: Sabertooth ×1 · B2: Dracorin ×3 · B3: Sabertooth ×2 · B4: Sabertooth + Dracorin ×2 · B5: Sabertooth ×4 + Dracorin ×2 (Sabertooth Lv6, Dracorin Lv5)

**2-5** — "The capital comes into view." (Lv 6, ~295 coins)
- B1: Sabertooth ×2 + Gorf · B2: Sabertooth ×2 + Dracorin + Gorf · B3: Dracorin ×4 · B4: Sabertooth ×2 + Dracorin ×2 + Gorf · **B5: Sabertooth ×2 + Spinetrich BOSS Lv9 (2×2)**

### Recorded material-drop tallies per stage (wiki "DungeonInfo" counts)

Weapon-material drop counts logged per full run, ordered Sword/Spear/Bow/Staff (Terra Swordsteel / Spearbronze / Bowstring / Staffwood), plus elemental rings:

| Stage | Sword | Spear | Bow | Staff | Elemental |
|---|---|---|---|---|---|
| 1-1 | 3 | 0 | 0 | 0 | — |
| 1-2 | 4 | 1 | 0 | 0 | — |
| 1-3 | 2 | 1 | 1 | 0 | — |
| 1-4 | 1 | 2 | 2 | 0 | — |
| 1-5 | 3 | 2 | 2 | 0 | — |
| 2-1 | 11 | 0 | 0 | 3 | — |
| 2-2 | 7 | 0 | 0 | 10 | — |
| 2-3 | 0 | 8 | 0 | 8 | 8 lightning |
| 2-4 | 0 | 7 | 8 | 0 | 7 lightning |
| 2-5 | 0 | 7 | 9 | 3 | 8 lightning |

(Interpretation: aggregate drop-table weightings recorded by wiki contributors, not guaranteed per-run counts.)

### Recommended party for these chapters

- Whatever you have works in ch. 1 (it's the tutorial). For ch. 2: bring the starter (Bahl/Grace), Knight, Archer/Warrior, and Healer — i.e. coverage of sword + spear + bow + a healer.
- Triangle pointers: Spear units (Knight) chew through the sword Orblings; sword units beat the bow Dracorins; bow units beat the spear Sabertooths/Spinetrich. Gorfs are staff (neutral) — burst them down before they heal, especially the boss-healer Gorfs in 2-2.
- Watch enemy action counters: regular ch. 1–2 enemies act only every 4–6 turns, but the bosses act every 2–3, and their row/area attacks (Slash — 1 Row; Discharge — Area 1) punish clustering. Knockback skills (Thrust Away, Breath, Sever) will shove your formation apart.

### Stage backgrounds / presentation

The wiki does not document per-stage background art. Per official screenshots, early-chapter battles play on muted parchment-toned boards with faint terrain texturing (rocky borderland tones in ch. 1–2); treat exact visuals as unverified.
