#!/usr/bin/env python3
"""TWEWY-style character art regeneration pipeline (Nano Banana / Gemini image models).

Per character: stitch the 3 original forms (base/job2/job3) into one labeled 3-panel
reference sheet -> send to a Gemini image model with a style prompt -> split the
returned sheet at fixed panel boundaries -> flood-fill the white background to alpha
-> resize to each original file's exact dimensions -> derive board tokens.
Every prompt and run's metadata is saved under out/<slug>/ for review.

Usage (from tools/twewy_restyle/, using .venv/bin/python):
  restyle.py stitch bahl                   # build labeled reference sheet (no API)
  restyle.py prompt bahl                   # build + save the exact prompt (no API)
  restyle.py gen bahl [--model M] [--resolution 2K]
  restyle.py split bahl [--raw PATH]       # split newest raw_*.png unless --raw
  restyle.py compare bahl                  # originals-vs-generated review sheet
  restyle.py run bahl                      # stitch + gen + split + compare
  restyle.py install bahl                  # backup originals, then overwrite assets
  restyle.py batch [slugs...]              # run for every slug in art_direction.json

The API key is read from GEMINI_API_KEY (environment or .env next to this file).
"""

import argparse
import io
import json
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parent
GAME = ROOT.parent.parent
ASSETS = GAME / "assets" / "terra"
MANIFEST = ASSETS / "characters" / "manifest.json"
ART_DIRECTION = ROOT / "art_direction.json"
TEMPLATE = ROOT / "PROMPT_TEMPLATE.md"
OUT = ROOT / "out"
BACKUP = ROOT / "backup"
STYLE_REFS = ROOT / "style_refs"

DEFAULT_MODEL = "gemini-3-pro-image"        # Nano Banana Pro (best quality)
AB_MODEL = "gemini-3.1-flash-image"         # Nano Banana 2 (fast/cheap A/B)
DEFAULT_RESOLUTION = "2K"
MAX_STYLE_REFS = 5

# Stitched-sheet geometry (see plan): 16:9 canvas, three cells, labels OUTSIDE the
# panel border so leaked text can never overlap art; 20px white corridor at each cut.
CANVAS_W, CANVAS_H = 1536, 864
CELL_W = CANVAS_W // 3
LABEL_STRIP_H = 70
BORDER_INSET_X = 10
BORDER_TOP = 78
BORDER_BOTTOM = CANVAS_H - 10
BORDER_PX = 3
BORDER_COLOR = (136, 136, 136)  # gray, not black, so it doesn't read as ink linework
LABELS = ["BASE", "POWER 1", "POWER 2"]
FORMS = ["base", "job2", "job3"]

WHITE_THRESHOLD = 240   # min channel value for a pixel to count as background-white
ALPHA_CONTENT = 10      # alpha above this counts as content for bbox purposes


def source_paths(slug):
    """Original asset paths for a slug's three forms (fulls + tokens)."""
    return {
        "base": {
            "full": ASSETS / "full" / f"{slug}_full.png",
            "token": ASSETS / "tokens" / f"{slug}_token.png",
        },
        "job2": {
            "full": ASSETS / "subjobs" / f"{slug}_job2_full.png",
            "token": ASSETS / "subjobs" / f"{slug}_job2_token.png",
        },
        "job3": {
            "full": ASSETS / "subjobs" / f"{slug}_job3_full.png",
            "token": ASSETS / "subjobs" / f"{slug}_job3_token.png",
        },
    }


def out_dir(slug):
    d = OUT / slug
    (d / "final").mkdir(parents=True, exist_ok=True)
    return d


def flatten_white(img):
    """RGBA -> RGB over solid white."""
    img = img.convert("RGBA")
    bg = Image.new("RGB", img.size, (255, 255, 255))
    bg.paste(img, mask=img.split()[-1])
    return bg


def load_font(size):
    for candidate in ("/System/Library/Fonts/Helvetica.ttc",
                      "/System/Library/Fonts/HelveticaNeue.ttc",
                      "/Library/Fonts/Arial.ttf"):
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default(size=size)


# ---------------------------------------------------------------- stitch

