#!/usr/bin/env python3
"""Download real per-job character art from the Terra Battle wiki.

For every unit in docs/mapping/characters.csv (Terra Battle unit -> slug), list the
files on its wiki page and download:
  job1 full  File:<Base>.png            -> assets/terra/full/<slug>_full.png
  job1 icon  File:<Base> icon.png       -> assets/terra/tokens/<slug>_token.png
  job2 full  File:<Base> job2.png       -> assets/terra/subjobs/<slug>_job2_full.png
  job2 icon  File:<Base> job2 icon.png  -> assets/terra/subjobs/<slug>_job2_token.png
  job3 full  File:<Base> job3.png       -> assets/terra/subjobs/<slug>_job3_full.png
  job3 icon  File:<Base> job3 icon.png  -> assets/terra/subjobs/<slug>_job3_token.png

File names are matched from the page's actual image list (via the "jobN" suffix),
so pages whose art files don't literally match the page title still resolve.
Existing files are OVERWRITTEN — this replaces the tinted job2/job3 placeholders
from gen_subjob_art.py with the real redrawn art. Units without job art on the
wiki (monsters) keep whatever files they already have.

Writes tools/out/job_art_manifest.json.
Run: python3 tools/fetch_job_art.py [slug ...]
"""
import csv
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV = os.path.join(ROOT, "docs", "mapping", "characters.csv")
FULL_DIR = os.path.join(ROOT, "assets", "terra", "full")
TOKEN_DIR = os.path.join(ROOT, "assets", "terra", "tokens")
SUBJOB_DIR = os.path.join(ROOT, "assets", "terra", "subjobs")
MANIFEST = os.path.join(ROOT, "tools", "out", "job_art_manifest.json")
API = "https://terrabattle.fandom.com/api.php"
UA = "TerraBattleFanRecreation-ArtBot/1.0 (personal research)"


def api_get(params):
    params = dict(params, format="json", formatversion="2")
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.load(r)


def page_image_titles(page):
    d = api_get({"action": "query", "prop": "images", "imlimit": "200",
                 "redirects": "1", "titles": page})
    pages = d.get("query", {}).get("pages", [])
    if not pages or "missing" in pages[0]:
        return None
    return [im["title"] for im in pages[0].get("images", [])]


def pick_files(page, titles):
    """Map art slots to wiki file titles using the page's actual image list."""
    slots = {}
    for n in (2, 3):
        for t in titles:
            if re.search(r"(?i)\bjob ?%d\.png$" % n, t):
                slots["job%d_full" % n] = t
            elif re.search(r"(?i)\bjob ?%d icon\.png$" % n, t):
                slots["job%d_token" % n] = t
    # base art name: derive from the job2 file, else fall back to the page title
    if "job2_full" in slots:
        base = re.sub(r"(?i)^File:|\s*job ?2\.png$", "", slots["job2_full"]).strip()
    else:
        base = page
    for cand, slot in ((f"File:{base}.png", "job1_full"),
                       (f"File:{base} icon.png", "job1_token")):
        if cand in titles:
            slots[slot] = cand
    return slots


def image_urls(titles):
    """Batch imageinfo -> {file_title: {url, width, height}}."""
    out = {}
    titles = list(titles)
    for i in range(0, len(titles), 50):
        d = api_get({"action": "query", "prop": "imageinfo",
                     "iiprop": "url|size", "titles": "|".join(titles[i:i + 50])})
        for p in d.get("query", {}).get("pages", []):
            info = (p.get("imageinfo") or [{}])[0]
            if info.get("url"):
                out[p["title"]] = {"url": info["url"], "width": info.get("width"),
                                   "height": info.get("height")}
        time.sleep(0.2)
    return out


def download(url, dest):
    # Fandom's CDN transcodes to WebP by default; format=original forces true PNG bytes
    url += ("&" if "?" in url else "?") + "format=original"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=90) as r:
        data = r.read()
    with open(dest, "wb") as f:
        f.write(data)
    return len(data)


def dest_path(slug, slot):
    return {
        "job1_full": os.path.join(FULL_DIR, f"{slug}_full.png"),
        "job1_token": os.path.join(TOKEN_DIR, f"{slug}_token.png"),
        "job2_full": os.path.join(SUBJOB_DIR, f"{slug}_job2_full.png"),
        "job2_token": os.path.join(SUBJOB_DIR, f"{slug}_job2_token.png"),
        "job3_full": os.path.join(SUBJOB_DIR, f"{slug}_job3_full.png"),
        "job3_token": os.path.join(SUBJOB_DIR, f"{slug}_job3_token.png"),
    }[slot]


def main():
    only = set(sys.argv[1:])
    with open(CSV, newline="") as f:
        rows = [(r["Terra Battle unit"].strip(), r["Slug"].strip())
                for r in csv.DictReader(f)]
    if only:
        rows = [r for r in rows if r[1] in only]
    print(f"{len(rows)} units to fetch")

    manifest, missing_pages, no_job_art = {}, [], []
    plan = []  # (slug, slot, file_title)
    for page, slug in rows:
        titles = page_image_titles(page)
        if titles is None and " the " in page:
            # some wiki pages drop the epithet (e.g. "Nakupí the Silken-Haired" -> "Nakupí")
            page = page.split(" the ")[0]
            titles = page_image_titles(page)
        if titles is None:
            missing_pages.append(f"{slug} ({page})")
            manifest[slug] = {"page": page, "status": "page_missing"}
            continue
        slots = pick_files(page, titles)
        if "job2_full" not in slots:
            no_job_art.append(f"{slug} ({page})")
        manifest[slug] = {"page": page, "slots": dict(slots)}
        plan += [(slug, slot, t) for slot, t in slots.items()]
        time.sleep(0.2)

    urls = image_urls({t for _, _, t in plan})
    ok = failed = 0
    for slug, slot, title in plan:
        info = urls.get(title)
        rec = manifest[slug].setdefault("files", {})
        if not info:
            rec[slot] = {"title": title, "status": "no_url"}
            failed += 1
            continue
        dest = dest_path(slug, slot)
        try:
            n = download(info["url"], dest)
            rec[slot] = {"title": title, "status": "downloaded", "bytes": n,
                         "size": [info["width"], info["height"]],
                         "file": os.path.relpath(dest, ROOT)}
            ok += 1
        except Exception as e:                                    # noqa: BLE001
            rec[slot] = {"title": title, "status": "failed", "error": str(e)}
            failed += 1
        time.sleep(0.05)
        if ok and ok % 25 == 0:
            print(f"  downloaded {ok}/{len(plan)}")

    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    if os.path.exists(MANIFEST):  # merge so partial (per-slug) runs keep the record
        old = json.load(open(MANIFEST)).get("units", {})
        old.update(manifest)
        manifest = old
    with open(MANIFEST, "w") as f:
        json.dump({"downloaded": ok, "failed": failed,
                   "missing_pages": missing_pages, "no_job_art": no_job_art,
                   "units": manifest}, f, indent=2)
    print(f"downloaded {ok}, failed {failed}")
    if missing_pages:
        print("pages not found:", ", ".join(missing_pages))
    if no_job_art:
        print("no job2/3 art on wiki:", ", ".join(no_job_art))
    print(f"manifest -> {os.path.relpath(MANIFEST, ROOT)}")


if __name__ == "__main__":
    main()
