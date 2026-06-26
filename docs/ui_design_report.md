# Water Margin Game — UI Design Report

## 1. Design Audit

### The core problem: the game is not one design, it's three pasted together

The audits make the situation unambiguous. There is a **declared aesthetic** (parchment-and-charcoal, serif, gold), a **partially-built aesthetic** (the menus/dialogue mostly honor it), and **two foreign aesthetics** that leaked in from Terra Battle's original assets (a dark navy+cyan battle HUD, and a dark blue+cyan "sci-fi" character/squad menu system). Nothing routes these — they're all hand-coded per scene.

**Three competing palettes, none tokenized:**

| Palette | Where | Signature colors |
|---|---|---|
| Parchment (intended) | Title, main menu, pre-battle hub, dialogue, victory/defeat | `#efe8d8` cream, `#3a362f` ink, `#bfa062` gold |
| Dark sci-fi (foreign) | characters_menu, squad_menu, change_unit, view_unit, unit cards | `#192A2A`/`#202638` dark blue, cyan borders `#8FD1D1` `#63D4D4` |
| Dark navy HUD (foreign) | In-battle HudBar | `#101419` navy, `#5CAACD`/`#6BEAE0` cyan |

The cyan family (`#6beadb`, `#72e6e6`, `#8FD1D1`, `#63D4D4`, `#5CAACD`) appears **nowhere in theme.tres** and reads as electric/sci-fi — the single most off-theme element for a Song-dynasty outlaw saga. It shows up on "YOUR TURN," the HUD border, unit-card frames, skill-feed attack labels, and stat icons.

**Font/size/color sprawl is real and quantifiable:**
- **3 typefaces** with no enforced hierarchy: Exo 2 (sans, the de-facto default for ~25 uses), EB Garamond (serif, ~10 uses), Cinzel Decorative (serif display, ~5 uses). The two serifs that *match* the aesthetic are the *least* used; the sans that fights it is the default.
- **~13 distinct font sizes** from 13pt to 72pt with **no modular scale** (gaps like 20→17→16→24 are arbitrary). Smallest is 13pt — risky on small/web screens.
- **45+ hardcoded `Color()` values** scattered across .tscn files instead of theme tokens. theme.tres holds maybe 40% of the system; 60% lives in scenes.
- "SemiBold" isn't a real cut — it's `FontVariation embolden=0.6` at runtime. No Exo2-SemiBold file ships.
- Three parchment tans (`#efe8d8` / `#f2eddf` / `#e8dfcd`) differ by ~3% lightness — too close to read as hierarchy.

**The HUD is the worst offender (and the most-seen screen):**
- Dark navy bar `#101419` directly abuts warm parchment — the audit calls it an "amateur copy-paste" from TB commit 3fde6a1. It is the clearest "two themes spliced together" moment in the game.
- **Grey monochrome icons on dark bar**: `ui_icons.png` is a Terra Battle artifact — greyscale strokes, no color. The clock icon at `#D1D1C2` on `#101419` is a "faint grey smudge"; the 7 squad portraits are "grey sludge" and become muddier when KO'd. This is a genuine *legibility* failure during the part of the game where squad-status glance-ability matters most.
- **Contrast failures**: "TURN" label `#AABABA` on navy ≈ 4.2:1 (fails WCAG AA). Dark buttons (`#212530`) are nearly invisible against the bar until hover.

**Other drift worth fixing:**
- Skill feed uses neon cyan/blue/magenta (`#72e0ff`, `#b7c1ff`, `#db9eff`) — "ripped from a sci-fi game," and 31pt *italic serif on moving labels* is hard to read at animation speed.
- Cut-in banner uses sans-serif white text — modern game-UI voice, not narrative callout.
- Dialogue **message** text inherits Exo 2 sans while **narration** uses EB Garamond serif — a tonal break *within a single cutscene*.
- Unit cards cram name + weapon + level + 4 stat rows + button into ~100px — overcrowded, weak 1px/7%-opacity borders, flat, no depth.
- Victory has a drop shadow and particles; defeat/settings/loading have none — inconsistent depth and polish parity. Loading text is 20px (too small to read as a loading state).
- Disabled buttons (60% opacity only) barely differ from enabled.

### What's actually good (don't throw it away)
The **macro discipline** is solid: every parchment screen shares the `#efe8d8` ColorRect background and a 50px margin convention; the button system has genuinely nice tactile feedback (1.04× BACK-ease pop + click SFX); the gold hover-border affordance is clean; victory screen shows real craft. The parchment aesthetic *is* visually coherent **where it's applied** — the problem is purely that it isn't applied everywhere, and isn't tokenized so it *could* be.

---

## 2. Four design directions

Each is a complete, app-wide system — HUD, menus, and dialogue all obey the same rules. All four kill the cyan, tokenize color, and fix the icon problem.

