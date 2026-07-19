#!/usr/bin/env python3
"""FF-style title-logo emblem generation for Heaven's Mandate (Nano Banana Pro).

Concept (user-picked): "falling stars over water" — the 108-star legend meeting
the literal water margin. Emblem art contains NO text; the wordmark stays a
Cinzel Godot Label and the hanzi live only in a separate 天命 seal-chop asset.

Usage (from tools/twewy_restyle/, using .venv/bin/python):
  logo.py gen [--variants 6]              # round-1 emblem candidates (API)
  logo.py seal [--n 3] [--pil]            # 天命 seal candidates (API or PIL fallback)
  logo.py sheet                           # rebuild review HTML, print file:// link
  logo.py refine CAND --instruction "..." [--variants 3]   # art-direction round
  logo.py finalize CAND [--seal PATH]     # alpha + install to assets/ui + lockup preview

The API key is read from GEMINI_API_KEY (environment or .env next to this file).
"""

import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

import restyle  # import-safe: module level is imports + constants only

ROOT = restyle.ROOT
GAME = restyle.GAME
OUT = ROOT / "out" / "logo"
REFS_DIR = ROOT / "logo_refs"          # optional style refs, separate from style_refs/
ASSETS_UI = GAME / "assets" / "ui"
CINZEL = GAME / "assets" / "fonts" / "CinzelDecorative-Bold.ttf"

DARK_BG = (21, 24, 29)                 # title screen #15181D
GOLD = (192, 160, 98)                  # #C0A062
SEAL_RED = (168, 50, 42)               # #A8322A
TEXT_COL = (220, 224, 228)             # #DCE0E4 (current TitleLabel color)

# ---------------------------------------------------------------- prompt bank

BASE = """A title-logo emblem in the exact visual tradition of classic FINAL FANTASY \
logo artwork (the Yoshitaka Amano emblem style): one refined line-art illustration \
drawn with fine, precise ink strokes — thin tapering pen lines, elegant sweeping \
contours, ornate delicate detail, sparse feathered hatching for shading — like a \
masterful etching. NOT thick brush calligraphy, NOT watercolor washes, NOT a cartoon.

The entire illustration is colored as a smooth gradient of ONE single hue, exactly \
like Final Fantasy title logos: {hue}. The strokes themselves carry the color — the \
gradient sweeps vertically through the whole drawing as one continuous flow. No \
second hue appears anywhere.

SUBJECT — {composition}

HARD RULES:
- exactly ONE emblem, centered on the canvas, generous empty white margin on all four sides
- the background is solid pure white (#FFFFFF); absolutely nothing else on it
- every stroke stays in tints and shades of the single hue; no black outlines
- fine, controlled line weight throughout; crisp edges; no glow, no airbrush haze
- NO text of any language: no letters, no numerals, no Chinese characters, no \
signature, no watermark
- no enclosing frame, border, or box around the design"""

CANVAS_DESC = {
    "white": ("solid pure white (#FFFFFF)", "white"),
    "black": ("solid pure black (#000000)", "black"),
}

HUES = {
    "vermilion": (
        "vermilion seal-red, running from pale blush at the highest strokes down "
        "through warm vermilion into deep carmine (#9C3B2E) at the base"),
    "gold": (
        "antique gold, running from pale champagne at the highest strokes down "
        "through warm amber into burnished gold-bronze (#8A6A34) at the base"),
    "indigo": (
        "night indigo, running from pale silver-blue at the highest strokes down "
        "through slate blue into deep ink-indigo at the base"),
}

COMP_CASCADE = (
    '"the falling stars over the water": a cascade of five slender four-pointed '
    "stars plunging in one steep diagonal sweep, each trailing long fine streamer "
    "lines like comet tails, the lines interweaving as they fall; at the base a "
    "still waterline drawn as thin horizontal strokes, pierced where the leading "
    "star meets it with a small crown of splash lines; beneath the waterline the "
    "stars' reflections break into short scattered line fragments and one "
    "expanding ripple ring.")

COMP_ONESTAR = (
    '"the last falling star over the water": one great slender four-pointed star '
    "diving headlong, its tail an ornate ribbon of many interweaving fine lines "
    "sweeping the full height of the emblem in a graceful S-curve; below, a still "
    "waterline of thin horizontal strokes, and the star's reflection breaking "
    "into small drifting line fragments and a single ripple ring.")

