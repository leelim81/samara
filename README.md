# Terra Battle — Web Fan Recreation

A personal, non-commercial fan recreation of Mistwalker's **Terra Battle** (2014),
playable in the browser. Built on Godot **4.6** for the Web (WASM) export target.

Terra Battle and its characters are the property of Mistwalker Corporation /
artist Kimihiko Fujisaka. This project is for private, personal use only and must
not be distributed.

## What's here

- **Two playable stages** with wiki-accurate enemies, stats and wave layouts:
  - *Borderlands* (Lv 1–4): 3 battles, Wee Orblings and the Orbling boss
  - *To the Capital* (Lv 5–6): 5 battles, Sabertooths, Dracorins, Gorf healers and the 2×2 boss Spinetrich
- **Terra Battle combat**: 6×8 grid, drag a unit (4-second timer), pincer enemies
  between two allies, row/column chains, weapon triangle (sword > bow > spear),
  skills with activation rates, enemy action countdowns, Terra's damage formulas
  (`1.395·power·ATK^1.7/DEF^0.7` physical, `1.5·power·MATK^1.7/MDEF^0.7` magical)
- **Six-character roster** (Bahl, Grace, Kuscah, Sh'berdan, Daiana, Ma'curi) with
  job names, base stats and first skills from the wiki, full job artwork in menus
- **Full UI flow**: title → chapter select (stage cards with difficulty/captions) →
  story narration → party dialogue → battle → victory/defeat → squad management →
  settings (EN/ES) — all in Terra Battle's parchment-and-charcoal visual style

## Running

```sh
# Desktop (Godot 4.6+)
godot --path .

# Web export + serve
godot --headless --export-release "Web" build/web/index.html
cd build/web && python3 -m http.server 8642
# open http://localhost:8642
```

## Development

- `docs/gameplay/` — researched documentation of Terra Battle's mechanics
  (combat spec, jobs/skills, progression, UI reference, chapter 1–2 data)
- `scripts/generate_terra_content.py` — regenerates stats/jobs/skills/enemy scenes/
  battle scenes/chapters from the wiki data tables
- `validate_check.gd` — loads every resource and instantiates every scene
- `test_pincer.gd` / `test_playthrough.gd` — headless combat integration tests
  (`godot --headless --script res://test_playthrough.gd -- res://battles/terra/borderlands.tscn`)
- `tools/screenshot.gd` — renders any scene to PNG for visual review

## Heritage and credits

The engine code is based on **Genso Battle** by illusorybread / ax9880 (MIT licensed),
a Touhou fangame with Terra Battle-inspired mechanics, migrated here from Godot 3.5
to Godot 4.6 and re-themed.

- Programming/UI of the original prototype: [illusorybread / ax9880](https://illusorybread.itch.io/)
- Original prototype writing: [Manwad](https://minmaximalistgames.itch.io/)
- Music: [Saishoo](https://saishoo.itch.io/) (`Unlocated_Hell.mp3` — not for reuse or redistribution)
- Sounds: Duelyst (open resources), freesound.org contributors (see `assets/sfx/credits.md`),
  Kenney Casino Audio
- Fonts: Cinzel Decorative, EB Garamond, Exo 2 (Google Fonts, OFL)
- Antialiased Line2D addon © Hugo Locurcio and contributors
- Terra Battle character/enemy artwork © Mistwalker Corporation, sourced from the
  Terra Battle wiki for personal use only (see `assets/terra/characters/manifest.json`)

The source code files (.gd, .tres) remain under the MIT license.
