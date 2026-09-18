#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys
import urllib.request

from .font_converter import convert_noto_to_windows, sha256
from .font_diagnostics import print_diagnostics

NOTO_URL = (
    "https://raw.githubusercontent.com/googlefonts/noto-emoji/"
    "main/2D/fonts/NotoColorEmoji_WindowsCompatible.ttf"
)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def default_template() -> Path:
    windir = os.environ.get("WINDIR") or os.environ.get("SystemRoot")
    if not windir:
        raise RuntimeError(
            "Windows directory not found. Pass --template explicitly."
        )
    return Path(windir) / "Fonts" / "seguiemj.ttf"


def download_source(output: Path, force: bool = False) -> Path:
    output.parent.mkdir(parents=True, exist_ok=True)

    if output.exists() and not force:
        print(f"Using existing source: {output}")
        return output

    partial = output.with_suffix(output.suffix + ".partial")
    partial.unlink(missing_ok=True)

    print(f"Downloading official Noto Windows-compatible font...")
    urllib.request.urlretrieve(NOTO_URL, partial)

    if partial.stat().st_size < 1024 * 1024:
        partial.unlink(missing_ok=True)
        raise RuntimeError("Downloaded file is unexpectedly small.")

    partial.replace(output)
    print(f"Saved: {output}")
    print(f"SHA256: {sha256(output)}")
    return output


def cmd_download(args) -> int:
    download_source(Path(args.output), force=args.force)
    return 0


def cmd_convert(args) -> int:
    root = repo_root()
    source = Path(args.input) if args.input else root / "fonts" / "NotoColorEmoji_WindowsCompatible.ttf"
    output = Path(args.output) if args.output else root / "fonts" / "SegoeUIEmoji.ttf"
    template = Path(args.template) if args.template else default_template()

    if not source.exists():
        download_source(source)

    convert_noto_to_windows(
        source,
        output,
        template,
        quiet=args.quiet,
    )
    return 0


def cmd_diagnose(args) -> int:
    print_diagnostics(args.font)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="emoji-win",
        description="Build a Windows Segoe UI Emoji replacement from Google Noto Color Emoji.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    download = sub.add_parser("download", help="Download Google's official Windows-compatible Noto font.")
    download.add_argument(
        "-o",
        "--output",
        default=str(repo_root() / "fonts" / "NotoColorEmoji_WindowsCompatible.ttf"),
    )
    download.add_argument("--force", action="store_true")
    download.set_defaults(func=cmd_download)

    convert = sub.add_parser("convert", help="Convert Noto into a Segoe UI Emoji replacement.")
    convert.add_argument("input", nargs="?")
    convert.add_argument("output", nargs="?")
    convert.add_argument("--template")
    convert.add_argument("--quiet", action="store_true")
    convert.set_defaults(func=cmd_convert)

    diagnose = sub.add_parser("diagnose", help="Inspect a source or converted emoji font.")
    diagnose.add_argument("font")
    diagnose.set_defaults(func=cmd_diagnose)

    return parser


def main() -> int:
    try:
        args = build_parser().parse_args()
        return args.func(args)
    except KeyboardInterrupt:
        return 130
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
