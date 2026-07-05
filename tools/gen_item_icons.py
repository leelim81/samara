#!/usr/bin/env python3
# Generates 64x64 faceted-gem material icons in five rarity tints, matching the
# soft pastel look of the status icons. Run:
#   python3 tools/gen_item_icons.py
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "items")
SS = 8
PX = 64
S = PX * SS

# id -> (base color, light edge color)
GEMS = {
	"scrap": ((150, 158, 168), (196, 202, 210)),
	"alloy": ((200, 160, 106), (232, 200, 150)),
	"cell": ((110, 184, 216), (168, 220, 244)),
	"core": ((176, 138, 224), (214, 188, 246)),
	"sigil": ((232, 196, 106), (250, 228, 160)),
}


def _finish(glyph, name):
	sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	sh.putalpha(glyph.split()[3])
	tint = Image.new("RGBA", (S, S), (8, 10, 16, 255))
	tint.putalpha(sh.filter(ImageFilter.GaussianBlur(SS * 1.7)).split()[3])
	base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	base.paste(tint, (0, int(SS * 2.6)), tint)
	img = Image.alpha_composite(base, glyph)
	img = img.resize((PX, PX), Image.LANCZOS)
	os.makedirs(OUT, exist_ok=True)
	img.save(os.path.join(OUT, name + ".png"))
	print("wrote", name)


def gem(name, base_color, edge_color):
	g = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	d = ImageDraw.Draw(g)
	cx = S // 2
	w = S * 0.30
	top = S * 0.30
	mid = S * 0.45
	bot = S * 0.76
	fill = base_color + (255,)
	edge = edge_color + (255,)
	facet = tuple(int(c * 0.72) for c in base_color) + (255,)

	tl = (cx - w * 0.62, top)
	tr = (cx + w * 0.62, top)
	mr = (cx + w, mid)
	ml = (cx - w, mid)
	bp = (cx, bot)
	body = [tl, tr, mr, bp, ml]
	d.polygon(body, fill=fill, outline=edge, width=int(SS * 1.6))

	# Facet lines from the table corners and mid points down to the point.
	for p in (tl, tr, ml, mr):
		d.line([p, bp], fill=facet, width=int(SS * 1.1))
	d.line([tl, tr], fill=edge, width=int(SS * 1.1))

	# Bright table highlight.
	tw = w * 0.38
	d.polygon([(cx - tw, top + S * 0.02), (cx + tw, top + S * 0.02),
			(cx + tw * 0.7, mid * 0.9), (cx - tw * 0.7, mid * 0.9)],
			fill=edge_color + (150,))

	_finish(g, name)


for gem_id, (base_c, edge_c) in GEMS.items():
	gem(gem_id, base_c, edge_c)
print("item icons -> assets/ui/items/")
