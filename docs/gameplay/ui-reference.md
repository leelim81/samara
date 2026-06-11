# Terra Battle — UI Reference (Screens, Flow, Aesthetic)

Source: Terra Battle Wiki (fandom), researched 2026-06-11. For personal fan-recreation reference only.
Wiki facts come from: `Combat Guide` (battle screen), `Characters` (menu/status/sort), `Tavern`, `Options`, `Pact of Fate` (envelope flow), `Battles` (resume dialog), `Template:Game menus`, archived official playguide. Visual/aesthetic notes are descriptive summaries of the game's widely documented art direction and official screenshots — treat exact colors as approximations, not data.

---

## 1. Overall aesthetic

- **Portrait orientation**, one-handed touch play.
- The signature look is **flat, minimalist, geometric**: large fields of muted **beige / cream / parchment** tones with a faint paper-like texture, thin hairline rules and outlined rectangles instead of skeuomorphic chrome, and a lot of negative space.
- **Typography is thin and elegant** (light-weight Latin sans-serif with wide tracking for headers; small caps/uppercase labels common). Numbers and labels are typically dark charcoal on light ground, or white on dark translucent panels.
- **Accent colors are sparse and semantic**: blue = allied, red = enemy, gold = boss/rare/reward, with rarity tones (bronze/silver/gold/rainbow) for gacha results.
- Character/job art is painterly full-body illustration shown against plain pale backdrops; in-battle units are small circular/square **chibi portrait tokens** with a colored border.
- Menus generally animate with simple slides/fades; the soundtrack and clean look carry the presentation rather than heavy VFX.

## 2. Title and main screen

