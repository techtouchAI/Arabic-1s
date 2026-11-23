#!/usr/bin/env python3
"""Generate pure-vector SVG grammatical/literary diagrams and app icons.

Every SVG uses pure geometric primitives (no <text> elements) so flutter_svg
renders identically on Android, Windows, and headless test environments while
Flutter renders the Arabic caption and color-coded legend pills with bundled
Arabic fonts.
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path
from typing import Dict

ROOT = Path(__file__).resolve().parents[1]
ILLUSTRATIONS_DIR = ROOT / "assets" / "illustrations"
BRANDING_DIR = ROOT / "assets" / "branding"

SVGS: Dict[str, str] = {
    "integrative-method": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 460">
  <rect x="40" y="36" width="720" height="388" rx="22" fill="#F6EFE2" opacity="0.7"/>
  <circle cx="400" cy="230" r="82" fill="#1B5E6B"/>
  <circle cx="400" cy="230" r="56" fill="#FAF4E8"/>
  <path d="M372 246 L400 198 L428 246 Z" fill="#9E3B26"/>
  <line x1="400" y1="148" x2="400" y2="94" stroke="#2C2E38" stroke-width="4" stroke-dasharray="6 6"/>
  <line x1="482" y1="230" x2="576" y2="230" stroke="#2C2E38" stroke-width="4" stroke-dasharray="6 6"/>
  <line x1="318" y1="230" x2="224" y2="230" stroke="#2C2E38" stroke-width="4" stroke-dasharray="6 6"/>
  <line x1="400" y1="312" x2="400" y2="366" stroke="#2C2E38" stroke-width="4" stroke-dasharray="6 6"/>
  <rect x="330" y="48" width="140" height="48" rx="14" fill="#9E3B26"/>
  <rect x="576" y="202" width="140" height="56" rx="14" fill="#C28B2C"/>
  <rect x="84" y="202" width="140" height="56" rx="14" fill="#3E704F"/>
  <rect x="330" y="364" width="140" height="48" rx="14" fill="#2C2E38"/>
</svg>""",
    "speech-parts": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 460">
  <rect x="300" y="42" width="200" height="68" rx="18" fill="#2C2E38"/>
  <circle cx="400" cy="76" r="16" fill="#FAF4E8"/>
  <path d="M400 110 L400 165 M400 165 L175 165 L175 215 M400 165 L400 215 M400 165 L625 165 L625 215" fill="none" stroke="#2C2E38" stroke-width="5" stroke-linecap="round"/>
  <rect x="530" y="215" width="190" height="175" rx="20" fill="#9E3B26"/>
  <circle cx="625" cy="275" r="30" fill="#FAF4E8" opacity="0.92"/>
  <rect x="565" y="330" width="120" height="14" rx="7" fill="#FAF4E8" opacity="0.8"/>
  <rect x="305" y="215" width="190" height="175" rx="20" fill="#1B5E6B"/>
  <polygon points="400,248 434,304 366,304" fill="#FAF4E8" opacity="0.92"/>
  <rect x="340" y="330" width="120" height="14" rx="7" fill="#FAF4E8" opacity="0.8"/>
  <rect x="80" y="215" width="190" height="175" rx="20" fill="#C28B2C"/>
  <rect x="148" y="250" width="54" height="54" rx="12" fill="#FAF4E8" opacity="0.92"/>
  <rect x="115" y="330" width="120" height="14" rx="7" fill="#FAF4E8" opacity="0.8"/>
