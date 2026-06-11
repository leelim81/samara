# Terra Battle — Combat System (Mechanical Reference)

Source: Terra Battle Wiki (fandom), researched 2026-06-11. For personal fan-recreation reference only.
Primary wiki pages: `Battles`, `Combat Guide`, `Weapons`, `Attributes`, `Status Effect`, `Traps`, `Bosses`, `Skills`, `Taps`, plus the archived official playguide (terra-battle.com/en/playguide, via Wayback Machine) and the enemy data Lua module (`Module:Enemy/Data`).

---

## 1. The battlefield

- Battles take place on a fixed grid that is **6 columns wide and 8 rows tall** (48 tiles).
- The player's squad of **up to 6 units** (minimum 2) is placed on the grid alongside enemy units.
- Allied units are marked with a **blue border**; enemy units with a **red border**. Bosses get a special **stylized golden-flame frame** instead of the plain red border.
- A stage ("quest") consists of several consecutive **battles** (also called floors): each time all enemies die, the next battle's enemy formation loads onto the same grid. Early story stages have 3–5 battles; some later stages have 10, and one (20-1) has 20.
- Objects other than units can occupy tiles: Powered Points, capsules, bombs, traps, and obstacles.

## 2. Turn structure (high level)

One full round is:

1. **Player turn**
   1. Movement — the player picks up ONE unit and drags it (time-limited, see §3). All other allied units can only be displaced passively by the dragged unit.
   2. All resulting **pincer attacks** resolve, one pincer at a time (see §4–§6 for ordering).
2. **Enemy turn** — every enemy whose action counter has expired acts. For each acting enemy, in any order:
   - enemy movement,
   - enemy pincers (which can trigger player **counter** skills),
   - enemy skills.
3. **End-of-round upkeep**, in this order:
   1. Status-effect damage (poison etc.) and trap damage,
   2. Regen healing,
   3. Buff/debuff/effect turn counters decrease by 1.

Within a single resolved pincer, the sub-phases run in this exact order:

1. Buff skills
2. The (basic) attack
3. Attack skills / debuff skills
4. Healing skills
5. Capsule-generating skills
6. Enemy counter skills

…then the next pincer (if any) resolves, repeating the same sub-phases.

## 3. Movement

- Tap-hold a unit and drag it across the grid. **The 4-second timer starts the moment the unit leaves its starting square** (not when you touch it), shown as a draining timer gauge on the HUD.
- The move ends when the player **releases the unit OR the timer expires**. On timeout the unit simply stops where it is — the turn then proceeds to pincer resolution as normal; there is no other penalty.
- **Displacement / swapping:** dragging your unit over a friendly unit makes the two **swap places**. This is the core repositioning tool — one drag can reshuffle many allies. Enemy units can NOT be displaced by your movement.
- **Enemies and obstacles block movement.** You cannot drag through them (exception: units with the *Stealth* skill — e.g. Gegonago Λ, Nazuna Λ, Hiso God — can pass through).
- **Diagonal movement is allowed** in addition to the 4 cardinal directions. The diagonal "hitbox" is smaller, so it's physically harder to do. You cannot slip diagonally between two enemies that are lined up diagonally.
- Powered Points and capsules on the field can also be displaced by dragging through them, just like allied units.
- Movement time modifiers:
  - *Control Time* skill: extends the moving time for that unit (stacks).
  - *Time Extension* power-up item (chosen before the battle): extends time.
  - Certain enemy skills and **time traps** reduce the remaining control time when triggered/stepped on.

## 4. Pincer attacks (the basic attack)

