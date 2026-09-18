# Noto Emoji on Windows

Replace the Windows system emoji font with Google's **Noto Color Emoji** while keeping Windows' existing `Segoe UI Emoji` registration.

> [!WARNING]
> Experimental. This project replaces a Windows system font. A verified backup is created before anything is staged, and the actual swap happens only after reboot. Test on a machine you can recover first.

## Why this exists

Google publishes `NotoColorEmoji_WindowsCompatible.ttf`, a Windows-installable CBDT/CBLC build of Noto Color Emoji. Simply installing it does not make Windows use it as the system emoji font because Windows still resolves emoji through `Segoe UI Emoji`.

Older replacement projects solved this by giving Google's font the same internal names as `Segoe UI Emoji`. This project does the same thing, but **copies the complete `name` table from the Segoe UI Emoji font on your own Windows installation at build time** instead of shipping a stale hard-coded table.

The source font is downloaded directly from Google's official repository:

`https://raw.githubusercontent.com/googlefonts/noto-emoji/main/fonts/NotoColorEmoji_WindowsCompatible.ttf`

No Google or Microsoft font binaries are stored in this repository.

## Requirements

- Windows 10 1607+ or Windows 11
- Administrator PowerShell
- Python 3.9+
- `fonttools`

Install the Python dependency:

```powershell
py -m pip install -r requirements.txt
```

## Apply

Run PowerShell as Administrator:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Apply-NotoEmoji.ps1
```

The script will:

1. Download Google's latest `NotoColorEmoji_WindowsCompatible.ttf`.
2. Copy your current `C:\Windows\Fonts\seguiemj.ttf` as a local backup.
3. Build a Noto font whose internal `name` table matches your current Segoe UI Emoji.
4. Validate the generated font and stage it as `seguiemj.ttf.new`.
5. Queue the replacement with `MoveFileEx(..., MOVEFILE_DELAY_UNTIL_REBOOT)`.
6. Clear/schedule rebuilding of the Windows font cache.

Nothing is swapped until you reboot.

## Restore

Run as Administrator:

```powershell
.\Restore-SegoeEmoji.ps1
```

Then reboot. The script stages the original backed-up Segoe UI Emoji font for restoration.

## Build only

You can build without installing:

```powershell
py .\scripts\build_font.py `
  --source .\work\NotoColorEmoji_WindowsCompatible.ttf `
  --template C:\Windows\Fonts\seguiemj.ttf `
  --output .\dist\seguiemj.ttf
```

## What to test

After reboot, check emoji in:

- Edge / Chromium
- Windows Search and Start
- Settings
- Notepad
- OneNote
- Terminal / PowerShell
- Emoji picker (`Win + .`)
- ZWJ sequences, skin tones and flags

If one app still shows Segoe or monochrome glyphs, note the app and rendering path in an issue. Some applications bundle or force their own emoji/font stack.

## Upstream / references

- Google Noto Emoji: https://github.com/googlefonts/noto-emoji
- Google Windows-compatible font: `fonts/NotoColorEmoji_WindowsCompatible.ttf`
- fontTools: https://github.com/fonttools/fonttools

The Noto Emoji font is licensed by Google under the SIL Open Font License 1.1. This repository's scripts are MIT licensed.
