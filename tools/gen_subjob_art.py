#!/usr/bin/env python3
# Generates PLACEHOLDER art for each hero's Job 2 (steel-blue "Vanguard") and
# Job 3 (violet "Adept", synthetic vibe per the wiki) by tinting the base art.
# Writes assets/terra/subjobs/<slug>_job2_full.png (+ token) and _job3_...
# Run after tools/list_heroes.gd (writes /tmp/heroes.json):
#   python3 tools/gen_subjob_art.py
import os
import json
from PIL import Image, ImageFilter, ImageEnhance

ROOT = os.path.join(os.path.dirname(__file__), "..")
HEROES = json.load(open("/tmp/heroes.json"))
OUT = os.path.join(ROOT, "assets", "terra", "subjobs")

JOBS = {
	"job2": {"glow": (120, 175, 235), "wash": (85, 140, 225), "wash_a": 60, "sat": 1.05, "con": 1.05},
	"job3": {"glow": (175, 115, 225), "wash": (140, 80, 215), "wash_a": 66, "sat": 1.15, "con": 1.10},
}


def _res(path):
	return os.path.join(ROOT, path.replace("res://", ""))


def _tint(img, cfg):
	img = img.convert("RGBA")
	w, h = img.size
	alpha = img.split()[3]

	radius = max(3, int(min(w, h) * 0.05))
	glow = Image.new("RGBA", (w, h), cfg["glow"] + (255,))
	glow.putalpha(alpha.filter(ImageFilter.GaussianBlur(radius)))

	wash = Image.new("RGBA", (w, h), cfg["wash"] + (cfg["wash_a"],))
	wash.putalpha(Image.composite(Image.new("L", (w, h), cfg["wash_a"]), Image.new("L", (w, h), 0), alpha))
	toned = Image.alpha_composite(img, wash)
	toned = ImageEnhance.Color(toned).enhance(cfg["sat"])
	toned = ImageEnhance.Contrast(toned).enhance(cfg["con"])

	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	out = Image.alpha_composite(out, glow)
	out = Image.alpha_composite(out, toned)
	return out


def _slug(base_path, suffix):
	# assets/terra/full/bahl_full.png + "_full" -> "bahl"
	return os.path.basename(base_path).replace(suffix + ".png", "")


made = 0
os.makedirs(OUT, exist_ok=True)
for h in HEROES:
	for base, suffix, kind in ((h["full"], "_full", "full"), (h["token"], "_token", "token")):
		if base == "" or not os.path.exists(_res(base)):
			continue
		slug = _slug(base, suffix)
		src_img = Image.open(_res(base))
		for job_key, cfg in JOBS.items():
			dst = os.path.join(OUT, "%s_%s_%s.png" % (slug, job_key, kind))
			_tint(src_img, cfg).save(dst)
			made += 1

print("generated %d subjob art files -> assets/terra/subjobs/" % made)
