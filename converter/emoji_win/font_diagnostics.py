#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from fontTools.ttLib import TTFont

from .bitmap_processor import analyze_bitmap_strikes, has_windows_outline_compat


def diagnose_font(path: str | Path) -> dict:
    path = Path(path)
    font = TTFont(path, recalcBBoxes=False, recalcTimestamp=False)

    cmaps = []
    for table in font["cmap"].tables:
        cmaps.append(
            {
                "platform": table.platformID,
                "encoding": table.platEncID,
                "format": table.format,
                "characters": len(getattr(table, "cmap", {})),
            }
        )

    return {
        "path": str(path),
        "family": font["name"].getDebugName(1) if "name" in font else None,
        "full_name": font["name"].getDebugName(4) if "name" in font else None,
        "postscript": font["name"].getDebugName(6) if "name" in font else None,
        "tables": sorted(font.keys()),
        "color_format": (
            "CBDT/CBLC"
            if "CBDT" in font and "CBLC" in font
            else "COLR/CPAL"
            if "COLR" in font and "CPAL" in font
            else "sbix"
            if "sbix" in font
            else "SVG"
            if "SVG " in font
            else None
        ),
        "units_per_em": font["head"].unitsPerEm if "head" in font else None,
        "windows_outline_compat": has_windows_outline_compat(font),
        "cmaps": cmaps,
        "bitmap_strikes": analyze_bitmap_strikes(font),
    }


def print_diagnostics(path: str | Path) -> None:
    info = diagnose_font(path)

    print(f"Font: {info['path']}")
    print(f"Family: {info['family']!r}")
    print(f"Full name: {info['full_name']!r}")
    print(f"PostScript: {info['postscript']!r}")
    print(f"Color format: {info['color_format']}")
    print(f"Units per em: {info['units_per_em']}")
    print(f"glyf/loca compatibility: {info['windows_outline_compat']}")
    print(f"Tables: {', '.join(info['tables'])}")

    print("cmap subtables:")
    for cmap in info["cmaps"]:
        print(
            "  "
            f"platform={cmap['platform']} "
            f"encoding={cmap['encoding']} "
            f"format={cmap['format']} "
            f"chars={cmap['characters']}"
        )

    if info["bitmap_strikes"]:
        print("bitmap strikes:")
        for strike in info["bitmap_strikes"]:
            print(
                "  "
                f"#{strike['index']}: "
                f"{strike['ppem_x']}x{strike['ppem_y']} "
                f"depth={strike['bit_depth']}"
            )
