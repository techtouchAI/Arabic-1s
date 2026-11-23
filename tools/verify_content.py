#!/usr/bin/env python3
"""Strict integrity & accuracy audit for generated Arabic 1st Intermediate content.

Exits non-zero if:
- Part 1 does not have all 10 official units or Part 2 does not have all 9 units,
- Any unit lacks reading, grammar, grammar summary/taqwim, evaluative text, or
  its expected 3rd lesson (orthography / expression),
- Any text contains U+FFFD, unexpanded U+0750..U+0759 placeholders, or garbled
  'اهلل' / 'هللا' sequences,
- Any question lacks prompt/options/answer/support,
- Any SVG illustration or branding icon is missing or malformed,
- Any official Word exam template fails degree total (80 = 30 + 35 + 15) or has
  unbalanced underline markers '_'.
"""

from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from curriculum_data import UNIT_SPECS  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "assets" / "content"

errors: list[str] = []
checks = 0


def expect(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if not condition:
        errors.append(message)


def load_json(name: str) -> dict:
    path = CONTENT / name
    expect(path.exists(), f"missing JSON asset: {path}")
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def check_clean_arabic(text: str, ctx: str) -> None:
    expect("\ufffd" not in text, f"[{ctx}] replacement character U+FFFD found")
    expect(
        not any(chr(c) in text for c in range(0x0750, 0x0760)),
        f"[{ctx}] unexpanded ligature placeholder found",
    )
    expect(
        not re.search(r"اهلل|هللا", text),
        f"[{ctx}] garbled Allah glyph sequence found",
    )


def main() -> int:
    curriculum = load_json("curriculum.json")
    lessons = load_json("lessons.json")
    glossary = load_json("glossary.json")
    exam_bank = load_json("exam_bank.json")

    units = curriculum["units"]
    unit_map = {u["id"]: u for u in units}
    expect(len(unit_map) == len(units), "duplicate unit ids in curriculum.json")

    p1_units = [u for u in units if u.get("sectionId") == "part1"]
    p2_units = [u for u in units if u.get("sectionId") == "part2"]
    expect(len(p1_units) == 10, f"expected 10 Part 1 units, found {len(p1_units)}")
    expect(len(p2_units) == 9, f"expected 9 Part 2 units, found {len(p2_units)}")
    expect("intro" in unit_map, "missing intro unit")
    expect("orthography-expression" in unit_map, "missing orthography-expression unit")

    # 1. Verify every official unit matches UNIT_SPECS structure & categories
    for spec in UNIT_SPECS:
        uid = spec["id"]
        expect(uid in unit_map, f"missing unit {uid}")
        if uid not in unit_map:
            continue
        u = unit_map[uid]
        expect(u["title"] == spec["title"], f"[{uid}] title mismatch")
        expect(u["part"] == spec["part"], f"[{uid}] part mismatch")
        categories = {t["category"] for t in u["topics"]}
        expect("reading" in categories, f"[{uid}] missing reading lesson")
        expect("grammar" in categories, f"[{uid}] missing grammar lesson")
        expect("evaluative" in categories, f"[{uid}] missing evaluative text")
        if spec["thirdLessonKind"] is not None:
            expect(
                spec["thirdLessonKind"] in categories,
                f"[{uid}] missing third lesson ({spec['thirdLessonKind']})",
            )
        has_taqwim = any(bool(t.get("taqwim")) for t in u["topics"])
        expect(has_taqwim, f"[{uid}] missing structured تقويم اللسان")

    # 2. Check all topics, bullets, questions across all units
    total_questions = 0
    for u in units:
        uid = u["id"]
        expect(bool(u["topics"]), f"[{uid}] unit has no topics")
        check_clean_arabic(u.get("unitText", ""), f"{uid}/unitText")
        t_ids = [t["id"] for t in u["topics"]]
        expect(len(set(t_ids)) == len(t_ids), f"[{uid}] duplicate topic ids")
        for t in u["topics"]:
            tid = f"{uid}/{t['id']}"
            expect(bool(t["title"].strip()), f"[{tid}] empty topic title")
            expect(bool(t["bullets"]), f"[{tid}] topic has no bullets")
            check_clean_arabic(t["title"], f"{tid}/title")
            for b in t["bullets"]:
                expect(bool(b.strip()), f"[{tid}] empty bullet")
                check_clean_arabic(b, f"{tid}/bullet")
            for li in t.get("listItems", []):
                check_clean_arabic(li, f"{tid}/listItem")

        q_ids = [q["id"] for q in u["questions"]]
        expect(len(set(q_ids)) == len(q_ids), f"[{uid}] duplicate question ids")
        total_questions += len(u["questions"])
        for q in u["questions"]:
            qid = f"{uid}/{q['id']}"
            expect(bool(q["prompt"].strip()), f"[{qid}] empty prompt")
            check_clean_arabic(q["prompt"], qid)
            if q["kind"] == "trueFalse":
                expect(isinstance(q.get("answer"), bool), f"[{qid}] bad trueFalse answer")
                expect(bool(q.get("answerSupport", "").strip()), f"[{qid}] missing trueFalse support")
            elif q["kind"] == "choice":
                opts = q.get("options", [])
                idx = q.get("answerIndex")
                expect(len(opts) >= 3, f"[{qid}] too few options")
                expect(idx is not None and 0 <= idx < len(opts), f"[{qid}] bad answerIndex")
                expect(bool(q.get("answerSupport", "").strip()), f"[{qid}] missing choice support")
            elif q["kind"] == "open":
                expect(bool(q.get("answer", "").strip()), f"[{qid}] empty open answer")

    expect(total_questions == 114, f"expected 114 unit questions, found {total_questions}")

    # 3. Verify 19 Grammar & Taqwim reference lessons
    expect(len(lessons["lessons"]) == 19, f"expected 19 grammar lessons, found {len(lessons['lessons'])}")
    expect(
        len([l for l in lessons["lessons"] if l["part"] == "part1"]) == 10,
        "expected 10 Part 1 grammar lessons",
    )
    expect(
        len([l for l in lessons["lessons"] if l["part"] == "part2"]) == 9,
        "expected 9 Part 2 grammar lessons",
    )
    for lsn in lessons["lessons"]:
        expect(lsn["unitId"] in unit_map, f"[{lsn['id']}] unknown unitId {lsn['unitId']}")
        expect(len(lsn["plans"]) == 1 and bool(lsn["plans"][0]["body"]), f"[{lsn['id']}] empty lesson plan")

    # 4. Verify glossary
    expect(len(glossary["terms"]) >= 50, f"glossary too small: {len(glossary['terms'])}")
    for term in glossary["terms"]:
        expect(term["part"] in ("part1", "part2"), f"[{term['id']}] invalid part")
        expect(term["unitId"] in unit_map, f"[{term['id']}] unknown unitId")
        check_clean_arabic(term["term"] + " " + term["definition"], term["id"])

    # 5. Verify SVG illustrations & icons exist and are well-formed XML
    figures = [fig for u in units for fig in u.get("figures", [])]
    figures += [fig for lsn in lessons["lessons"] for fig in lsn.get("figures", [])]
    seen_svg: set[str] = set()
    for fig in figures:
        svg_path = ROOT / fig["asset"]
        expect(svg_path.exists(), f"missing SVG asset: {fig['asset']}")
        if svg_path.exists() and fig["asset"] not in seen_svg:
            seen_svg.add(fig["asset"])
            root_el = ET.fromstring(svg_path.read_text(encoding="utf-8"))
            expect(root_el.tag.endswith("svg"), f"invalid SVG root in {fig['asset']}")
            # Ensure zero <text> nodes so flutter_svg renders identically everywhere
            text_nodes = [el for el in root_el.iter() if el.tag.endswith("text")]
            expect(not text_nodes, f"{fig['asset']} must not contain <text> elements")
    expect(len(seen_svg) >= 14, f"expected >= 14 distinct SVG assets, found {len(seen_svg)}")

    expect((ROOT / "assets/branding/app_icon.png").exists(), "missing app_icon.png")
    expect((ROOT / "windows/runner/resources/app_icon.ico").exists(), "missing app_icon.ico")

    # 6. Verify Exam Bank & all 4 official Word exam templates
    expect(len(exam_bank["compositionTopics"]) >= 12, "expected >= 12 composition topics")
    expect(len(exam_bank["grammarItems"]) >= 55, "expected >= 55 grammar bank items")
    expect(len(exam_bank["orthographyItems"]) >= 10, "expected >= 10 orthography bank items")
    expect(len(exam_bank["officialTemplates"]) == 4, "expected all 4 official Word exam templates")

    for gi in exam_bank["grammarItems"]:
        expect(gi["text"].count("_") % 2 == 0, f"[{gi['id']}] unbalanced '_' underline marker")

    for tpl in exam_bank["officialTemplates"]:
        tid = tpl["id"]
        c_deg = tpl["composition"]["degree"]
        g_deg = tpl["grammar"]["degree"]
        o_deg = tpl["orthography"]["degree"]
        expect(c_deg == 30 and g_deg == 35 and o_deg == 15, f"[{tid}] official section degrees must be 30/35/15")
        g_sum = sum(
            br["degree"]
            for q in tpl["grammar"]["questions"]
            for br in q["branches"]
        )
        o_sum = sum(
            br["degree"]
            for q in tpl["orthography"]["questions"]
            for br in q["branches"]
        )
        expect(g_sum == g_deg, f"[{tid}] grammar branch sum {g_sum} != {g_deg}")
        expect(o_sum == o_deg, f"[{tid}] orthography branch sum {o_sum} != {o_deg}")
        for sec_key in ("grammar", "orthography"):
            for q in tpl[sec_key]["questions"]:
                for br in q["branches"]:
                    expect(br["prompt"].count("_") % 2 == 0, f"[{tid}] unbalanced '_' in prompt")
                    for it in br["items"]:
                        expect(it.count("_") % 2 == 0, f"[{tid}] unbalanced '_' in item")

    if errors:
        print(f"content verification FAILED ({len(errors)} problems / {checks} checks)")
        for err in errors[:40]:
            print(" -", err)
        return 1

    print(f"content verification passed ({checks} checks)")
    print(
        f"units={len(units)} topics={sum(len(u['topics']) for u in units)} "
        f"questions={total_questions} svgs={len(seen_svg)} glossary={len(glossary['terms'])}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
