#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parent
    converter = root / "converter"

    try:
        return subprocess.run(
            ["uv", "run", "--project", str(converter), "python", "-m", "emoji_win", *sys.argv[1:]],
            cwd=root,
            check=False,
        ).returncode
    except FileNotFoundError:
        env = os.environ.copy()
        env["PYTHONPATH"] = str(converter)
        return subprocess.run(
            [sys.executable, "-m", "emoji_win", *sys.argv[1:]],
            cwd=root,
            env=env,
            check=False,
        ).returncode


if __name__ == "__main__":
    raise SystemExit(main())