VARIANTS = [
    {"tag": "verm_cascade", "canvas": "white",
     "hue": HUES["vermilion"], "composition": COMP_CASCADE},
    {"tag": "gold_cascade", "canvas": "white",
     "hue": HUES["gold"], "composition": COMP_CASCADE},
    {"tag": "indigo_cascade", "canvas": "white",
     "hue": HUES["indigo"], "composition": COMP_CASCADE},
    {"tag": "verm_onestar", "canvas": "white",
     "hue": HUES["vermilion"], "composition": COMP_ONESTAR},
    {"tag": "gold_onestar", "canvas": "white",
     "hue": HUES["gold"], "composition": COMP_ONESTAR},
    {"tag": "indigo_onestar", "canvas": "white",
     "hue": HUES["indigo"], "composition": COMP_ONESTAR},
]

SEAL_LAYOUTS = [
    "stacked vertically, 天 above 命",
    "stacked vertically, 天 above 命",
    "side by side, 天 on the right and 命 on the left (read right to left)",
]

SEAL_PROMPT = """A traditional Chinese seal impression (a red name chop) as a flat \
graphic asset: a square vermilion stamp (#A8322A) with slightly rough, organically \
inked edges, containing EXACTLY two Chinese characters carved in white: 天 and 命 \
("Heaven's Mandate"), written in classical zhuanshu seal script, arranged {layout}. \
The two characters must be structurally correct and clearly legible as 天 and 命 — \
no invented strokes, no decorative corruption. Solid pure white (#FFFFFF) background \
around the stamp, nothing else: no other characters, no Latin letters, no extra marks."""

REFINE_PROMPT = (
    "Edit this logo emblem. {instruction}\n"
    "Change ONLY what the instruction requires — keep the overall composition, motif, "
    "palette, line quality, and art style EXACTLY as in the input image. Keep the "
    "background the same single flat solid color as the input image. Crisp silhouette "
    "edges, no outer glow. Output ZERO text of any language, no watermarks, no frames.")

STYLE_REF_RIDER = (
    "\nThe attached images (before this prompt) are STYLE references only — match "
    "their line quality, gradient treatment, and overall elegance; never copy their "
    "actual subjects or compositions.")


# ---------------------------------------------------------------- api core

def _generate(parts, model, resolution, aspect="1:1"):
    """One image via the proven config ladder + transient retry (cf. restyle.gen)."""
    from google import genai
    from google.genai import types

    key = restyle.load_env_key()
    if not key:
        sys.exit("No GEMINI_API_KEY found (env or tools/twewy_restyle/.env).")
    client = genai.Client(api_key=key,
                          http_options=types.HttpOptions(timeout=240_000))
    configs = [
        ("full", types.GenerateContentConfig(
            response_modalities=["TEXT", "IMAGE"],
            image_config=types.ImageConfig(aspect_ratio=aspect,
                                           image_size=resolution))),
        ("no_image_config", types.GenerateContentConfig(
            response_modalities=["TEXT", "IMAGE"])),
        ("bare", None),
    ]
    resp, config_used, last_err = None, None, None
    for attempt in range(1, 5):
        for cfg_name, cfg in configs:
            try:
                resp = client.models.generate_content(model=model, contents=parts,
                                                      config=cfg)
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
                    sys.exit(f"Model '{model}' not found for this key: {msg[:300]}")
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
    return image_bytes, config_used, texts


def _ref_parts():
    """Optional style-ref images from logo_refs/ (attached before the prompt)."""
    from google.genai import types
    refs = []
    if REFS_DIR.is_dir():
        for p in sorted(REFS_DIR.iterdir()):
            if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
                refs.append(p)
    refs = refs[:restyle.MAX_STYLE_REFS]
    parts = []
    for ref in refs:
        mime = ("image/jpeg" if ref.suffix.lower() in (".jpg", ".jpeg")
                else f"image/{ref.suffix.lower().lstrip('.')}")
        parts.append(types.Part.from_bytes(data=ref.read_bytes(), mime_type=mime))
    return parts, refs


def _save(dest, image_bytes, meta):
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(image_bytes)
    with Image.open(dest) as check:  # normalize to real PNG
        if (check.format or "PNG") != "PNG":
            check.convert("RGB").save(dest, "PNG")
        meta["output_size"] = check.size
    dest.with_suffix(".json").write_text(json.dumps(meta, indent=2))
    print(f"generated -> {dest} {meta['output_size']} in {meta['duration_s']}s "
          f"(config={meta['config_used']})")


