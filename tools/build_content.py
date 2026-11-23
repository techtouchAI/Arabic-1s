#!/usr/bin/env python3
"""Deterministic content builder for اللغة العربية — الصف الأول المتوسط
(الجزء الأول والجزء الثاني).

Reads the two official Iraqi Ministry of Education PDF textbooks in the repo root,
reconstructs clean vocalized RTL Arabic text and sidebars, segments each unit
into its official الطريقة التكاملية lessons, generates vector SVG diagrams and
platform icons, and writes deterministic JSON assets under assets/content/.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).parent))

from curriculum_data import (  # noqa: E402
    EXAM_BANK,
    GLOSSARY_ENTRIES,
    GRAMMAR_LESSONS,
    PALETTE,
    UNIT_QUESTIONS,
    UNIT_SPECS,
    figure,
    legend,
)
from generate_illustrations import generate_all  # noqa: E402
from pdf_extractor import ExtractedLine, ExtractedPage, extract_page, open_patched_pdf  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CONTENT_DIR = ROOT / "assets" / "content"
PDF_PART1 = ROOT / "كتاب_العربي_اول_متوسط_الجزء_الاول.pdf"
PDF_PART2 = ROOT / "كتاب_العربي_اول_متوسط_الجزء_الثاني.pdf"

ARABIC_DIGITS = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")


def to_ar_digits(num: int | str) -> str:
    return str(num).translate(ARABIC_DIGITS)


def strip_harakat(text: str) -> str:
    text = re.sub(r"[\u064b-\u0655\u0670\u0640]", "", text)
    text = (
        text.replace("أ", "ا")
        .replace("إ", "ا")
        .replace("آ", "ا")
        .replace("ٱ", "ا")
        .replace("ى", "ي")
        .replace("ة", "ه")
    )
    return re.sub(r"\s+", " ", text).strip()


def clean_tatweel(text: str) -> str:
    """Remove excessive decorative kashida/tatweel stretches from narrow sidebars."""
    text = re.sub(r"\u0640([\u064b-\u0655]*)", r"\1", text)
    text = re.sub(r"\s{2,}", " ", text)
    return text.strip()


_ITEM_START_RE = re.compile(
    r"^("
    r"[0-9٠-٩]+\s*[-–.)/]"
    r"|\(\s*[0-9٠-٩]+\s*\)"
    r"|[أبجدوهـ]\s*[-–/)]"
    r"|\(\s*[أبجدوهـ]\s*\)"
    r"|أو[َّ]?ل[اًا]|ثاني[اًا]|ثالث[اًا]|رابع[اًا]"
    r"|[*•\-–]"
    r"|قُلْ\s*:|وَ?لا\s*تَقُلْ\s*:"
    r")"
)


def _classify_marker(plain: str, ln: ExtractedLine) -> Optional[str]:
    """Detect major structural boundaries inside an official textbook unit."""
    p = plain.strip(" :.،-–")
    # Unit banner (skip repeating the unit title itself)
    if p.startswith("الوحده ال") and ln.size >= 18.5:
        return "UNIT_BANNER"
    if p in ("تمهيد", "المفاهيم المتضمنه", "ما قبل النص"):
        return "OPENER"
    if p.startswith("الدرس الاول") or p in ("المطالعه والنصوص",):
        return "LESSON_READING"
    if p in ("التحليل", "تحليل النص", "نشاط الفهم والاستيعاب", "نشاط الفهم و الاستيعاب"):
        return "READING_ANALYSIS"
    if p.startswith("نشاط 1") or p.startswith("نشاط 2"):
        return "READING_ANALYSIS"
    if p.startswith("الدرس الثاني") or (p == "القواعد" and ln.color == 0xED1C24 and ln.size >= 17.5):
        return "LESSON_GRAMMAR"
    if p.startswith(("خلاصه القواعد", "خلصه القواعد")):
        return "GRAMMAR_SUMMARY"
    if p.startswith("الدرس الثالث"):
        return "LESSON_THIRD"
    if p in ("الاملاء والخط", "الخط والاملاء", "ا / الاملاء", "ا/ الاملاء", "ب / الخط", "ب/ الخط"):
        return "LESSON_ORTHOGRAPHY"
    if p == "التعبير" and (ln.color in (0xED1C24, 0xFFFFFF) and ln.size >= 17.0):
        return "LESSON_EXPRESSION"
    if p.startswith("اولا: التعبير الشفهي") or p.startswith("ثانيا: التعبير التحريري") or p.startswith("ثانيا:التعبير التحريري"):
        return "LESSON_EXPRESSION"
    if p.startswith("النص التقويمي"):
        return "EVALUATIVE_TEXT"
    if p == "التمرينات" and (ln.color in (0xFFFFFF, 0x231F20, 0xED1C24) and ln.size >= 17.0):
        return "EXERCISES"
    return None


def _reflow_lines(lines: List[ExtractedLine]) -> Tuple[List[str], bool]:
    """Reflow visual PDF lines into clean logical paragraphs, verses, and exercise items."""
    bullets: List[str] = []
    cur: List[str] = []
    prev_y1: Optional[float] = None
    prev_page: Optional[int] = None
    verse_count = 0

    def flush() -> None:
        if cur:
            joined = " ".join(cur)
            joined = re.sub(r"\s{2,}", " ", joined).strip()
            if joined:
                bullets.append(joined)
            cur.clear()

    for ln in lines:
        txt = clean_tatweel(ln.text)
        if not txt:
            continue
        plain = strip_harakat(txt)
        # Skip standalone section chrome words already represented in topic title
        if plain in (
            "تمهيد",
            "النص",
            "في اثناء النص",
            "ما بعد النص",
            "الدرس الاول:",
            "الدرس الاول",
            "المطالعه والنصوص",
            "الدرس الثاني:",
            "الدرس الثاني",
            "القواعد",
            "خلاصه القواعد",
            "التمرينات",
            "الدرس الثالث:",
            "الدرس الثالث",
            "الاملاء والخط",
            "الخط والاملاء",
            "التعبير",
            "النص التقويمي",
            "تقويم اللسان",
        ):
            flush()
            continue

        # Poetic two-hemistich verse: always keep on its own line
        if "✦" in txt:
            flush()
            bullets.append(txt)
            verse_count += 1
            prev_y1 = ln.y1
            prev_page = ln.page
            continue

        # Standalone exercise group number like "( 1 )" -> attach to next line as "التمرين (1):"
        m_num = re.match(r"^\(\s*([0-9٠-٩]+)\s*\)$", txt)
        if m_num:
            flush()
            cur.append(f"التمرين ({to_ar_digits(m_num.group(1))}):")
            prev_y1 = ln.y1
            prev_page = ln.page
            continue

        is_heading_like = (
            (ln.color in (0xED1C24, 0xA650, 0xFFFFFF) and len(txt) <= 68)
            or _ITEM_START_RE.match(plain) is not None
        )
        large_gap = (
            prev_page == ln.page
            and prev_y1 is not None
            and (ln.y0 - prev_y1) > 15.0
        )

        if is_heading_like or large_gap:
            # Keep "التمرين (١):" prefix attached to the prompt line right after it
            if len(cur) == 1 and cur[0].startswith("التمرين ("):
                cur.append(txt)
            else:
                flush()
                cur.append(txt)
        else:
            if cur and re.search(r"[.؟!)):»]$", cur[-1]) and len(" ".join(cur)) > 170:
                flush()
            cur.append(txt)

        prev_y1 = ln.y1
        prev_page = ln.page

    flush()
    return bullets, (verse_count >= 3)


def _reflow_sidebar(lines: List[ExtractedLine]) -> List[str]:
    """Turn narrow sidebar lines into crisp notes."""
    if not lines:
        return []
    notes: List[str] = []
    cur: List[str] = []
    prev_y1: Optional[float] = None
    for ln in lines:
        txt = clean_tatweel(ln.text)
        if not txt:
            continue
        plain = strip_harakat(txt)
        if plain in ("تقويم اللسان",):
            if cur:
                notes.append(" ".join(cur))
                cur.clear()
            continue
        is_new = (
            plain in ("المفاهيم المتضمنه", "ما قبل النص", "في اثناء النص", "ما بعد النص", "اضاءه", "فائده", "انتبه")
            or txt.startswith(("*", "-", "•", "قُلْ", "لا تَقُلْ", "وَلا"))
            or (prev_y1 is not None and abs(ln.y0 - prev_y1) > 22.0)
        )
        if is_new and cur:
            notes.append(" ".join(cur))
            cur.clear()
        cur.append(txt)
        prev_y1 = ln.y1
    if cur:
        notes.append(" ".join(cur))
    # Filter out Taqwim fragments already cleanly rendered in structured taqwim cards
    cleaned: List[str] = []
    for n in notes:
        pn = strip_harakat(n)
        if pn.startswith(("قل:", "لا تقل:", "ولا تقل:")) or (" ام (" in pn and len(pn) < 85):
            continue
        if len(n.strip()) >= 4:
            cleaned.append(re.sub(r"\s{2,}", " ", n).strip())
    return cleaned


def build_unit_from_pdf(doc_pages: List[ExtractedPage], spec: dict) -> dict:
    p_start, p_end = spec["pdfPages"]
    unit_pages = [doc_pages[p - 1] for p in range(p_start, p_end + 1)]

    buckets: Dict[str, Dict[str, list]] = {
        "opener": {"lines": [], "side": [], "pages": set()},
        "reading_text": {"lines": [], "side": [], "pages": set()},
        "reading_analysis": {"lines": [], "side": [], "pages": set()},
        "reading_exercises": {"lines": [], "side": [], "pages": set()},
        "grammar_body": {"lines": [], "side": [], "pages": set()},
        "grammar_summary": {"lines": [], "side": [], "pages": set()},
        "grammar_exercises": {"lines": [], "side": [], "pages": set()},
        "third_lesson": {"lines": [], "side": [], "pages": set()},
        "evaluative_text": {"lines": [], "side": [], "pages": set()},
        "evaluative_exercises": {"lines": [], "side": [], "pages": set()},
    }

    state = "opener"
    third_kind = spec["thirdLessonKind"]  # 'orthography' | 'expression' | None

    for ep in unit_pages:
        page_start_state = state
        for ln in ep.main_lines:
            plain = strip_harakat(ln.text)
            marker = _classify_marker(plain, ln)
            if marker == "UNIT_BANNER":
                continue
            elif marker == "OPENER" and state == "opener":
                state = "opener"
            elif marker == "LESSON_READING":
                state = "reading_text"
            elif marker == "READING_ANALYSIS" and state in ("opener", "reading_text", "reading_analysis"):
                state = "reading_analysis"
            elif marker == "LESSON_GRAMMAR":
                state = "grammar_body"
            elif marker == "GRAMMAR_SUMMARY" and state in ("grammar_body", "grammar_summary"):
                state = "grammar_summary"
            elif marker == "LESSON_THIRD":
                state = "third_lesson"
            elif marker in ("LESSON_ORTHOGRAPHY", "LESSON_EXPRESSION") and third_kind is not None:
                if state in ("grammar_body", "grammar_summary", "grammar_exercises", "third_lesson"):
                    state = "third_lesson"
            elif marker == "EVALUATIVE_TEXT":
                state = "evaluative_text"
            elif marker == "EXERCISES":
                if state in ("reading_text", "reading_analysis"):
                    state = "reading_exercises"
                elif state in ("grammar_body", "grammar_summary"):
                    state = "grammar_exercises"
                elif state == "evaluative_text":
                    state = "evaluative_exercises"

            buckets[state]["lines"].append(ln)
            buckets[state]["pages"].add(ep.page)

        # Attach page sidebars to the primary active lesson on this page
        side_target = state if buckets[state]["pages"] and ep.page in buckets[state]["pages"] else page_start_state
        if side_target == "reading_exercises":
            side_target = "reading_analysis"
        elif side_target == "grammar_exercises":
            side_target = "grammar_body"
        elif side_target == "evaluative_exercises":
            side_target = "evaluative_text"
        buckets[side_target]["side"].extend(ep.sidebar_lines)
        if ep.sidebar_lines:
            buckets[side_target]["pages"].add(ep.page)

    topics: List[dict] = []

    def page_badge(pages_set: set) -> str:
        if not pages_set:
            return f"ص {to_ar_digits(p_start)}"
        lo, hi = min(pages_set), max(pages_set)
        return f"ص {to_ar_digits(lo)}" if lo == hi else f"ص {to_ar_digits(lo)}–{to_ar_digits(hi)}"

    def add_topic(
        key_bucket: str,
        title: str,
        category: str,
        lesson_badge: str,
        forced_kind: Optional[str] = None,
        extra_taqwim: Optional[List[dict]] = None,
    ) -> None:
        b = buckets[key_bucket]
        bullets, is_poetry = _reflow_lines(b["lines"])
        side_notes = _reflow_sidebar(b["side"])
        if not bullets and not side_notes and not extra_taqwim:
            return
        kind = forced_kind or ("poetry" if is_poetry else "prose")
        topic: dict = {
            "id": f"t{len(topics) + 1}",
            "title": title,
            "category": category,
            "lessonBadge": f"{lesson_badge} • {page_badge(b['pages'])}",
            "kind": kind,
            "bullets": bullets if bullets else side_notes[:2],
            "listTitle": "إضاءات وملاحظات هامشية" if (bullets and side_notes) else None,
            "listItems": side_notes if bullets else side_notes[2:],
        }
        if extra_taqwim:
            topic["taqwim"] = extra_taqwim
        topics.append(topic)

    # 1. Opener (التمهيد والمفاهيم المتضمنة)
    add_topic(
        "opener",
        "التمهيد والمفاهيم المتضمنة",
        "opener",
        "مدخل الوحدة",
    )

    # 2. Lesson 1: Reading & Texts (المطالعة والنصوص)
    add_topic(
        "reading_text",
        f"المطالعة والنصوص: {spec['readingTitle']}",
        "reading",
        "الدرس الأول • المطالعة والنصوص",
    )
    add_topic(
        "reading_analysis",
        "التحليل ونشاط الفهم والاستيعاب",
        "reading",
        "الدرس الأول • التحليل والنشاط",
    )
    add_topic(
        "reading_exercises",
        "تمرينات المطالعة والنصوص",
        "reading",
        "الدرس الأول • التمرينات",
        forced_kind="exercises",
    )

    # 3. Lesson 2: Grammar (القواعد + خلاصة القواعد وتقويم اللسان + التمرينات)
    add_topic(
        "grammar_body",
        f"القواعد: {spec['grammarTitle']}",
        "grammar",
        "الدرس الثاني • القواعد",
    )
    add_topic(
        "grammar_summary",
        f"خلاصة القواعد وتقويم اللسان ({spec['grammarTitle']})",
        "grammar",
        "الدرس الثاني • خلاصة القواعد",
        forced_kind="rules",
        extra_taqwim=spec["taqwim"],
    )
    add_topic(
        "grammar_exercises",
        f"تمرينات القواعد ({spec['grammarTitle']})",
        "grammar",
        "الدرس الثاني • التمرينات",
        forced_kind="exercises",
    )

    # 4. Lesson 3: Orthography / Expression (when present in this unit)
    if third_kind == "orthography":
        add_topic(
            "third_lesson",
            spec["thirdLessonTitle"],
            "orthography",
            "الدرس الثالث • الإملاء والخط",
        )
    elif third_kind == "expression":
        add_topic(
            "third_lesson",
            spec["thirdLessonTitle"],
            "expression",
            "الدرس الثالث • التعبير",
        )

    # 5. Evaluative Text & Exercises (النص التقويمي والتمرينات)
    add_topic(
        "evaluative_text",
        f"النص التقويمي: {spec['evaluativeTitle']}",
        "evaluative",
        "النص التقويمي",
    )
    add_topic(
        "evaluative_exercises",
        "تمرينات النص التقويمي",
        "evaluative",
        "النص التقويمي • التمرينات",
        forced_kind="exercises",
    )

    # Build full unit corpus for search & strict verification
    unit_corpus_parts = [
        t["title"]
        + "\n"
        + "\n".join(t["bullets"])
        + "\n"
        + "\n".join(t.get("listItems", []))
        + "\n"
        + "\n".join(
            f"قل: {tq['say']} ولا تقل: {tq['dontSay']}" for tq in t.get("taqwim", [])
        )
        for t in topics
    ]
    unit_text = "\n".join(unit_corpus_parts)

    # Attach verified unit self-test questions
    raw_questions = UNIT_QUESTIONS[spec["id"]]
    questions: List[dict] = []
    for idx, q in enumerate(raw_questions, start=1):
        q_entry = dict(q)
        q_entry["id"] = f"{spec['id']}-q{idx}"
        if q_entry["kind"] == "choice":
            ans_opt = q_entry["options"][q_entry["answerIndex"]]
            q_entry["answerSupport"] = _resolve_choice_support(ans_opt, unit_text, spec)
        questions.append(q_entry)

    return {
        "id": spec["id"],
        "sectionId": spec["part"],
        "part": spec["part"],
        "order": spec["order"],
        "title": spec["title"],
        "displayTitle": spec["displayTitle"],
        "unitLabel": spec["unitLabel"],
        "grade": spec["partLabel"],
        "pageRange": f"ص {to_ar_digits(p_start)}–{to_ar_digits(p_end)}",
        "grammarTitle": spec["grammarTitle"],
        "readingTitle": spec["readingTitle"],
        "thirdLessonTitle": spec["thirdLessonTitle"],
        "evaluativeTitle": spec["evaluativeTitle"],
        "template": spec["template"],
        "accent": spec["accent"],
        "figures": spec["figures"],
        "topics": topics,
        "questions": questions,
        "unitText": unit_text,
    }


def _resolve_choice_support(option: str, unit_text: str, spec: dict) -> str:
    """Find an authentic supporting sentence in the unit text for a choice option."""
    opt_plain = strip_harakat(option)
    # Extract key roots >= 3 chars
    words = [
        w
        for w in re.findall(r"[\u0621-\u064a0-9٠-٩]+", opt_plain)
        if len(w) >= 3 and w not in ("على", "الى", "في", "من", "هذا", "هذه", "التي", "الذي", "بانه", "لانه")
    ]
    sentences = [s.strip() for s in re.split(r"[\n.؟!]", unit_text) if len(s.strip()) > 12]
    for s in sentences:
        sp = strip_harakat(s)
        if opt_plain in sp:
            return s
    if words:
        for s in sentences:
            sp = strip_harakat(s)
            if all(w in sp for w in words):
                return s
        for s in sentences:
            sp = strip_harakat(s)
            if any(w in sp for w in words):
                return s
    return f"{spec['grammarTitle']}: {option}"


def build_intro_unit(doc1_pages: List[ExtractedPage]) -> dict:
    """Extract the official book introduction (المقدمة, Part 1 p. 3)."""
    p3 = doc1_pages[2]
    bullets, _ = _reflow_lines(p3.main_lines)
    # Remove standalone heading "المقدمة"
    bullets = [b for b in bullets if strip_harakat(b) != "المقدمه"]
    topics = [
        {
            "id": "t1",
            "title": "مقدمة الكتاب الرسمي — الطريقة التكاملية",
            "category": "opener",
            "lessonBadge": "مقدمة لجنة التأليف • ص ٣",
            "kind": "prose",
            "bullets": bullets,
            "listTitle": "مرتكزات المنهج التكاملي في الصف الأول المتوسط",
            "listItems": [
                "بُني الكتاب بجزأيه الأول والثاني على نظام الوحدات المتكاملة، ولكل فصل دراسي جزء مستقل.",
                "تشتمل كل وحدة على نص رئيس تُشتق منه دروس القواعد والإملاء والخط والتعبير، ونص تقويمي يعزز المهارات التطبيقية.",
                "تحقيق مهارات التعلم الأربع (الاستماع، والتحدث، والقراءة، والكتابة) بلغة وظيفية فاعلة.",
            ],
        },
        {
            "id": "t2",
            "title": "توزيع فروع المادة في الامتحان التحريري الرسمي",
            "category": "grammar",
            "lessonBadge": "دليل المدرس للتقويم",
            "kind": "list",
            "bullets": [
                "تتألف ورقة الأسئلة التحريرية الرسمية للغة العربية في الصف الأول المتوسط من ثلاثة أقسام متكاملة وفق نماذج الأسئلة المعتمدة:",
            ],
            "listTitle": "أقسام ورقة الامتحان التحريري",
            "listItems": [
                "أولاً — الإنشاء والتعبير التحريري (٣٠ درجة): الكتابة في أحد موضوعين مختارين.",
                "ثانياً — قواعد اللغة العربية (٣٥ درجة): ثلاثة أسئلة متنوعة تشمل الاستخراج والتطبيق والإعراب وبيان الفرق والاختيارات.",
                "ثالثاً — الإملاء (١٥ درجة): قواعد التنوين، واللام الشمسية والقمرية، وألف التفريق، والتاء المبسوطة والمربوطة، وتصحيح الأخطاء الإملائية.",
            ],
        },
    ]
    unit_text = "\n".join(
        t["title"] + "\n" + "\n".join(t["bullets"]) + "\n" + "\n".join(t["listItems"])
        for t in topics
    )
    return {
        "id": "intro",
        "sectionId": "intro",
        "part": "both",
        "order": 1,
        "title": "مقدمة المنهج التكاملي",
        "displayTitle": "مقدمة المنهج التكاملي",
        "unitLabel": "المقدمة",
        "grade": "الجزء الأول والثاني",
        "pageRange": "ص ٣",
        "grammarTitle": "الطريقة التكاملية",
        "readingTitle": "مقدمة لجنة التأليف",
        "thirdLessonTitle": None,
        "evaluativeTitle": None,
        "template": "concept",
        "accent": "secondary",
        "figures": [
            figure(
                "integrative-method",
                "الطريقة التكاملية: اشتقاق المطالعة والقواعد والإملاء والتعبير من النص المحوري.",
                legend(
                    ("المطالعة والنصوص", "primary"),
                    ("القواعد", "gold"),
                    ("الإملاء والخط", "green"),
                    ("التعبير والنص التقويمي", "ink"),
                ),
            ),
        ],
        "topics": topics,
        "questions": [],
        "unitText": unit_text,
    }


def build_orthography_summary_unit() -> dict:
    """Comprehensive reference unit for all official الإملاء والخط والتعبير lessons."""
    topics = [
        {
            "id": "t1",
            "title": "التنوين وصوره ومواضع امتناعه (الجزء الأول — الوحدة الأولى)",
            "category": "orthography",
            "lessonBadge": "الجزء الأول • الإملاء",
            "kind": "rules",
            "bullets": [
                "التنوين: نون ساكنة زائدة نلفظها في آخر الاسم المنوّن ولا نكتبها، وله ثلاث صور: تنوين الضم (ٌ)، وتنوين الفتح (ً)، وتنوين الكسر (ٍ).",
                "يختص التنوين بالأسماء النكرة، فلا يدخل على الأفعال ولا الحروف، ولا يدخل على الاسم المعرّف بـ (ال) ولا الاسم المضاف.",
                "عند تنوين الاسم المنتهي بهمزة مسبوقة بألف (سماءً، ماءً) أو بتاء مربوطة (مدرسةً، هبةً) أو بألف مقصورة (هدىً، فتىً) يُكتب تنوين الفتح من دون إضافة ألف بعده.",
            ],
            "listTitle": None,
            "listItems": [],
        },
        {
            "id": "t2",
            "title": "الحروف الشمسية والحروف القمرية (الجزء الأول — الوحدة الرابعة)",
            "category": "orthography",
            "lessonBadge": "الجزء الأول • الإملاء",
            "kind": "rules",
            "bullets": [
                "الحروف القمرية أربعة عشر حرفاً جُمعت في عبارة: (إبغِ حجّكَ وخَفْ عقيمَه)، وتُلفظ معها لام (ال) التعريف واضحةً غير مدغمة مثل: (الكتاب، القلم، العلم، الجمل، اليمامة).",
                "الحروف الشمسية أربعة عشر حرفاً هي بقية أحرف الهجاء (ت، ث، د، ذ، ر، ز، س، ش، ص، ض، ط، ظ، ل، ن)، وتُدغم معها لام (ال) التعريف في الحرف الشمسي فلا تُلفظ اللام ويُشدد الحرف بعدها مثل: (الشّمس، الصّديق، الثّور، السّيارة، النّور).",
            ],
            "listTitle": None,
            "listItems": [],
        },
        {
            "id": "t3",
            "title": "ألف التفريق بعد واو الجماعة (الجزء الثاني — الوحدة الثالثة)",
            "category": "orthography",
            "lessonBadge": "الجزء الثاني • الإملاء",
            "kind": "rules",
            "bullets": [
                "ألف التفريق: ألف زائدة تُكتب ولا تُلفظ بعد ضمير واو الجماعة المتصل بالفعل الماضي (كتبوا)، أو المضارع المنصوب والمجزوم من الأفعال الخمسة (لن يتقاعسوا، لم يبخلوا)، أو فعل الأمر (اكتبوا)؛ للتفريق بين واو الجماعة وغيرها من الواوات.",
                "لا تُكتب ألف التفريق بعد الواو الأصلية التي من بنية الفعل مثل (يدعو، يسمو، نرجو)، ولا بعد واو جمع المذكر السالم المضاف مثل (معلمو المدرسة، حافظو العهد، مهندسو المشروع).",
            ],
            "listTitle": None,
            "listItems": [],
        },
        {
            "id": "t4",
            "title": "التاء المبسوطة والتاء المربوطة (الجزء الثاني — الوحدة الخامسة)",
            "category": "orthography",
            "lessonBadge": "الجزء الثاني • الإملاء",
            "kind": "rules",
            "bullets": [
                "التاء المبسوطة (الطويلة ـت / ت): تُلفظ تاءً واضحة في جميع الأحوال عند الوصل وعند الوقف، وترد في الأفعال (تاء الفاعل وتاء التأنيث الساكنة وتاء الفعل الأصلية مثل صَمَتَ)، وفي الأسماء الثلاثية الساكنة الوسط (بيت، وقت، صوت، موت)، وجمع المؤنث السالم (طالبات، قراءات، ضروريات).",
                "التاء المربوطة (ـة / ة): تقع في آخر الأسماء المفردة بعد فتح وتُلفظ تاءً في درج الكلام وهاءً عند الوقف عليها مثل: (مكتبة، قراءة، حرّة، نافذة، واسعة، ضرورية، فاطمة، حمزة)، وفي جمع التكسير الذي لا ينتهي مفرده بتاء مبسوطة مثل (قضاة، رعاة).",
            ],
            "listTitle": None,
            "listItems": [],
        },
        {
            "id": "t5",
            "title": "قواعد الخط القياسي وغير القياسي وموضوعات التعبير",
            "category": "expression",
            "lessonBadge": "الجزء الأول والثاني • الخط والتعبير",
            "kind": "list",
            "bullets": [
                "يُدرَّب الطالب في دروس الخط على كتابة العبارات بخط واضح وحسن مع التمييز بين الخط القياسي (ما كُتب كما يُلفظ) والخط غير القياسي كالرسم القرآني العثماني وما فيه من زيادة حرف أو حذفه مثل (هذا، ذلك، لكن، الرحمن، أولئك، مائة).",
            ],
            "listTitle": "محاور التعبير الشفهي والتحريري الرسمية في الكتابين",
            "listItems": [
                "طلب العلم وأثره في عزة الأمم: (كل عزٍّ لم يُؤيَّد بعلمٍ فإلى ذلٍّ يصير — المنفلوطي).",
                "مكارم الأخلاق والاقتداء بسيرة الرسول الكريم (ص).",
                "التسامح والتعايش السلمي وأثرهما في وحدة المجتمع: (النفوس الكبيرة وحدها تعرف كيف تسامح).",
                "اللغة العربية رمز وجودنا وواجبنا في الحفاظ على فصاحتها.",
                "بيئتنا أمانة وأثر النظافة والتشجير في صحة الإنسان.",
                "الإيثار خُلُق الكرام وسمة الصالحين.",
                "الوقت حياتك واستثمار العمر في العمل الصالح النافع.",
                "العفو عند المقدرة وأثره في إشاعة المحبة والسلام.",
            ],
        },
    ]
    unit_text = "\n".join(
        t["title"] + "\n" + "\n".join(t["bullets"]) + "\n" + "\n".join(t["listItems"])
        for t in topics
    )
    return {
        "id": "orthography-expression",
        "sectionId": "orthography",
        "part": "both",
        "order": 1,
        "title": "جامع قواعد الإملاء والخط والتعبير",
        "displayTitle": "قواعد الإملاء والخط والتعبير",
        "unitLabel": "مرجع شامل",
        "grade": "الجزء الأول والثاني",
        "pageRange": "مرجع متكامل",
        "grammarTitle": "الإملاء والخط والتعبير",
        "readingTitle": "التنوين • الشمسية والقمرية • ألف التفريق • التاء",
        "thirdLessonTitle": None,
        "evaluativeTitle": None,
        "template": "comparison",
        "accent": "gold",
        "figures": [
            figure(
                "tanween-forms",
                "صور التنوين الثلاث ومواضع امتناع دخوله.",
                legend(("ضم", "primary"), ("فتح", "gold"), ("كسر", "green")),
            ),
            figure(
                "taa-orthography",
                "التمييز بين التاء المبسوطة والتاء المربوطة وصلاً ووقفاً.",
                legend(("التاء المبسوطة", "primary"), ("التاء المربوطة", "secondary")),
            ),
        ],
        "topics": topics,
        "questions": [],
        "unitText": unit_text,
    }


def build_lessons_json() -> dict:
    """Format the 19 structured Grammar + Taqwim + Irab reference lessons."""
    lessons: List[dict] = []
    for item in GRAMMAR_LESSONS:
        body_blocks: List[dict] = [{"kind": "heading", "text": "القواعد الأساسية والضوابط"}]
        for rule in item["rules"]:
            body_blocks.append({"kind": "bullet", "text": rule})
        body_blocks.append({"kind": "heading", "text": "الشواهد والأمثلة التطبيقية"})
        for ex in item["examples"]:
            body_blocks.append({"kind": "paragraph", "text": ex})
        if item.get("irab"):
            body_blocks.append({"kind": "heading", "text": "أنموذج في الإعراب"})
            for ir in item["irab"]:
                body_blocks.append({"kind": "bullet", "text": ir})
        if item.get("taqwim"):
            body_blocks.append({"kind": "heading", "text": "تقويم اللسان (قُلْ ولا تَقُلْ)"})
            for tq in item["taqwim"]:
                body_blocks.append(
                    {
                        "kind": "bullet",
                        "text": f"قُلْ: «{tq['say']}»  —  وَلا تَقُلْ: «{tq['dontSay']}»",
                    }
                )
        lessons.append(
            {
                "id": item["id"],
                "part": item["part"],
                "partLabel": item["partLabel"],
                "unitId": item["unitId"],
                "order": item["order"],
                "title": item["title"],
                "summary": item["summary"],
                "accent": item["accent"],
                "template": "lesson",
                "figures": item["figures"],
                "taqwim": item["taqwim"],
                "plans": [
                    {
                        "kind": "grammar",
                        "label": item["partLabel"],
                        "subject": f"القواعد وتقويم اللسان — {item['title']}",
                        "body": body_blocks,
                        "homework": [],
                    }
                ],
            }
        )
    return {"schemaVersion": 1, "lessons": lessons}


def build_glossary_json(units_by_id: Dict[str, dict]) -> dict:
    terms: List[dict] = []
    for idx, entry in enumerate(GLOSSARY_ENTRIES, start=1):
        unit = units_by_id[entry["unitId"]]
        # Link to reading topic if present, else first topic
        reading_topic = next(
            (t["id"] for t in unit["topics"] if t.get("category") == "reading"),
            unit["topics"][0]["id"],
        )
        terms.append(
            {
                "id": f"term-{idx:02d}",
                "part": entry["part"],
                "term": entry["term"],
                "definition": entry["definition"],
                "unitId": entry["unitId"],
                "topicId": reading_topic,
            }
        )
    return {"schemaVersion": 1, "terms": terms}


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def main() -> None:
    if not PDF_PART1.exists():
        raise SystemExit(f"missing Part 1 textbook PDF: {PDF_PART1}")
    if not PDF_PART2.exists():
        raise SystemExit(f"missing Part 2 textbook PDF: {PDF_PART2}")

    generate_all()

    doc1 = open_patched_pdf(PDF_PART1)
    doc2 = open_patched_pdf(PDF_PART2)
    pages1 = [extract_page(doc1, i) for i in range(len(doc1))]
    pages2 = [extract_page(doc2, i) for i in range(len(doc2))]

    intro_unit = build_intro_unit(pages1)
    ortho_unit = build_orthography_summary_unit()

    built_units: List[dict] = []
    for spec in UNIT_SPECS:
        src_pages = pages1 if spec["part"] == "part1" else pages2
        built_units.append(build_unit_from_pdf(src_pages, spec))

    all_units = [intro_unit, ortho_unit] + built_units
    units_by_id = {u["id"]: u for u in all_units}

    glossary_payload = build_glossary_json(units_by_id)
    for term in glossary_payload["terms"]:
        u = units_by_id.get(term["unitId"])
        if u is not None:
            u.setdefault("glossary", []).append(term["id"])

    lessons_payload = build_lessons_json()

    sections = [
        {
            "id": "intro",
            "title": "مقدمة المنهج التكاملي",
            "subtitle": "فلسفة الكتاب وتوزيع الدرجات الرسمية",
            "kind": "intro",
        },
        {
            "id": "part1",
            "title": "الجزء الأول",
            "subtitle": "عشر وحدات دراسية متكاملة (الفصل الأول)",
            "kind": "grade",
        },
        {
            "id": "part2",
            "title": "الجزء الثاني",
            "subtitle": "تسع وحدات دراسية متكاملة (الفصل الثاني)",
            "kind": "grade",
        },
        {
            "id": "lessons",
            "title": "ملخصات القواعد وتقويم اللسان",
            "subtitle": "تسعة عشر درساً نحوياً مع الشواهد والإعراب",
            "kind": "lessons",
        },
        {
            "id": "orthography",
            "title": "جامع الإملاء والخط والتعبير",
            "subtitle": "التنوين، اللام الشمسية والقمرية، ألف التفريق، والتاء",
            "kind": "orthography",
        },
    ]

    curriculum_payload = {
        "schemaVersion": 1,
        "title": "بَيَان",
        "subtitle": "اللغة العربية للصف الأول المتوسط",
        "sections": sections,
        "units": all_units,
    }

    write_json(CONTENT_DIR / "curriculum.json", curriculum_payload)
    write_json(CONTENT_DIR / "lessons.json", lessons_payload)
    write_json(CONTENT_DIR / "glossary.json", glossary_payload)
    write_json(CONTENT_DIR / "exam_bank.json", EXAM_BANK)

    total_topics = sum(len(u["topics"]) for u in all_units)
    total_questions = sum(len(u["questions"]) for u in all_units)
    print(
        f"built units={len(all_units)} (part1=10, part2=9 + intro + orthography) "
        f"topics={total_topics} questions={total_questions} "
        f"grammar_lessons={len(lessons_payload['lessons'])} "
        f"glossary={len(glossary_payload['terms'])} "
        f"exam_templates={len(EXAM_BANK['officialTemplates'])}"
    )


if __name__ == "__main__":
    main()
