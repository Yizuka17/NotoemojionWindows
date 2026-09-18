#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import os
from pathlib import Path
import sys

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._c_m_a_p import CmapSubtable

IDENTITY_NAME_IDS = {1, 2, 3, 4, 6, 16, 17, 21, 22, 25}

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().upper()

def best_unicode_cmap(font: TTFont):
    candidates = []
    for table in font["cmap"].tables:
        if not table.isUnicode():
            continue
        score = 0
        if table.format == 12:
            score += 100
        if table.platformID == 3 and table.platEncID == 10:
            score += 50
        candidates.append((score, table))
    if not candidates:
        raise RuntimeError("No Unicode cmap found.")
    return max(candidates, key=lambda item: item[0])[1]

def ensure_windows_cmaps(font: TTFont) -> None:
    cmap = font["cmap"]
    full = best_unicode_cmap(font)

    has_bmp = any(
        t.platformID == 3 and t.platEncID == 1 and t.format == 4
        for t in cmap.tables
    )
    if not has_bmp:
        bmp = CmapSubtable.newSubtable(4)
        bmp.platformID = 3
        bmp.platEncID = 1
        bmp.language = 0
        bmp.cmap = {cp: glyph for cp, glyph in full.cmap.items() if cp <= 0xFFFF}
        cmap.tables.append(bmp)

    has_full = any(
        t.platformID == 3 and t.platEncID == 10 and t.format == 12
        for t in cmap.tables
    )
    if not has_full:
        fmt12 = CmapSubtable.newSubtable(12)
        fmt12.platformID = 3
        fmt12.platEncID = 10
        fmt12.language = 0
        fmt12.cmap = dict(full.cmap)
        cmap.tables.append(fmt12)

def copy_segoe_identity(source: TTFont, template: TTFont) -> int:
    source_name = source["name"]
    template_name = template["name"]

    source_name.names = [
        rec for rec in source_name.names if rec.nameID not in IDENTITY_NAME_IDS
    ]
    copied = [
        copy.deepcopy(rec)
        for rec in template_name.names
        if rec.nameID in IDENTITY_NAME_IDS
    ]
    if not copied:
        raise RuntimeError("Segoe UI Emoji template has no usable identity names.")

    source_name.names.extend(copied)
    return len(copied)

def tune_directwrite(source: TTFont, template: TTFont) -> None:
    # emoji-win showed that DirectWrite is sensitive to OS/2 typography metrics.
    # Pull them from the user's own Segoe UI Emoji build instead of hard-coding
    # one Windows version.
    if "OS/2" in source and "OS/2" in template:
        src = source["OS/2"]
        tpl = template["OS/2"]
        for attr in (
            "sTypoAscender",
            "sTypoDescender",
            "sTypoLineGap",
            "usWinAscent",
            "usWinDescent",
        ):
            if hasattr(src, attr) and hasattr(tpl, attr):
                setattr(src, attr, getattr(tpl, attr))

        # Regular + USE_TYPO_METRICS. Preserve unrelated selection bits.
        src.fsSelection = (src.fsSelection | (1 << 6) | (1 << 7)) & ~(1 << 0)

    if "head" in source:
        source["head"].macStyle = 0

    if "post" in source:
        source["post"].formatType = 3.0

def validate_source(font: TTFont) -> None:
    required = {"cmap", "name", "head", "hhea", "maxp", "hmtx", "OS/2"}
    missing = sorted(required - set(font.keys()))
    if missing:
        raise RuntimeError("Source font is missing required tables: " + ", ".join(missing))

    if not ({"CBDT", "CBLC"} <= set(font.keys()) or {"COLR", "CPAL"} <= set(font.keys())):
        raise RuntimeError("Source font has no supported color emoji tables.")

    # The official Windows-compatible Noto build should already contain these.
    if "glyf" not in font or "loca" not in font:
        raise RuntimeError(
            "Source has no glyf/loca tables. Use NotoColorEmoji_WindowsCompatible.ttf."
        )

def identity_snapshot(font: TTFont):
    out = {}
    for rec in font["name"].names:
        if rec.nameID in IDENTITY_NAME_IDS:
            key = (rec.nameID, rec.platformID, rec.platEncID, rec.langID)
            try:
                value = rec.toUnicode()
            except Exception:
                value = bytes(rec.string)
            out[key] = value
    return out

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert Google's Windows-compatible Noto Color Emoji into a Segoe UI Emoji replacement."
    )
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--template", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    if not args.source.is_file():
        raise FileNotFoundError(args.source)
    if not args.template.is_file():
        raise FileNotFoundError(args.template)

    source = TTFont(args.source, recalcBBoxes=False, recalcTimestamp=False)
    template = TTFont(args.template, recalcBBoxes=False, recalcTimestamp=False)

    validate_source(source)
    ensure_windows_cmaps(source)
    copied = copy_segoe_identity(source, template)
    tune_directwrite(source, template)

    if "DSIG" in source:
        del source["DSIG"]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    temp = args.output.with_suffix(args.output.suffix + ".tmp")
    temp.unlink(missing_ok=True)

    source.save(temp, reorderTables=None)

    built = TTFont(temp, recalcBBoxes=False, recalcTimestamp=False)
    validate_source(built)

    expected = identity_snapshot(template)
    actual = identity_snapshot(built)
    mismatches = {
        key: value for key, value in expected.items()
        if key not in actual or actual[key] != value
    }
    if mismatches:
        temp.unlink(missing_ok=True)
        raise RuntimeError(
            f"Segoe identity verification failed for {len(mismatches)} name records."
        )

    os.replace(temp, args.output)

    color_format = (
        "CBDT/CBLC" if "CBDT" in built and "CBLC" in built
        else "COLR/CPAL"
    )
    print(f"Built: {args.output}")
    print(f"Color format: {color_format}")
    print(f"Copied Segoe identity records: {copied}")
    print(f"Family: {built['name'].getDebugName(1)!r}")
    print(f"Full name: {built['name'].getDebugName(4)!r}")
    print(f"PostScript: {built['name'].getDebugName(6)!r}")
    print(f"SHA256: {sha256(args.output)}")
    return 0

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