def next_round_dir():
    OUT.mkdir(parents=True, exist_ok=True)
    nums = [int(p.name[1:]) for p in OUT.glob("r*")
            if p.is_dir() and p.name[1:].isdigit()]
    return OUT / f"r{max(nums) + 1 if nums else 1}"


# ---------------------------------------------------------------- commands

def cmd_gen(variants, model, resolution):
    rdir = next_round_dir()
    ref_parts, refs = _ref_parts()
    chosen = VARIANTS[:variants]
    for i, v in enumerate(chosen, start=1):
        prompt = BASE.format(hue=v["hue"], composition=v["composition"])
        if ref_parts:
            prompt += STYLE_REF_RIDER
        started = time.time()
        image_bytes, config_used, texts = _generate(
            ref_parts + [prompt], model, resolution)
        meta = {
            "tag": v["tag"], "canvas": v["canvas"], "model": model,
            "resolution": resolution, "config_used": config_used,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "duration_s": round(time.time() - started, 1),
            "style_refs": [str(r) for r in refs],
            "model_text": " ".join(texts)[:2000], "prompt": prompt,
        }
        _save(rdir / f"stars_v{i:02d}_{v['tag']}.png", image_bytes, meta)
        if i < len(chosen):
            time.sleep(6)
    cmd_sheet()


def cmd_seal(n, model, resolution, pil_only=False):
    sdir = OUT / "seal"
    sdir.mkdir(parents=True, exist_ok=True)
    if not pil_only:
        for i in range(1, n + 1):
            layout = SEAL_LAYOUTS[(i - 1) % len(SEAL_LAYOUTS)]
            prompt = SEAL_PROMPT.format(layout=layout)
            started = time.time()
            image_bytes, config_used, texts = _generate([prompt], model, resolution)
            meta = {
                "tag": f"seal_{i}", "canvas": "white", "layout": layout,
                "model": model, "resolution": resolution, "config_used": config_used,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "duration_s": round(time.time() - started, 1),
                "model_text": " ".join(texts)[:2000], "prompt": prompt,
            }
            _save(sdir / f"seal_v{i:02d}.png", image_bytes, meta)
            if i < n:
                time.sleep(6)
    _seal_pil(sdir)
    cmd_sheet()


def _seal_pil(sdir):
    """Deterministic fallback: 天命 in a system CJK font on a vermilion square."""
    candidates = [
        ("kaiti", "/System/Library/Fonts/Supplemental/Kaiti.ttc"),
        ("songti", "/System/Library/Fonts/Supplemental/Songti.ttc"),
    ]
    made = 0
    for name, path in candidates:
        if not Path(path).exists():
            continue
        try:
            font = ImageFont.truetype(path, 150)
        except OSError:
            continue
        img = Image.new("RGB", (400, 400), (255, 255, 255))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((20, 20, 380, 380), radius=14, fill=SEAL_RED)
        for ch, cy in (("天", 115), ("命", 275)):
            bbox = d.textbbox((0, 0), ch, font=font)
            w = bbox[2] - bbox[0]
            h = bbox[3] - bbox[1]
            d.text((200 - w / 2 - bbox[0], cy - h / 2 - bbox[1]), ch,
                   font=font, fill=(255, 255, 255))
        dest = sdir / f"seal_pil_{name}.png"
        img.save(dest)
        made += 1
        print(f"pil fallback -> {dest}")
    if not made:
        print("  (no system CJK font found for PIL fallback)")


def cmd_refine(candidate, instruction, variants, model, resolution):
    from google.genai import types
    src = Path(candidate)
    if not src.exists():
        sys.exit(f"missing candidate: {src}")
    rdir = next_round_dir()
    prompt = REFINE_PROMPT.format(instruction=instruction)
    canvas = _sidecar_canvas(src)
    src_part = types.Part.from_bytes(data=src.read_bytes(), mime_type="image/png")
    for i in range(1, variants + 1):
        started = time.time()
        image_bytes, config_used, texts = _generate([src_part, prompt],
                                                    model, resolution)
        meta = {
            "tag": f"refined_{src.stem}", "canvas": canvas, "source": str(src),
            "instruction": instruction, "model": model, "resolution": resolution,
            "config_used": config_used,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "duration_s": round(time.time() - started, 1),
            "model_text": " ".join(texts)[:2000], "prompt": prompt,
        }
        _save(rdir / f"refined_{src.stem}_v{i:02d}.png", image_bytes, meta)
        if i < variants:
            time.sleep(6)
    cmd_sheet()


