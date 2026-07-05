#!/usr/bin/env python3
# Generates 64x64 status-effect glyph icons for the advanced status effects that
# have no match in assets/ui/ui_icons.png (icebind, petrify, blind, weakness).
# Style: soft pastel line art with a subtle dark drop shadow, matching the look
# of the existing status icons. Run:
#   python3 tools/gen_status_icons.py
import os
import math
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "status")
SS = 8            # supersample factor
PX = 64           # final icon size
S = PX * SS


def _new():
	return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def _finish(glyph, name):
	# Soft dark drop shadow, offset down, for the embossed look of the set.
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


def icebind():
	g = _new()
	d = ImageDraw.Draw(g)
	c = (150, 205, 255, 255)
	w = int(SS * 3.2)
	cx = cy = S // 2
	r = int(S * 0.33)
	for k in range(6):
		a = math.radians(60 * k)
		ex, ey = cx + r * math.cos(a), cy + r * math.sin(a)
		d.line([(cx, cy), (ex, ey)], fill=c, width=w)
		for t in (0.5, 0.78):
			bx, by = cx + r * t * math.cos(a), cy + r * t * math.sin(a)
			bl = r * 0.26
			for da in (-42, 42):
				a2 = a + math.radians(da)
				d.line([(bx, by), (bx + bl * math.cos(a2), by + bl * math.sin(a2))], fill=c, width=int(w * 0.8))
	_finish(g, "icebind")


def petrify():
	g = _new()
	d = ImageDraw.Draw(g)
	fill = (176, 176, 186, 255)
	edge = (208, 208, 216, 255)
	crack = (96, 98, 108, 255)
	cx = cy = S // 2
	r = S * 0.34
	# Irregular rounded stone (fixed points, no randomness).
	offs = [1.02, 0.86, 1.05, 0.9, 1.0, 0.84]
	pts = []
	for k in range(6):
		a = math.radians(60 * k - 15)
		rr = r * offs[k]
		pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
	d.polygon(pts, fill=fill, outline=edge, width=int(SS * 1.6))
	# A crack down the middle.
	d.line([(cx - r * 0.18, cy - r * 0.7), (cx + r * 0.05, cy - r * 0.1),
			(cx - r * 0.12, cy + r * 0.25), (cx + r * 0.1, cy + r * 0.7)],
			fill=crack, width=int(SS * 1.8), joint="curve")
	_finish(g, "petrify")


def blind():
	g = _new()
	d = ImageDraw.Draw(g)
	c = (196, 158, 240, 255)
	iris = (150, 110, 210, 255)
	cx = cy = S // 2
	w = int(S * 0.36)
	h = int(S * 0.22)
	# Eye almond.
	d.ellipse([cx - w, cy - h, cx + w, cy + h], outline=c, width=int(SS * 3.0))
	# Iris.
	ir = int(S * 0.12)
	d.ellipse([cx - ir, cy - ir, cx + ir, cy + ir], fill=iris)
	# Slash (blinded).
	d.line([(cx - w * 0.95, cy + h * 1.5), (cx + w * 0.95, cy - h * 1.5)], fill=c, width=int(SS * 3.2))
	_finish(g, "blind")


def weakness():
	g = _new()
	d = ImageDraw.Draw(g)
	c = (230, 140, 140, 255)
	cx = S // 2
	w = int(S * 0.3)
	top = int(S * 0.24)
	mid = int(S * 0.5)
	bot = int(S * 0.72)
	th = int(SS * 4.0)
	# Two stacked downward chevrons.
	d.line([(cx - w, top), (cx, top + w), (cx + w, top)], fill=c, width=th, joint="curve")
	d.line([(cx - w, mid), (cx, mid + w), (cx + w, mid)], fill=c, width=th, joint="curve")
	_ = bot
	_finish(g, "weakness")


icebind()
petrify()
blind()
weakness()
print("status icons -> assets/ui/status/")
