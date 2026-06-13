# Terra Battle character stats (wiki snapshot)

Downloaded 2026-06 from the Terra Battle wiki `Characters/Stats` page
(`https://terrabattle.fandom.com/wiki/Characters/Stats`) via the MediaWiki
API (`action=parse`), for reference when balancing this fan recreation.

- `level_<N>.json` — every playable character's stats at that level
  (the wiki exposes levels 1, 10, 15, 25, 35, 45, 50, 65, 80, 90).
- `all_levels.json` — all of the above keyed by `Level_<N>`.

Each record: `name, rarity, weapon, attribute, hp, atk, def, matk, mdef, exp`
(numeric stats are ints). 618 characters per level.

## Using these for balance

The engine computes a stat as `level * base * 0.1 * percentage`
(`base` = 1500 for HP, 50 for the others — see `stats/stats.gd`). So to give
a unit a real wiki value at a chosen level:

    percentage = wiki_value / (level * base * 0.1)

i.e. `hp% = wiki_hp / (level * 150)`, `stat% = wiki_stat / (level * 5)`.
The generator (`scripts/generate_terra_content.py`) already does this; the
enemy/character stat blocks there are calibrated to the wiki value at each
unit's level.

Note the engine's growth is LINEAR per level, while real Terra Battle growth
curves slightly. A `percentage` is therefore exact only at the level it was
calibrated for; keep a unit near that level for accuracy.

### Verified 2026-06
Player characters match the wiki at level 1 (Bahl 321, Grace 318, Kuscah 293,
Daiana 317 HP). The recruitable enemies match at their levels (dracorin L5
411 ≈ wiki ~402; sabertooth L6 425 ≈ wiki ~478). The boss (spinetrich) HP is
intentionally buffed above the recruitable value.
