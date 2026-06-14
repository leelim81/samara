#!/usr/bin/env python3
"""Scope all 42 Terra Battle main-story chapters from the Fandom wiki API.

The wiki HTML is 403-blocked, but the MediaWiki API (api.php) is reachable.
This pulls the chapter list + every chapter page's stage/battle/enemy layout,
aggregates a unique-enemy roster, cross-references local art, and writes:

  tools/out/terra_scope.json          machine-readable manifest (for the generator)
  docs/gameplay/scope-42-chapters.md  human-readable summary

Run: python3 tools/scope_chapters.py
"""
import json
import os
import re
import urllib.parse
import urllib.request

API = "https://terrabattle.fandom.com/api.php"
UA = "TerraBattleFanRecreation-ScopeBot/1.0 (personal research; contact leelim)"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_JSON = os.path.join(ROOT, "tools", "out", "terra_scope.json")
OUT_MD = os.path.join(ROOT, "docs", "gameplay", "scope-42-chapters.md")
ART_DIRS = [os.path.join(ROOT, "assets", "terra")]


# ---------------------------------------------------------------- API helpers
def api_get(params):
    params = dict(params, format="json", formatversion="2")
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.load(r)


def wikitext_single(page):
    return api_get({"action": "parse", "page": page, "prop": "wikitext"})["parse"]["wikitext"]


def wikitext_batch(titles):
    """Fetch up to 50 pages' wikitext in one query call. -> {final_title: content}."""
    d = api_get({
        "action": "query", "prop": "revisions", "rvprop": "content",
        "rvslots": "main", "redirects": "1", "titles": "|".join(titles),
    })
    q = d["query"]
    resolve = {}
    for n in q.get("normalized", []):
        resolve[n["from"]] = n["to"]
    for r in q.get("redirects", []):
        resolve[r["from"]] = r["to"]
    content = {}
    for p in q.get("pages", []):
        if p.get("revisions"):
            content[p["title"]] = p["revisions"][0]["slots"]["main"]["content"]
        else:
            content[p["title"]] = None

    def final_title(t):
        seen = set()
        while t in resolve and t not in seen:
            seen.add(t)
            t = resolve[t]
        return t

    return content, final_title


# ---------------------------------------------------------------- parsing
CHAP_RE = re.compile(r"Chapter\s+(\d+):\s*\[\[([^\]]+)\]\]")
STAGE_HDR = re.compile(r"==\s*(\d+[.\-]\d+\w*)\s*==")
DUNGEON_RE = re.compile(r"\{\{DungeonInfo(.*?)\}\}", re.S)
LV_RE = re.compile(r"\b[Ll][Vv]?\.?\s*(\d+)")          # matches "LV 50", "Lv.49", "L50"
CT_RE = re.compile(r"[xX×]\s*(\d+)\b")
NAME_RE = re.compile(r"\[\[([^\]|#]+)(?:[#|][^\]]+)?\]\]")
BATTLE_HDR_RE = re.compile(r"'''\s*Battle\s*\d+\s*'''")
BOSS_RE = re.compile(r"Bosses#|\{\{\s*Boss|\|\s*Boss\s*\]\]|\(\s*Boss\s*\)", re.I)


def parse_chapter_list(wt):
    chapters = []
    for m in CHAP_RE.finditer(wt):
        link = m.group(2)
        target, _, display = link.partition("|")
        chapters.append({
            "num": int(m.group(1)),
            "name": (display or target).strip(),
            "page": target.strip(),
        })
    return chapters


def parse_kv(block):
    kv = {}
    for part in block.split("|"):
        if "=" in part:
            k, v = part.split("=", 1)
            kv[k.strip()] = v.strip()
    return kv


def parse_enemy_line(line):
    if "[[" not in line:
        return None
    mlv = LV_RE.search(line)
    if not mlv:               # real enemy lines always carry a level
        return None
    mname = NAME_RE.search(line)
    if not mname:
        return None
    mct = CT_RE.search(line)
    return {
        "name": mname.group(1).strip(),
        "level": int(mlv.group(1)),
        "count": int(mct.group(1)) if mct else 1,
        "boss": bool(BOSS_RE.search(line)),
    }


def nearest_stage_label(wt, pos, fallback):
    """Last '== X.Y ==' header appearing before pos, else fallback."""
    label = None
    for m in STAGE_HDR.finditer(wt, 0, pos):
        label = m.group(1)
    return label or fallback