---

### Direction A — "Illuminated Scroll" (parchment, everywhere)
**Vibe:** an aged Song-dynasty handscroll; the whole game lives on warm paper, including battle.

**Typography**
- Display/titles: **Cinzel Decorative Bold** (already shipped) — chapter names, screen titles, victory/defeat.
- Narrative + names + numbers: **EB Garamond** (shipped) — narration, dialogue *and* message body, unit names, stat values.
- Functional micro-labels only (timers, "TURN", counters): **Exo 2** at small sizes, treated as a deliberate "annotation" voice, not the main voice.
- One modular scale: 14 / 16 / 20 / 28 / 40 / 56. Kill the 13/17 orphans.

**Palette (7 tokens)**
| Token | Hex | Role |
|---|---|---|
| `paper` | `#efe8d8` | all backgrounds, HUD included |
| `paper-card` | `#e0d4b8` | cards/panels — push the delta to ~10% so layers read |
| `ink` | `#3a362f` | all text |
| `ink-dim` | `#6b6457` | secondary text (replace 70%-alpha hacks) |
| `gold` | `#bfa062` | borders, focus, gauge fill, accent |
| `seal-red` | `#9c3b2e` | enemy faction, HP danger, defeat (a Chinese seal-ink red, NOT `#da5247` neon) |
| `jade` | `#5e7a52` | success/heal/cleared (a muted celadon, replacing every cyan/lime) |

**Components:** Panels get a thin gold rule + a soft warm shadow (`ink` at ~12%) for depth — apply to defeat/settings too, for parity. Gauges: gold fill on an ink-15% track. Buttons: keep the existing cream states + pop animation (they already work). **Cards** gain breathing room (taller, fewer rows visible at once).

**Fixes the HUD clash:** the HUD *becomes parchment* — bar = `paper-card` with a `gold` bottom rule instead of navy+cyan. The splice disappears entirely; the game is one surface.

**Fixes icons:** recolor `ui_icons.png` to **single-color `ink`** (they're already monochrome strokes — a tint/modulate pass is trivial). On `paper-card` that's ~9:1 contrast. KO state = `seal-red` tint at 50%, not muddy grey. Clock, squad portraits, and spoils icons all become crisp ink glyphs.

**Fit/risk:** *Best thematic fit by far.* Risk: a bright HUD over a busy battle grid can reduce figure/ground separation — mitigate by giving the grid itself a slightly darker paper tone so the HUD reads as "margin."

---

### Direction B — "Lamplight & Lacquer" (warm dark, atmospheric — the Terra Battle slot)
**Vibe:** an outlaw war-camp at night — dark lacquered wood and bronze, lit by lamplight. Keeps TB's dark drama but **warm**, not navy/cyan.

**Typography**
- Display: **Cinzel Decorative Bold**, in `gold`.
- Body/names/numbers: **EB Garamond** (light cream).
- Micro-labels: **Exo 2** small.
- Same modular scale as A.

**Palette**
| Token | Hex | Role |
|---|---|---|
| `lacquer` | `#231a14` | dark warm-brown base (replaces navy `#101419`) |
| `lacquer-raised` | `#33271d` | cards/HUD-raised |
| `cream` | `#efe6d2` | primary text |
| `cream-dim` | `#b8a98c` | secondary text |
| `bronze` | `#c0a062` | accent, borders, gauge, focus (replaces ALL cyan) |
| `seal-red` | `#b34532` | enemy/danger |
| `jade` | `#7a9a5e` | success/heal/your-turn (replaces cyan `#6beadb`) |

**Components:** Dark warm panels with a thin `bronze` border and a real drop shadow — depth that TB-style UIs do well. Gauges: `bronze` fill on near-black track. Buttons: warm dark fills with bronze hover border (mirror the existing state logic, just recolored from `#212530`→`lacquer-raised`).

**Fixes the HUD clash:** instead of pulling the HUD up to parchment, this pulls the **menus and dialogue down** to warm-dark. The two foreign dark screens (characters/squad) stop being a clash because *everything* is intentionally dark — and the cyan that made them feel sci-fi is gone, replaced by bronze. One dark warm world, top to bottom.

**Fixes icons:** recolor `ui_icons.png` to **`cream`/`bronze`** — bright glyphs on dark warm ground read at ~8:1. KO = desaturated `seal-red`. This keeps the existing dark HUD bar but makes its icons finally legible.

**Fit/risk:** Strong fit — wuxia *can* be nocturnal and brooding. Risk: it walks away from the user's *stated* parchment intent. Best if they decide readability-in-battle + drama matters more than the scroll metaphor. (Could also be shipped as a battle-only "dusk mode" paired with A's parchment menus, but that reintroduces a seam — not recommended.)

---

