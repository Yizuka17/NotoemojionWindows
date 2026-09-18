# Converter

This directory mirrors the converter-oriented layout used by `jjjuk/emoji-win`.

## Commands

From the repository root:

```powershell
.\emoji-win.bat download
.\emoji-win.bat convert
.\emoji-win.bat diagnose .\fonts\SegoeUIEmoji.ttf
```

Or from this directory:

```bash
python -m emoji_win download
python -m emoji_win convert
python -m emoji_win diagnose ../fonts/SegoeUIEmoji.ttf
```

## Modules

- `font_converter.py` — cmap, Segoe identity and DirectWrite metric conversion.
- `bitmap_processor.py` — CBDT/CBLC strike inspection. It intentionally does not resize Google's bitmaps yet.
- `font_diagnostics.py` — prints the tables and compatibility data needed while testing Windows rendering paths.
- `cli.py` — command-line interface.
- `windows_font_manager.bat` — Windows menu.
- `windows_font_manager.ps1` — verified backup, boot-time install/restore and cache handling.