def parse_chapter(num, wt):
    """Split by DungeonInfo blocks (one per stage); robust to single-stage
    chapters and non-numeric headers. -> (stage dicts, warnings)."""
    stages, warnings = [], []
    dis = list(DUNGEON_RE.finditer(wt))
    if not dis:
        warnings.append("no DungeonInfo blocks found")
        return stages, warnings
    for i, di in enumerate(dis):
        info = parse_kv(di.group(1))
        body = wt[di.end():(dis[i + 1].start() if i + 1 < len(dis) else len(wt))]
        # collect enemies, grouped per "'''Battle N'''" header
        enemies = []
        battles_detail = []
        cur = {"n": 1, "enemies": []}
        for raw in body.splitlines():
            ls = raw.strip()
            bh = re.match(r"\**\s*'''\s*Battle\s*(\d+)", ls)
            if bh:
                if cur["enemies"]:
                    battles_detail.append(cur)
                cur = {"n": int(bh.group(1)), "enemies": []}
                continue
            if ls.startswith("*"):
                e = parse_enemy_line(ls)
                if e:
                    enemies.append(e)
                    cur["enemies"].append(e)
        if cur["enemies"]:
            battles_detail.append(cur)
        battle = info.get("battle", "")
        battle = int(battle) if battle.isdigit() else len(BATTLE_HDR_RE.findall(body)) or None

        def num_field(k):
            v = info.get(k, "")
            return int(v) if v.isdigit() else None
        stages.append({
            "id": nearest_stage_label(wt, di.start(), "%d.%d" % (num, i + 1)),
            "stam": num_field("stam"),
            "rec_level": num_field("level"),
            "coin": num_field("coin"),
            "xp": num_field("xp"),
            "battles": battle,
            "enemy_stacks": len(enemies),
            "enemies": enemies,
            "battles_detail": battles_detail,
        })
    return stages, warnings