- Title screen: game logo over a minimal background; tap to proceed (standard mobile flow; user data loads, then the main screen).
- The **Main (home) screen** features the world-map/menu hub with **scrolling tip messages** along the screen (these tips can be toggled off in Options — "Main Screen Tips"). News popups and login-bonus dialogs appear here on launch.
- Documented top-level navigation (matches the wiki's "Game Menus" box):
  - **Map** — story chapters + special map zones
  - **Arena** — challenge quests
  - **Huntland** — grinding quests (added v5.5.0; earlier these lived under Arena/map banners)
  - **Main** — Characters / Party Formation / Companions / Items / Achievements
  - **Tavern** — Recruit (pacts), Trading Post, Add Jobs, Recode DNA, companion upgrade/evolve, Shop
  - **Options**
- Mode buttons are stacked as large flat rectangular banners the player scrolls through vertically; sub-menus are vertical lists as well.

## 3. Stage select / pre-battle

- The **World Map** presents chapters in sequence; selecting a chapter lists its stages (1-1 … 1-5 etc.). Side quests (Cryptid Forest, Orbling Cavern) appear as separate map entrances.
- Each stage has a **battle information screen** before entry showing: flavor caption (one-line story text, e.g. stage 1-1 "The wild creatures of this world are on the attack."), **stamina cost**, **difficulty level** (Lv N), number of battles, and whether continues are allowed. Power-up items (EXP Boost, Coin Boost, Time Extension, Disarmer — only one) are chosen here.
- Squad selection: pick one of the saved parties before starting.

## 4. In-battle HUD

Documented HUD elements (from the wiki's annotated battle screenshot):

| Element | Behavior |
|---|---|
| **Power Gauge** (top-left) | 3 segmented bars; each filled bar spawns a Powered Point on a random tile. |
| **Timer Gauge** | The 4-second movement timer; starts draining when the held unit leaves its square. |
| **Coins** | Coins accumulated this stage (live counter). |
| **EXP** | Experience accumulated this stage. |
| **Units** | Number of enemy units recruited ("captured") this stage; a small dragon-head icon flags a successful recruit. |
| **Treasure** | Items collected this stage. |
| **Pause** | Pause button — pause menu includes music/SFX toggles and give-up. |
| **Fwd (>>)** | Fast-forward toggle for attack animations (×2 or ×3, configurable in Options). |

- Battle floor counter: stages are sequences of battles ("Battle 1/3" style wave indicator between floors).
- **Units on the grid**: allied tokens have **blue borders**, enemies **red borders**, bosses a **golden stylized-flame frame**. Enemy tokens display their **action countdown number**; ally HP is inspectable per unit (tap-hold), with damage/heal numbers popping over tiles during resolution. Status icons overlay afflicted tokens.
- Skill activations print the skill name as floating text near the acting unit while the chain resolves; pincer/chain links are drawn as connecting lines when you set up a move.
- Tap a character **before** moving to fire Tap skills (Augment/Impair) — tapping shows remaining charges.

## 5. Battle results screen

- Appears after the final floor: tallies **EXP per character** (level-up animations), **coins**, **items/treasure**, **recruited units**, and then the **Luck Treasure Chests** reveal (chests A/B/C/D/Luck 80/Luck 100 opening based on team average Luck).
- Results-screen Luck gains (the +0.1–0.3 battle-end roll on 8+ stamina quests) are shown here per character.
- If the app is killed mid-run, next launch shows a **Resume dialog** ("resume battle?" with the option to decline; declining forfeits rewards; consumed stamina/items are not refunded). Resuming a cleared run jumps straight to results.
- Game over screen offers **Continue (1 Energy, revives the whole squad)** or quit.

## 6. Characters menu and status screen

- **Characters list**: grid of owned character portraits showing each one's current job, available jobs, job levels, Skill Boost %, and Luck.
- **Sort/filter UI**: two sort keys from {None, Date, Attribute, Weapon, Level, HP, ATK, DEF, MATK, MDEF, Race, Rarity, SB, Luck} + a Reverse toggle; filters darken non-matching units by Weapon {Sword, Spear, Bow, Staff, Unarmed}, Attribute {Fire, Ice, Lightning, Darkness, Photon, Graviton, Healing, Remedy, None}, Type {Adventurer, Monster}, Race (13 species); plus a reset.
- **Status screen** (tap a character): shows species, class, level + EXP-to-next, the 5 stats, Skill Boost, Luck, equipped Companion (with a swap button), and the skill list. Tapping the artwork opens a **full-screen illustration with profile/lore text**. Job icons let you switch active job; skill-slot management lives here too.
- **Party Formation**: 15 squads; each squad holds 2–6 characters; squads are renameable (≤10 characters). Job/skill-slot changes propagate to all squads.

## 7. Tavern screens

- **Recruit**: horizontally swipeable pact pages (Pact of Fate / Pact of Truth / Pact of Fellowship / Companions of Truth / Companions of Fellowship). Each shows cost, a **Lineup** button revealing exact pull rates, and 1× / 10× pull buttons.
- **Pull animation**: an envelope/pact appears — **Bronze, Silver, Gold, or Rainbow** styling telegraphs the rarity tier (D / A–C / S–SS / Z). The envelope must be **tapped to open**; backing out before opening cancels the pull. "+" pacts are visually marked and add bonus levels/SB/Luck.
- **Add Jobs**: pick character → next job slot shows required items/coins with owned-vs-needed counts → confirm.
- **Recode DNA**: pick an eligible character; the screen lists the required monsters, helixes, items, coins; consumed units must not be in squads.
- **Upgrade Companion** (fusion with coin cost) and **Evolve Companion** (max-level + items) flows; **Trading Post** (Animata-item currency); **Shop** (energy purchase, stamina restore).

## 8. Options menu (documented entries)

Music on/off, Sound Effects on/off, Live Soundtrack toggle (live-recorded versions of tracks), Fast Forward speed (×2/×3), Main Screen Tips toggle, Companion Compendium (every companion ever owned), Help (online playguide), Tips gallery, **Story** (replay all unlocked chapter story text), User Info (user ID/name/inquiry ID; rename every 2 weeks), Language (EN/JA/FR/DE/ES/2×Trad. Chinese), Change Devices (account-transfer ID), Credits, License, Support, ToS, Privacy Policy. (Historical: gift-code entry and friend-invite existed pre-2016.)

## 9. Flow summary (happy path)

Title → Main screen (login bonus popup) → Map → chapter → stage info (cost/difficulty/power-up/squad) → battle floors 1..N (drag-move per turn; pincers resolve; enemy turn) → boss floor → results (EXP/coins/items/luck chests) → back to map (first-clear: +1 Energy, stamina refilled/max-up; next stage unlocked) → Tavern between runs (pulls / Add Jobs / companions) → Main > Characters (jobs, skill slots, companions) → repeat.