### Direction C — "Vermilion & Ink" (parchment base, bold seal-red identity)
**Vibe:** Direction A with a louder voice — the brush-and-seal energy of a wanted poster. Parchment world, but red carries real graphic weight.

**Typography:** identical to A (Cinzel / EB Garamond / Exo 2 micro), but titles and key callouts get **`seal-red`** as a co-primary with ink — e.g., chapter titles in red on cream, "DEFEAT" in red, cut-in enemy banners red-on-cream.

**Palette:** A's tokens, but `seal-red` `#a8322a` is promoted from "danger only" to **brand accent** alongside `gold`. Gold = navigation/structure; red = drama/identity/enemy.

**Components:** Cut-in banners flip to **cream pill, seal-red serif text, gold border** — finally on-theme (the audit's #1 complaint about the sans-serif white-on-dark pill). Skill feed recolors to a 4-tone *muted* set drawn from the palette: `ink` (attack), `jade` (heal), `gold` (buff), `seal-red` (debuff) — no neon. Otherwise inherits A's panels/buttons/shadows.

**Fixes the HUD & icons:** same mechanism as A (parchment HUD, ink-tinted icons), plus the live counters and "YOUR TURN" pick up red/gold instead of cyan, giving the HUD a clear color logic (gold = your stuff, red = threat).

**Fit/risk:** *Excellent, most distinctive fit* — red+gold+cream is unmistakably Chinese and high-energy. Risk: red is strong; over-applying it tires the eye or muddies the "danger" signal. Needs discipline (red for identity + threat *only*).

---

### Direction D — "Swiss / International Typographic" (the honest evaluation)
**Vibe:** Helvetica-grid, flat color fields, ruthless alignment, no ornament.

**What it would be:** **Inter** or **Helvetica Now** (new Google-licensed sans), a strict 8px grid, 2-3 flat colors, hairline rules, type doing all the work — no textures, no serifs, no shadows.

**Does it fit a warm wuxia outlaw saga? No — and I'd advise against it.** Swiss style is *anti-ornament, anti-historical, anti-warmth* by design; its entire value proposition is neutral, timeless, corporate-grade clarity. A Water Margin saga wants the opposite: aged paper, brush serifs, seal-stamp reds, ornament-as-character. Adopting Swiss would mean **deleting the very things that make the game feel like its setting** — Cinzel, EB Garamond, parchment, gold. You'd end up with a beautifully organized UI that feels like a banking app cosplaying as a folk epic.

**The one thing worth stealing from it:** its *discipline*. The audits' real failures — 13 ad-hoc font sizes, 45+ untokenized colors, no spacing scale — are exactly what Swiss methodology fixes. So: **adopt the Swiss *process* (modular scale, grid, semantic tokens, alignment rigor) and reject the Swiss *aesthetic*.** That rigor is baked into A/B/C above.

**Fit/risk:** Poor aesthetic fit, high thematic risk. Recommended only as a methodology, not a look.

---

## 3. Recommendation

**Go with Direction A "Illuminated Scroll" — with Direction C "Vermilion & Ink" as the natural next step once A is stable.** A honors the user's stated intent exactly, makes the game *one* surface (eliminating the dark-HUD splice rather than relocating it), and reuses fonts and the genuinely-good button system already shipped. C is the same system turned up — adopt its red-and-gold identity and on-theme cut-in/skill-feed once the foundation is solid. Direction B is the strong fallback only if battle-readability and nocturnal drama end up mattering more than the parchment metaphor; Swiss is a no for the look, a yes only for its tokenization discipline.

**Highest-leverage first fix: reskin the in-battle HUD to parchment.** It's the most-seen screen, the most obviously broken ("amateur copy-paste"), and self-contained. Concretely: swap `HudBar` bg `#101419` → `paper-card` with a `gold` bottom rule; replace the dark button styles with the existing theme.tres cream buttons; recolor the "YOUR TURN"/border cyan to `gold`/`jade`. 

**On the icons:** both fixes work, pick by appetite. *Fast:* the `ui_icons.png` glyphs are already monochrome strokes, so a per-`TextureRect` `modulate` to `ink` (on parchment) instantly lifts the clock/squad/spoils icons from ~5:1 grey-smudge to ~9:1 crisp — zero new assets, do it in the same HUD pass. *Better/longer:* commission a small original Water-Margin icon set (period weapons, seal motifs) to also retire the last Terra Battle sprite artifacts the project memory says you want gone. Start with the recolor to ship the HUD fix today; queue the replacement set as art backlog.

The deeper, parallel win is **tokenizing**: lift the ~45 scattered colors and 13 sizes into named theme.tres tokens (the 7-color palette + the 14/16/20/28/40/56 scale above). That's what converts "visually coherent where applied" into "structurally impossible to drift again."
