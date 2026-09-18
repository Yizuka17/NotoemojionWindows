#!/usr/bin/env python3
from __future__ import annotations

from fontTools.ttLib import TTFont


def analyze_bitmap_strikes(font: TTFont) -> list[dict]:
    """Return CBDT/CBLC strike metadata without modifying Noto artwork."""
    if "CBLC" not in font:
        return []

    result = []
    for index, strike in enumerate(font["CBLC"].strikes):
        table = getattr(strike, "bitmapSizeTable", None)
        result.append(
            {
                "index": index,
                "ppem_x": getattr(table, "ppemX", None),
                "ppem_y": getattr(table, "ppemY", None),
                "bit_depth": getattr(table, "bitDepth", None),
                "flags": getattr(table, "flags", None),
            }
        )
    return result


def has_windows_outline_compat(font: TTFont) -> bool:
    """Google's Windows-compatible build should contain empty glyf/loca tables."""
    return "glyf" in font and "loca" in font
