#!/usr/bin/env python3
from __future__ import annotations

from .cli import main


def interactive_main() -> int:
    print("Noto Emoji on Windows")
    print("1. Download source font")
    print("2. Convert to Segoe UI Emoji replacement")
    print("3. Exit")
    choice = input("Select (1-3): ").strip()

    if choice == "1":
        return main_with(["download"])
    if choice == "2":
        return main_with(["convert"])
    return 0


def main_with(argv):
    import sys
    old = sys.argv[:]
    try:
        sys.argv = [old[0], *argv]
        return main()
    finally:
        sys.argv = old


if __name__ == "__main__":
    raise SystemExit(interactive_main())