</svg>""",
    "tanween-forms": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 440">
  <rect x="52" y="54" width="696" height="332" rx="24" fill="#F6EFE2" opacity="0.65"/>
  <g transform="translate(530,96)">
    <rect x="0" y="0" width="180" height="248" rx="20" fill="#FAF4E8" stroke="#9E3B26" stroke-width="4"/>
    <circle cx="72" cy="76" r="18" fill="#9E3B26"/>
    <circle cx="108" cy="76" r="18" fill="#9E3B26"/>
    <rect x="36" y="150" width="108" height="18" rx="9" fill="#2C2E38"/>
  </g>
  <g transform="translate(310,96)">
    <rect x="0" y="0" width="180" height="248" rx="20" fill="#FAF4E8" stroke="#C28B2C" stroke-width="4"/>
    <line x1="62" y1="84" x2="118" y2="58" stroke="#C28B2C" stroke-width="10" stroke-linecap="round"/>
    <line x1="62" y1="108" x2="118" y2="82" stroke="#C28B2C" stroke-width="10" stroke-linecap="round"/>
    <rect x="36" y="150" width="108" height="18" rx="9" fill="#2C2E38"/>
  </g>
  <g transform="translate(90,96)">
    <rect x="0" y="0" width="180" height="248" rx="20" fill="#FAF4E8" stroke="#3E704F" stroke-width="4"/>
    <rect x="36" y="112" width="108" height="18" rx="9" fill="#2C2E38"/>
    <line x1="62" y1="184" x2="118" y2="158" stroke="#3E704F" stroke-width="10" stroke-linecap="round"/>
    <line x1="62" y1="208" x2="118" y2="182" stroke="#3E704F" stroke-width="10" stroke-linecap="round"/>
  </g>
</svg>""",
    "murab-mabni": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 450">
  <rect x="420" y="56" width="330" height="338" rx="22" fill="#1B5E6B" opacity="0.12" stroke="#1B5E6B" stroke-width="3"/>
  <circle cx="585" cy="146" r="42" fill="#1B5E6B"/>
  <circle cx="505" cy="276" r="32" fill="#3E704F"/>
  <circle cx="585" cy="276" r="32" fill="#9E3B26"/>
  <circle cx="665" cy="276" r="32" fill="#C28B2C"/>
  <path d="M585 188 L505 244 M585 188 L585 244 M585 188 L665 244" stroke="#1B5E6B" stroke-width="4"/>
  <rect x="50" y="56" width="330" height="338" rx="22" fill="#9E3B26" opacity="0.12" stroke="#9E3B26" stroke-width="3"/>
  <rect x="155" y="118" width="120" height="120" rx="18" fill="#9E3B26"/>
  <rect x="183" y="146" width="64" height="64" rx="10" fill="#FAF4E8"/>
  <rect x="115" y="286" width="200" height="22" rx="11" fill="#2C2E38"/>
</svg>""",
    "alam-types": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 450">
  <circle cx="400" cy="84" r="46" fill="#2C2E38"/>
  <path d="M400 130 L400 176 M140 176 L660 176 M140 176 L140 226 M313 176 L313 226 M486 176 L486 226 M660 176 L660 226" fill="none" stroke="#2C2E38" stroke-width="4"/>
  <rect x="590" y="226" width="140" height="162" rx="18" fill="#3E704F"/>
  <circle cx="660" cy="296" r="28" fill="#FAF4E8"/>
  <rect x="416" y="226" width="140" height="162" rx="18" fill="#9E3B26"/>
  <rect x="442" y="274" width="38" height="44" rx="8" fill="#FAF4E8"/>
  <rect x="492" y="274" width="38" height="44" rx="8" fill="#FAF4E8" opacity="0.75"/>
  <rect x="243" y="226" width="140" height="162" rx="18" fill="#1B5E6B"/>
  <path d="M276 296 A26 26 0 1 1 324 296 A26 26 0 1 1 350 296" fill="none" stroke="#FAF4E8" stroke-width="10" stroke-linecap="round"/>
  <rect x="70" y="226" width="140" height="162" rx="18" fill="#C28B2C"/>
  <polygon points="140,262 174,324 106,324" fill="#FAF4E8"/>
</svg>""",
    "sun-moon-letters": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 440">
  <rect x="424" y="48" width="328" height="344" rx="24" fill="#1B5E6B"/>
  <path d="M620 140 A76 76 0 1 0 620 292 A58 58 0 1 1 620 140 Z" fill="#FAF4E8"/>
  <circle cx="520" cy="168" r="8" fill="#C28B2C"/>
  <circle cx="496" cy="222" r="6" fill="#C28B2C"/>
  <rect x="48" y="48" width="328" height="344" rx="24" fill="#C28B2C"/>
  <circle cx="212" cy="216" r="58" fill="#FAF4E8"/>
  <g stroke="#FAF4E8" stroke-width="8" stroke-linecap="round">
    <line x1="212" y1="126" x2="212" y2="100"/>
    <line x1="212" y1="306" x2="212" y2="332"/>
    <line x1="122" y1="216" x2="96" y2="216"/>
    <line x1="302" y1="216" x2="328" y2="216"/>
    <line x1="148" y1="152" x2="130" y2="134"/>
    <line x1="276" y1="280" x2="294" y2="298"/>
    <line x1="276" y1="152" x2="294" y2="134"/>
    <line x1="148" y1="280" x2="130" y2="298"/>
  </g>
