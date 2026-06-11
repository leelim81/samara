# Terra Battle — Game Overview

Source: Terra Battle Wiki (fandom), researched 2026-06-11. For personal fan-recreation reference only.

## What the game is

- **Terra Battle** was a free-to-play mobile tactics/puzzle RPG by **Mistwalker**, released **October 9, 2014** on iOS and Android. Servers shut down **June 30, 2020**.
- Game design by **Hironobu Sakaguchi** (Final Fantasy creator), music by **Nobuo Uematsu**, lead character art by **Kimihiko Fujisaka**, with guest artists added via the "Download Starter" milestone campaign (Amano, Minaba, Suzuki, etc.).
- Genre blend: a **tile/grid puzzle battler** (drag a unit within a time limit, displacing allies as you go — comparable to Puzzle & Dragons' orb-shuffling) crossed with **JRPG systems** (jobs, classes, elements, gacha recruitment, leveling).
- A short-lived desktop port existed via AndApp (Japan, Apr 2017 – Feb 2018). The final major client version was 5.5.0 (Oct 9, 2018).

## Story premise (paraphrased)

The world is a dying, fractured land — millennia after the fall of the primordial civilization of Gallus, the atmosphere is thinning and even gravity is failing. Humans, the reptilian-amphibian **Lizardfolk**, and the feral **Beastfolk** each tell of a mysterious creator, the **Maker**, said to slumber deep underground. A band of adventurers sets out from the borderlands toward the capital and then downward into the earth on a pilgrimage to find the Maker, uncovering ancient myths along the way. (Predators — non-sentient monsters — roam everywhere and attack all races.)

## Core loop

1. **Spend Stamina** to enter a story stage (or special quest). Stamina regenerates 1 point per 2 minutes (1 per 5 minutes at launch).
2. **Fight** through the stage's 3–10 sequential battles on the 6×8 grid (see `combat-system.md`).
3. **Collect** EXP, coins, item drops, occasional recruited monsters/companions, plus end-of-run **Luck treasure chests**.
4. **Upgrade** between runs: level characters, unlock and level **jobs** (Add Jobs), equip skill slots and companions, evolve/upgrade companions, eventually **Recode DNA** characters into Λ (Lambda) versions.
5. **Recruit** new characters via the Tavern's gacha pacts: **Pact of Truth** (premium currency: Energy) and **Pact of Fellowship** (coins), later also **Pact of Fate** (Luck-focused duplicates).
6. Clearing a chapter for the first time awards **1 Energy**, raises **max stamina**, and refills stamina — fueling the next loop.

## Currencies

| Currency | Role | Main sources |
|---|---|---|
| **Energy** | Premium currency. 5 = one Pact of Truth/Fate(energy) pull; 3 = Companions of Truth pull; 1 = full stamina refill; 1 = continue after game over. | IAP shop ($0.99 ≈ 1 Energy), login bonuses, 1/day video ad, chapter first-clears, achievements |
| **Stamina** | Entry cost for quests (1 per early stage, dozens for late ones). Starts at max 25, grows to 167 by Chapter 42. | Regenerates over time; refilled by chapter clears or 1 Energy |
| **Coins** | Soft currency: 3,000 = Pact of Fellowship/Fate(coins) pull; 2,000 = Companions of Fellowship pull; pays for Add Jobs, Recode DNA, companion upgrades. | Battle drops, login bonuses, selling companions, coin-farming quests |

## Game modes / menu map

Top-level menu sections (final 5.5.0 layout):

- **Map (World Map / Main Quest)** — the story: **42 chapters** (Part 1 = ch. 1–30, Part 1.5 = ch. 31–34, Part 2 = ch. 35–42), each chapter containing ~5–10 stages. Side zones unlock on the map: **Cryptid Forest** (after ch. 4), **Orbling Cavern** (after ch. 5), Λ character quests (after ch. 34). "To Another World" bonus chapters: **Ultimate Five** (after ch. 19) and **The Death of Shay and Arionne** (after ch. 25).
- **Arena** — hard content: **Special Quests** (event/crossover quests, e.g. The Last Story, FFXV, Mobius FF), **Descent Quests** (superboss series: Bahamut/Leviathan/Odin Descended→Evolved→Ultra→Recoded, Dragon Kings, Royal Rings), **Eidolon Quests**, **Tower of Temptation** (challenge towers).
- **Huntland** — grind content: **Metal Zone** (high-EXP leveling runs, level-banded 1–19 … 70–89), **Hunting Zone** (material farming: Attack of the Coin Creeps = coins, Pudding Time = elemental mats, Tin Parade = weapon mats/tears, Puppet Show = race mats, Crystal Road), **Strikes Back** quests (companion farming), **Daily Quests** (rotating daily rewards: energy, coins, items).
- **Main** — collection management: **Characters**, **Party Formation** (15 squads × 6 units), **Companions**, **Items**, **Achievements**.
- **Tavern** — economy hub: Recruit (the gacha pacts), Trading Post, **Add Jobs**, **Recode DNA**, Upgrade/Evolve Companions, Energy shop, stamina restore.
- **Options** — settings, story replay, tips, account transfer, credits.

### Removed/retired modes (existed 2015–2018, removed in v5.5.0)

- **Co-op Mode** — up to real-time multiplayer rooms (private/public/quick match) for story stages and special Eidolon quests; host got 100% of coin/EXP rewards, guests 20%; guests level-capped relative to quest difficulty. Tapping during others' turns charged a summon gauge to spawn **Eidolon** summons.
- **VS Mode** — asynchronous-real-time 1v1 PvP during scheduled "Cup" events, with its own VS Stamina (100 cap, 1/3min), leagues, rankings, and team-cost limits per class (Z=18 … D≈4).
- **Eidolons** — summonable mega-units used in Co-op/VS (Bahamut, Odin, Leviathan, Artemis, etc.); after v5.5.0 they became pure collectibles.
- **Weekly Challenge** — score-attack mode with rankings.

## Platform & live-ops notes (useful context for a recreation)

- Portrait-orientation, one-finger play; whole game is touch-driven (drag + tap).
- Stage entries cost stamina; chapter difficulty is expressed as a recommended level (Lv 1 → Lv 90 max).
- Daily login bonuses (coins/energy), daily free ad-pull, rotating daily quests and a per-day "Daily Bonus" buff (e.g. boosted drop rates on certain chapters).
- The "Download Starter" campaign added new characters/features at download milestones (e.g. new playable characters at 200K/300K/…/2M downloads, console project at 2M).
