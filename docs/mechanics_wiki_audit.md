# Mechanics vs the Terra Battle wiki

Audit of every combat / progression calculation against the Terra Battle wiki
(fetched 2026-07-09 via the wiki API; raw wikitext quotes were checked page by
page). Each mechanic below is either EXACT (matches the wiki formula) or an
ADAPTATION (deliberate divergence for this single-player reskin, with the
reason). Tests in `tools/test_*.gd` assert the EXACT rows.

## Exact (wiki formula, implemented and tested)

| Mechanic | Wiki rule | Where | Test |
| --- | --- | --- | --- |
| Physical damage | `1.395 x power x ATK^1.7 / DEF^0.7` | `units/skill_applier.gd` | test_damage |
| Magical damage | `1.5 x power x MATK^1.7 / MDEF^0.7` | `units/skill_applier.gd` | test_damage |
| Damage variance | `x RANDOM(0.9, 1.1)` | skill_applier + attacker | test_damage (formula) |
| Elemental skills are magical | fire/ice/lightning/darkness/healing skills use MATK vs MDEF even on physical weapons; basic pincer attacks stay physical | `skill_applier.calculate_damage(from_skill)` | test_damage |
| Weapon triangle | one-directional double damage: Sword > Gun(Bow) > Spear > Sword; staff neutral; no reverse penalty | `_get_weapon_type_advantage` | test_damage |
| Elements | opposed pairs deal x2 both ways: Fire/Ice, Lightning/Darkness | `_get_attribute_multiplier` | test_damage |
| Chained units' weapon type | chained units strike with their own stats but the pincering unit's weapon type decides the triangle bonus | `board/attacker.gd` | test_full_chain |
| Chain = extra attacks | each chained unit grants one full extra attack; no per-link multiplier | `board/attacker.gd` | test_full_chain |
| Powered Point | x1.5 all damage and healing for the rest of the player turn; every skill guaranteed; companion frequency at max; infliction chance unchanged; player-only | board + skill_applier + unit | test_powered_point |
| Skill Boost is additive | effective rate = listed rate + boost (+ modifiers) | `unit.activate_skills` | test_activation, test_skill_growth |
| Activation modifiers | positive modifier raises the chance; Demoralize's -1 disables skills AND counters | unit + attacker | test_activation |
| Demoralize | attack to 0, skills disabled, MATK untouched | `status_effects/demoralize.gd` | test_status_advanced |
| Poison tick | `MATK x power x 0.5`, then `x RANDOM(1, 1.2)` | `status_effects/poison.gd` | test_status_advanced |
| Sleep / Deep Sleep | sleep wakes on hit; deep sleep does not | unit.on_attacked | test_status_advanced |
| Icebind | frozen unit dies when pincered | `board/board.gd` pincer resolution | test_status_board |
| Petrify | blocks moving/acting but NOT chaining | `unit.can_chain` + pincerer | test_status_board |
| Counterattack | triggers via COUNTER skills when pincered, x1.5 power; elemental counters run on MATK | counterattack.tres (power 1.5) + skill weapon/attribute | test_counter |
| Buff/debuff caps | total stat buffs cap at +100 percent, debuffs at -30 percent | `unit._apply_stat_caps` | (covered in battle flow) |
| Kill-combo EXP | 2nd kill 110 percent, 3rd 120, 4th 130...; counters and traps excluded | `board/board.gd` | test_campaign_drip |
| Luck chests | A chest guaranteed at 40 average Luck, B at 85, C 50 percent and D 25 percent at 100; Luck caps at 100 | `drops/luck_drops.gd`, `jobs/job.gd` | test_luck_drops |
| Skill slots | unlock at levels 1 / 15 / 35 / 65 | job model | test_jobs |
| Jobs | 3 per character, unlocked in order with items + coins, switch freely outside battle, own art/stats/skills | jobs system | test_jobs |
| Level cap | 90 | `stats/leveling.gd` | test_leveling |

## Adaptations (deliberate, documented divergences)

- **EXP curve.** The wiki gives per-character curves (`exp = expMax x f^~2.1`,
  expMax 2M..12.5M). This game uses one tunable curve of the same power-law
  family (`80 x (level-1)^2.4`) because the 42-chapter campaign pacing is
  tuned around it (test_campaign_drip).
- **Stat growth.** The wiki interpolates statMin to statMax (about 10x) toward
  L99. This game uses `base x L^0.53`, anchored to the wiki's Mechaclops
  336 to 3660 HP data point, reaching about 11x at the L90 cap.
- **Skill-up growth.** The wiki ties Skill Boost mostly to gacha duplicates
  (+0.1 percent per proc in battle, capped per quest). No gacha here, so use
  growth is simplified to +2 percent per 8 uses, capped at +20 percent
  (stats/skill_growth.gd).
- **Companion scaling.** The wiki levels companions separately by fusion
  (linear vMin..vMax in the companion's own level). Companions here ride the
  owner's growth curve and reach full listed strength at L90.
- **Capsules.** TB capsules are skill-created board objects granting resist
  buffs. This game's capsules (recovery / coin, dropped by defeated enemies
  and collected by chaining) are a house system; the chain-to-collect rule
  and the Extend Chain interaction match TB.
- **Elements.** Four of the wiki's eight elements (Fire/Ice,
  Lightning/Darkness). Solar/Lunar/Photon/Graviton were deliberately removed.
- **Petrify "cannot be moved".** Not implemented: the drag system is physics
  driven and blocking displacement mid-drag would need invasive changes. The
  gameplay-relevant halves (cannot move or act, chain passes through) are in.
- **Sub-threshold luck odds.** The wiki only specifies the guarantee points;
  below them this game ramps the chest chance linearly from zero.
- **Heal amounts.** The wiki lists per-skill flat caps but no formula below
  the cap. Heals here scale from MATK through the magical formula with a
  x3 multiplier (HEAL_POWER_MULTIPLIER), tuned for this campaign.
- **New-to-TB statuses.** Blind and Weakness have no TB equivalent (no
  accuracy system exists); they are house ailments modeled as stat reduction
  and an elemental damage multiplier.
