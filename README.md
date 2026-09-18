# Noto Emoji on Windows

Bring Google's **Noto Color Emoji** to Windows as a system `Segoe UI Emoji` replacement.

This repository intentionally follows the project layout of [jjjuk/emoji-win](https://github.com/jjjuk/emoji-win) so the two projects are easy to compare while investigating Windows 11 / DirectWrite emoji compatibility.

> [!WARNING]
> Experimental. Replacing `C:\Windows\Fonts\seguiemj.ttf` is a system modification. The installer creates a verified backup and stages the actual swap for the next reboot.

## Project layout

```text
.
├─ emoji-win.py
├─ emoji-win.sh
├─ emoji-win.bat
├─ convert.sh
├─ fonts/
├─ converter/
│  ├─ main.py
│  ├─ convert.sh
│  ├─ windows_font_manager.bat
│  ├─ windows_font_manager.ps1
│  ├─ pyproject.toml
│  ├─ emoji_win/
│  │  ├─ __init__.py
│  │  ├─ __main__.py
│  │  ├─ cli.py
│  │  ├─ font_converter.py
│  │  ├─ bitmap_processor.py
│  │  ├─ font_diagnostics.py
│  │  └─ interactive_cli.py
│  └─ tests/
└─ pyproject.toml
```

## Why Noto needs less conversion than Apple Emoji

Google already publishes `NotoColorEmoji_WindowsCompatible.ttf`. Its official build uses `--add_cmap4 --add_glyf`, so the font already contains the Windows BMP cmap and empty `glyf/loca` compatibility tables that Apple Emoji converters have to add themselves.

This converter therefore keeps Google's Windows-compatible structure and focuses on the remaining system-replacement pieces:

- make sure Windows format 4 / format 12 cmap subtables exist;
- copy the local Windows installation's `Segoe UI Emoji` identity records;
- copy relevant DirectWrite typography metrics from the local `seguiemj.ttf`;
- preserve Noto's color artwork, GSUB data, Google metadata and OFL records;
- stage the replacement safely for the next reboot.

## Quick start

With `uv`:

```powershell
git clone https://github.com/Yizuka17/NotoemojionWindows.git
cd NotoemojionWindows

.\emoji-win.bat download
.\emoji-win.bat convert
```

Without `uv`:

```powershell
py -m pip install fonttools
.\emoji-win.bat download
.\emoji-win.bat convert
```

The converted replacement is written to:

```text
fonts\SegoeUIEmoji.ttf
```

## Windows font manager

Run:

```text
converter\windows_font_manager.bat
```

It provides:

1. download the official Google source font;
2. build the Windows replacement;
3. stage installation for the next reboot;
4. stage restoration of the original Segoe UI Emoji;
5. diagnose the converted font.

The original Windows font is backed up outside the repository at:

```text
C:\FontBackup\NotoEmojiOnWindows\seguiemj_original.ttf
```

## CLI

```powershell
.\emoji-win.bat download
.\emoji-win.bat convert
.\emoji-win.bat diagnose .\fonts\SegoeUIEmoji.ttf
```

The converter automatically uses `C:\Windows\Fonts\seguiemj.ttf` as the template when running on Windows. You can override it:

```powershell
.\emoji-win.bat convert --template D:\Fonts\seguiemj.ttf
```

## Compatibility notes

This project is inspired by the compatibility work in [jjjuk/emoji-win](https://github.com/jjjuk/emoji-win), especially its investigation of Windows cmap, font naming, OS/2 metrics and DirectWrite behavior.

Unlike that project, this repository currently **does not rescale Noto's CBDT bitmap strikes**. Google's Windows-compatible build is tested first in its native form. If specific Windows 11 rendering paths still fall back to monochrome glyphs or clip bitmaps, bitmap-strike handling is the next area to investigate.

Useful test targets after reboot:

- Edge / Chromium
- Start and Search
- Settings
- Notepad
- OneNote
- Windows Terminal / PowerShell
- `Win + .` emoji picker
- flags
- skin tones
- ZWJ sequences

## Upstream

- Google Noto Emoji: https://github.com/googlefonts/noto-emoji
- emoji-win: https://github.com/jjjuk/emoji-win
- fontTools: https://github.com/fonttools/fonttools

Noto Emoji is distributed under the SIL Open Font License 1.1. The scripts in this repository are MIT licensed.