</svg>""",
    "pronouns-map": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 450">
  <rect x="44" y="44" width="712" height="362" rx="24" fill="#F6EFE2" opacity="0.6"/>
  <circle cx="600" cy="225" r="76" fill="#9E3B26"/>
  <circle cx="600" cy="225" r="34" fill="#FAF4E8"/>
  <circle cx="400" cy="225" r="76" fill="#1B5E6B"/>
  <path d="M362 225 L438 225" stroke="#FAF4E8" stroke-width="14" stroke-linecap="round"/>
  <circle cx="362" cy="225" r="16" fill="#C28B2C"/>
  <circle cx="200" cy="225" r="76" fill="none" stroke="#3E704F" stroke-width="8" stroke-dasharray="12 10"/>
  <circle cx="200" cy="225" r="28" fill="#3E704F" opacity="0.5"/>
</svg>""",
    "demonstratives-relatives": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 440">
  <rect x="430" y="62" width="320" height="316" rx="22" fill="#9E3B26" opacity="0.12" stroke="#9E3B26" stroke-width="3"/>
  <circle cx="670" cy="220" r="24" fill="#9E3B26"/>
  <line x1="646" y1="220" x2="510" y2="220" stroke="#9E3B26" stroke-width="8" stroke-linecap="round"/>
  <polygon points="490,220 524,198 524,242" fill="#9E3B26"/>
  <rect x="50" y="62" width="320" height="316" rx="22" fill="#1B5E6B" opacity="0.12" stroke="#1B5E6B" stroke-width="3"/>
  <rect x="86" y="182" width="96" height="76" rx="16" fill="#1B5E6B"/>
  <rect x="238" y="182" width="96" height="76" rx="16" fill="#3E704F"/>
  <path d="M182 220 C198 184 222 184 238 220 C222 256 198 256 182 220 Z" fill="#C28B2C"/>
</svg>""",
    "maarif-overview": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 450">
  <rect x="64" y="60" width="672" height="330" rx="24" fill="#F6EFE2" opacity="0.65"/>
  <rect x="454" y="146" width="212" height="158" rx="20" fill="#C28B2C"/>
  <circle cx="560" cy="225" r="34" fill="#FAF4E8" opacity="0.85"/>
  <rect x="134" y="146" width="212" height="158" rx="20" fill="#9E3B26"/>
  <polygon points="240,185 280,258 200,258" fill="#FAF4E8"/>
  <path d="M454 225 L346 225" stroke="#2C2E38" stroke-width="10" stroke-linecap="round"/>
  <polygon points="346,225 376,204 376,246" fill="#2C2E38"/>
</svg>""",
    "past-imperative-building": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 440">
  <rect x="536" y="96" width="200" height="248" rx="20" fill="#9E3B26"/>
  <line x1="604" y1="176" x2="668" y2="148" stroke="#FAF4E8" stroke-width="12" stroke-linecap="round"/>
  <rect x="300" y="96" width="200" height="248" rx="20" fill="#1B5E6B"/>
  <circle cx="400" cy="168" r="24" fill="none" stroke="#FAF4E8" stroke-width="10"/>
  <rect x="64" y="96" width="200" height="248" rx="20" fill="#3E704F"/>
  <circle cx="164" cy="164" r="20" fill="#FAF4E8"/>
  <path d="M180 174 Q164 214 136 206" fill="none" stroke="#FAF4E8" stroke-width="10" stroke-linecap="round"/>
