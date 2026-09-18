# Repository layout

The repository follows the same broad split as `jjjuk/emoji-win`:

- root wrappers provide a simple entry point;
- `fonts/` is the local input/output workspace;
- `converter/` contains the Python package and Windows font manager;
- `converter/emoji_win/` contains the conversion implementation.

The project is intentionally small for now: Noto already has an official Windows-compatible build, so Apple-specific extraction and bitmap-conversion machinery is not duplicated unless testing shows it is needed.
