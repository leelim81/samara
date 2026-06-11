# Terra Battle — Skill System

Source: Terra Battle Wiki (fandom), researched 2026-06-11. For personal fan-recreation reference only.
Primary wiki pages: `Skills`, `Taps`, `Status Effect`, `Attributes`, `Weapons`, `Battles`, `Skill Boost Farming`, `Module:Skills/Data`.

---

## 1. Skill model

- Adventurers learn **4 skills per job** (unlock at job levels 1/15/35/65; recoded Λ at 1/30/50/80–90). Monsters learn 1–4 skills at their own level thresholds.
- A skill is either:
  - **Equip** — a passive that is always on while the unit is alive (e.g. "Attack +10%, Equip", "Levitation, Equip"), or
  - **Triggered** — listed with an **activation percentage** (e.g. "Fire, Area (2), 40%"). When the unit participates in a pincer or chain (per the skill's trigger condition), the skill rolls its percentage.
- **Activation rate = listed rate + the unit's Skill Boost%** — *additive*, not multiplicative (60% skill + 40% SB = 100%, not 84%). Cap 100%.
- **Trigger conditions:**
  - *Pincer-only* skills fire only when the unit is one of the two flanking units (typical for unmodified weapon strikes like Megasword, and skills explicitly noted "only when leading").
  - *Chain* skills fire when the unit is flanking **or** chained (typical for spells and area-modified skills). In the wiki's data files most enemy/ally attack skills carry condition "Chain" with a 30% rate.
  - *Counter* skills fire only when the unit is pincered by the enemy.
  - *Tap* skills are manually activated (see §7).
- During one pincer, skills resolve by phase: **buffs → attack/debuff → healing → capsule → counters** (see combat-system.md §2).
- A **Powered Point** in the chain forces all triggered skills to 100% activation that turn.
- Damage/negative skills only hit enemies, healing/positive skills only hit allies — except explicitly indiscriminate skills (e.g. Zavison's Indiscriminate Fire hits both sides).

## 2. Skill Boost (SB)

A per-character meta-stat that raises all of that character's activation rates (cap 100%).

Gain methods:
- **Duplicate pulls** (Pact of Truth/Fellowship): +12% (Z), +10% (SS/S), +5% (A and below); "+ pacts" add another +0.5–3%.
- **In-battle recruitment** of the same unit: +5% or +3%.
- **Using skills in combat**: each time a skill activates, chance = `2% / (skill's activation rate)` to gain **+0.1% SB** (e.g. a 50% skill ⇒ 4% chance). Four independent phases can each yield at most one boost per quest — Attack, Healing, Capsule, Counterattack — but a unit can bank at most **+0.2% per quest**. If several skills of the same phase fire at once, only the lowest-rate one rolls.
- **Skill Candy** items.

Notes: SB gains work even in zero-EXP quests; a unit that dies loses SB gained that run (unless revived, after which it can gain again); at 100% SB the character is removed from the Truth/Fellowship pools.

## 3. Area-of-effect grammar

A skill's listing is `Name, Area descriptor, Rate%`. Descriptor meanings (6×8 grid):

| Descriptor | Affected tiles |
|---|---|
| *(none)* | Only the pincered enemies; weapon skills with no descriptor fire only when this unit initiates the pincer. |
| Equip | Passive, always on. |
| Self | The caster only. |
| Adjacent | Passive aura on units next to the caster (not the caster). |
| All | Every unit on the field. |
| Area (X) | Square within X tiles of the caster (Area (1) = 3×3, Area (2) = 5×5). |
| Cross (X) | Line of length X in all 4 cardinal directions from the caster. |
| Diamond | Union of Area (1) and Cross (2). |
| Ring | Tiles exactly 2 away from the caster (hollow ring). |
| Lateral (X) | X tiles left and right of the caster. |
| Vertical (X) | X tiles above and below the caster. |
| X Column(s) / X Row(s) | X full columns/rows centered on the caster. |
| 2 Outer Columns / 2 Outer Rows | The 2 columns/rows just inside the border columns/rows. |
| Border | All tiles on the outer rim of the grid. |
| 4x6 Grid | All interior tiles (those fully surrounded — the 4×6 center). |
| Corners | The 4 corner tiles. |
| Chain | Every unit in the chain. |
| Pincer | Only the pincered enemies (e.g. Tiamat). |
| Pincer Area | Pincered enemies + 1 tile around them. |
| Pincer Area (Column/Row) | Full columns/rows of that 1-tile surround. |
| Pincer Column / Pincer Row | Full columns/rows through the pincered enemies. |
| Pincer Ring | Tiles exactly 2 away from the pincered units. |
| Sword/Bow/Spear | Filter: only affects units of that weapon type. |
| Fire/Ice/Lightning/Darkness/Healing/Remedy | Filter: only units of that attribute. |
| Wild Beast/Dragon/Machine/Oxsecian | Filter: only units of that race. |

## 4. Damage skill families

### Physical weapon strikes (use ATK; carry the skill's weapon type)

| Tier | Sword / Spear / Bow names | Power |
|---|---|---|
| 1 | Megasword / Megaspear / Megabow | ×1 |
| 2 | Gigasword / Gigaspear / Gigabow | ×2 |
| 3 | Terasword / Teraspear / Terabow | ×3 |
| 4 | Petasword / Petaspear / Petabow | ×3.5 |

Specials: Thousand Ray Sword / Thousand Spears / Thousand Arrows (flat 1000 damage), Swordspin (0.3× to all), Tremor (4 hits of 0.25× to grounded enemies), launcher skills (Mega/Giga-launcher, chain-capable), Leeching Blade (2×, MATK-based drain, 700 cap), Wild Shot (3.5×, 30%/target).

### Elemental spells (use MATK; element advantage ×2; see Attributes)

| Tier | Fire | Ice | Lightning | Darkness | Photon | Graviton | Power |
|---|---|---|---|---|---|---|---|
| 1 | Fire | Ice | Thunder | Shadow | Radiance | Crush | ×1 |
| 2 | Inferno | Glacier | Lightning | Abyss | Luxon | Gravity | ×2 |
| 3 | Solar Wind | Absolute Zero | Tempest | Dark Matter | Tachyon | Supergravity | ×3 |
| 4 | — | — | — | — | Holy | Axion | ×3.5 |

### Elemental weapon skills ("Blade"/"Arrows"/"Strike")

Hybrid hits since v2.7.0: tier 1 = 1× MATK elemental + 0.5× ATK physical; tier 2 = 2× + 0.7×; tier 3 = 3× + 0.9×. The physical part respects the Circle of Carnage.

### Non-elemental magic (MATK, no element interactions)

Trance (×1), Ultima (×2), Transcendence (×3); "Blast" variants add physical (1×+0.5×, 2×+0.7×, 3×+0.9×).

## 5. Healing and revival (all MATK-scaled)

| Skill | Heal cap |
|---|---|
| Heal / Mega Heal (and themed variants: Healing Wind/Melody/Dance/Fragrance, White Spores, Energy Refill) | 700 |
| Giga Heal / Energy Refill EX | 1300 |
| Tera Heal | 2500 |
| Regen / Mega Regen / Giga Regen | per-turn ticks, no flat cap listed |

Revival: Ally Revival (1 HP), Dual Revival (2 allies, 25% HP), Major Ally Revival (50% HP), Party Revival (all, 1 HP) — all of these only trigger **when advancing to the next battle**; One-Time Revival (self, 25% HP) fires immediately on death, once per quest.

## 6. Buff / debuff / utility skills

- Stat buffs: `Attack/Defense/Magic Attack/Magic Defense +X%` (stack; regular buffs cap at +100% total), HP +X%, Frequency +X% (skill boost up), Desperate Measures (ATK rises as HP falls, max +100%).
- Stat debuffs: `Defense −X%`, Debilitate, etc. — total debuff cap **−30%**.
- Damage-multiplier "Boosts": Physical/Elemental/Heal Boost ×1.5 (stack to the ×3 damage-buff cap).
- Protective: Anti-(Element) Shield (−40% from that element), (E) Dmg Down X%, Physical Dmg Down X%, Aerial Shield (−20% all + Levitation), evasion skills (Fancy Footwork +25%, Evasive Arts / Ninja Footwork +50% physical-evasion odds).
- Capsules: Anti-(Element) Capsule / Capsule Point — drop a capsule on the field; chaining it grants the squad a stacking −10% (element or physical) buff; max 5 capsules/bombs on the field.
- Positioning/economy: Outflank (+50% vs fully surrounded foes, non-stacking), Augment Circle (+20% Circle of Carnage, stacking), Control Time (longer move timer), Expand Power Gauge (+1 stored Powered Point, max +2), Powered Point Amp (+20% gauge rate, non-stacking), Summon Point Amp, Treasure Hunter (+25% item drops, stacking), Negotiator/Pro Negotiator (+200%/+800% recruit chance, chain-activated, stacking), Money Bags (+15%/+30% coins), Coin Bonus, Seasoned Pro (+15% EXP), Pickpocket/Mug (30% to steal a % of enemy base coins; ≤4 steals per enemy), Self Sacrifice (redirect physical damage to self unless lethal), Conversion Rite (10% of damage dealt returned as party healing), Life Drain / Bloodsucker (HP absorb), Build Bomb / Summon Bomb / Disarm Bomb, Stealth (move through enemies), Extend Chain (chain through PP/capsules/units), Reduce Life (cut current HP by 1/3), Add Action Turn (+1 to enemy action counter, 80%).

## 7. Tap skills

- Activated by **tapping the character before moving**; most carry **3 charges per quest**; effect lasts **1 turn**; charges can be spent freely (all at once or spread out). Tapping a unit with several tap skills fires all of them.
- **Augment** taps: +30% to ALL allies' stat(s) per tap — Augment Attack / Magic / Defense / Magic Defense / All. They stack past the normal +100% buff cap, up to the +200% tap cap.
- **Impair** taps: −10% to ALL enemies' stat(s) per tap — Impair Attack / Magic / Defense / Magic Defense / All; share the −30% debuff cap; bypass most debuff immunities (even bosses).

## 8. Counter skills (trigger when the holder is pincered)

Counterattack (physical, 1.5× ATK), elemental counters at 1.5× MATK (Blazing/Icy/Thunderous/Shadow/Radiant/Crushing Counter), Defensive Counter (+10–20% DEF), Offensive Counter (+10% ATK), Restorative Counter / Lick Wounds (self-heal), Demoralizing Counter (75% demoralize chance).

## 9. Status-effect skills

Infliction chance = activation% × hidden infliction% × target's hidden vulnerability% (see combat-system.md §10). Guard = 50% resist; Ward = 100% resist. Panacea cures Poison, Sleep, Paralysis, Confusion, Demoralization, Petrification, Icebind, Shadowbind (not Scorch/Lunacy/skill-rate debuffs/Nullify Healing); Ribbon = 50% resist to nearly everything incl. Death.

| Ailment | Inflictors (examples) | Cures |
|---|---|---|
| Poison / Venom | Poison (x), Green Spores, Poison Sting/Vial/Arrows | Antidote |
| Sleep / Deep Sleep | Lullaby, Slumber, Sleeping Gas, Rose Thorn | Rise and Shine; damage wakes (normal sleep) |
| Paralysis | Paralyze, Paralyzing Blade/Arrows/Dust/Tentacles | Locomotion |
| Confusion | Confuse, Chaos Arrows, Garbage | Clarity |
| Demoralize | Demoralize, Demoralizing Spear/Counter, Intimidate | Esprit de Corps |
| Petrify | Petrify, Petrifying Arrows (80%, 99 turns) | Reanimation |
| Instant Death | Death, Assassinate, Dispatch, Chaos Blade | prevented by Death Guard/Ward |
| Shadowbind | Shadowbind, Gravity Field | Panacea |
| Icebind | Icebind | Panacea |
| Scorch / Lunacy | enemy-only | Scorch Relief / Lunacy Relief |
| Multi | Mood Swing / Fickle Birds (poison+sleep+demoralize), Plague (poison+sleep+confusion) | Cleansing Caper / Panacea |
| Other | Nullify Healing (blocks heal phase), Negate Circle (disables Circle of Carnage) | — |

Standard enemy debuff skills usually pair "30% activation × 100% infliction" or "100% activation × 30% infliction", both lasting 3 turns.

## 10. Companion skills

A character's equipped Companion adds flat stats and one skill that rolls on the **companion's own frequency stat** (level-scaled: `vMin + (vMax−vMin) × (level−1)/(maxLevel−1)`), unaffected by the wearer's Skill Boost or debuffs. With a Powered Point, companion frequency is treated as max-level frequency.
