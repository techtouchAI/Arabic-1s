"""Import question structure from the repository's authoritative Word papers.

Only source metadata is configured here; question text, order, marks, numbering,
inline lists and underlining are read from OOXML, never transcribed by hand.
"""
from __future__ import annotations

from pathlib import Path
import re
import xml.etree.ElementTree as ET
from zipfile import ZipFile

NS = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
W = "{" + NS["w"] + "}"
SOURCES = (
    ("الدور الاول.docx", "tpl-midyear-r1", "part1", "الدور الأول"),
    ("الدور الثاتيي.docx", "tpl-midyear-r2", "part1", "الدور الثاني"),
    ("الدور الاول 2025.docx", "tpl-final-r1", "part2", "الدور الأول"),
    ("الدور الثاني 2025.docx", "tpl-final-r2", "part2", "الدور الثاني"),
)
DEGREE = re.compile(r"\(\s*(\d+)\s+درج[ةات]+\s*\)\s*$")
QUESTION = re.compile(r"^س\s*(\d+)\s*/\s*")
BRANCH = re.compile(r"^([أبجدهـ]+)\s*[-–/]\s*")
ITEM = re.compile(r"(?:^|\s)(\d+)\s*[-–]\s*")


def paragraph_text(p: ET.Element, *, rich: bool = False) -> str:
    parts: list[str] = []
    for run in p.findall("w:r", NS):
        text = "".join(
            node.text or "" if node.tag == W + "t" else "\n" if node.tag == W + "br" else "\t"
            for node in run if node.tag in {W + "t", W + "br", W + "tab"}
        )
        underline = run.find("w:rPr/w:u", NS)
        if rich and underline is not None and underline.get(W + "val") not in {"none", "0", "false"} and text.strip():
            # Keep surrounding whitespace outside semantic underline markers.
            text = text[:len(text) - len(text.lstrip())] + "_" + text.strip() + "_" + text[len(text.rstrip()):]
        parts.append(text)
    return "".join(parts).strip()


def _items(text: str, auto_numbered: bool) -> tuple[str, list[str]]:
    manual = re.match(r"^\d+\s*[-–]\t\s*", text)
    if manual:
        return "vertical", [text[manual.end():]]
    if text.startswith("(") and not auto_numbered:
        return "prose", [text]
    markers = list(ITEM.finditer(text))
    if markers and (markers[0].group(1) == "1" or auto_numbered):
        chunks = []
        start = 0
        for marker in markers:
            if marker.start() > start and text[start:marker.start()].strip():
                chunks.append(text[start:marker.start()].strip())
            start = marker.end()
        if text[start:].strip():
            chunks.append(text[start:].strip())
        return ("inline" if len(chunks) > 1 else "vertical", chunks)
    return ("vertical" if auto_numbered else "prose", [text])


def import_template(root: Path, source: tuple[str, str, str, str]) -> dict:
    filename, template_id, part, round_label = source
    with ZipFile(root / filename) as archive:
        doc = ET.fromstring(archive.read("word/document.xml"))
    paragraphs = doc.findall("w:body/w:p", NS)
    all_text = "\n".join(paragraph_text(p) for p in paragraphs)
    year = re.search(r"\d{4}-\d{4}", all_text)
    title = "اسئلة امتحان نصف السنة" if part == "part1" else "اسئلة امتحان نهاية السنة"
    result = dict(id=template_id, label=f"{title} — {round_label} (الرسمي)", part=part,
                  sourceFile=filename, examTitle=title, roleLabel=round_label,
                  academicYear=year.group() if year else "", duration="ساعة ونصف",
                  showStudentFields="اسم الطالب" in all_text)
    section = None
    current_branch = None
    for p in paragraphs:
        plain = paragraph_text(p)
        if plain.startswith("مدرس المادة"):
            break
        if not plain:
            continue
        degree = DEGREE.search(plain)
        if plain.startswith(("الانشاء", "قواعد اللغة العربية", "الاملاء")):
            if degree is None:
                raise ValueError(f"{filename}: section without marks: {plain}")
            key = "composition" if plain.startswith("الانشاء") else "grammar" if plain.startswith("قواعد") else "orthography"
            section = dict(degree=int(degree[1]))
            result[key] = section
            if key == "composition":
                section.update(topics=[])
                section["prompt"] = DEGREE.sub("", plain.split(":", 1)[1]).strip()
            else:
                section["questions"] = []
            current_branch = None
            continue
        if section is None:
            continue
        rich = paragraph_text(p, rich=True)
        numbered = p.find("w:pPr/w:numPr", NS) is not None
        if "topics" in section:
            if numbered:
                section["topics"].append(rich)
            elif section["topics"]:
                section["topics"][-1] += "\n" + rich
            else:
                raise ValueError(f"{filename}: unnumbered first topic")
            continue
        if degree:
            prompt = DEGREE.sub("", rich).strip()
            question = QUESTION.match(prompt)
            if question:
                section["questions"].append(dict(number=int(question[1]), branches=[]))
                prompt = prompt[question.end():]
            branch = BRANCH.match(prompt)
            if not section["questions"]:
                raise ValueError(f"{filename}: branch before question")
            current_branch = dict(branch=branch[1] if branch else "", prompt=prompt[branch.end():] if branch else prompt,
                                  degree=int(degree[1]), layout="prose", items=[])
            section["questions"][-1]["branches"].append(current_branch)
        elif current_branch is not None:
            layout, items = _items(rich, numbered)
            # Multiple unnumbered paragraphs are one prose item with explicit breaks.
            if current_branch["items"] and current_branch["layout"] == layout == "prose":
                current_branch["items"][-1] += "\n" + items[0]
            else:
                current_branch["layout"] = layout
                current_branch["items"].extend(items)
        else:
            raise ValueError(f"{filename}: orphan paragraph: {plain}")
    for key in ("grammar", "orthography"):
        actual = sum(b["degree"] for q in result[key]["questions"] for b in q["branches"])
        if actual != result[key]["degree"]:
            raise ValueError(f"{filename}: {key} marks mismatch")
    return result


def load_official_templates(root: Path | None = None) -> list[dict]:
    root = root or Path(__file__).resolve().parents[1]
    return [import_template(root, source) for source in SOURCES]
