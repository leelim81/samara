#!/usr/bin/env python3
# Generates PLACEHOLDER awakened-form portraits for every hero by tinting the
# base art with a gold aura, and writes docs/placeholder_art.md so an artist or
# AI can generate real awakened art and drop it in at the same paths. Run after
# tools/list_heroes.gd (which writes /tmp/heroes.json):
#   python3 tools/gen_awakened_placeholders.py
import os
import json
from PIL import Image, ImageFilter, ImageEnhance

ROOT = os.path.join(os.path.dirname(__file__), "..")
HEROES = json.load(open("/tmp/heroes.json"))


def _res(path):
	# res://assets/... -> absolute path
	return os.path.join(ROOT, path.replace("res://", ""))


def _awaken(img):
	img = img.convert("RGBA")
	w, h = img.size
	alpha = img.split()[3]

	# Soft gold rim glow from the silhouette.
	radius = max(3, int(min(w, h) * 0.05))
	glow_alpha = alpha.filter(ImageFilter.GaussianBlur(radius))
	glow = Image.new("RGBA", (w, h), (255, 205, 95, 255))
	glow.putalpha(glow_alpha)

	# Warm gold wash over the character only.
	wash = Image.new("RGBA", (w, h), (255, 190, 70, 70))
	wash.putalpha(Image.composite(Image.new("L", (w, h), 70), Image.new("L", (w, h), 0), alpha))
	warmed = Image.alpha_composite(img, wash)
	warmed = ImageEnhance.Color(warmed).enhance(1.15)
	warmed = ImageEnhance.Contrast(warmed).enhance(1.08)

	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	out = Image.alpha_composite(out, glow)
	out = Image.alpha_composite(out, warmed)
	return out


def _variant_path(src):
	# res://assets/terra/full/x.png -> res://assets/terra/awakened/full/x.png
	return src.replace("res://assets/terra/", "res://assets/terra/awakened/")


def _generate(src):
	if src == "":
		return None
	src_abs = _res(src)
	if not os.path.exists(src_abs):
		return None
	dst = _variant_path(src)
	dst_abs = _res(dst)
	os.makedirs(os.path.dirname(dst_abs), exist_ok=True)
	_awaken(Image.open(src_abs)).save(dst_abs)
	return dst


rows = []
made = 0
for h in HEROES:
	full_dst = _generate(h["full"])
	token_dst = _generate(h["token"])
	if full_dst:
		made += 1
	rows.append((h, full_dst or "", token_dst or ""))

print("generated awakened placeholders for %d heroes" % made)

# ---- Manifest ----
lines = []
lines.append("# Placeholder art manifest\n")
lines.append("This lists every **placeholder** image the game ships so an artist or an AI ")
lines.append("image generator can produce real art and replace the file **at the same path** ")
lines.append("(no code changes needed). Keep the same dimensions and a transparent background.\n")
lines.append("\n## How to replace\n")
lines.append("For each entry, generate an image matching the description, then overwrite the ")
lines.append("file at *Path*. Re-run `godot --headless --import` so Godot re-imports it.\n")

lines.append("\n## Awakened hero portraits (Metamorphosis / Awaken)\n")
lines.append("When a hero is Awakened, the game swaps to these portraits. The placeholders are ")
lines.append("the base art with a gold aura. Real art should show the **same character and outfit, ")
lines.append("evolved**: radiant, empowered, a golden aura, a more heroic pose. Match the game's ")
lines.append("painterly full-body character-art style. Full portraits are ~212x212; tokens are the ")
lines.append("smaller square thumbnail.\n")
lines.append("\n| Hero | Kind | Path | Description |\n")
lines.append("| --- | --- | --- | --- |\n")
for h, full_dst, token_dst in rows:
	bio = (h.get("description") or "").replace("\n", " ").replace("|", "/").strip()
	desc = "Awakened form of %s. %s" % (h["name"].replace("|", "/"), bio)
	if full_dst:
		lines.append("| %s | full | `%s` | %s |\n" % (h["name"].replace("|", "/"), full_dst.replace("res://", ""), desc))
	if token_dst:
		lines.append("| %s | token | `%s` | Thumbnail of the above. |\n" % (h["name"].replace("|", "/"), token_dst.replace("res://", "")))

lines.append("\n## Procedurally-generated icons (optional upgrades)\n")
lines.append("These already ship as clean generated glyphs and are fully functional, but an ")
lines.append("artist may want to replace them with hand-drawn versions matching `assets/ui/ui_icons.png`.\n")
lines.append("\n| Icon | Path | Description |\n")
lines.append("| --- | --- | --- |\n")
icons = [
	("Icebind status", "assets/ui/status/icebind.png", "A pale-blue snowflake / freeze glyph, 64x64, soft emboss shadow."),
	("Petrify status", "assets/ui/status/petrify.png", "A grey cracked-stone glyph, 64x64."),
	("Blind status", "assets/ui/status/blind.png", "A violet eye with a slash through it, 64x64."),
	("Weakness status", "assets/ui/status/weakness.png", "A red downward double-chevron (stat down), 64x64."),
	("Scrap Iron material", "assets/ui/items/scrap.png", "A grey faceted gem/ore, 64x64. Common tier."),
	("Refined Alloy material", "assets/ui/items/alloy.png", "A bronze faceted gem, 64x64. Uncommon tier."),
	("Power Cell material", "assets/ui/items/cell.png", "A blue faceted gem/cell, 64x64. Rare tier."),
	("Neural Core material", "assets/ui/items/core.png", "A violet faceted gem/core, 64x64. Epic tier."),
	("Sigil Shard material", "assets/ui/items/sigil.png", "A gold faceted gem/shard, 64x64. Legendary tier."),
]
for name, path, desc in icons:
	lines.append("| %s | `%s` | %s |\n" % (name, path, desc))

manifest_path = os.path.join(ROOT, "docs", "placeholder_art.md")
os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
open(manifest_path, "w").write("".join(lines))
print("wrote docs/placeholder_art.md (%d rows)" % len(rows))
