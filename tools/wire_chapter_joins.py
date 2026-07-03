#!/usr/bin/env python3
"""Wire the Outer Heaven recruitment drip into chapter data.

Stamps `unlocked_job_paths` into each chapter_data/terra/*.tres so that
clearing chapter N grants that chapter's joining hero (see the Recruitment
grants table in docs/outer_heaven_bible.md). SaveData._grant_chapter_jobs
performs the grant idempotently at runtime.

Re-runnable: chapters not in GRANTS get the property removed if present.
Run: python3 tools/wire_chapter_joins.py
Then: godot --headless --import
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# chapter number (1-42, story order) -> joining hero's job slug.
# Starters (bahl, grace, kuscah) live in save_data/default_save_data.tres.
GRANTS = {
    2: "shberdan", 3: "daiana", 4: "bagunar", 5: "macuri", 6: "kem",
    8: "zan", 9: "korin", 10: "samupi", 11: "eileen", 15: "burbaba",
    16: "maralme", 17: "nakupi", 18: "harold", 20: "sorman", 21: "gigojago",
    23: "manmer", 25: "unasag", 29: "raprow", 30: "iskar", 31: "lan",
    32: "amazora", 34: "zenzoze",
}


def ordered_slugs():
    lst = open(os.path.join(ROOT, "chapter_data", "main_story_chapter_list.tres")).read()
    return re.findall(r"chapter_data/terra/([a-z0-9_]+)\.tres", lst)


def main():
    slugs = ordered_slugs()
    assert len(slugs) == 42, "expected 42 chapters, got %d" % len(slugs)

    granted_slugs = set(GRANTS.values())
    job_dir = os.path.join(ROOT, "jobs", "terra")
    for s in granted_slugs:
        assert os.path.exists(os.path.join(job_dir, s + "_job.tres")), "missing job: " + s

    stamped = cleared = 0
    for num, slug in enumerate(slugs, 1):
        path = os.path.join(ROOT, "chapter_data", "terra", slug + ".tres")
        txt = open(path).read()
        txt = re.sub(r'\nunlocked_job_paths = \[[^\]]*\]', "", txt)

        if num in GRANTS:
            line = '\nunlocked_job_paths = [ "res://jobs/terra/%s_job.tres" ]' % GRANTS[num]
            assert 'battle_scene_path = "' in txt, "no battle_scene_path in " + slug
            txt = re.sub(r'(battle_scene_path = "[^"]*")', lambda m: m.group(1) + line, txt, count=1)
            stamped += 1
        else:
            cleared += 1

        open(path, "w").write(txt)

    print("join grants stamped: %d, chapters without grants: %d" % (stamped, cleared))
    for num in sorted(GRANTS):
        print("  ch.%02d (%s) -> %s" % (num, slugs[num - 1], GRANTS[num]))


if __name__ == "__main__":
    main()