</svg>""",
    "mudari-cases": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 450">
  <polygon points="400,56 710,384 90,384" fill="#F6EFE2" stroke="#2C2E38" stroke-width="3"/>
  <circle cx="400" cy="132" r="44" fill="#3E704F"/>
  <circle cx="556" cy="316" r="44" fill="#1B5E6B"/>
  <circle cx="244" cy="316" r="44" fill="#9E3B26"/>
  <line x1="400" y1="176" x2="528" y2="282" stroke="#2C2E38" stroke-width="4" stroke-dasharray="7 7"/>
  <line x1="400" y1="176" x2="272" y2="282" stroke="#2C2E38" stroke-width="4" stroke-dasharray="7 7"/>
  <line x1="498" y1="316" x2="302" y2="316" stroke="#2C2E38" stroke-width="4" stroke-dasharray="7 7"/>
</svg>""",
    "five-verbs": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 450">
  <circle cx="400" cy="225" r="64" fill="#2C2E38"/>
  <circle cx="400" cy="76" r="40" fill="#3E704F"/>
  <circle cx="556" cy="168" r="40" fill="#3E704F"/>
  <circle cx="504" cy="348" r="40" fill="#9E3B26"/>
  <circle cx="296" cy="348" r="40" fill="#9E3B26"/>
  <circle cx="244" cy="168" r="40" fill="#C28B2C"/>
  <g stroke="#2C2E38" stroke-width="4">
    <line x1="400" y1="161" x2="400" y2="116"/>
    <line x1="458" y1="198" x2="518" y2="180"/>
    <line x1="440" y1="276" x2="478" y2="318"/>
    <line x1="360" y1="276" x2="322" y2="318"/>
    <line x1="342" y1="198" x2="282" y2="180"/>
  </g>
</svg>""",
    "verbal-sentence": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 420">
  <rect x="546" y="110" width="194" height="200" rx="22" fill="#1B5E6B"/>
  <polygon points="643,164 683,238 603,238" fill="#FAF4E8"/>
  <rect x="303" y="110" width="194" height="200" rx="22" fill="#3E704F"/>
  <circle cx="400" cy="205" r="38" fill="#FAF4E8"/>
  <rect x="60" y="110" width="194" height="200" rx="22" fill="#9E3B26"/>
  <rect x="122" y="170" width="70" height="70" rx="14" fill="#FAF4E8"/>
  <line x1="546" y1="210" x2="497" y2="210" stroke="#2C2E38" stroke-width="8"/>
  <line x1="303" y1="210" x2="254" y2="210" stroke="#2C2E38" stroke-width="8"/>
</svg>""",
    "taa-orthography": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 430">
  <rect x="424" y="68" width="320" height="294" rx="24" fill="#FAF4E8" stroke="#9E3B26" stroke-width="5"/>
  <path d="M510 218 L510 262 L658 262 L658 218" fill="none" stroke="#9E3B26" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="566" cy="176" r="12" fill="#9E3B26"/>
  <circle cx="602" cy="176" r="12" fill="#9E3B26"/>
  <rect x="56" y="68" width="320" height="294" rx="24" fill="#FAF4E8" stroke="#1B5E6B" stroke-width="5"/>
  <circle cx="216" cy="236" r="44" fill="none" stroke="#1B5E6B" stroke-width="14"/>
  <circle cx="198" cy="162" r="12" fill="#1B5E6B"/>
  <circle cx="234" cy="162" r="12" fill="#1B5E6B"/>
</svg>""",
    "nominal-sentence": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 450">
  <rect x="510" y="128" width="224" height="194" rx="22" fill="#1B5E6B"/>
  <circle cx="622" cy="225" r="42" fill="#FAF4E8"/>
  <path d="M510 225 L390 225 M390 112 L390 338 M390 112 L310 112 M390 225 L310 225 M390 338 L310 338" fill="none" stroke="#2C2E38" stroke-width="6" stroke-linecap="round"/>
  <rect x="74" y="72" width="236" height="80" rx="16" fill="#3E704F"/>
  <rect x="74" y="185" width="236" height="80" rx="16" fill="#C28B2C"/>
  <rect x="74" y="298" width="236" height="80" rx="16" fill="#9E3B26"/>
</svg>""",
    "kana-inna": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 440">
  <rect x="424" y="60" width="324" height="320" rx="22" fill="#1B5E6B" opacity="0.12" stroke="#1B5E6B" stroke-width="4"/>
  <rect x="462" y="102" width="248" height="58" rx="14" fill="#1B5E6B"/>
  <circle cx="642" cy="260" r="42" fill="#3E704F"/>
  <rect x="484" y="220" width="80" height="80" rx="16" fill="#9E3B26"/>
  <rect x="52" y="60" width="324" height="320" rx="22" fill="#9E3B26" opacity="0.12" stroke="#9E3B26" stroke-width="4"/>
  <rect x="90" y="102" width="248" height="58" rx="14" fill="#9E3B26"/>
  <rect x="228" y="220" width="80" height="80" rx="16" fill="#9E3B26"/>
  <circle cx="148" cy="260" r="42" fill="#3E704F"/>
