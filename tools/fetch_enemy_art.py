#!/usr/bin/env python3
"""Download enemy sprites for the full roster from the Terra Battle wiki.

For each unique enemy name in tools/out/terra_scope.json, query the MediaWiki
pageimages API for the page's lead image, then download it to
assets/terra/enemies/<slug>.png. Skips enemies we already have art for.

Writes tools/out/enemy_art_manifest.json (name -> url, file, status).
Run: python3 tools/fetch_enemy_art.py
"""
import json
import os
import re
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCOPE = os.path.join(ROOT, "tools", "out", "terra_scope.json")
ART_DIR = os.path.join(ROOT, "assets", "terra", "enemies")
MANIFEST = os.path.join(ROOT, "tools", "out", "enemy_art_manifest.json")
API = "https://terrabattle.fandom.com/api.php"
UA = "TerraBattleFanRecreation-ArtBot/1.0 (personal research)"


def slugify(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def api_get(params):
    params = dict(params, format="json", formatversion="2")
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.load(r)


def page_images(titles):
    """-> {final_title: image_url or None}. Batches of <=50."""
    out, resolve = {}, {}
    d = api_get({
        "action": "query", "prop": "pageimages", "piprop": "original",
        "pilimit": "50", "redirects": "1", "titles": "|".join(titles),
    })
    q = d.get("query", {})
    for n in q.get("normalized", []):
        resolve[n["from"]] = n["to"]
    for r in q.get("redirects", []):
        resolve[r["from"]] = r["to"]
    for p in q.get("pages", []):
        src = (p.get("original") or {}).get("source")
        out[p["title"]] = src

    def final(t):
        seen = set()
        while t in resolve and t not in seen:
            seen.add(t)
            t = resolve[t]
        return t

    return out, final


def download(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    with open(dest, "wb") as f:
        f.write(data)
    return len(data)


def main():
    os.makedirs(ART_DIR, exist_ok=True)
    roster = json.load(open(SCOPE))["enemy_roster"]
    names = [r["name"] for r in roster]
    print(f"{len(names)} unique enemies to resolve")

    # resolve image URLs in batches of 50
    url_by_name = {}
    for i in range(0, len(names), 50):
        batch = names[i:i + 50]
        imgs, final = page_images(batch)
        for nm in batch:
            url_by_name[nm] = imgs.get(final(nm))
        print(f"  resolved {min(i + 50, len(names))}/{len(names)}")
        time.sleep(0.2)

    manifest, ok, skipped, no_image, failed = {}, 0, 0, [], []
    for nm in names:
        slug = slugify(nm)
        url = url_by_name.get(nm)
        rec = {"url": url, "file": None, "status": None}
        if not url:
            rec["status"] = "no_image_on_page"
            no_image.append(nm)
            manifest[nm] = rec
            continue
        ext = os.path.splitext(urllib.parse.urlparse(url).path)[1].lower() or ".png"
        if ext not in (".png", ".jpg", ".jpeg", ".webp", ".gif"):
            ext = ".png"
        dest = os.path.join(ART_DIR, slug + ext)
        rel = os.path.relpath(dest, ROOT)
        if os.path.exists(dest):
            rec.update(status="exists", file=rel)
            skipped += 1
            manifest[nm] = rec
            continue
        try:
            n = download(url, dest)
            rec.update(status="downloaded", file=rel, bytes=n)
            ok += 1
        except Exception as e:                       # noqa: BLE001
            rec.update(status="failed", error=str(e))
            failed.append(nm)
        manifest[nm] = rec
        time.sleep(0.05)

    json.dump({
        "art_dir": os.path.relpath(ART_DIR, ROOT),
        "totals": {"roster": len(names), "downloaded": ok, "already_present": skipped,
                   "no_image_on_page": len(no_image), "failed": len(failed)},
        "no_image": no_image,
        "failed": failed,
        "enemies": manifest,
    }, open(MANIFEST, "w"), indent=1)

    print(f"\n=== ART FETCH ===")
    print(f"  downloaded         {ok}")
    print(f"  already present    {skipped}")
    print(f"  no image on page   {len(no_image)}")
    print(f"  failed             {len(failed)}")
    print(f"  -> {os.path.relpath(ART_DIR, ROOT)}/  (manifest: {os.path.relpath(MANIFEST, ROOT)})")
    if no_image:
        print(f"\n  no-image examples: {no_image[:12]}")


if __name__ == "__main__":
    main()
