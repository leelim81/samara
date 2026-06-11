# Terra Battle — Characters, Jobs, Classes, Stats, Leveling

Source: Terra Battle Wiki (fandom), researched 2026-06-11. For personal fan-recreation reference only.
Primary wiki pages: `Characters`, `Adventurers`, `Monsters`, `Classes`, `Add Jobs`, `Levels`, `Weapons`, `Attributes`, `Recode DNA`, individual character pages (Bahl, Grace, Healer, Knight, Archer, Warrior), `Module:Characters/Data`.

---

## 1. Character taxonomy

Two big categories of playable units:

- **Adventurers** — the named hero characters (classes Z, SS, S, A, B). Most have **3 jobs**; each job teaches **4 skills**. Obtained from the Pact of Truth/Fate (energy), story events, or rarely the Pact of Fellowship.
- **Monsters** — recruitable creatures/generic humanoids (classes A, B, C, D, plus special Λ monsters). They have **one job** and learn **1–4 skills** (lower rarity → fewer skills), and **no skill slots**. Obtained from the Pact of Fellowship/Fate (coins) or as rare battle drops.

Other unit-like collectibles: **Companions** (equippable accessories — one per character — granting flat ATK/DEF/MATK/MDEF and a skill with its own activation frequency) and **Eidolons** (legacy co-op summons).

Players can own only **one copy of each character**; duplicates pulled from gachas instead grant levels + Skill Boost (Truth/Fellowship) or levels + Luck (Fate). A Λ (recoded) version counts as a separate character from its base.

## 2. Classes (rarity)

7 tiers, highest to lowest: **Z, SS, S, A, B, C, D**.

- Adventurers: Z–B. Monsters: A–D (Λ monsters can be S/Z).
- Higher class ⇒ generally better stats/skills, rarer pulls, bigger duplicate bonuses, higher Luck caps.
- Pact of Truth rates: **Z 4%, SS 10%, S 15%, A/B 71%** (evenly split).
- Class also gates costs: e.g. Add Jobs coins (see §5), recode coins, duplicate gains (Z +6 levels/+12% SB; SS/S +5/+10%; A and below +1/+5%).

## 3. Roles, weapons, attributes

There is no formal "class = Swordsman" system; a unit's role emerges from its **weapon type + attribute + skills**:

- **Weapon types** (the Circle of Carnage triangle, ×2 one-way damage): **Sword > Bow > Spear > Sword**; **Staff** and **Unarmed** are neutral.
- **Attributes**: Fire, Ice, Lightning, Darkness, Photon, Graviton, Solar, Lunar (the 8 elements), plus support attributes **Healing** and **Remedy**, plus skill-only **Non-elemental**.
- Community/guide role shorthand:
  - *Swordsman / Spearman / Archer* — physical attackers (ATK-based), pick by triangle coverage.
  - *Mage* — staff + element; MATK-based area spells (Fire/Inferno/Solar Wind etc.).
  - *Healer* — Healing attribute; MATK-based heal skills.
  - *Remedy (support)* — cures/prevents status ailments; little damage.
- A character's job change can switch its weapon type (e.g. Suoh: Job1 Sword → Job2 Bow → Job3 Spear).
- **Species/races** (mostly flavor + material requirements + race-targeted skills): Human, Lizardfolk, Beastfolk, Stonefolk, Wild Beast, Dragon, Machine, Cell, Celestial, Oxsecian, Spirit, Riftworlder, Eidolon.
- Recommended starter party composition (from guides): 1× sword, 1× spear, 1× bow, 1× mage, 1× healer, +1 flex (remedy later).

## 4. Stats

Exactly **5 core parameters**: **HP, ATK (Attack), DEF (Defense), MATK (Magic Attack), MDEF (Magic Defense)**.
There is **no speed/agility stat** (turn order is positional, not stat-based). Two meta-stats grow outside leveling:

- **Skill Boost (SB%)** — additive bonus to every skill's activation rate (cap 100%). See `skills.md`.
- **Luck** — affects end-of-stage treasure chests (cap 100 for Λ/Z, 80 for SS/S, 70 for A and below). See `progression.md`.

### Example stat blocks (level 1 → level 90, from character pages)

| Unit | Class | Weapon | HP | ATK | DEF | MATK | MDEF |
|---|---|---|---|---|---|---|---|
| Bahl (Job 1, "Dark Duelist") | B | Sword | 321→2957 | 31→284 | 26→238 | 13→119 | 15→138 |
| Bahl (Job 3, "Dark Hero") | B | Sword | 442→4072 | 39→356 | 32→293 | 19→174 | 21→193 |
| Grace (Job 1, "Archer") | B | Bow | 318→2942 | 31→284 | 24→220 | 15→137 | 17→155 |
| Healer (monster) | C | Staff/Healing | 245→2669 | 12→119 | 14→153 | 24→238 | 25→272 |
| Knight (monster) | C | Spear | 315→3453 | 30→298 | 23→250 | 12→119 | 14→153 |
| Archer (monster) | C | Bow | 316→3442 | 30→298 | 23→250 | 12→119 | 14→153 |
| Warrior (monster) | C | Sword | 315→3431 | 30→298 | 23→250 | 12→119 | 14→153 |
| Sabertooth (monster) | D | Spear | 333→3627 | 32→318 | 26→283 | 10→99 | 14→152 |