- The only basic attack is the **pincer**: sandwich an enemy between two allied units on directly opposite sides — either **horizontally (left+right)** or **vertically (above+below)** on the same row/column, adjacent to the enemy.
- **All valid pincers at the end of movement execute** — not just ones involving the unit you dragged. Position several pincers and they all fire in one turn.
- **Multi-enemy pincers:** several enemies standing in an unbroken line in one row/column can all be pincered by flanking the whole line (`X O O O X` hits all three). Allied units inside the line split it: `X O O X O O X` forms two pincers and hits all four enemies. **There is no damage penalty for pincering multiple enemies** — every sandwiched enemy takes full damage.
- **Corner pincers:** an enemy sitting in one of the 4 corner tiles can be pincered with an L-shape — one ally orthogonally adjacent horizontally and one vertically (the only two open sides). Example, enemy `O` in the top-left corner:
  ```
  O X
  X
  ```
- **Outflank:** surrounding an enemy on all four orthogonal sides is recognized; the *Outflank* skill grants +50% damage against foes surrounded on all sides (multiple Outflanks don't stack). Certain special enemies (e.g. Lucky Orbling) give a guaranteed bonus when outflanked.
- **Enemies pincer you with exactly the same rules** (`O X O` damages your unit; `O X X X O` hits all three sandwiched allies).
- Pincer (basic) damage is physical: attacker's **ATK vs target's DEF**, modified by the Circle of Carnage (§8).
- Being pincered triggers the target's **counter** skills (e.g. Counterattack 1.5×ATK) — these fire in the "enemy counter" sub-phase after the pincer's healing/capsule phases.

### Pincer resolution order

When multiple pincers exist simultaneously, they resolve in this order ("leading" = the pincer includes the unit you dragged):

1. Leading horizontal pincer
2. Leading vertical pincer
3. Leading corner pincer
4. Other horizontal pincers — scanned bottom-to-top, then left-to-right
5. Other vertical pincers — scanned left-to-right, then bottom-to-top
6. Other corner pincers — bottom-left, bottom-right, top-left, top-right

## 5. Chains

- A **chain** forms when other allied units line up with a pincering unit: a unit is in the chain if it is **in the same row or column as a pincering unit with no enemies or obstacles between them**.
- Each chained unit contributes **one extra basic attack** to that pincer's damage, and gets a chance to trigger its skills.
- **A unit can join only ONE chain per pincer** — it can't be counted toward both pincering units at once.
- Skill activation rules differ by linkage:
  - Skills tagged for **pincers** activate only for the two flanking units.
  - Skills tagged for **chains** activate for chained units (and generally also when pincering).
  - Plain weapon-strike skills (e.g. Megasword with no area modifier) typically activate **only when that unit leads/flanks a pincer**, not from a chain; spells and area-modified skills generally CAN activate from chains. (Exact behavior is defined per skill.)
- Petrified allies do **not** break a chain drawn through them; confused units never chain. Powered Points and capsules sitting in the line do not break chains (and with the *Extend Chain* skill they even act as additional chain nodes, on the skill-holder's side of the chain).
- Chain heals work the same way: a healer chained into a pincer fires its heal skill.

### Chain resolution order (within one pincer)

Attacks/skills fire in this character order:

1. **First pincering unit** — the LEFT unit for horizontal pincers, the BOTTOM unit for vertical pincers (left/bottom side for corner pincers).
2. **Second pincering unit** — right / top.
3. **Chained units**, in this scan order:
   1. first unit to the right of pincering unit #1,
   2. first unit to the left of pincering unit #1,
   3. first unit above pincering unit #1,
   4. first unit below pincering unit #1,
   5. first unit to the right of pincering unit #2,
   6. first unit to the left of pincering unit #2,
   7. first unit above pincering unit #2,
   8. first unit below pincering unit #2,
   then continue outward with the next unit in each chain direction until all chained units have acted.

## 6. Damage calculation

### Stat pipeline (applied in order)

1. **Passive stat buffs** (Equip skills, e.g. "Attack +10%, Equip").
2. **Active stat buffs** (e.g. "Attack +10%, Self"). → Steps 1+2 combined are capped at **+100%**.
3. **Tap stat buffs** (Augment skills, +30% per charge). → Total buffs through step 3 capped at **+200%**.
4. **Companion flat stats** (e.g. a maxed Earth Sword companion = +80 ATK).
5. **Damaging skill** computes damage with the formula below, including **Circle of Carnage** and **elemental advantage** multipliers. Stat **debuffs are capped at −30%**.
6. **Damage multiplier buffs** (e.g. "Physical Damage ×1.5", "Fire Attack ×1.5") — capped at +200% (i.e. ×3 total).
7. **Powered Point** bonus: all damage (and healing) ×1.5.
8. **Target's damage reductions** (Phys Dmg Down, elemental shields, barriers, innate reductions).

### Damage formulas

`power` is the skill's multiplier (Megasword = 1, Gigasword = 2, Terasword = 3, Petasword = 3.5; basic pincer attack behaves as a power-1 physical hit).

```
base physical damage = 1.1 × power × (ATK × 1.15)^1.7 / DEF^0.7
                     = 1.395 × power × ATK^1.7 / DEF^0.7

base magical damage  = 1.5 × power × MATK^1.7 / MDEF^0.7

actual damage        = base damage × RANDOM(0.9, 1.1)
```

Poison (and shadowbind) tick damage:

```
base poison damage   = MATK × power × 0.5
actual poison damage = base × RANDOM(1.0, 1.2)
```

Healing amounts are driven by the caster's MATK, with hard per-skill caps (Heal/Mega Heal cap 700, Giga Heal 1300, Tera Heal 2500).

### Circle of Carnage (weapon triangle)

- **Sword deals ×2 damage to Bow. Bow deals ×2 to Spear. Spear deals ×2 to Sword.**
- It is **one-directional**: sword does double to bow, but bow does *normal* damage back to sword (no "weak against" penalty).
- Staff and Unarmed units sit outside the triangle (no weapon advantage either way).
- Applies equally to enemies attacking the player.
- For the basic pincer hit, the **weapon type of the two flanking units' current jobs** is what counts; chained units' extra basic attacks inherit **the pincering unit's weapon type**, but any *skills* the chained units fire use the **skill's own weapon type**. (Since v2.9.0, skills carry their own weapon type; "character-weapon damage" skills use the current job's type.)
- *Augment Circle* skill: increases the Circle of Carnage effect by 20%, stackable. *Negate Circle* removes it.

### Elemental advantage

- Opposed element pairs deal **×2 damage to each other (both directions)**: Fire↔Ice, Lightning↔Darkness, Solar↔Lunar, Photon↔Graviton; additionally Solar is strong vs Ice, Lunar vs Fire, Photon vs Darkness, Graviton vs Lightning.
- Elemental skills always compute from **MATK vs MDEF**. The skill's element is used when dealing damage; the unit's element is used when receiving it.
- Enemies also have hidden per-element resistances; from Chapter 21 on, enemies heavily resist their own element, and from Chapter 26 on they absorb it.

## 7. The Power Gauge and Powered Points

- HUD shows a **Power Gauge of 3 bars**. The gauge charges with **every damaging hit on an enemy that survives** the hit. The *Powered Point Amp* skill increases charge rate by 20% (not stackable).
- When one bar fills, a **Powered Point** spawns on a random tile.
- Up to **3 Powered Points can exist/stack at once** (*Expand Power Gauge* skill raises the max by +1, up to +2 total).
- A Powered Point is consumed by **including it in a chain** (it can also be pushed around like an ally). When chained:
  - all damage AND healing this turn ×1.5;
  - **every skill is guaranteed to activate** (100% activation, though hidden status infliction odds are unchanged);
  - companion skill frequency is treated as if the companion were max level.

## 8. Capsules

- Some skills generate **capsules** (e.g. Anti-Fire Capsule, Capsule Point) that sit on the field.
- Chaining a capsule consumes it and gives the whole squad a stacking buff (typically −10% damage taken from the matching element, or −10% physical for Capsule Point).
- A maximum of **5 capsules / magic bombs** can exist on the field at once.

## 9. Enemy behavior / AI

- Every enemy has an **action counter** ("turn counter" / "move" value in the game data). It is displayed on the enemy and **counts down by 1 each player turn**; when it expires, the enemy acts during the enemy phase, then the counter resets.
  - Tutorial-tier examples from the data files: Wee Orbling 5, Gorf 6, Dracorin 4, Sabertooth 4, Archer 4 — while bosses act much more often (Chapter 2 boss Orbling: 2, Spinetrich: 3).
  - **Sleep and Paralysis freeze the counter** — it doesn't tick down while the enemy is disabled.
  - The *Add Action Turn* skill adds +1 to an enemy's counter (80% infliction).
- On its action an enemy may **move, pincer your units** (same flanking rules), and/or use skills. Enemy skills have the same area grammar as player skills (e.g. "Slash, Lateral (1)", "Thunder, Area (2)", "Stab, Vertical (1)", row/column/area attacks, ranged attacks from across the board).
- Some enemy skills have **knockback** ("blowoff" in data — e.g. Thrust Away, Breath) that pushes player units 1–2 tiles.
- **Runner**-type enemies (Metal Zone, Lucky Runner) have a chance (50% for Lucky Runner) to flee/move away when player units approach, and Metal Zone enemies leave the board entirely after ~2 turns — kill them fast.
- Enemies can damage each other with area attacks (friendly fire); such kills award base EXP but don't count toward combo bonuses.
- Some enemies **summon** reinforcements (summoned units award 1 EXP but count toward kill combos); some bosses summon bombs.
- Scripted boss behaviors exist (e.g. the Chapter 4 boss sleeps until attacked, wakes, attacks for two turns, then sleeps again).

## 10. Status effects in battle

Infliction model for ailments (3 multiplicative gates):
1. the skill must **activate** (its activation %, usually 30%);
2. the skill's **hidden infliction chance** (e.g. Paralyzing Blade 80%);
3. the target's **hidden vulnerability** per ailment (tutorial Wee Orblings: 80%; most bosses: 0% = immune; some special enemies exceed 100%, e.g. Metal Zone 3 runners are 400% vulnerable to paralysis).

A Powered Point forces step 1 to 100% but does not change steps 2–3. "Guard" skills give the holder 50% resistance; "Ward" skills give 100% immunity.

Ailment mechanics (default duration 3 turns unless noted):

| Effect | Mechanics |
|---|---|
| Poison / Venom | Damage at start of each turn for 3 turns (formula in §6). Venom is a stronger tier. |
| Sleep | Can't move or act for 3 turns; enemy action timers freeze; normal Sleep breaks on damage (Deep Sleep doesn't). |
| Paralysis | Can't move or act for 3 turns; timers freeze; does NOT break on damage. |
| Confusion | Unit becomes uncontrollable and wanders randomly at the end of the player turn; never initiates pincers nor joins chains. |
| Demoralize | ATK and skill activation rate drop to 0 (MATK unaffected; Powered Points still force skills). |
| Petrify | Turned to stone: can't move or be moved; chains still pass through it. |
| Instant Death / Doom | Damage equal to remaining HP (Doom triggers when its countdown hits 0). |
| Shadowbind | Can't move or act, removes Levitation, deals damage each turn (poison formula). |
| Icebind | Can't move or act; **being pincered while icebound kills the unit**. |
| Scorch | Swapping with a scorched unit damages the OTHER party in the swap for 50% of its current HP (both damaged if both scorched). |
| Lunacy | If the afflicted unit is included in a chain, all allies' ATK/DEF/MATK/MDEF are severely reduced. |
| Levitation (buff) | Immune to floor traps and ground-based attacks; twisters deal double to levitating units. |

Buffs: Attack/Defense/Magic Attack/Magic Defense Up (equip, 2-turn temporary, or position-based), Elemental Damage Down (3 turns), Regen (heals at turn start, 3 turns).

## 11. Traps and tile hazards

| Hazard | Behavior |
|---|---|
| Floor traps (spikes, magma, poison floor, slime, ice walls, lightning floors, fire barriers) | Deal damage when a unit moves over them. *Levitation* avoids ground traps; the pre-battle *Disarmer* item neutralizes most floor traps. |
| Bombs | Explode when moved over (or on their own timer), damaging an area — boss-summoned bombs ~10–30% of target HP with damage caps (500/800). *Disarm Bomb* removes them safely; allies can create friendly bombs (*Build Bomb*, *Summon Bomb*). |
| Time traps ("Time Loss") | Moving across them drains your remaining control time for the current move. Ward/disarm skills exist. (Introduced Ch. 35.) |
| Kinetic traps | Constant damage while in contact. Ward/disarm skills exist. |
| Dimensional rifts ("warpholes") | A unit that falls in vanishes from the battle for several turns and takes damage when it returns. |
| Twisters ("Damage Air") | Damage when moved over; double damage to levitating units. |

## 12. Bosses

- Bosses normally occupy a **2×2 block of tiles**. A 2×2 boss **cannot be corner-pincered or outflanked** — you pincer it across its 2-wide body (flanking units on opposite sides of the block; a 2×2 boss can be pincered by units on opposite sides of either of its rows/columns).
- A minority of bosses are **1×1** (e.g. the Chapter 1-5 Orbling, the Chapter 3-5 Heroes) and obey all normal rules including corner pincers and Outflank.
- Bosses appear on the final battle of a stage, framed in golden flames, are immune to most status ailments (vulnerability 0), but **stat debuffs (Impair taps) still work on almost all of them** (impair vulnerability 100%).
- Bosses have short action counters (often 1–3) and multi-skill kits; many have scripted phases.

## 13. Winning, losing, continuing

- **Victory:** defeat all enemies in every battle of the stage (special quests can have other objectives). Clearing the last battle leads to the results screen.
- **Defeat:** when you can no longer attack — i.e. when **fewer than two units remain alive** a game over triggers (a single survivor cannot form a pincer).
- **Continue:** on game over you may spend **1 Energy to revive the whole squad** in place and continue. Some quests forbid continues (flagged on the pre-battle info screen).
- Death is not permanent: dead units still receive full EXP if the stage is cleared. However, a dead unit loses skill-boost % gained earlier in that run (regains eligibility if revived).
- Most revival skills only trigger **on the transition to the next battle** (One-Time Revival is the exception, firing immediately on death, once per stage).
- **Resuming:** if the app closes mid-stage, on restart the player is offered a resume — back to the start of the current battle/floor (floor progress lost), or to the results screen if the stage was already cleared. Declining forfeits rewards; stamina/items are not refunded.

## 14. Recruitment ("capture") in battle

- Defeated monsters have a small chance to **join the party as recruited units** (per-enemy `job_drop` rates, typically ~2%; some scripted recruits are 100%, e.g. the tutorial Archer/Warrior in 1-2, Ba'gunar at 4-10).
- The HUD "Units" counter tracks how many enemy units have been recruited this stage; a dragon-head icon appears in the upper right when a recruit drops.
- *Negotiator* (+200%) and *Pro Negotiator* (+800%) skills multiply recruit chance; they activate when chaining and stack.
- Enemies can also drop **items** (per-enemy drop tables, commonly ~4% per slot) and rarely **companions**.

## 15. Misc battle rules

- Pause button and a fast-forward (Fwd) button sit on the HUD; fast-forward speed is configurable to ×2 or ×3 in Options.
- Coins, EXP, captured-unit count, and treasure count for the current run are displayed live on the HUD.
- EXP combo: each additional enemy killed within the same player turn awards stacking bonus EXP (+10% per extra kill: 100%, 110%, 120%, 130%…). Kills outside your turn (counters, traps, enemy friendly fire) award base EXP and don't combo.
- Skill activation rate = listed skill % + the unit's accumulated Skill Boost % (additive, not multiplicative; cap 100%).
- In real-time resolution, a unit's damaging/debuff skills apply in the order of its skill list.