def _sidecar_canvas(png_path):
    sc = png_path.with_suffix(".json")
    if sc.exists():
        try:
            return json.loads(sc.read_text()).get("canvas", "white")
        except json.JSONDecodeError:
            pass
    return "white"


# ---------------------------------------------------------------- postprocess

def alpha_cut(img, canvas="white", thr=240, dark_thr=28, punch_holes=False):
    """Background -> alpha for a logo emblem. Border-connected flood only, so
    enclosed pockets survive (cf. restyle.background_mask, parameterized)."""
    if canvas == "white":
        img = restyle.strip_dark_bars(img.convert("RGB"))
    else:
        img = img.convert("RGB")
    arr = np.asarray(img)
    near = ((arr >= thr).all(axis=2) if canvas == "white"
            else (arr <= dark_thr).all(axis=2))
    labels, _ = ndimage.label(near)
    border = np.unique(np.concatenate([
        labels[0, :], labels[-1, :], labels[:, 0], labels[:, -1]]))
    border = border[border != 0]
    content = ~np.isin(labels, border)

    if punch_holes:  # optionally clear big enclosed background-colored pockets
        interior = near & content
        ilabels, ni = ndimage.label(interior)
        if ni:
            areas = ndimage.sum(interior, ilabels, index=range(1, ni + 1))
            big = [i + 1 for i, a in enumerate(areas) if a >= 0.001 * near.size]
            if big:
                content &= ~np.isin(ilabels, big)

    # drop dust specks
    clabels, nc = ndimage.label(content)
    if nc:
        areas = ndimage.sum(content, clabels, index=range(1, nc + 1))
        kill = [i + 1 for i, a in enumerate(areas) if a < 0.0005 * content.size]
        if kill:
            content &= ~np.isin(clabels, kill)

    ys, xs = np.nonzero(content)
    if ys.size == 0:
        sys.exit("nothing left after background removal — check --threshold/--dark")
    alpha = np.where(content, 255, 0).astype(np.uint8)
    alpha_img = Image.fromarray(alpha, "L").filter(ImageFilter.GaussianBlur(0.6))
    rgba = img.convert("RGBA")
    rgba.putalpha(alpha_img)
    return rgba.crop((int(xs.min()), int(ys.min()),
                      int(xs.max()) + 1, int(ys.max()) + 1))