Later jobs have higher bases and caps than Job 1 (see Bahl above).

## 5. Jobs and Add Jobs

- Each adventurer has up to **3 jobs**. Job 1 is available from the start; **Jobs 2 and 3 are purchased in the Tavern ("Add Jobs")** with items + coins, strictly in order (Job 2 before Job 3).
- What a new job gives: **new character art**, new profile text, a **new set of 4 skills** (unlocked at job levels 1/15/35/65), and usually **better stats**.
- **Each job levels independently** (new job starts at level 1; old jobs keep their levels). Players can switch the active job any time **outside battle** from the character's Status screen.
- Add Jobs coin costs by class: Z Job2 14,000 / Job3 28,000; SS & S Job2 10,000 / Job3 20,000; A & B Job2 8,000 / Job3 16,000.
- Material pattern: Job 2 needs species-specific + weapon-type items + **Tears**; Job 3 needs species + weapon items + **Particles** (e.g. Bahl Job 3: 15× Wisdom Flower, 15× Terra Swordsteel, 3× Spirit Particle, 16,000 coins). Story starters' Job 2 needs a special **Terra Fragment** from the story.

### Skill slots

- Adventurers start with **1 skill slot**; more unlock as jobs level, to a max of **4 slots**:
  - Standard 3-job adventurers: slot 2/3/4 when Job 1/Job 2/Job 3 each reach **level 20**.
  - Z-class: slots at Job1 lv20, Job2 lv40, Job3 lv60.
  - Recoded (Λ, single job): slots at levels 20/40/60 of the one job.
  - Single-job non-recoded units (monsters): **no skill slots**.
- Slots hold skills from the character's **other jobs** (any of them, regardless of weapon/element); a slotted skill only functions in battle once it has actually been **unlocked** by leveling its source job. Active kit = current job's 4 skills + up to 4 slotted = **max 8 usable skills**.

## 6. Leveling and stat growth

- Cap: **level 90 per job** (and per monster). At 90, EXP still accrues until "1 EXP to next level".
- Characters earn EXP from cleared quests even if they died during the run.
- New gacha recruits start at **level 10**.
- EXP-boost skills stack additively up to **+130%**; the EXP Boost item (+50%) stacks on top separately.
- Kill-combo EXP bonus: +10% per extra enemy killed in the same turn (2nd kill 110%, 3rd 120%, …).

### Growth formula (from the wiki's character data module)

Stats interpolate from a level-1 value to a calibration value at an internal max level of 99:

```
f          = (level − 1) / (99 − 1)          # 0.0 at lv1, 1.0 at lv99
stat(level)= floor( statMin + (statMax − statMin) × f^coeff )
exp(level) = floor( expMax × f^expCoeff )
```

Each of HP/ATK/DEF/MATK/MDEF has its own `statMin`, `statMax`, and curve coefficient (`coeff` 1.0 = linear, >1 = exponential). Level 90 (f ≈ 0.92) is the real in-game ceiling; the level-99 numbers are just curve parameters.

## 7. Recode DNA (Λ characters)

End-game character evolution, unlocked by **clearing Chapter 20**, performed in the Tavern:

- Requirements (per-character specifics vary): base character at **level 80+ in all jobs**, two **specific monsters at level 50+** (consumed; Joker Λ can substitute for one), **5 Helixes** (Deepwater/Mantle/Temporal; some recodes want 50 Flawless Helixes), one special recode item (Ether/Elixir/Black Hole/White Hole/Wormhole/etc.), **15 weapon- or attribute-type items**, and **30,000 coins** (Z-class result) or 20,000 (lower).
- Result: a new **Λ character** of a higher class with higher stat caps, starting at **level 1**, with a **single job**. Skills unlock at **1/30/50/80(or 90)**; skill slots at **1/20/40/60**, able to slot any skill from all of the base character's old jobs.
- Carryover: 100% of the base character's Skill Boost and Luck, plus 20% of each material monster's SB and Luck (total SB ≤ 100). Λ Luck cap = 100. Recoding again when the Λ is already owned adds SB/Luck (+5 Luck) instead of a new unit.
- The consumed base character and monsters can be re-obtained later as fresh copies.

## 8. Starter and story characters

- New players choose/receive a starter adventurer: **Bahl** (B, sword) or **Grace** (B, bow), plus the monster **Healer** (C, staff/healing). (Later live events replaced Healer with an adventurer healer: Kuscah, Sorman, Amina, Amimari, A'misandra.)
- Tutorial recruits: **Knight** (C, spear) joins after stage 1-1; after 1-2, **Archer** joins if you started with Bahl, or **Warrior** if you started with Grace (you fight them as level-1 enemies first, 100% recruit on first clear).
- Story joins: **Ba'gunar** (B, sword/lightning) after Chapter 4; **Palpa** (S, remedy) after Chapter 10. Completing Chapter 34 / 38 adds 54B2, 36AIS / Jag to the gacha pools.
- Event-only adventurers (Bahamut, Leviathan, Odin, Jade Dragon, etc.) come from Arena events; promotional ones (Yulia, download-milestone characters) from codes/milestones.

## 9. Party formation

- A squad = **2 to 6 characters**; the player can save **15 squads** (10 at launch) and rename them (≤10 characters).
- Job and skill-slot setups are per-character and shared across all squads.
- Each character can equip **one Companion** (must meet the companion's required job level for it to function).
