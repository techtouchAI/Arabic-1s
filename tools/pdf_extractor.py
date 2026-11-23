#!/usr/bin/env python3
"""Deterministic RTL Arabic text & layout extractor for the Iraqi First
Intermediate Arabic textbooks (Part 1 & Part 2 PDFs).

Root causes solved by this module:
1. Subsetted Identity-H fonts (ArialMT, Arial-BoldMT, TimesNewRomanPS-BoldMT,
   ae_AlMateen-Bold) contain Lam-Alef and Allah ligature CIDs whose ToUnicode
   entries are either multi-codepoint (<06440627>) or truncated (<0644>).
   Multi-codepoint entries split into 0-width glyphs that invert under x-sort,
   and truncated entries lose the Alef/Allah tail.
   -> Before MuPDF parses pages, we patch those CIDs in-memory to single-char
      Arabic Supplement placeholders U+0750..U+0759 (BiDi class AL), sort base
      glyphs geometrically by descending x, attach combining marks to their
      nearest non-space base glyph, and expand placeholders back to Arabic.
2. Decorative headings emit a white (0xFFFFFF) drop-shadow span underneath dark
   or red foreground spans -> deduplicated geometrically while preserving real
   white text on dark/colored banners.
3. Page sidebars (المفاهيم المتضمنة, ما قبل النص, في أثناء النص, إضاءة, فائدة)
   and two-hemistich poetry verses are separated/paired geometrically instead
   of interleaving with main-column prose.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pymupdf

LIGATURE_PLACEHOLDERS: Dict[str, str] = {
    "\u0750": "لله",
    "\u0751": "الله",
    "\u0752": "لآ",
    "\u0753": "لآ",
    "\u0754": "لأ",
    "\u0755": "لأ",
    "\u0756": "لإ",
    "\u0757": "لإ",
    "\u0758": "لا",
    "\u0759": "لا",
}

MULTI_CHAR_TOUNICODE: Dict[str, str] = {
    "064406440647": "0750",
    "0627064406440647": "0751",
    "06440622": "0752",
    "06440623": "0754",
    "06440625": "0756",
    "06440627": "0758",
    "FB50": "0627",
}

HARAKAT_SET = set("\u064b\u064c\u064d\u064e\u064f\u0650\u0651\u0652\u0653\u0654\u0655\u0670")


def _is_combining(ch: str) -> bool:
    return ch in HARAKAT_SET or unicodedata.category(ch) == "Mn"


def open_patched_pdf(pdf_path: Path) -> pymupdf.Document:
    """Open a PDF and patch truncated/multi-char Arabic ligature ToUnicode CMaps
    in memory without modifying the source PDF file on disk."""
    raw_doc = pymupdf.open(str(pdf_path))
    tu_to_fonts: Dict[int, List[str]] = {}
    for xr in range(1, raw_doc.xref_length()):
        obj = raw_doc.xref_object(xr)
        tu_match = re.search(r"/ToUnicode\s+(\d+)\s+0\s+R", obj)
        if not tu_match:
            continue
        bf_match = re.search(r"/BaseFont\s+/([^\s/]+)", obj)
        tu_xref = int(tu_match.group(1))
        tu_to_fonts.setdefault(tu_xref, []).append(bf_match.group(1) if bf_match else "")

    for tu_xref, font_names in tu_to_fonts.items():
        stream = raw_doc.xref_stream(tu_xref).decode("latin1")
        joined_names = " ".join(font_names)
        is_2byte = "<0000> <FFFF>" in stream

        # 1. Replace any multi-codepoint ligature mapping in any font.
        for src_hex, dst_hex in MULTI_CHAR_TOUNICODE.items():
            stream = re.sub(
                rf"<([0-9A-Fa-f]+)>\s*<{src_hex}>",
                rf"<\1> <{dst_hex}>",
                stream,
                flags=re.IGNORECASE,
            )

        # 2. Patch truncated single-<0644> ligature CIDs in Arial / Times subsets.
        if is_2byte and ("Arial" in joined_names or "TimesNewRoman" in joined_names):
            arial_fixes = {
                "037F": "0750",  # لله
                "0BCC": "0751",  # الله
                "03F5": "0752",  # لآ isolated
                "03F6": "0753",  # لآ final
                "03F7": "0754",  # لأ isolated
                "03F8": "0755",  # لأ final
                "03F9": "0756",  # لإ isolated
                "03FA": "0757",  # لإ final
                "03FB": "0758",  # لا isolated
                "03FC": "0759",  # لا final
            }
            for cid, repl in arial_fixes.items():
                stream = re.sub(
                    rf"<{cid}>\s*<[0-9A-Fa-f]+>",
                    f"<{cid}> <{repl}>",
                    stream,
                    flags=re.IGNORECASE,
                )

        # 3. Patch ae_AlMateen-Bold ligatures.
        if is_2byte and "ae_AlMateen" in joined_names:
            mateen_fixes = {
                "014A": "0750",
                "01C0": "0752",
                "01C1": "0753",
                "01C2": "0754",
                "01C3": "0755",
                "01C4": "0756",
                "01C5": "0757",
                "01C6": "0758",
                "01C7": "0759",
            }
            for cid, repl in mateen_fixes.items():
                stream = re.sub(
                    rf"<{cid}>\s*<[0-9A-Fa-f]+>",
                    f"<{cid}> <{repl}>",
                    stream,
                    flags=re.IGNORECASE,
                )

        # 4. Add missing ASCII fill-in-the-blank / bracket CIDs in Identity-H fonts
        #    where <0003> is space ('<0020>').
        if is_2byte and re.search(r"<0003>\s*<0020>", stream):
            extra_cids = []
            for cid, uni in [("0020", "005F"), ("0028", "0029"), ("005B", "005D")]:
                if not re.search(rf"<{cid}>", stream, flags=re.IGNORECASE):
                    extra_cids.append(f"<{cid}> <{uni}>")
            if extra_cids:
                insert_block = "1 beginbfchar\n" + "\n".join(extra_cids) + "\nendbfchar\nendcmap"
                # Fix count properly
                insert_block = (
                    f"{len(extra_cids)} beginbfchar\n"
                    + "\n".join(extra_cids)
                    + "\nendbfchar\nendcmap"
                )
                stream = stream.replace("endcmap", insert_block)

        raw_doc.update_stream(tu_xref, stream.encode("latin1"))

    buf = raw_doc.tobytes()
    raw_doc.close()
    return pymupdf.open("pdf", buf)


# Known lexical restorations where the original typesetter entered visual-order
# glyphs or unligated kerning pairs in the source InDesign file.
_POST_REGEX_FIXES: List[Tuple[re.Pattern[str], str]] = [
    # Visual-order or split-ligature Allah glyphs preserving case vowel on ه
    (re.compile(r"ا([\u064b-\u0655]*)ه([\u064b-\u0655]*)ل([\u064b-\u0655]*)ل([\u064b-\u0655]*)"), r"الل\3\4ه\2\1"),
    (re.compile(r"ه([\u064b-\u0655]*)ل([\u064b-\u0655]*)ل([\u064b-\u0655]*)ا"), r"الل\2\3ه\1"),
    (re.compile(r"(^|[\s(«وفبكل])ال([\u064b-\u0655]*)ه([\u064b-\u0655]*)ل([\u064b-\u0655]*)(?=\s|$|[،؛:.؟!)»])"), r"\1الل\4ه\2\3"),
    # Collapse duplicate kasra on للهِِ -> للهِ
    (re.compile(r"للهِِ"), "للهِ"),
    # Double-haraka wide-Lam in ال + إ / أ / ا (e.g. وَالِْنْسِ -> وَالإِنْسِ)
    (re.compile(r"الِْ"), "الإِ"),
    (re.compile(r"لِلِْ"), "لِلإِ"),
    (re.compile(r"الَْ"), "الأَ"),
    (re.compile(r"الُْ"), "الأُ"),
    (re.compile(r"الْجَابَ"), "الإِجَابَ"),
    (re.compile(r"الْسْتِ"), "الاسْتِ"),
    (re.compile(r"خ([\u064b-\u0655]*)ل\u064eص([\u064b-\u0655]*)ة"), r"خ\1لاَص\2ة"),
    (re.compile(r"(^|[\s(«،:؛])ل\u064eح([\u064b-\u0655]*)ظ"), r"\1لاَح\2ظ"),
    # Standalone negative/prohibitive لا and إلا where wide-Lam glyph lost its Alef
    (re.compile(r"(^|[\s(«،:؛])([وفأ]?\u064e?)ل\u064e(?=\s|$|[)،.»])"), r"\1\2لاَ"),
    (re.compile(r"(^|[\s(«،:؛])إِ?ل\u0651?\u064e(?=\s|$|[)،.»])"), r"\1إِلاَّ"),
    (re.compile(r"(^|[\s(«،:؛])إِل\u064e\u0651(?=\s|$|[)،.»])"), r"\1إِلاَّ"),
    # Reversed unligated Alef+Lam inside words where Sukun precedes Lam-Alef
    (re.compile(r"ْا([\u064b-\u0655]*)ل([\u064b-\u0655]*)"), r"ْلا\1\2"),
    (re.compile(r"الك([\u064b-\u0655]*)ل\u064eم"), r"الك\1لاَم"),
    (re.compile(r"الْك([\u064b-\u0655]*)ل\u064eم"), r"الْك\1لاَم"),
]


def _normalize_shadda_order(text: str) -> str:
    """Keep canonical Shadda + vowel order and normalize ligature expansions."""
    for placeholder, expanded in LIGATURE_PLACEHOLDERS.items():
        text = text.replace(placeholder, expanded)
    # Swap vowel + shadda -> shadda + vowel for consistent Unicode order
    text = re.sub(r"([\u064b-\u0650])\u0651", "\u0651\\1", text)
    for pattern, repl in _POST_REGEX_FIXES:
        text = pattern.sub(repl, text)
    # Collapse repeated spaces (preserving single spaces and underscores)
    text = re.sub(r"[ \t]{2,}", " ", text).strip()
    # Remove stray space before punctuation or combining mark
    text = re.sub(r"\s+([\u064b-\u0655\u0670])", r"\1", text)
    text = re.sub(r"\s+([،؛:.؟!])", r"\1", text)
    return text


def reconstruct_rtl_line(spans: List[dict]) -> str:
    """Reconstruct a single visual line in logical Arabic RTL reading order."""
    base_glyphs: List[dict] = []
    marks: List[Tuple[str, float]] = []

    for sp in spans:
        font = sp.get("font", "")
        size = sp.get("size", 14.0)
        for ch_obj in sp.get("chars", []):
            ch = ch_obj["c"]
            x0, y0, x1, y1 = ch_obj["bbox"]
            if _is_combining(ch):
                marks.append((ch, x0))
                continue
            # Detect unpatched wide isolated Lam (width >= 0.52 * font_size) in Arial
            # when it represents isolated لا
            base_glyphs.append({
                "ch": ch,
                "x0": x0,
                "x1": x1,
                "xc": 0.5 * (x0 + x1),
                "w": x1 - x0,
                "size": size,
                "font": font,
                "marks": [],
            })

    if not base_glyphs:
        return ""

    # Fix 0-width split ligature tail glyphs (e.g. 3-codepoint <0644064E0627>):
    # MuPDF assigns width=0 at x = parent.x1 to the trailing Alef of a multi-char
    # ligature. Shift its xc to the left edge of the parent glyph so RTL -xc sort
    # places it AFTER the parent Lam instead of before it.
    for idx, g in enumerate(base_glyphs):
        if g["w"] < 0.2 and not g["ch"].isspace():
            for other in base_glyphs:
                if other is not g and other["w"] >= 1.5 and abs(other["x1"] - g["x0"]) < 0.6:
                    g["xc"] = other["x0"] - 0.05
                    break

    # Sort base glyphs right-to-left (descending xc)
    base_glyphs.sort(key=lambda g: -g["xc"])

    # Deduplicate same-character drop-shadow glyphs (e.g. 0xfff799 'ننششااطط 1')
    deduped_glyphs: List[dict] = []
    for g in base_glyphs:
        if (
            deduped_glyphs
            and not g["ch"].isspace()
            and deduped_glyphs[-1]["ch"] == g["ch"]
            and abs(deduped_glyphs[-1]["xc"] - g["xc"]) < 2.4
        ):
            continue
        deduped_glyphs.append(g)
    base_glyphs = deduped_glyphs

    # Attach each combining mark to the nearest non-space, non-digit, non-punct
    # Arabic base glyph whose horizontal span covers or touches xm.
    # Bare Alef (U+0627) never takes fatha/damma/kasra/sukun/shadda (only 064B/0670).
    letter_indices = [
        idx
        for idx, g in enumerate(base_glyphs)
        if not g["ch"].isspace()
        and g["w"] >= 0.2
        and (
            "\u0600" <= g["ch"] <= "\u077f"
            or "\ufb50" <= g["ch"] <= "\ufdff"
            or "\ufe70" <= g["ch"] <= "\ufeff"
        )
    ]
    for mark_ch, xm in marks:
        if not letter_indices:
            break
        best_idx = None
        best_score = 1e9
        for idx in letter_indices:
            g = base_glyphs[idx]
            if g["ch"] == "\u0627" and mark_ch not in ("\u064b", "\u0670", "\u0653"):
                continue
            # In Arabic fonts, combining marks sit near x0 (left edge of glyph)
            # or inside [x0 - 2.5, x1 + 2.5].
            if g["x0"] - 3.0 <= xm <= g["x1"] + 3.0:
                score = abs(xm - g["x0"]) * 0.7 + abs(xm - g["xc"]) * 0.3
            else:
                score = min(abs(xm - g["x0"]), abs(xm - g["x1"])) + 5.0
            if score < best_score:
                best_score = score
                best_idx = idx
        if best_idx is not None and best_score < 22.0:
            base_glyphs[best_idx]["marks"].append(mark_ch)

    # Reverse LTR runs (ASCII digits and Latin words) that were reversed by -xc sort
    tokens: List[Tuple[str, bool]] = []
    for g in base_glyphs:
        ch = g["ch"]
        is_ltr = ("0" <= ch <= "9") or ("A" <= ch <= "Z") or ("a" <= ch <= "z")
        # Flip mirrored parentheses if font CMap stored visual paren
        piece = ch + "".join(g["marks"])
        tokens.append((piece, is_ltr))

    out_parts: List[str] = []
    i = 0
    while i < len(tokens):
        if tokens[i][1]:
            j = i
            while j < len(tokens) and tokens[j][1]:
                j += 1
            out_parts.extend(tok for tok, _ in reversed(tokens[i:j]))
            i = j
        else:
            out_parts.append(tokens[i][0])
            i += 1

    return _normalize_shadda_order("".join(out_parts))


@dataclass
class ExtractedLine:
    page: int  # 1-based PDF page
    y0: float
    y1: float
    x0: float
    x1: float
    size: float
    color: int
    is_bold: bool
    zone: str  # 'main', 'sidebar_right', 'sidebar_left', 'poetry_right', 'poetry_left'
    text: str


@dataclass
class ExtractedPage:
    page: int
    main_lines: List[ExtractedLine] = field(default_factory=list)
    sidebar_lines: List[ExtractedLine] = field(default_factory=list)


def extract_page(doc: pymupdf.Document, page_index: int) -> ExtractedPage:
    """Extract clean, shadow-deduplicated, column-classified lines from one page."""
    page_num = page_index + 1
    rd = doc[page_index].get_text("rawdict")
    fg_boxes: List[Tuple[float, float, float, float]] = []

    raw_lines: List[Tuple[Tuple[float, float, float, float], List[dict], bool]] = []
    for block in rd["blocks"]:
        if block.get("type") != 0:
            continue
        for line in block.get("lines", []):
            lb = line["bbox"]
            # Skip bottom page-number footer (> 653 pt on 708.7 pt page)
            if lb[1] > 653.0:
                continue
            fg_spans = [s for s in line["spans"] if s["color"] != 0xFFFFFF]
            wh_spans = [s for s in line["spans"] if s["color"] == 0xFFFFFF]
            if fg_spans:
                fg_boxes.append(lb)
                raw_lines.append((lb, fg_spans, False))
            if wh_spans:
                raw_lines.append((lb, wh_spans, True))

    kept_lines: List[ExtractedLine] = []
    for lb, spans, is_white in raw_lines:
        if is_white:
            # Drop white drop-shadow spans that overlap a foreground line within 4pt
            overlaps_fg = any(
                abs(lb[1] - fb[1]) < 4.5
                and min(lb[2], fb[2]) - max(lb[0], fb[0]) > 5.0
                for fb in fg_boxes
            )
            if overlaps_fg:
                continue

        text = reconstruct_rtl_line(spans)
        if not text:
            continue
        # Ignore standalone decorative digits or watermarks of 1 char unless numbered
        max_size = max(s.get("size", 14.0) for s in spans)
        dom_color = spans[0].get("color", 0)
        is_bold = any(
            "Bold" in s.get("font", "") or "Mateen" in s.get("font", "")
            for s in spans
        )
        x0, y0, x1, y1 = lb
        width = x1 - x0

        kept_lines.append(
            ExtractedLine(
                page=page_num,
                y0=y0,
                y1=y1,
                x0=x0,
                x1=x1,
                size=max_size,
                color=dom_color,
                is_bold=is_bold,
                zone="main",
                text=text,
            )
        )

    # Geometrically classify left/right sidebars ONLY when another column coexists
    # in the same vertical band (±28 pt), preventing short RTL paragraph tail
    # lines (x=370..450) from ever being misclassified as right sidebars.
    for ln in kept_lines:
        width = ln.x1 - ln.x0
        if width < 175.0 and ln.x1 < 190.0:
            has_right_neighbor = any(
                other is not ln
                and abs(other.y0 - ln.y0) <= 32.0
                and other.x0 >= ln.x1 - 6.0
                for other in kept_lines
            )
            if has_right_neighbor:
                ln.zone = "sidebar_left"
        elif width < 145.0 and ln.x0 > 332.0:
            has_left_body = any(
                other is not ln
                and abs(other.y0 - ln.y0) <= 32.0
                and other.x1 <= ln.x0 + 6.0
                and other.x1 > 235.0
                and (other.x1 - other.x0) > 180.0
                for other in kept_lines
            )
            if has_left_body:
                ln.zone = "sidebar_right"

    # Bucket main lines within ±4.5 pt in y; keep left and right sidebars separate
    main_raw = [ln for ln in kept_lines if ln.zone == "main"]
    side_right = [ln for ln in kept_lines if ln.zone == "sidebar_right"]
    side_left = [ln for ln in kept_lines if ln.zone == "sidebar_left"]

    main_sorted = _merge_visual_rows(main_raw)
    side_sorted = _merge_visual_rows(side_right) + _merge_visual_rows(side_left)

    return ExtractedPage(page=page_num, main_lines=main_sorted, sidebar_lines=side_sorted)


def _merge_visual_rows(lines: List[ExtractedLine]) -> List[ExtractedLine]:
    if not lines:
        return []
    lines = sorted(lines, key=lambda l: (l.y0, -l.x1))
    rows: List[List[ExtractedLine]] = []
    for ln in lines:
        if rows and abs(ln.y0 - rows[-1][0].y0) <= 4.5:
            rows[-1].append(ln)
        else:
            rows.append([ln])

    merged: List[ExtractedLine] = []
    for row in rows:
        row.sort(key=lambda l: -l.x1)
        if len(row) == 1:
            merged.append(row[0])
            continue
        # Never concatenate separate white-banner section titles on the same y
        if any(r.color == 0xFFFFFF and r.size >= 16.5 for r in row):
            merged.extend(row)
            continue
        # Check if row consists of two non-overlapping poetic hemistichs or columns
        non_overlapping = all(
            row[idx].x0 >= row[idx + 1].x1 - 8.0 for idx in range(len(row) - 1)
        )
        if non_overlapping and len(row) == 2:
            gap = row[0].x0 - row[1].x1
            # Poetic hemistichs have a distinct middle gap (12..90 pt) around x=290..320
            if (
                gap >= 10.0
                and 270.0 <= row[0].x0 <= 355.0
                and 240.0 <= row[1].x1 <= 330.0
                and len(row[0].text) >= 10
                and len(row[1].text) >= 10
            ):
                combined = f"{row[0].text}   ✦   {row[1].text}"
            else:
                combined = f"{row[0].text} {row[1].text}"
            merged.append(
                ExtractedLine(
                    page=row[0].page,
                    y0=min(r.y0 for r in row),
                    y1=max(r.y1 for r in row),
                    x0=min(r.x0 for r in row),
                    x1=max(r.x1 for r in row),
                    size=max(r.size for r in row),
                    color=row[0].color,
                    is_bold=any(r.is_bold for r in row),
                    zone=row[0].zone,
                    text=combined,
                )
            )
        else:
            joined = " ".join(r.text for r in row)
            merged.append(
                ExtractedLine(
                    page=row[0].page,
                    y0=min(r.y0 for r in row),
                    y1=max(r.y1 for r in row),
                    x0=min(r.x0 for r in row),
                    x1=max(r.x1 for r in row),
                    size=max(r.size for r in row),
                    color=row[0].color,
                    is_bold=any(r.is_bold for r in row),
                    zone=row[0].zone,
                    text=joined,
                )
            )
    return merged