def _pad_resize(rgba, size, pad):
    scale = size / max(rgba.size)
    fitted = rgba.resize((max(1, round(rgba.width * scale)),
                          max(1, round(rgba.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (fitted.width + 2 * pad, fitted.height + 2 * pad),
                       (0, 0, 0, 0))
    canvas.paste(fitted, (pad, pad))
    return canvas


def _on_color(rgba, color):
    bg = Image.new("RGBA", rgba.size, color + (255,))
    bg.alpha_composite(rgba)
    return bg.convert("RGB")


def cmd_finalize(candidate, size, pad, thr, dark_thr, force_dark, punch_holes,
                 seal_path, seal_size):
    src = Path(candidate)
    if not src.exists():
        sys.exit(f"missing candidate: {src}")
    canvas = "black" if force_dark else _sidecar_canvas(src)
    rgba = alpha_cut(Image.open(src), canvas=canvas, thr=thr, dark_thr=dark_thr,
                     punch_holes=punch_holes)
    emblem = _pad_resize(rgba, size, pad)
    ASSETS_UI.mkdir(parents=True, exist_ok=True)
    dest = ASSETS_UI / "logo_emblem.png"
    emblem.save(dest)
    print(f"emblem -> {dest} {emblem.size} (from {src.name}, canvas={canvas})")

    fdir = OUT / "final"
    fdir.mkdir(parents=True, exist_ok=True)
    _on_color(emblem, (255, 255, 255)).save(fdir / "emblem_white.png")
    _on_color(emblem, DARK_BG).save(fdir / "emblem_dark.png")

    seal_dest = ASSETS_UI / "logo_seal.png"
    if seal_path:
        sp = Path(seal_path)
        if not sp.exists():
            sys.exit(f"missing seal: {sp}")
        seal_rgba = alpha_cut(Image.open(sp), canvas="white", thr=thr)
        seal = _pad_resize(seal_rgba, seal_size, 4)
        seal.save(seal_dest)
        print(f"seal   -> {seal_dest} {seal.size}")

    _lockup_preview(emblem, seal_dest if seal_dest.exists() else None, fdir)
    cmd_sheet()


def _tracked_text(draw, xy, text, font, fill, tracking):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        bbox = draw.textbbox((0, 0), ch, font=font)
        x += (bbox[2] - bbox[0]) + tracking


def _tracked_width(draw, text, font, tracking):
    w = 0
    for ch in text:
        bbox = draw.textbbox((0, 0), ch, font=font)
        w += (bbox[2] - bbox[0]) + tracking
    return w - tracking if text else 0


def _lockup_preview(emblem, seal_path, fdir):
    """720x960 mock of the title screen top block: emblem, rules, wordmark, seal."""
    W, H = 720, 960
    img = Image.new("RGB", (W, H), DARK_BG)
    d = ImageDraw.Draw(img)

    max_w, max_h = 460, 380
    scale = min(max_w / emblem.width, max_h / emblem.height, 1.0)
    esize = (round(emblem.width * scale), round(emblem.height * scale))
    e = emblem.resize(esize, Image.LANCZOS)
    img.paste(e, ((W - e.width) // 2, 120), e)
    y = 120 + e.height + 26

    d.rectangle((W // 2 - 140, y, W // 2 + 140, y + 1), fill=GOLD)
    y += 22
    try:
        font = ImageFont.truetype(str(CINZEL), 54)
    except OSError:
        font = ImageFont.load_default(size=54)
    for line in ("HEAVEN'S", "MANDATE"):
        lw = _tracked_width(d, line, font, 4)
        _tracked_text(d, ((W - lw) // 2, y), line, font, TEXT_COL, 4)
        y += 66
    y += 8
    d.rectangle((W // 2 - 140, y, W // 2 + 140, y + 1), fill=GOLD)

    if seal_path and Path(seal_path).exists():
        seal = Image.open(seal_path).convert("RGBA")
        s = 56
        seal = seal.resize((s, round(seal.height * s / seal.width)), Image.LANCZOS)
        img.paste(seal, (W // 2 + 150, y - 10 - seal.height), seal)

    dest = fdir / "lockup_preview.png"
    img.save(dest)
    print(f"lockup preview -> {dest}")


# ---------------------------------------------------------------- sheet

def _dark_preview(png, canvas):
    """Cached quick dark-bg composite so white-canvas candidates can be judged
    in title-screen context before finalize."""
    prev = png.with_name(png.stem + ".darkprev.png")
    if prev.exists() and prev.stat().st_mtime >= png.stat().st_mtime:
        return prev
    try:
        rgba = alpha_cut(Image.open(png), canvas=canvas)
    except SystemExit:
        return None
    tile = _on_color(_pad_resize(rgba, 480, 16), DARK_BG)
    tile.save(prev)
    return prev


def cmd_sheet():
    OUT.mkdir(parents=True, exist_ok=True)
    sections = []
    round_dirs = sorted([p for p in OUT.glob("r*") if p.is_dir()
                         and p.name[1:].isdigit()],
                        key=lambda p: int(p.name[1:]))
    for d in round_dirs:
        sections.append((f"Round {d.name[1:]}", d))
    if (OUT / "seal").is_dir():
        sections.append(("Seal 天命", OUT / "seal"))
    if (OUT / "final").is_dir():
        sections.append(("Finalized", OUT / "final"))

    html = ["<!doctype html><meta charset='utf-8'>",
            "<title>Heaven's Mandate — logo review</title><style>",
            "body{background:#15181d;color:#efe8d8;font:14px Georgia,serif;margin:24px}",
            "h1{color:#dce0e4;font-weight:normal;letter-spacing:2px}",
            "h2{color:#c0a062;font-weight:normal;border-bottom:1px solid #c0a06255;",
            "padding-bottom:4px;margin-top:36px}",
            ".grid{display:flex;flex-wrap:wrap;gap:16px}",
            "figure{margin:0;background:#fff;padding:8px;width:300px;",
            "border:1px solid #c0a06233}",
            "figure.dark{background:#15181d;border-color:#c0a06266}",
            "img{width:100%;display:block}",
            "figcaption{font-size:12px;color:#3a362f;padding-top:6px}",
            ".dark figcaption{color:#efe8d8}</style>",
            "<h1>HEAVEN'S MANDATE — logo candidates</h1>"]
    for title, d in sections:
        pngs = sorted(p for p in d.glob("*.png")
                      if not p.name.endswith(".darkprev.png"))
        if not pngs:
            continue
        html.append(f"<h2>{title}</h2><div class='grid'>")
        for p in pngs:
            rel = p.relative_to(OUT)
            meta = {}
            sc = p.with_suffix(".json")
            if sc.exists():
                try:
                    meta = json.loads(sc.read_text())
                except json.JSONDecodeError:
                    pass
            cap = p.stem
            if meta:
                cap += (f" — {meta.get('model', '')} {meta.get('resolution', '')}"
                        f" {meta.get('duration_s', '')}s")
            canvas = meta.get("canvas", "white")
            klass = " class='dark'" if canvas == "black" or d.name == "final" else ""
            html.append(f"<figure{klass}><a href='{rel}'><img src='{rel}'></a>"
                        f"<figcaption>{cap}</figcaption></figure>")
            if canvas == "white" and d.name not in ("final",):
                prev = _dark_preview(p, canvas)
                if prev:
                    prel = prev.relative_to(OUT)
                    html.append(f"<figure class='dark'><a href='{prel}'>"
                                f"<img src='{prel}'></a>"
                                f"<figcaption>{p.stem} — on title-screen dark"
                                f"</figcaption></figure>")
        html.append("</div>")

    dest = OUT / "index.html"
    dest.write_text("\n".join(html))
    link = f"file://{dest}"
    print(f"sheet -> {dest}")
    print(f"REVIEW: {link}")
    return link


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)

    p = sub.add_parser("gen", help="round-1 emblem candidates")
    p.add_argument("--variants", type=int, default=6)
    p.add_argument("--model", default=restyle.DEFAULT_MODEL)
    p.add_argument("--resolution", default="2K", choices=["1K", "2K", "4K"])

    p = sub.add_parser("seal", help="天命 seal-chop candidates")
    p.add_argument("--n", type=int, default=3)
    p.add_argument("--pil", action="store_true", help="PIL fallback only (no API)")
    p.add_argument("--model", default=restyle.DEFAULT_MODEL)
    p.add_argument("--resolution", default="1K", choices=["1K", "2K", "4K"])

    sub.add_parser("sheet", help="rebuild review HTML + print link")

    p = sub.add_parser("refine", help="art-direction round on one candidate")
    p.add_argument("candidate")
    p.add_argument("--instruction", required=True)
    p.add_argument("--variants", type=int, default=3)
    p.add_argument("--model", default=restyle.DEFAULT_MODEL)
    p.add_argument("--resolution", default="2K", choices=["1K", "2K", "4K"])

    p = sub.add_parser("finalize", help="alpha + install to assets/ui")
    p.add_argument("candidate")
    p.add_argument("--size", type=int, default=560)
    p.add_argument("--pad", type=int, default=12)
    p.add_argument("--threshold", type=int, default=240)
    p.add_argument("--dark-threshold", type=int, default=28)
    p.add_argument("--dark", action="store_true",
                   help="treat candidate as black-canvas regardless of sidecar")
    p.add_argument("--punch-holes", action="store_true",
                   help="also clear big enclosed background-colored pockets")
    p.add_argument("--seal", help="seal candidate to finalize alongside")
    p.add_argument("--seal-size", type=int, default=140)

    args = ap.parse_args()
    if args.command == "gen":
        cmd_gen(args.variants, args.model, args.resolution)
    elif args.command == "seal":
        cmd_seal(args.n, args.model, args.resolution, pil_only=args.pil)
    elif args.command == "sheet":
        cmd_sheet()
    elif args.command == "refine":
        cmd_refine(args.candidate, args.instruction, args.variants,
                   args.model, args.resolution)
    elif args.command == "finalize":
        cmd_finalize(args.candidate, args.size, args.pad, args.threshold,
                     args.dark_threshold, args.dark, args.punch_holes,
                     args.seal, args.seal_size)


if __name__ == "__main__":
    main()
