#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if command -v uv >/dev/null 2>&1; then
  exec uv run --project "$ROOT/converter" python -m emoji_win "$@"
fi
PYTHONPATH="$ROOT/converter${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONPATH
exec python3 -m emoji_win "$@"