</svg>""",
}


def _make_png(size: int) -> bytes:
    """Create a clean, crisp RGBA PNG app icon (warm parchment nib + arch)."""
    rows = []
    cx = cy = (size - 1) / 2.0
    r_bg = size * 0.46
    corner = size * 0.22
    for y in range(size):
        row = bytearray([0])  # filter type 0
        for x in range(size):
            # Rounded square mask
            dx = max(abs(x - cx) - (r_bg - corner), 0.0)
            dy = max(abs(y - cy) - (r_bg - corner), 0.0)
            dist = (dx * dx + dy * dy) ** 0.5
            if dist > corner + 1.0:
                row.extend((0, 0, 0, 0))
                continue
            alpha = 255 if dist <= corner else int(255 * (corner + 1.0 - dist))

            # Terracotta / deep Mesopotamian teal motif with calligraphy nib
            nx = (x - cx) / (size * 0.5)
            ny = (y - cy) / (size * 0.5)
            # Nib diamond + central slit + gold dot (Arabic ب / ن dot)
            in_nib = abs(nx) * 1.45 + abs(ny + 0.06) <= 0.62 and ny < 0.45
            in_dot = (nx * nx + (ny - 0.52) ** 2) <= 0.018
            in_slit = abs(nx) < 0.025 and -0.35 < ny < 0.12
            if in_dot:
                r, g, b = (217, 163, 74)  # warm gold
            elif in_nib and not in_slit:
                r, g, b = (250, 244, 232)  # parchment
            else:
                # Subtle diagonal gradient between deep teal and terracotta
                t = max(0.0, min(1.0, 0.5 + 0.4 * (nx + ny)))
                r = int(27 * (1 - t) + 158 * t)
                g = int(94 * (1 - t) + 59 * t)
                b = int(107 * (1 - t) + 38 * t)
            row.extend((r, g, b, alpha))
        rows.append(bytes(row))

    raw = b"".join(rows)

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def _make_ico(png_bytes: bytes, size: int = 256) -> bytes:
    """Wrap a PNG image in a valid Windows ICO container."""
    dim = 0 if size >= 256 else size
    header = struct.pack("<HHH", 0, 1, 1)
    entry = struct.pack(
        "<BBBBHHII",
        dim,
        dim,
        0,
        0,
        1,
        32,
        len(png_bytes),
        6 + 16,
    )
    return header + entry + png_bytes


def generate_all() -> None:
    ILLUSTRATIONS_DIR.mkdir(parents=True, exist_ok=True)
    for name, svg in SVGS.items():
        (ILLUSTRATIONS_DIR / f"{name}.svg").write_text(svg.strip() + "\n", encoding="utf-8")

    BRANDING_DIR.mkdir(parents=True, exist_ok=True)
    png_512 = _make_png(512)
    png_256 = _make_png(256)
    png_192 = _make_png(192)
    (BRANDING_DIR / "app_icon.png").write_bytes(png_512)
    (BRANDING_DIR / "app_icon_192.png").write_bytes(png_192)

    win_res = ROOT / "windows" / "runner" / "resources"
    win_res.mkdir(parents=True, exist_ok=True)
    (win_res / "app_icon.ico").write_bytes(_make_ico(png_256, 256))

    # Android mipmap launcher icons
    mipmap_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    android_res = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, px in mipmap_sizes.items():
        target = android_res / folder
        target.mkdir(parents=True, exist_ok=True)
        (target / "ic_launcher.png").write_bytes(_make_png(px))


if __name__ == "__main__":
    generate_all()
    print(f"generated {len(SVGS)} SVG illustrations + Android/Windows icons")