def stitch(slug):
    paths = source_paths(slug)
    sheet = Image.new("RGB", (CANVAS_W, CANVAS_H), (255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    font = load_font(40)

    for i, form in enumerate(FORMS):
        src = paths[form]["full"]
        if not src.exists():
            sys.exit(f"missing source image: {src}")
        art = flatten_white(Image.open(src))

        cell_x = i * CELL_W
        # label centered in the strip above the panel area. NO border boxes:
        # the model mirrors any frames it sees into the output (sketchy frames
        # that survive line-removal), and figure segmentation doesn't need them.
        label = LABELS[i]
        tw = draw.textlength(label, font=font)
        draw.text((cell_x + (CELL_W - tw) / 2, 14), label, fill=(0, 0, 0), font=font)
        # art centered in the cell below the label strip, downscaled only to fit
        bx0, by0 = cell_x + BORDER_INSET_X, BORDER_TOP
        bx1, by1 = cell_x + CELL_W - BORDER_INSET_X, BORDER_BOTTOM
        iw, ih = bx1 - bx0 - 2 * BORDER_PX, by1 - by0 - 2 * BORDER_PX
        scale = min(1.0, iw / art.width, ih / art.height)
        if scale < 1.0:
            art = art.resize((round(art.width * scale), round(art.height * scale)),
                             Image.LANCZOS)
        ax = bx0 + BORDER_PX + (iw - art.width) // 2
        ay = by0 + BORDER_PX + (ih - art.height) // 2
        sheet.paste(art, (ax, ay))

    dest = out_dir(slug) / "stitched_input.png"
    sheet.save(dest)
    print(f"stitched -> {dest}")
    return dest


# ---------------------------------------------------------------- prompt

def load_json(path):
    with open(path) as f:
        return json.load(f)


def build_prompt(slug):
    manifest = load_json(MANIFEST)
    entry = next((c for c in manifest["characters"] if c.get("slug") == slug), {})
    ad = load_json(ART_DIRECTION).get(slug, {})

    weapon = entry.get("weapon", "weapon")
    jobs = ad.get("jobs") or entry.get("jobs") or ["base form", "powered form", "final form"]
    fields = {
        "NAME": ad.get("name") or entry.get("name") or slug,
        "EPITHET": ad.get("epithet", ""),
        "IDENTITY_LINE": ad.get("identity_line")
            or f"a {entry.get('species', 'human').lower()} {entry.get('type', 'adventurer').lower()} who fights with a {weapon.lower()}",
        "APPEARANCE_LINE": ad.get("appearance_line")
            or "exactly the face, hair color and style, eye color, and build shown in the reference panels",
        "JOB1": jobs[0], "JOB2": jobs[1], "JOB3": jobs[2],
        "BASE_DESC": ad.get("base_desc")
            or "the simplest outfit, weapon, and pose, exactly as drawn in the BASE reference panel",
        "POWER1_DESC": ad.get("power1_desc")
            or "the upgraded outfit and larger, more ornate weapon exactly as drawn in the "
               "POWER 1 reference panel — clearly stronger-looking than BASE",
        "POWER2_DESC": ad.get("power2_desc")
            or "the most elaborate outfit and the grandest weapon exactly as drawn in the "
               "POWER 2 reference panel — clearly stronger-looking than POWER 1, with the "
               "strongest energy effects",
        "PERSONALITY_LINE": ad.get("personality_line", "confident and battle-ready"),
        "SIGNATURE_TRAITS_LINE": ad.get("traits_line")
            or f"their signature {weapon.lower()}, unmistakably the same weapon in all three panels",
    }
    prompt = TEMPLATE.read_text().format(**fields)

    refs = style_ref_files()
    if refs:
        prompt += (
            "\nThe additional attached images (after the reference sheet) are pure STYLE "
            "references from the target art style: copy their line quality, shading and "
            "finish only — never their characters, faces, poses, or outfits.\n"
        )
    return prompt


def style_ref_files():
    if not STYLE_REFS.exists():
        return []
    files = sorted(p for p in STYLE_REFS.iterdir()
                   if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"))
    return files[:MAX_STYLE_REFS]


def save_prompt(slug):
    prompt = build_prompt(slug)
    dest = out_dir(slug) / "prompt.txt"
    dest.write_text(prompt)
    print(f"prompt -> {dest}")
    return prompt


# ---------------------------------------------------------------- gen

def load_env_key():
    import os
    env_file = ROOT / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
    return os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")


def gen(slug, model=DEFAULT_MODEL, resolution=DEFAULT_RESOLUTION):
    from google import genai
    from google.genai import types

    key = load_env_key()
    if not key:
        sys.exit("No GEMINI_API_KEY found (env or tools/twewy_restyle/.env). "
                 "Create one at aistudio.google.com and add it to .env first.")

    stitched = out_dir(slug) / "stitched_input.png"
    if not stitched.exists():
        stitch(slug)
    prompt = save_prompt(slug)

    parts = [types.Part.from_bytes(data=stitched.read_bytes(), mime_type="image/png")]
    refs = style_ref_files()
    for ref in refs:
        mime = "image/jpeg" if ref.suffix.lower() in (".jpg", ".jpeg") else f"image/{ref.suffix.lower().lstrip('.')}"
        parts.append(types.Part.from_bytes(data=ref.read_bytes(), mime_type=mime))
    parts.append(prompt)

    client = genai.Client(api_key=key,
                          http_options=types.HttpOptions(timeout=240_000))

    configs = [
        ("full", types.GenerateContentConfig(
            response_modalities=["TEXT", "IMAGE"],
            image_config=types.ImageConfig(aspect_ratio="16:9", image_size=resolution))),
        ("no_image_config", types.GenerateContentConfig(
            response_modalities=["TEXT", "IMAGE"])),
        ("bare", None),
    ]

    started = time.time()
    resp, config_used, last_err = None, None, None
    for attempt in range(1, 5):
        for cfg_name, cfg in configs:
            try:
                resp = client.models.generate_content(
                    model=model, contents=parts, config=cfg)
                config_used = cfg_name
                break
            except Exception as e:  # noqa: BLE001 — classify by message below
                msg = str(e)
                last_err = e
                if any(t in msg for t in ("INVALID_ARGUMENT", "image_config",
                                          "image_size", "response_modalities",
                                          "aspect_ratio", "not supported")):
                    print(f"  config '{cfg_name}' rejected, trying next: {msg[:160]}")
                    continue
                if "NOT_FOUND" in msg or "404" in msg:
                    sys.exit(f"Model '{model}' not found for this key: {msg[:300]}\n"
                             f"Try --model {AB_MODEL} or list models in AI Studio.")
                raise
        if resp is not None:
            break
        if any(t in str(last_err) for t in ("429", "RESOURCE_EXHAUSTED", "500",
                                            "503", "UNAVAILABLE", "DEADLINE")):
            wait = 12 * attempt
            print(f"  transient error, retrying in {wait}s: {str(last_err)[:160]}")
            time.sleep(wait)
        else:
            raise last_err
    if resp is None:
        raise last_err

    image_bytes, texts = None, []
    for part in resp.candidates[0].content.parts:
        inline = getattr(part, "inline_data", None)
        if inline is not None and getattr(inline, "mime_type", "").startswith("image/"):
            if image_bytes is None:
                image_bytes = inline.data
        elif getattr(part, "text", None):
            texts.append(part.text)
    if image_bytes is None:
        sys.exit(f"No image in response. Text: {' '.join(texts)[:500]}")

    raw = out_dir(slug) / f"raw_{model}.png"
    raw.write_bytes(image_bytes)
    with Image.open(raw) as check:  # normalize to real PNG if another format came back
        if (check.format or "PNG") != "PNG":
            check.convert("RGB").save(raw, "PNG")
        size = check.size

    run_meta = {
        "slug": slug, "model": model, "resolution": resolution,
        "config_used": config_used,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "duration_s": round(time.time() - started, 1),
        "stitched_input": str(stitched),
        "style_refs": [str(r) for r in refs],
        "output": str(raw), "output_size": size,
        "model_text": " ".join(texts)[:2000],
        "prompt": prompt,
    }
    meta_path = out_dir(slug) / f"run_{model}.json"
    meta_path.write_text(json.dumps(run_meta, indent=2))
    print(f"generated -> {raw} {size} in {run_meta['duration_s']}s (config={config_used})")
    return raw


# ---------------------------------------------------------------- split

def detect_anime_face(content_img):
    """Anime-face detection via lbpcascade_animeface (OpenCV). Returns
    (cx, cy, face_w) in content_img coordinates, or None."""
    xml = ROOT / "lbpcascade_animeface.xml"
    if not xml.exists():
        return None
    try:
        import cv2
    except ImportError:
        return None
    flat = flatten_white(content_img)
    scale = min(1.0, 900 / flat.height)
    small = flat.resize((max(1, round(flat.width * scale)),
                         max(1, round(flat.height * scale))), Image.LANCZOS)
    gray = cv2.equalizeHist(cv2.cvtColor(np.asarray(small), cv2.COLOR_RGB2GRAY))
    cascade = cv2.CascadeClassifier(str(xml))
    faces = cascade.detectMultiScale(gray, scaleFactor=1.06, minNeighbors=4,
                                     minSize=(24, 24))
    if len(faces) == 0:
        faces = cascade.detectMultiScale(gray, scaleFactor=1.04, minNeighbors=3,
                                         minSize=(20, 20))
    if len(faces) == 0:
        return []
    upper = [f for f in faces if (f[1] + f[3] / 2) < 0.7 * small.height]
    # prefer top-central: companions (hawks, gnomes) perch at the edges and
    # decorative faces (sword engravings) sit low — the hero's face is high
    # and near the figure's center line
    sw = small.width

    def score(f):
        return (f[1] + f[3] / 2) / small.height \
            + 0.7 * abs((f[0] + f[2] / 2) - sw / 2) / sw
    ranked = sorted(upper or list(faces), key=score)
    return [((x + fw / 2) / scale, (y + fh / 2) / scale, fw / scale)
            for x, y, fw, fh in ranked]


def crop_contains_face(crop_img):
    """Cheap validation that a candidate token crop actually shows a face."""
    xml = ROOT / "lbpcascade_animeface.xml"
    try:
        import cv2
    except ImportError:
        return True  # can't verify — accept
    if not xml.exists():
        return True
    gray = cv2.equalizeHist(cv2.cvtColor(
        np.asarray(flatten_white(crop_img)), cv2.COLOR_RGB2GRAY))
    cascade = cv2.CascadeClassifier(str(xml))
    faces = cascade.detectMultiScale(gray, scaleFactor=1.05, minNeighbors=3,
                                     minSize=(max(16, crop_img.width // 5),) * 2)
    return len(faces) > 0


def derive_token(content_img, token_src, dest):
    """Face-centered square crop CUT from the actual art, tightly zoomed.

    Builds a ranked list of face-center candidates — anime-face cascade hits
    (top-central first), then warm top-central distance-transform peaks, then
    a row-mass body-top guess — and takes the FIRST candidate whose crop
    verifiably contains a face (re-checked with the cascade on the crop)."""
    w, h = content_img.width, content_img.height
    candidates = []  # (cx, cy, side)
    for cx, cy, fw in detect_anime_face(content_img)[:4]:
        side = round(min(min(w, h), max(0.13 * h, min(0.24 * h, 2.0 * fw))))
        candidates.append((cx, cy, side))

    a = np.asarray(content_img.split()[-1]) > ALPHA_CONTENT
    rgb = np.asarray(content_img.convert("RGB")).astype(int)
    dist = ndimage.distance_transform_edt(a)
    thr = max(6.0, 0.03 * h)
    k = max(9, int(0.03 * h) | 1)
    peaks = (ndimage.maximum_filter(dist, size=k) == dist) & (dist >= thr)
    cand = [(y / h + 0.7 * abs(x - w / 2) / w, int(y), int(x))
            for y, x in zip(*np.nonzero(peaks)) if y < 0.6 * h]
    cand.sort()  # top-central first
    edt_side = min(min(w, h), max(16, round(0.19 * h)))
    accepted, held_back = [], []
    for _, y, x in cand:
        # the head reads as warm skin/mid tones; blade spines are near-black,
        # blade edges near-white, cold steel blue-grey, gold/flames vivid
        r = max(3, int(dist[y, x] * 0.5))
        patch = rgb[max(0, y - r):y + r + 1, max(0, x - r):x + r + 1]
        mask = a[max(0, y - r):y + r + 1, max(0, x - r):x + r + 1]
        if not mask.any():
            continue
        med = np.median(patch[mask], axis=0)
        v = med.max() / 255.0
        s = (med.max() - med.min()) / max(1, med.max())
        warm = med[0] >= med[2] + 8
        if v < 0.25 or (v > 0.97 and s < 0.05) or s > 0.6 or not warm:
            held_back.append((x, y, edt_side))
        else:
            accepted.append((x, y, edt_side))
    candidates += accepted[:4] + held_back[:2]

    row_mass = a.sum(axis=1)
    strong = np.flatnonzero(row_mass > 0.25 * np.percentile(row_mass, 95))
    body_top = int(strong[0]) if strong.size else 0
    candidates.append((w / 2, body_top + 0.12 * (h - body_top), edt_side))

    chosen = None
    for cx, cy, side in candidates:
        side = int(min(side, w, h))
        x0 = int(max(0, min(w - side, round(cx) - side // 2)))
        y0 = int(max(0, min(h - side, round(cy) - side // 2)))
        crop = content_img.crop((x0, y0, x0 + side, y0 + side))
        if chosen is None:
            chosen = crop
        if crop_contains_face(crop):
            chosen = crop
            break
    if chosen is None:
        chosen = content_img
    with Image.open(token_src) as orig_token:
        chosen = chosen.resize(orig_token.size, Image.LANCZOS)
    chosen.save(dest)


def newest_raw(slug):
    raws = sorted((OUT / slug).glob("raw_*.png"), key=lambda p: p.stat().st_mtime)
    if not raws:
        sys.exit(f"no raw_*.png in {OUT / slug}; run gen first")
    return raws[-1]


def strip_dark_bars(img):
    """Crop away solid dark header/footer bars and edge divider lines that the
    model sometimes adds (label bars, panel frames) despite the no-text rule."""
    arr = np.asarray(img.convert("RGB"))
    h, w = arr.shape[:2]
    dark = (arr < 100).all(axis=2)
    top = 0
    while top < h * 0.15 and dark[top].mean() > 0.4:
        top += 1
    bot = h
    while bot > h * 0.85 and dark[bot - 1].mean() > 0.4:
        bot -= 1
    left = 0
    while left < w * 0.05 and dark[:, left].mean() > 0.4:
        left += 1
    right = w
    while right > w * 0.95 and dark[:, right - 1].mean() > 0.4:
        right -= 1
    if (top, bot, left, right) != (0, h, 0, w):
        img = img.crop((left, top, right, bot))
    return img


def background_mask(rgb_array):
    """Boolean mask of border-connected near-white background."""
    near_white = (rgb_array >= WHITE_THRESHOLD).all(axis=2)
    labels, _ = ndimage.label(near_white)
    border_labels = np.unique(np.concatenate([
        labels[0, :], labels[-1, :], labels[:, 0], labels[:, -1]]))
    border_labels = border_labels[border_labels != 0]
    return np.isin(labels, border_labels)


def remove_line_components(content):
    """Delete decorations the model sometimes draws around panels: full-length
    divider lines (thin, near-full-height/width) and hollow frame rectangles
    (huge bbox, tall, but almost no filled pixels)."""
    h, w = content.shape
    labels, n = ndimage.label(content)
    if n:
        areas = ndimage.sum(content, labels, index=range(1, n + 1))
        thin_v = max(8, round(0.005 * w))
        thin_h = max(8, round(0.005 * h))
        for cid, slc in enumerate(ndimage.find_objects(labels), start=1):
            if slc is None:
                continue
            hh, ww = slc[0].stop - slc[0].start, slc[1].stop - slc[1].start
            cx = (slc[1].start + slc[1].stop) / 2
            is_line = (ww <= thin_v and hh >= 0.5 * h) or \
                      (hh <= thin_h and ww >= 0.5 * w)
            # divider fragments live at the 1/3 and 2/3 cut lines; anti-aliasing
            # can shatter a divider into short pieces, and the model sometimes
            # draws THICK bars — so at the cut positions allow much wider runs
            at_cut = min(abs(cx - w / 3), abs(cx - 2 * w / 3)) < 0.035 * w
            is_divider_frag = (at_cut and hh >= 0.12 * h and
                               ww <= max(12, round(0.015 * w)))
            fill = areas[cid - 1] / max(1, hh * ww)
            is_frame = fill < 0.05 and hh >= 0.8 * h and ww >= 0.2 * w
            if is_line or is_divider_frag or is_frame:
                content[slc][labels[slc] == cid] = False
    return content


def unseal_panels(arr, content):
    """Panels drawn as CLOSED frames around a near-white fill come out of the
    border flood-fill as giant solid rectangles (the frame seals the interior).
    For any such component: estimate the fill color just inside the frame,
    flood the fill out from that ring (so enclosed light pixels ON the figure
    survive), and drop the frame band itself."""
    labels, n = ndimage.label(content)
    H, W = content.shape
    for cid, slc in enumerate(ndimage.find_objects(labels), start=1):
        if slc is None:
            continue
        comp = labels[slc] == cid
        bh, bw = comp.shape
        if comp.sum() < 0.08 * H * W or comp.sum() / (bh * bw) < 0.85:
            continue  # not a sealed panel — a normal figure
        sub = arr[slc]
        t = max(4, round(0.01 * min(bh, bw)))
        ring = np.zeros(comp.shape, bool)
        ring[t:3 * t, t:-t] = True
        ring[-3 * t:-t, t:-t] = True
        ring[t:-t, t:3 * t] = True
        ring[t:-t, -3 * t:-t] = True
        ring &= comp
        if not ring.any():
            continue
        fill = np.median(sub[ring].reshape(-1, 3), axis=0)
        if fill.min() < 200:
            continue  # interior isn't a light fill — leave it alone
        near_fill = (np.abs(sub.astype(int) - fill.astype(int)).max(axis=2) <= 14) & comp
        lab2, _ = ndimage.label(near_fill)
        seeds = np.unique(lab2[ring & near_fill])
        seeds = seeds[seeds != 0]
        bg2 = np.isin(lab2, seeds)
        frame_band = np.ones(comp.shape, bool)
        inner = round(t * 1.5)
        frame_band[inner:-inner, inner:-inner] = False
        content[slc] &= ~((bg2 | frame_band) & comp)
    return content


def strip_frame_lines(m):
    """Remove panel-frame lines from a figure mask even when the frame touches
    the figure: thin (<=10px) rows/columns with near-full coverage sitting at
    the mask's bbox edges are frame lines, never body parts. Requires at least
    two such edge-runs so a lone vertical staff is never mistaken for a frame."""
    ys, xs = np.nonzero(m)
    if ys.size == 0:
        return m
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    sub = m[y0:y1, x0:x1]
    bh, bw = sub.shape
    max_line_px = max(12, round(0.02 * max(bh, bw)))
    runs = []  # (is_col, run_indices)
    for cov, size, is_col in ((sub.mean(axis=0), bw, True),
                              (sub.mean(axis=1), bh, False)):
        idx = np.flatnonzero(cov > 0.85)
        if idx.size:
            for run in np.split(idx, np.flatnonzero(np.diff(idx) > 1) + 1):
                near_edge = run[0] < 0.12 * size or run[-1] > 0.88 * size
                if run.size <= max_line_px and near_edge:
                    runs.append((is_col, run))
    if len(runs) >= 2:
        for is_col, run in runs:
            if is_col:
                sub[:, run] = False
            else:
                sub[run, :] = False
        m[y0:y1, x0:x1] = sub
    return m


def erase_cut_zone_bars(content):
    """Erase divider bars even when they touch the figures: within the 1/3 and
    2/3 cut zones, drop content pixels belonging to columns that are mostly
    filled AND whose horizontal run is bar-thin. Art crossing the zone (spears,
    halos held sideways) has long horizontal runs and survives."""
    h, w = content.shape
    max_run = max(14, round(0.02 * w))
    # per-pixel horizontal run length of contiguous content
    runlen = np.zeros((h, w), dtype=np.int32)
    mask8 = content.astype(np.int8)
    for y in range(h):
        row = mask8[y]
        if not row.any():
            continue
        changes = np.flatnonzero(np.diff(row, prepend=0, append=0))
        for s, e in zip(changes[::2], changes[1::2]):
            runlen[y, s:e] = e - s
    for cut in (w // 3, 2 * w // 3):
        z0, z1 = max(0, round(cut - 0.035 * w)), min(w, round(cut + 0.035 * w))
        zone = content[:, z0:z1]
        col_frac = zone.mean(axis=0)
        strong = np.zeros(w, dtype=bool)
        strong[z0:z1] = col_frac > 0.4
        kill = content & strong[None, :] & (runlen <= max_run)
        content &= ~kill
    return content


def remove_top_label_text(content):
    """Drop leaked label text: the stitched input carries BASE/POWER labels in
    the top strip, and the model sometimes mirrors them there. Any small
    component living entirely in the top 8% of the canvas is label text, never
    figure art (heads start well below)."""
    h, w = content.shape
    labels, n = ndimage.label(content)
    if n:
        for cid, slc in enumerate(ndimage.find_objects(labels), start=1):
            if slc is None:
                continue
            hh, ww = slc[0].stop - slc[0].start, slc[1].stop - slc[1].start
            if slc[0].stop <= 0.08 * h and hh <= 0.05 * h and ww <= 0.25 * w:
                content[slc][labels[slc] == cid] = False
    return content


def trim_isolated_edge_lines(m):
    """Drop thin isolated bands at a figure mask's left/right extremes — leftover
    divider lines that got attached to the group. A band only dies if a wide
    empty gap separates it from the rest, so a held staff (connected via the
    hand, no gap) is never touched."""
    h, w = m.shape
    thin = max(8, round(0.006 * w))
    for _ in range(2):
        cols = np.flatnonzero(m.any(axis=0))
        if cols.size == 0:
            return m
        runs = np.split(cols, np.flatnonzero(np.diff(cols) > 1) + 1)
        changed = False
        if len(runs) >= 2:
            first, second = runs[0], runs[1]
            if first.size <= thin and second[0] - first[-1] >= 3 * thin:
                m[:, first] = False
                changed = True
            last, prev = runs[-1], runs[-2]
            if last.size <= thin and last[0] - prev[-1] >= 3 * thin:
                m[:, last] = False
                changed = True
        if not changed:
            return m
    return m


def split(slug, raw_path=None):
    """Extract the three figures from the generated sheet.

    The model doesn't reliably confine each figure to its exact third (weapons
    and effects sprawl across panel boundaries), so instead of cutting at fixed
    thirds we segment the white background, take the three largest connected
    components as the figures (left to right), and attach every minor component
    (petals, flame wisps) to its nearest figure. Falls back to a fixed-thirds
    cut if segmentation doesn't find three plausible figures.
    """
    paths = source_paths(slug)
    raw = Path(raw_path) if raw_path else newest_raw(slug)
    raw_img = Image.open(raw).convert("RGB")
    warnings = []

    img = strip_dark_bars(raw_img)
    w, h = img.size
    arr = np.asarray(img)
    content = erase_cut_zone_bars(~background_mask(arr))
    content = remove_line_components(content)
    content = unseal_panels(arr, content)
    content = remove_top_label_text(content)
    labels, n = ndimage.label(content)

    groups = None
    if n >= 3:
        sizes = ndimage.sum(content, labels, index=range(1, n + 1))
        order = np.argsort(sizes)[::-1]
        if sizes[order[2]] >= 0.03 * sizes[order[0]]:
            cents = ndimage.center_of_mass(content, labels, index=range(1, n + 1))
            anchors = sorted((int(order[i]) + 1 for i in range(3)),
                             key=lambda cid: cents[cid - 1][1])  # left to right
            assign = {a: [] for a in anchors}
            for cid in range(1, n + 1):
                cy, cx = cents[cid - 1]
                best = min(anchors, key=lambda a: (cents[a - 1][1] - cx) ** 2
                           + 0.25 * (cents[a - 1][0] - cy) ** 2)
                assign[best].append(cid)
            groups = [np.isin(labels, assign[a]) for a in anchors]
        else:
            warnings.append("3rd-largest component is tiny — figures may be merged; "
                            "falling back to fixed-thirds split")
    else:
        warnings.append(f"only {n} component(s) found — falling back to fixed thirds")
    if groups is None:
        groups = []
        for x0, x1 in ((0, w // 3), (w // 3, 2 * w // 3), (2 * w // 3, w)):
            m = np.zeros_like(content)
            m[:, x0:x1] = content[:, x0:x1]
            groups.append(m)

    groups = [trim_isolated_edge_lines(strip_frame_lines(m)) for m in groups]

    # QA: consecutive figures shouldn't interleave much horizontally
    spans = []
    for m in groups:
        cols = np.flatnonzero(m.any(axis=0))
        spans.append((int(cols[0]), int(cols[-1])) if cols.size else (0, 0))
    for i in range(2):
        overlap = spans[i][1] - spans[i + 1][0]
        if overlap > 0.06 * w:
            warnings.append(f"figures {FORMS[i]}/{FORMS[i + 1]} overlap by "
                            f"{overlap}px horizontally — check the split")

    finals = {}
    for m, form in zip(groups, FORMS):
        ys, xs = np.nonzero(m)
        if ys.size == 0:
            warnings.append(f"{form}: no content found")
            continue
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        if x0 <= 1 or y0 <= 1 or x1 >= w - 1 or y1 >= h - 1:
            warnings.append(f"{form}: content touches the image edge (may be cut off)")

        alpha = np.where(m, 255, 0).astype(np.uint8)
        alpha_img = Image.fromarray(alpha, "L").filter(ImageFilter.GaussianBlur(0.6))
        rgba = img.convert("RGBA")
        rgba.putalpha(alpha_img)
        content_img = rgba.crop((int(x0), int(y0), int(x1), int(y1)))

        # aspect-fit into the original file's exact dimensions
        with Image.open(paths[form]["full"]) as orig:
            tw, th = orig.size
        scale = min(tw / content_img.width, th / content_img.height)
        fitted = content_img.resize((max(1, round(content_img.width * scale)),
                                     max(1, round(content_img.height * scale))),
                                    Image.LANCZOS)
        canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
        canvas.paste(fitted, ((tw - fitted.width) // 2, (th - fitted.height) // 2))
        full_dest = out_dir(slug) / "final" / f"{form}_full.png"
        canvas.save(full_dest)
        finals[form] = full_dest

        token_src = paths[form]["token"]
        if token_src.exists():
            derive_token(content_img, token_src,
                         out_dir(slug) / "final" / f"{form}_token.png")

    qa = {"raw": str(raw), "warnings": warnings,
          "timestamp": datetime.now(timezone.utc).isoformat()}
    (out_dir(slug) / "qa.json").write_text(json.dumps(qa, indent=2))
    status = "OK" if not warnings else f"{len(warnings)} warning(s)"
    print(f"split {raw.name} -> {len(finals)} finals [{status}]")
    for wmsg in warnings:
        print(f"  ⚠ {wmsg}")
    return finals


# ---------------------------------------------------------------- edit

EDIT_PROMPT = (
    "Edit this character illustration. {instruction}\n"
    "Change ONLY what the instruction requires — keep the character's identity, face, "
    "hairstyle, outfit, colors, art style, line quality, proportions, and overall pose "
    "EXACTLY as in the input image. The entire background must be solid pure white "
    "(#FFFFFF). Output ZERO text, no labels, no watermarks, no frames, no borders. "
    "The full body stays visible with clear white margin on all four sides."
)


def edit(slug, form, instruction, model=DEFAULT_MODEL, resolution=DEFAULT_RESOLUTION,
         refs=None):
    """Targeted touch-up of one already-split form; re-processes and re-saves it.

    refs: optional list of image paths attached AFTER the main image — visual
    references for the requested change (a mask design, a pose, a style)."""
    from google import genai
    from google.genai import types

    key = load_env_key()
    if not key:
        sys.exit("No GEMINI_API_KEY found (env or tools/twewy_restyle/.env).")
    src = out_dir(slug) / "final" / f"{form}_full.png"
    if not src.exists():
        sys.exit(f"missing {src}; run split first")

    prompt = EDIT_PROMPT.format(instruction=instruction)
    if refs:
        prompt += ("\nThe additional attached images (after the first) are visual "
                   "REFERENCES for the requested change only — copy the specific "
                   "referenced elements' design, never the overall composition, "
                   "identity, or art style of the reference images.")
    buf = io.BytesIO()
    flatten_white(Image.open(src)).save(buf, "PNG")
    parts = [types.Part.from_bytes(data=buf.getvalue(), mime_type="image/png")]
    for ref in refs or []:
        rbuf = io.BytesIO()
        flatten_white(Image.open(ref)).save(rbuf, "PNG")
        parts.append(types.Part.from_bytes(data=rbuf.getvalue(),
                                           mime_type="image/png"))
    parts.append(prompt)
    client = genai.Client(api_key=key,
                          http_options=types.HttpOptions(timeout=240_000))
    configs = [
        ("res_only", types.GenerateContentConfig(
            response_modalities=["TEXT", "IMAGE"],
            image_config=types.ImageConfig(image_size=resolution))),
        ("bare", None),
    ]
    resp, config_used, last_err = None, None, None
    for attempt in range(1, 4):
        for cfg_name, cfg in configs:
            try:
                resp = client.models.generate_content(model=model, contents=parts,
                                                      config=cfg)
                config_used = cfg_name
                break
            except Exception as e:  # noqa: BLE001
                last_err = e
                if any(t in str(e) for t in ("INVALID_ARGUMENT", "image_config",
                                             "image_size", "response_modalities")):
                    continue
                raise
        if resp is not None:
            break
        if any(t in str(last_err) for t in ("429", "RESOURCE_EXHAUSTED", "500",
                                            "503", "UNAVAILABLE", "DEADLINE")):
            time.sleep(12 * attempt)
        else:
            raise last_err
    if resp is None:
        raise last_err

    image_bytes, texts = None, []
    for part in resp.candidates[0].content.parts:
        inline = getattr(part, "inline_data", None)
        if inline is not None and getattr(inline, "mime_type", "").startswith("image/"):
            if image_bytes is None:
                image_bytes = inline.data
        elif getattr(part, "text", None):
            texts.append(part.text)
    if image_bytes is None:
        sys.exit(f"No image in edit response. Text: {' '.join(texts)[:400]}")

    raw = out_dir(slug) / f"edit_{form}_{model}.png"
    raw.write_bytes(image_bytes)
    (out_dir(slug) / f"edit_{form}_{model}.json").write_text(json.dumps({
        "slug": slug, "form": form, "model": model, "config_used": config_used,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "instruction": instruction, "prompt": prompt,
        "model_text": " ".join(texts)[:1000],
    }, indent=2))

    # postprocess the single figure exactly like split does
    img = strip_dark_bars(Image.open(raw).convert("RGB"))
    arr = np.asarray(img)
    content = remove_line_components(~background_mask(arr))
    content = unseal_panels(arr, content)
    content = strip_frame_lines(content)
    ys, xs = np.nonzero(content)
    if ys.size == 0:
        sys.exit("edit came back empty after background removal")
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    alpha = np.where(content, 255, 0).astype(np.uint8)
    alpha_img = Image.fromarray(alpha, "L").filter(ImageFilter.GaussianBlur(0.6))
    rgba = img.convert("RGBA")
    rgba.putalpha(alpha_img)
    content_img = rgba.crop((int(x0), int(y0), int(x1), int(y1)))

    paths = source_paths(slug)
    with Image.open(paths[form]["full"]) as orig:
        tw, th = orig.size
    scale = min(tw / content_img.width, th / content_img.height)
    fitted = content_img.resize((max(1, round(content_img.width * scale)),
                                 max(1, round(content_img.height * scale))),
                                Image.LANCZOS)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.paste(fitted, ((tw - fitted.width) // 2, (th - fitted.height) // 2))
    shutil.copy2(src, src.with_suffix(".prev.png"))
    canvas.save(src)

    token_src = paths[form]["token"]
    if token_src.exists():
        derive_token(content_img, token_src,
                     out_dir(slug) / "final" / f"{form}_token.png")
    print(f"edited {form} -> {src} (previous kept as {src.with_suffix('.prev.png').name})")


# ---------------------------------------------------------------- compare

def compare(slug):
    paths = source_paths(slug)
    d = out_dir(slug)
    font = load_font(22)
    row_h, tok_h, pad = 340, 120, 12

    def thumbs(images, height):
        out = []
        for im in images:
            im = flatten_white(im)
            s = height / im.height
            out.append(im.resize((max(1, round(im.width * s)), height), Image.LANCZOS))
        return out

    orig = thumbs([Image.open(paths[f]["full"]) for f in FORMS], row_h)
    gen_files = [d / "final" / f"{f}_full.png" for f in FORMS]
    gens = thumbs([Image.open(p) for p in gen_files if p.exists()], row_h)

    tok_pairs = []
    for f in FORMS:
        op, np_ = paths[f]["token"], d / "final" / f"{f}_token.png"
        if op.exists() and np_.exists():
            tok_pairs += [Image.open(op), Image.open(np_)]
    toks = thumbs(tok_pairs, tok_h) if tok_pairs else []

    width = max(sum(r.width for r in row) + pad * (len(row) + 1)
                for row in (orig, gens or orig, toks or orig))
    height = 40 + row_h + 40 + row_h + (40 + tok_h if toks else 0) + 4 * pad
    sheet = Image.new("RGB", (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(sheet)

    def put_row(row, label, y):
        draw.text((pad, y), label, fill=(0, 0, 0), font=font)
        x = pad
        for im in row:
            sheet.paste(im, (x, y + 34))
            x += im.width + pad
        return y + 34 + (row[0].height if row else 0) + pad

    y = put_row(orig, f"{slug} — ORIGINAL (base / power1 / power2)", pad)
    y = put_row(gens, "GENERATED", y)
    if toks:
        put_row(toks, "TOKENS (original, new) per form", y)

    dest = d / "compare.png"
    sheet.save(dest)
    print(f"compare -> {dest}")
    qa_trapped_white(slug)
    return dest


def qa_trapped_white(slug, white=225, min_size=12000):
    """QA WARNING (not an auto-fix): flag enclosed near-white 'pockets' left inside a
    figure. `background_mask` only removes BORDER-CONNECTED white, so white background
    sealed inside an enclosed loop — bent arms + crossed weapons, the inside of a drawn
    bow, the gap between a cane and a leg — survives as opaque white. It is INVISIBLE on
    the white compare sheet but shows as white BLOBS on the game's dark background.

    Deliberately NOT auto-removed: legit white fur/skin/hair/glow reads identically to a
    trapped pocket, so blind removal destroys art (it ate a fur cape in testing). This
    only warns and writes out/<slug>/qa_dark.png for the operator to eyeball; fix real
    pockets with `restyle.py fixpocket <slug> <form> --center cx,cy`."""
    d = out_dir(slug)
    hits, darks = [], []
    for form in FORMS:
        full = d / "final" / f"{form}_full.png"
        if not full.exists():
            continue
        im = Image.open(full).convert("RGBA")
        w, h = im.size
        a = np.asarray(im)
        ow = (a[..., 3] > 128) & (a[..., :3] >= white).all(axis=2)
        lbl, n = ndimage.label(ow)
        sizes = ndimage.sum(np.ones_like(lbl), lbl, index=range(1, n + 1))
        for i in range(n):
            if sizes[i] < min_size:
                continue
            ys, xs = np.where(lbl == i + 1)
            cx = xs.mean() / w
            if cx < 0.34 or cx > 0.62:  # off the central garment column = suspicious
                hits.append((form, int(sizes[i]), round(cx, 2), round(ys.mean() / h, 2)))
        darks.append(Image.alpha_composite(
            Image.new("RGBA", (w, h), (18, 18, 22, 255)), im).convert("RGB"))
    if hits:
        thumbs = [dk.resize((max(1, round(280 / dk.height * dk.width)), 280)) for dk in darks]
        mont = Image.new("RGB", (sum(t.width for t in thumbs) + 10 * (len(thumbs) + 1), 300),
                         (18, 18, 22))
        x = 10
        for t in thumbs:
            mont.paste(t, (x, 10))
            x += t.width + 10
        qa_path = d / "qa_dark.png"
        mont.save(qa_path)
        print(f"WARNING: {slug} has {len(hits)} large off-center near-white region(s) — "
              f"possible TRAPPED BACKGROUND (white blobs on the game's dark bg):")
        for form, sz, cx, cy in hits:
            print(f"    {form}: {sz}px at ({cx},{cy})")
        print(f"    Eyeball {qa_path} on the dark bg. If a region is trapped background "
              f"(not fur/skin/glow), remove it: restyle.py fixpocket {slug} <form> "
              f"--center cx,cy")
    return hits


def fix_trapped_pocket(slug, form, centers, white=225, min_size=6000, shave=2):
    """Remove trapped white background pocket(s) from one already-split form: for each
    (cx,cy) fractional center, delete the near-white opaque connected component closest
    to it (a 2px halo shave cleans the anti-aliased rim, stopping at the dark outline),
    keep the previous as .prev.png, and re-derive the token. Centers come from eyeballing
    out/<slug>/qa_dark.png (or a component color-map)."""
    src = out_dir(slug) / "final" / f"{form}_full.png"
    if not src.exists():
        sys.exit(f"missing {src}; run split first")
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    a = np.asarray(im).copy()
    rgb, al = a[..., :3], a[..., 3]
    ow = (al > 128) & (rgb >= white).all(axis=2)
    lbl, n = ndimage.label(ow)
    sizes = ndimage.sum(np.ones_like(lbl), lbl, index=range(1, n + 1))
    comps = []
    for i in range(n):
        if sizes[i] < min_size:
            continue
        ys, xs = np.where(lbl == i + 1)
        comps.append((i + 1, xs.mean() / w, ys.mean() / h, int(sizes[i])))
    if not comps:
        sys.exit("no near-white components above min_size found")
    remove = np.zeros((h, w), bool)
    for (tx, ty) in centers:
        cid, cx, cy, sz = min(comps, key=lambda c: (c[1] - tx) ** 2 + (c[2] - ty) ** 2)
        remove |= (lbl == cid)
        print(f"    removing component at ({cx:.2f},{cy:.2f}) size {sz}px")
    light = (al > 128) & (rgb >= 200).all(axis=2)
    for _ in range(shave):
        remove |= ndimage.binary_dilation(remove) & ~remove & light
    a[..., 3][remove] = 0
    shutil.copy2(src, src.with_suffix(".prev.png"))
    Image.fromarray(a).save(src)
    # re-derive token from the cleaned figure
    rgba = Image.fromarray(a)
    ys, xs = np.nonzero(np.asarray(rgba.split()[-1]) > ALPHA_CONTENT)
    if ys.size:
        content = rgba.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
        token_src = source_paths(slug)[form]["token"]
        if token_src.exists():
            derive_token(content, token_src, out_dir(slug) / "final" / f"{form}_token.png")
    print(f"fixed {form}: cleared {int(remove.sum())}px trapped background -> {src} "
          f"(previous kept as {src.with_suffix('.prev.png').name})")


TOKEN_PROMPT = (
    "The attached image shows the same character in three forms side by side "
    "(left to right: BASE, POWER 1, POWER 2). Create THREE square FACE PORTRAIT "
    "icons arranged in one row in the same left-to-right order, one portrait per "
    "form. Each portrait: the character's head and shoulders only, face large and "
    "centered, filling most of its square; identical identity, face and hairstyle "
    "in all three; match each form's own coloring, gear and energy effects (glow, "
    "flames) around the head. Same art style as the input. Solid pure white "
    "background, generous white spacing between the three portraits, no text, no "
    "labels, no frames, no borders."
)


def gen_tokens(slug, model=AB_MODEL, resolution="1K"):
    """Model-composed face icons: one call returns a 3-portrait sheet, split by
    segmentation. Better than cropping when weapons/effects crowd the head."""
    from google import genai
    from google.genai import types

    key = load_env_key()
    if not key:
        sys.exit("No GEMINI_API_KEY found (env or tools/twewy_restyle/.env).")
    paths = source_paths(slug)
    fulls = []
    for form in FORMS:
        p = out_dir(slug) / "final" / f"{form}_full.png"
        if not p.exists():
            sys.exit(f"missing {p}; run split first")
        im = flatten_white(Image.open(p))
        s = 700 / im.height
        fulls.append(im.resize((round(im.width * s), 700), Image.LANCZOS))
    gutter = 60
    sheet = Image.new("RGB", (sum(f.width for f in fulls) + 4 * gutter, 700 + 2 * gutter),
                      (255, 255, 255))
    x = gutter
    for f in fulls:
        sheet.paste(f, (x, gutter))
        x += f.width + gutter
    buf = io.BytesIO()
    sheet.save(buf, "PNG")

    client = genai.Client(api_key=key,
                          http_options=types.HttpOptions(timeout=240_000))
    parts = [types.Part.from_bytes(data=buf.getvalue(), mime_type="image/png"),
             TOKEN_PROMPT]
    configs = [
        ("ar4x1", types.GenerateContentConfig(
            response_modalities=["TEXT", "IMAGE"],
            image_config=types.ImageConfig(aspect_ratio="4:1", image_size=resolution))),
        ("ar21x9", types.GenerateContentConfig(
            response_modalities=["TEXT", "IMAGE"],
            image_config=types.ImageConfig(aspect_ratio="21:9", image_size=resolution))),
        ("bare", None),
    ]
    resp, last_err = None, None
    for cfg_name, cfg in configs:
        try:
            resp = client.models.generate_content(model=model, contents=parts,
                                                  config=cfg)
            break
        except Exception as e:  # noqa: BLE001
            last_err = e
            if any(t in str(e) for t in ("INVALID_ARGUMENT", "image_config",
                                         "aspect_ratio", "image_size",
                                         "response_modalities", "not supported")):
                continue
            raise
    if resp is None:
        raise last_err

    image_bytes = None
    for part in resp.candidates[0].content.parts:
        inline = getattr(part, "inline_data", None)
        if inline is not None and getattr(inline, "mime_type", "").startswith("image/"):
            image_bytes = inline.data
            break
    if image_bytes is None:
        sys.exit("no image in token-sheet response")
    raw = out_dir(slug) / f"raw_tokens_{model}.png"
    raw.write_bytes(image_bytes)

    img = strip_dark_bars(Image.open(raw).convert("RGB"))
    arr = np.asarray(img)
    content = remove_line_components(~background_mask(arr))
    content = unseal_panels(arr, content)
    labels, n = ndimage.label(content)
    if n < 3:
        sys.exit(f"token sheet split failed ({n} components) — falling back: "
                 f"run 'tokens {slug}' for crop-based tokens")
    sizes = ndimage.sum(content, labels, index=range(1, n + 1))
    order = np.argsort(sizes)[::-1]
    cents = ndimage.center_of_mass(content, labels, index=range(1, n + 1))
    anchors = sorted((int(order[i]) + 1 for i in range(3)),
                     key=lambda cid: cents[cid - 1][1])
    for cid, form in zip(anchors, FORMS):
        m = labels == cid
        ys, xs = np.nonzero(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        side = max(y1 - y0, x1 - x0)
        sx0 = max(0, min(img.width - side, cx - side // 2))
        sy0 = max(0, min(img.height - side, cy - side // 2))
        alpha = np.where(m, 255, 0).astype(np.uint8)
        alpha_img = Image.fromarray(alpha, "L").filter(ImageFilter.GaussianBlur(0.6))
        rgba = img.convert("RGBA")
        rgba.putalpha(alpha_img)
        token = rgba.crop((sx0, sy0, sx0 + side, sy0 + side))
        token_src = paths[form]["token"]
        if token_src.exists():
            with Image.open(token_src) as orig_token:
                token = token.resize(orig_token.size, Image.LANCZOS)
            token.save(out_dir(slug) / "final" / f"{form}_token.png")
            print(f"token generated: {form}")


def rebuild_tokens(slug, centers=None):
    """Re-derive tokens from the existing final full-art (no API call).

    centers: optional {form: (fx, fy)} manual face centers as fractions of the
    FINAL image, for the rare panels where no detector finds the real face."""
    paths = source_paths(slug)
    for form in FORMS:
        full = out_dir(slug) / "final" / f"{form}_full.png"
        token_src = paths[form]["token"]
        if not full.exists() or not token_src.exists():
            continue
        rgba = Image.open(full).convert("RGBA")
        dest = out_dir(slug) / "final" / f"{form}_token.png"
        if centers and form in centers:
            fx, fy, sizefrac = centers[form]
            cx, cy = fx * rgba.width, fy * rgba.height
            side = int(min(rgba.width, rgba.height, round(sizefrac * rgba.height)))
            x0 = int(max(0, min(rgba.width - side, round(cx) - side // 2)))
            y0 = int(max(0, min(rgba.height - side, round(cy) - side // 2)))
            token = rgba.crop((x0, y0, x0 + side, y0 + side))
            with Image.open(token_src) as orig_token:
                token = token.resize(orig_token.size, Image.LANCZOS)
            token.save(dest)
            print(f"token rebuilt (manual center): {form}")
            continue
        a = np.asarray(rgba.split()[-1]) > ALPHA_CONTENT
        ys, xs = np.nonzero(a)
        if ys.size == 0:
            continue
        content_img = rgba.crop((int(xs.min()), int(ys.min()),
                                 int(xs.max()) + 1, int(ys.max()) + 1))
        derive_token(content_img, token_src, dest)
        print(f"token rebuilt: {form}")


# ---------------------------------------------------------------- install

def install(slug):
    paths = source_paths(slug)
    d = out_dir(slug) / "final"
    plan = []
    for form in FORMS:
        for kind in ("full", "token"):
            final = d / f"{form}_{kind}.png"
            target = paths[form][kind]
            if kind == "full" and not final.exists():
                sys.exit(f"missing {final}; run split first")
            if final.exists() and target.exists():
                with Image.open(final) as a, Image.open(target) as b:
                    if a.size != b.size:
                        sys.exit(f"dimension mismatch {final.name}: "
                                 f"{a.size} vs original {b.size}")
                plan.append((final, target))

    for final, target in plan:
        rel = target.relative_to(GAME)
        bak = BACKUP / rel
        bak.parent.mkdir(parents=True, exist_ok=True)
        if not bak.exists():  # keep the FIRST backup — that's the true original
            shutil.copy2(target, bak)
        shutil.copy2(final, target)
        print(f"installed {rel}")
    print(f"{len(plan)} files installed (originals backed up under {BACKUP})")


# ---------------------------------------------------------------- orchestration

def run(slug, model=DEFAULT_MODEL, resolution=DEFAULT_RESOLUTION):
    stitch(slug)
    gen(slug, model=model, resolution=resolution)
    split(slug)
    compare(slug)


def batch(slugs, model=DEFAULT_MODEL, resolution=DEFAULT_RESOLUTION):
    slugs = slugs or list(load_json(ART_DIRECTION).keys())
    failures = []
    for i, slug in enumerate(slugs):
        missing = [p["full"] for p in source_paths(slug).values()
                   if not p["full"].exists()]
        if missing:
            print(f"[{slug}] skipped — missing {len(missing)} source file(s)")
            continue
        print(f"[{i + 1}/{len(slugs)}] {slug}")
        try:
            run(slug, model=model, resolution=resolution)
        except Exception as e:  # noqa: BLE001 — keep the batch going
            failures.append((slug, str(e)[:200]))
            print(f"  ✗ {slug} failed: {e}")
        time.sleep(6)
    if failures:
        print("\nFailures:")
        for slug, err in failures:
            print(f"  {slug}: {err}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["stitch", "prompt", "gen", "split", "compare",
                                        "run", "install", "batch", "edit", "tokens",
                                        "qa", "fixpocket"])
    ap.add_argument("slugs", nargs="*", help="character slug(s); for edit: slug form")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--resolution", default=DEFAULT_RESOLUTION,
                    choices=["1K", "2K", "4K"])
    ap.add_argument("--raw", help="specific raw output to split")
    ap.add_argument("--instruction", help="edit instruction (edit command)")
    ap.add_argument("--gen", action="store_true",
                    help="tokens command: model-composed portraits instead of crops")
    ap.add_argument("--center", action="append",
                    help="tokens command: manual face center, form=fx,fy "
                         "(fractions of the final image), repeatable")
    ap.add_argument("--ref", action="append",
                    help="edit command: reference image path for the change, "
                         "repeatable")
    args = ap.parse_args()

    if args.command == "batch":
        batch(args.slugs, model=args.model, resolution=args.resolution)
        return
    if not args.slugs:
        ap.error("a character slug is required")
    slug = args.slugs[0]
    if args.command == "stitch":
        stitch(slug)
    elif args.command == "prompt":
        save_prompt(slug)
    elif args.command == "gen":
        gen(slug, model=args.model, resolution=args.resolution)
    elif args.command == "split":
        split(slug, raw_path=args.raw)
    elif args.command == "compare":
        compare(slug)
    elif args.command == "run":
        run(slug, model=args.model, resolution=args.resolution)
    elif args.command == "install":
        install(slug)
    elif args.command == "edit":
        if len(args.slugs) < 2 or args.slugs[1] not in FORMS or not args.instruction:
            ap.error('usage: edit <slug> <base|job2|job3> --instruction "..."')
        edit(slug, args.slugs[1], args.instruction,
             model=args.model, resolution=args.resolution, refs=args.ref)
    elif args.command == "qa":
        qa_trapped_white(slug)
    elif args.command == "fixpocket":
        if len(args.slugs) < 2 or args.slugs[1] not in FORMS or not args.center:
            ap.error('usage: fixpocket <slug> <base|job2|job3> '
                     '--center cx,cy [--center cx,cy ...]')
        centers = [(float(s.split(",")[0]), float(s.split(",")[1]))
                   for s in args.center]
        fix_trapped_pocket(slug, args.slugs[1], centers)
    elif args.command == "tokens":
        if args.gen:
            gen_tokens(slug, model=args.model if args.model != DEFAULT_MODEL
                       else AB_MODEL, resolution="1K")
        else:
            centers = {}
            for spec in args.center or []:
                form, xy = spec.split("=")
                parts = xy.split(",")
                fx, fy = float(parts[0]), float(parts[1])
                sizefrac = float(parts[2]) if len(parts) > 2 else 0.18
                centers[form] = (fx, fy, sizefrac)
            rebuild_tokens(slug, centers=centers or None)


if __name__ == "__main__":
    main()
