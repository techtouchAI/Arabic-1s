"""Regression tests against the four real Word sources (standard library only)."""
import json
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET
from zipfile import ZipFile

from official_exam_importer import SOURCES, _items, load_official_templates

ROOT = Path(__file__).resolve().parents[1]
NS = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}


def arabic(text):
    # Compare every Arabic letter/diacritic, independent of Word's layout spaces,
    # automatic/manual list labels and punctuation. Shape is checked separately.
    return "".join(re.findall(r"[\u0621-\u065f]", text))


class OfficialExamImportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.templates = load_official_templates(ROOT)

    def test_every_question_in_source_order_without_transcription(self):
        for source, template in zip(SOURCES, self.templates):
            with self.subTest(source=source[0]):
                with ZipFile(ROOT / source[0]) as z:
                    doc = ET.fromstring(z.read("word/document.xml"))
                source_text = []
                inside = False
                for p in doc.findall("w:body/w:p", NS):
                    text = "".join(t.text or "" for t in p.findall(".//w:t", NS)).strip()
                    if text.startswith("الانشاء"):
                        inside = True
                    if text.startswith("مدرس المادة"):
                        break
                    if not inside or not text:
                        continue
                    text = re.sub(r"\(\s*\d+\s+درج[ةات]+\s*\)\s*$", "", text)
                    text = re.sub(r"^س\s*\d+\s*/\s*", "", text)
                    text = re.sub(r"^[أبجدهـ]+\s*[-–/]\s*", "", text)
                    source_text.append(text)
                rendered = ["الانشاء :", template["composition"]["prompt"], *template["composition"]["topics"]]
                for key, title in (("grammar", "قواعد اللغة العربية"), ("orthography", "الاملاء")):
                    rendered.append(title)
                    for q in template[key]["questions"]:
                        for b in q["branches"]:
                            rendered.extend([b["prompt"], *b["items"]])
                self.assertEqual(arabic("".join(rendered)), arabic("".join(source_text)))

    def test_question_branch_degree_layout_and_count(self):
        midyear = [[(6, "vertical", 4), (4, "vertical", 2)], [(10, "vertical", 6)], [(10, "vertical", 6), (5, "prose", 1)]]
        final = [[(10, "vertical", 7), (5, "prose", 0)], [(6, "inline", 3), (4, "vertical", 2)], [(6, "vertical", 6), (4, "inline", 3)]]
        for t in self.templates:
            with self.subTest(template=t["id"]):
                self.assertEqual([q["number"] for q in t["grammar"]["questions"]], [1, 2, 3])
                shape = [[(b["degree"], b["layout"], len(b["items"])) for b in q["branches"]] for q in t["grammar"]["questions"]]
                self.assertEqual(shape, midyear if t["part"] == "part1" else final)
                self.assertEqual([b["degree"] for b in t["orthography"]["questions"][0]["branches"]], [5, 6, 4] if t["part"] == "part1" else [5, 5, 5])
                self.assertEqual(len(t["composition"]["topics"]), 2)
                self.assertEqual(t["academicYear"], "2024-2025")

    def test_continuations_underlines_and_nested_numbering(self):
        self.assertIn("\nواحسن", self.templates[1]["composition"]["topics"][1])
        items = self.templates[0]["grammar"]["questions"][2]["branches"][0]["items"]
        self.assertIn("_سيبويه_", items[1])
        self.assertIn("1- سافرتُ", items[2])
        self.assertIn("2- سافرتْ", items[2])
        self.assertEqual(_items("1-\tنص 1- داخلي 2- داخلي", False), ("vertical", ["نص 1- داخلي 2- داخلي"]))
        self.assertEqual(_items("أول    2- ثان    3- ثالث", True), ("inline", ["أول", "ثان", "ثالث"]))

    def test_generated_assets_match_sources(self):
        data = json.loads((ROOT / "assets/content/exam_bank.json").read_text())
        self.assertEqual(data["officialTemplates"], self.templates)


if __name__ == "__main__":
    unittest.main()
