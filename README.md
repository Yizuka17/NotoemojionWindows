# Noto Emoji on Windows

Replace Windows' system emoji font with Google's **Noto Color Emoji**, while keeping the identity Windows expects from `Segoe UI Emoji`.

> [!WARNING]
> Experimental. This modifies a Windows system font. The original font is backed up and the actual swap is queued for the next reboot, but you should still test on a machine you can recover.

## Why this exists

Windows normally resolves system emoji through `Segoe UI Emoji` / `seguiemj.ttf`. Installing Noto Color Emoji alongside it therefore does not make Windows use Noto everywhere.

Google already ships `NotoColorEmoji_WindowsCompatible.ttf`. Its own build process adds a Windows BMP cmap and empty `glyf/loca` outline tables specifically for compatibility. This project keeps that work and adds the remaining pieces needed to act as a system replacement.

The converter:

- preserves Google's Noto artwork, color tables, GSUB data and OFL metadata;
- ensures Windows-compatible format 4 and format 12 cmap subtables exist;
- copies only the **font identity** name records from the machine's current `Segoe UI Emoji`;
- copies relevant DirectWrite typography metrics from that same local Segoe build instead of hard-coding one Windows version;
- keeps the output as `seguiemj.ttf` so Windows' existing registration can be reused.

No Google or Microsoft font binaries are committed to this repository.

## Inspiration

The compatibility work is informed by [jjjuk/emoji-win](https://github.com/jjjuk/emoji-win), which converts Apple Color Emoji for Windows 11 by fixing Windows cmap/name/OS2/head/post compatibility and handling DirectWrite-specific bitmap behavior.

Noto needs less surgery than Apple because Google's `WindowsCompatible` build already contains the Windows cmap + `glyf/loca` compatibility layer.

Older Noto replacement work such as [perguto/Country-Flag-Emojis-for-Windows](https://github.com/perguto/Country-Flag-Emojis-for-Windows) also demonstrated that changing the internal font identity to `Segoe UI Emoji` can make Noto act as Windows' default emoji font.

## Requirements

- Windows 10 1607+ or Windows 11
- Administrator PowerShell
- Python 3.9+
- `fonttools`

Install the dependency:

```powershell
py -m pip install -r requirements.txt
```

## Apply

Open PowerShell as Administrator:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Apply-NotoEmoji.ps1
```

The script downloads Google's official `NotoColorEmoji_WindowsCompatible.ttf`, backs up `C:\Windows\Fonts\seguiemj.ttf`, builds the replacement, verifies the staged copy, queues the swap with `MoveFileEx(..., MOVEFILE_DELAY_UNTIL_REBOOT)`, and requests a font-cache rebuild.

**Nothing is replaced until you reboot.**

## Restore

Run as Administrator:

```powershell
.\Restore-SegoeEmoji.ps1
```

Then reboot. The original font stored in `backup\seguiemj-ORIGINAL.ttf` is staged back into place.

## Build only

After the source font exists in `work\`:

```powershell
py .\scripts\build_font.py --source .\work\NotoColorEmoji_WindowsCompatible.ttf --template C:\Windows\Fonts\seguiemj.ttf --output .\dist\seguiemj.ttf
```

## What to test

After reboot, check Edge/Chromium, Start/Search, Settings, Notepad, OneNote, Terminal/PowerShell, the `Win + .` emoji picker, flags, skin tones and ZWJ sequences.

Application behavior can still differ because some apps use their own font or emoji rendering stack. `emoji-win` likewise documents good results on current Windows 11/browser apps while noting that some native apps can still bypass the converted font.

## Upstream

- Google Noto Emoji: https://github.com/googlefonts/noto-emoji
- Google source font: `fonts/NotoColorEmoji_WindowsCompatible.ttf`
- emoji-win: https://github.com/jjjuk/emoji-win
- fontTools: https://github.com/fonttools/fonttools

Noto Emoji is distributed under the SIL Open Font License 1.1. The scripts in this repository are MIT licensed.
