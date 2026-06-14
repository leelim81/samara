#!/usr/bin/env python3
"""Join enemy stats + skill defs onto the 42-chapter scope.

Inputs (downloaded by curl into tools/out/_cache/):
  enemy_data.lua   = Module:Enemy/Data  (1749 enemies, keyed CH<chap>_<code>)
  skills_data.lua  = Module:Skills/Data (skills by integer id)
  tools/out/terra_scope.json = chapter/stage/battle layout (scope_chapters.py)

Output:
  tools/out/terra_dataset.json   full join: chapters->stages->battles->enemy refs,
                                  a main-story bestiary (stats + resolved skills),
                                  recovered rosters for the 5 stub chapters.
  docs/gameplay/scope-42-chapters.md  (re-written with a stats/skills section)

Run: python3 tools/build_dataset.py   (after scope_chapters.py)
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, "tools", "out", "_cache")
SCOPE = os.path.join(ROOT, "tools", "out", "terra_scope.json")
OUT = os.path.join(ROOT, "tools", "out", "terra_dataset.json")
OUT_MD = os.path.join(ROOT, "docs", "gameplay", "scope-42-chapters.md")

STR = r'"((?:[^"\\]|\\.)*)"'


# ---------------------------------------------------------------- Lua parsing
def balanced(text, i):
    """text[i] is '{'. Return inner text up to the matching '}'."""
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i + 1:j]
    return text[i + 1:]


def sfield(body, name):
    m = re.search(r"\b" + name + r"\s*=\s*" + STR, body)
    return m.group(1) if m else None


def ifield(body, name):
    m = re.search(r"\b" + name + r"\s*=\s*(-?\d+)", body)
    return int(m.group(1)) if m else None


def droplist(body, field):
    m = re.search(field + r"\s*=\s*\{", body)
    if not m:
        return []
    inner = balanced(body, m.end() - 1)
    return [{"name": n, "ratio": int(r)} for n, r in
            re.findall(r"name\s*=\s*" + STR + r"\s*,\s*ratio\s*=\s*(-?\d+)", inner)]


def singledrop(body, field):
    m = re.search(field + r"\s*=\s*\{([^}]*)\}", body)
    if not m:
        return None
    mn = re.search(r"name\s*=\s*" + STR, m.group(1))
    mr = re.search(r"ratio\s*=\s*(-?\d+)", m.group(1))
    return {"name": mn.group(1) if mn else None,
            "ratio": int(mr.group(1)) if mr else None}


def parse_enemies(text):
    out = {}
    for m in re.finditer(r'^\t\["([^"]+)"\]\s*=\s*\{', text, re.M):
        key = m.group(1)
        body = balanced(text, m.end() - 1)
        cm = re.match(r"CH(\d+)_", key)
        av = {}
        ma = re.search(r"avoids\s*=\s*\{([^}]*)\}", body, re.S)
        if ma:
            av = {k: int(v) for k, v in re.findall(r"(\w+)\s*=\s*(-?\d+)", ma.group(1))}
        msk = re.search(r"skills\s*=\s*\{([^}]*)\}", body)
        skills = [int(x) for x in re.findall(r"\d+", msk.group(1))] if msk else []
        out[key] = {
            "key": key,
            "chapter": int(cm.group(1)) if cm else None,
            "name": sfield(body, "name"),
            "enemy_type": sfield(body, "enemy_type"),
            "species": sfield(body, "species"),
            "weapon": sfield(body, "weapon"),
            "attribute": sfield(body, "attribute") or None,
            "level": ifield(body, "level"),
            "hp": ifield(body, "hp"), "atk": ifield(body, "atk"),
            "def": ifield(body, "def"), "matk": ifield(body, "matk"),
            "mdef": ifield(body, "mdef"), "move": ifield(body, "move"),
            "exp": ifield(body, "exp"), "coin": ifield(body, "coin"),
            "skill_ids": skills,
            "avoids": av,
            "item_drops": droplist(body, "item_drops"),
            "job_drop": singledrop(body, "job_drop"),
            "buddy_drop": singledrop(body, "buddy_drop"),
        }
    return out


def parse_skills(text):
    out = {}
    for m in re.finditer(r"^\t\[(\d+)\]\s*=\s*\{", text, re.M):
        sid = int(m.group(1))
        body = balanced(text, m.end() - 1)
        out[sid] = {
            "name": sfield(body, "name"),
            "range": sfield(body, "range"),
            "target": sfield(body, "target") or None,
            "condition": sfield(body, "condition"),
            "emitratio": ifield(body, "emitratio"),
            "effect": sfield(body, "effect"),
            "descr": sfield(body, "descr"),
            "blowoff": ifield(body, "blowoff"),
        }
    return out


# ---------------------------------------------------------------- matching
ROMAN = {"Ⅰ": "I", "Ⅱ": "II", "Ⅲ": "III", "Ⅳ": "IV", "Ⅴ": "V",
         "Ⅵ": "VI", "Ⅶ": "VII", "Ⅷ": "VIII", "Ⅸ": "IX", "Ⅹ": "X"}


def norm(s):
    if not s:
        return ""
    for u, a in ROMAN.items():
        s = s.replace(u, a)
    s = re.sub(r"\s*\(.*?\)", "", s)            # drop "(Boss)"/"(Enemy)"
    return re.sub(r"\s+", "", s).lower()        # collapse spaces, lowercase


def build_index(enemies):
    by_name, by_norm = {}, {}
    for e in enemies.values():
        by_name.setdefault(e["name"], []).append(e)
        by_norm.setdefault(norm(e["name"]), []).append(e)
    return by_name, by_norm


def match(idx, chapter, name, level):
    by_name, by_norm = idx
    cands = by_name.get(name)
    if not cands:
        cands = by_name.get(re.sub(r"\s*\(.*?\)", "", name).strip())
    if not cands:                               # spacing / unicode-roman fallback
        cands = by_norm.get(norm(name))
    if not cands:
        return None, "none"
    for e in cands:                                  # exact chapter + level
        if e["chapter"] == chapter and e["level"] == level:
            return e, "exact"
    same = [e for e in cands if e["chapter"] == chapter]
    if same:                                         # same chapter, near level
        return min(same, key=lambda e: abs((e["level"] or 0) - level)), "chapter"
    for e in cands:                                  # any chapter, exact level
        if e["level"] == level:
            return e, "level"
    return min(cands, key=lambda e: abs((e["level"] or 0) - level)), "nearest"


# ---------------------------------------------------------------- main
def main():
    enemies = parse_enemies(open(os.path.join(CACHE, "enemy_data.lua")).read())
    skills = parse_skills(open(os.path.join(CACHE, "skills_data.lua")).read())
    scope = json.load(open(SCOPE))
    idx = build_index(enemies)
    print(f"parsed {len(enemies)} enemy entries, {len(skills)} skills")

    quality = {"exact": 0, "chapter": 0, "level": 0, "nearest": 0, "none": 0}
    unmatched_names = {}
    used_keys = set()
    used_skill_ids = set()

    for c in scope["chapters"]:
        for s in c.get("stages", []):
            for e in s["enemies"]:
                ent, q = match(idx, c["num"], e["name"], e["level"])
                quality[q] += 1
                if ent:
                    e["enemy_key"] = ent["key"]
                    e["match"] = q
                    used_keys.add(ent["key"])
                    used_skill_ids.update(ent["skill_ids"])
                else:
                    e["enemy_key"] = None
                    e["match"] = q
                    unmatched_names[e["name"]] = unmatched_names.get(e["name"], 0) + 1
            # annotate per-battle groups with the same stat keys
            for btl in s.get("battles_detail", []):
                for e in btl["enemies"]:
                    ent, _ = match(idx, c["num"], e["name"], e["level"])
                    e["enemy_key"] = ent["key"] if ent else None

    # recover stub-chapter rosters from chapter-prefixed keys
    stub = scope["totals"]["chapters_metadata_only"]
    recovered = {}
    for c in scope["chapters"]:
        if c["num"] in stub:
            keys = sorted(k for k, e in enemies.items() if e["chapter"] == c["num"])
            c["recovered_enemy_keys"] = keys
            recovered[c["num"]] = keys
            used_keys.update(keys)
            for k in keys:
                used_skill_ids.update(enemies[k]["skill_ids"])

    # main-story bestiary = every CH1..42 entry + anything referenced
    bestiary = {}
    for k, e in enemies.items():
        if (e["chapter"] and 1 <= e["chapter"] <= 42) or k in used_keys:
            entry = dict(e)
            entry["skills"] = [dict(id=sid, **(skills.get(sid) or {"name": "?"}))
                               for sid in e["skill_ids"]]
            bestiary[k] = entry
            used_skill_ids.update(e["skill_ids"])

    skills_table = {str(sid): skills[sid] for sid in sorted(used_skill_ids) if sid in skills}

    occ = sum(quality.values())
    matched = occ - quality["none"]
    dataset = {
        "generated_from": "terrabattle.fandom.com (Module:Enemy/Data + Module:Skills/Data + chapter pages)",
        "totals": dict(scope["totals"], **{
            "enemy_stat_entries_total": len(enemies),
            "bestiary_main_story": len(bestiary),
            "skills_referenced": len(skills_table),
            "battle_enemy_occurrences": occ,
            "occurrences_matched_to_stats": matched,
            "match_quality": quality,
            "recovered_stub_enemies": sum(len(v) for v in recovered.values()),
            "unmatched_enemy_names": len(unmatched_names),
        }),
        "chapters": scope["chapters"],
        "bestiary": bestiary,
        "skills": skills_table,
        "unmatched_enemy_names": unmatched_names,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(dataset, open(OUT, "w"), indent=1)

    append_md(dataset)
    print(f"\nwrote {OUT}  ({os.path.getsize(OUT)//1024} KB)")
    t = dataset["totals"]
    print("\n=== JOIN RESULTS ===")
    print(f"  battle enemy occurrences      {occ}")
    print(f"  matched to a stat block       {matched}  ({100*matched//occ}%)")
    print(f"  match quality                 {quality}")
    print(f"  main-story bestiary           {t['bestiary_main_story']} enemies")
    print(f"  skills referenced             {t['skills_referenced']}")
    print(f"  recovered stub enemies        {t['recovered_stub_enemies']}")
    if unmatched_names:
        top = sorted(unmatched_names.items(), key=lambda x: -x[1])[:15]
        print(f"  unmatched names ({len(unmatched_names)}): {top}")


def append_md(d):
    t = d["totals"]
    md = open(OUT_MD).read()
    marker = "\n## Stats & skills join\n"
    md = md.split(marker)[0].rstrip() + "\n"
    L = [marker.strip(), ""]
    L.append("Enemy stats joined from `Module:Enemy/Data`, skills from `Module:Skills/Data` "
             "(via `tools/build_dataset.py` → `tools/out/terra_dataset.json`).\n")
    q = t["match_quality"]
    L.append(f"- **Battle enemy occurrences:** {t['battle_enemy_occurrences']}")
    L.append(f"- **Matched to a full stat block:** {t['occurrences_matched_to_stats']} "
             f"({100 * t['occurrences_matched_to_stats'] // t['battle_enemy_occurrences']}%) "
             f"— exact {q['exact']}, same-chapter {q['chapter']}, level {q['level']}, "
             f"nearest {q['nearest']}, none {q['none']}")
    L.append(f"- **Main-story bestiary:** {t['bestiary_main_story']} enemies with "
             "HP/ATK/DEF/MATK/MDEF, move, exp, coin, resolved skills, ailment resists, drops")
    L.append(f"- **Skills resolved:** {t['skills_referenced']} unique")
    L.append(f"- **Recovered from the 5 stub chapters:** {t['recovered_stub_enemies']} "
             "enemy stat blocks (full stats; per-battle placement still unknown)")
    if t["unmatched_enemy_names"]:
        L.append(f"- **Names with no stat match:** {t['unmatched_enemy_names']} "
                 "(see `unmatched_enemy_names` in the JSON)")
    L.append("")
    open(OUT_MD, "w").write(md + "\n".join(L))


if __name__ == "__main__":
    main()