# ---------------------------------------------------------------- local art
def slugify(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def local_art_tokens():
    tokens = set()
    strip = ("enemy-", "token-", "full-")
    for d in ART_DIRS:
        for dirpath, _, files in os.walk(d):
            for f in files:
                if not f.lower().endswith((".png", ".jpg", ".webp")):
                    continue
                base = os.path.splitext(f)[0].lower()
                for p in strip:
                    if base.startswith(p):
                        base = base[len(p):]
                base = re.sub(r"-(job\d|boss|enemy|token|full|icon)$", "", base)
                for tok in re.split(r"[^a-z0-9]+", base):
                    if len(tok) >= 4:
                        tokens.add(tok)
    return tokens


def have_art(name, tokens):
    # Match on the base name (drop "(Boss)"/"(Enemy)" qualifiers); exact only,
    # so variants like "Phi Orbling" don't falsely match the base Orbling sprite.
    base = slugify(re.sub(r"\(.*?\)", "", name))
    return base in tokens


# ---------------------------------------------------------------- main
def main():
    print("Fetching chapter list ...")
    chapters = parse_chapter_list(wikitext_single("Chapters"))
    print(f"  found {len(chapters)} chapters")

    print("Batch-fetching all chapter pages ...")
    content, final_title = wikitext_batch([c["page"] for c in chapters])

    roster = {}          # name -> aggregate
    art_tokens = local_art_tokens()
    total_stages = total_battles = 0

    for c in chapters:
        wt = content.get(final_title(c["page"]))
        if wt is None:
            c["warnings"] = ["page content not returned"]
            c["stages"] = []
            continue
        stages, warnings = parse_chapter(c["num"], wt)
        c["stages"] = stages
        c["warnings"] = warnings
        c["stage_count"] = len(stages)
        c["battle_count"] = sum(s["battles"] or 0 for s in stages)
        total_stages += c["stage_count"]
        total_battles += c["battle_count"]
        for s in stages:
            for e in s["enemies"]:
                r = roster.setdefault(e["name"], {
                    "name": e["name"], "slug": slugify(e["name"]),
                    "chapters": set(), "min_level": e["level"], "max_level": e["level"],
                    "appearances": 0, "total_units": 0, "is_boss": False,
                })
                r["chapters"].add(c["num"])
                r["min_level"] = min(r["min_level"], e["level"])
                r["max_level"] = max(r["max_level"], e["level"])
                r["appearances"] += 1
                r["total_units"] += e["count"]
                r["is_boss"] = r["is_boss"] or e["boss"]

    enemy_roster = []
    for r in sorted(roster.values(), key=lambda x: (min(x["chapters"]), x["name"])):
        r["chapters"] = sorted(r["chapters"])
        r["have_art"] = have_art(r["name"], art_tokens)
        enemy_roster.append(r)
    art_needed = [r["name"] for r in enemy_roster if not r["have_art"]]
    metadata_only = [c["num"] for c in chapters
                     if sum(s["enemy_stacks"] for s in c.get("stages", [])) == 0]

    manifest = {
        "generated_from": "terrabattle.fandom.com MediaWiki API (action=parse / query)",
        "totals": {
            "chapters": len(chapters),
            "stages": total_stages,
            "battles": total_battles,
            "unique_enemies": len(enemy_roster),
            "bosses": sum(1 for r in enemy_roster if r["is_boss"]),
            "enemies_with_local_art": len(enemy_roster) - len(art_needed),
            "enemies_needing_art": len(art_needed),
            "chapters_with_full_enemy_detail": len(chapters) - len(metadata_only),
            "chapters_metadata_only": metadata_only,
        },
        "chapters": chapters,
        "enemy_roster": enemy_roster,
        "art_needed": art_needed,
    }

    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w") as f:
        json.dump(manifest, f, indent=2)
    write_markdown(manifest)
    print(f"\nWrote {OUT_JSON}")
    print(f"Wrote {OUT_MD}")
    t = manifest["totals"]
    print(f"\n=== TOTALS ===")
    for k, v in t.items():
        print(f"  {k:38s} {v}")
    warned = [c["num"] for c in chapters if c.get("warnings")]
    if warned:
        print(f"\n  chapters with parse warnings: {warned}")


def write_markdown(m):
    t = m["totals"]
    L = []
    L.append("# Terra Battle — Full 42-Chapter Scope\n")
    L.append("Auto-generated by `tools/scope_chapters.py` from the Terra Battle wiki API. "
             "Counts are parsed from each chapter's `{{DungeonInfo}}` + battle lists; "
             "art coverage is a filename heuristic (verify before trusting).\n")
    L.append("## Totals\n")
    L.append(f"- **Chapters:** {t['chapters']}")
    L.append(f"- **Stages:** {t['stages']}")
    L.append(f"- **Battles (floors):** {t['battles']}")
    L.append(f"- **Unique enemies:** {t['unique_enemies']} (of which **{t['bosses']}** bosses)")
    L.append(f"- **Enemies needing art:** {t['enemies_needing_art']} "
             f"(already have {t['enemies_with_local_art']})")
    L.append(f"- **Chapters with full enemy detail:** {t['chapters_with_full_enemy_detail']}/42 — "
             f"chapters {t['chapters_metadata_only']} have stage/battle metadata only "
             f"(wiki stubs; enemy rosters not filled in, recoverable from `Module:Enemy/Data`)\n")
    L.append("## Per-chapter\n")
    L.append("| Ch | Name | Stages | Battles | Stamina | Rec. level | Coins |")
    L.append("|---:|------|-------:|--------:|:-------:|:----------:|------:|")
    for c in m["chapters"]:
        stages = c.get("stages", [])
        stams = [s["stam"] for s in stages if s["stam"]]
        recs = [s["rec_level"] for s in stages if s["rec_level"]]
        coins = sum(s["coin"] or 0 for s in stages)

        def rng(xs):
            return f"{min(xs)}–{max(xs)}" if xs and min(xs) != max(xs) else (str(xs[0]) if xs else "?")
        warn = " ⚠️" if c.get("warnings") else ""
        L.append(f"| {c['num']} | {c['name']}{warn} | {c.get('stage_count', 0)} | "
                 f"{c.get('battle_count', 0)} | {rng(stams)} | {rng(recs)} | {coins or '?'} |")
    L.append("\n## Enemy roster\n")
    L.append(f"{t['unique_enemies']} unique enemies across all chapters. "
             "`art?` = filename heuristic for whether we already have a sprite.\n")
    L.append("| Enemy | Chapters | Lv range | Appears | Units | art? |")
    L.append("|-------|----------|:--------:|--------:|------:|:----:|")
    for r in m["enemy_roster"]:
        chs = ",".join(str(x) for x in r["chapters"])
        if len(chs) > 28:
            chs = chs[:25] + "…"
        lv = f"{r['min_level']}–{r['max_level']}" if r["min_level"] != r["max_level"] else str(r["min_level"])
        L.append(f"| {r['name']} | {chs} | {lv} | {r['appearances']} | {r['total_units']} | "
                 f"{'✅' if r['have_art'] else '—'} |")
    L.append("\n## Art still needed (heuristic)\n")
    L.append(", ".join(m["art_needed"]) or "_none_")
    L.append("")
    with open(OUT_MD, "w") as f:
        f.write("\n".join(L))


if __name__ == "__main__":
    main()
