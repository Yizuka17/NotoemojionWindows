<#
.SYNOPSIS
    Build and stage Google Noto Color Emoji as Windows' Segoe UI Emoji replacement.

.DESCRIPTION
    Downloads Google's official NotoColorEmoji_WindowsCompatible.ttf, converts it
    with scripts/build_font.py, backs up the current seguiemj.ttf, and schedules
    the replacement for early boot with MoveFileEx.

    The active system font is not overwritten while Windows is running.
#>

[CmdletBinding()]
param(
    [switch]$SkipDownload,
    [switch]$NoCacheClear
)

$ErrorActionPreference = 'Stop'

$Base       = Split-Path -Parent $MyInvocation.MyCommand.Definition
$WorkDir    = Join-Path $Base 'work'
$DistDir    = Join-Path $Base 'dist'
$BackupDir  = Join-Path $Base 'backup'
$SourceFont = Join-Path $WorkDir 'NotoColorEmoji_WindowsCompatible.ttf'
$BuiltFont  = Join-Path $DistDir 'seguiemj.ttf'
$BackupFont = Join-Path $BackupDir 'seguiemj-ORIGINAL.ttf'
$Builder    = Join-Path $Base 'scripts\build_font.py'
$Target     = Join-Path $env:SystemRoot 'Fonts\seguiemj.ttf'
$Staged     = Join-Path $env:SystemRoot 'Fonts\seguiemj.ttf.new'
$FontUrl    = 'https://raw.githubusercontent.com/googlefonts/noto-emoji/main/fonts/NotoColorEmoji_WindowsCompatible.ttf'

function Step([string]$Message) { Write-Host ""; Write-Host "==> $Message" -ForegroundColor Cyan }
function Ok([string]$Message)   { Write-Host "    $Message" -ForegroundColor Green }
function Warn([string]$Message) { Write-Host "    $Message" -ForegroundColor Yellow }
function Sha([string]$Path)     { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

function Find-Python {
    foreach ($candidate in @('py', 'python', 'python3')) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            return $candidate
        }
    }
    return $null
}

Step 'Checking Administrator privileges'
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    throw 'Run PowerShell as Administrator and try again.'
}
Ok 'Administrator privileges confirmed.'

foreach ($dir in @($WorkDir, $DistDir, $BackupDir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $Target)) {
    throw "System emoji font not found: $Target"
}
if (-not (Test-Path -LiteralPath $Builder)) {
    throw "Builder script not found: $Builder"
}

Step 'Checking Python and fontTools'
$Python = Find-Python
if (-not $Python) {
    throw 'Python 3 was not found. Install Python, then run: py -m pip install -r requirements.txt'
}

& $Python -c "import fontTools; print(fontTools.__version__)" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'fontTools is missing. Run: py -m pip install -r requirements.txt'
}
Ok "Using Python command: $Python"

Step 'Obtaining Google Noto Color Emoji'
if (-not (Test-Path -LiteralPath $SourceFont)) {
    if ($SkipDownload) {
        throw "Source font is missing and -SkipDownload was specified: $SourceFont"
    }

    $Partial = "$SourceFont.partial"
    Remove-Item -LiteralPath $Partial -Force -ErrorAction SilentlyContinue

    try {
        Invoke-WebRequest -UseBasicParsing -Uri $FontUrl -OutFile $Partial
        if ((Get-Item -LiteralPath $Partial).Length -lt 1MB) {
            throw 'Downloaded file is unexpectedly small.'
        }
        Move-Item -LiteralPath $Partial -Destination $SourceFont -Force
    }
    catch {
        Remove-Item -LiteralPath $Partial -Force -ErrorAction SilentlyContinue
        throw
    }

    Ok 'Downloaded official Windows-compatible Noto font.'
}
else {
    Ok 'Using cached source font.'
}
Ok "Source SHA256: $(Sha $SourceFont)"

Step 'Backing up current Segoe UI Emoji'
$CurrentSha = Sha $Target
if (-not (Test-Path -LiteralPath $BackupFont)) {
    Copy-Item -LiteralPath $Target -Destination $BackupFont -Force
    if ((Sha $BackupFont) -ne $CurrentSha) {
        Remove-Item -LiteralPath $BackupFont -Force -ErrorAction SilentlyContinue
        throw 'Backup verification failed. Nothing has been staged.'
    }
    Ok "Backup created: $BackupFont"
}
else {
    Ok 'Backup already exists; leaving it untouched.'
}
Ok "Current system font SHA256: $CurrentSha"

Step 'Building the Windows replacement font'
& $Python $Builder --source $SourceFont --template $Target --output $BuiltFont
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $BuiltFont)) {
    throw 'Font conversion failed. Nothing has been staged.'
}
$BuiltSha = Sha $BuiltFont
Ok "Built font SHA256: $BuiltSha"

if ($BuiltSha -eq $CurrentSha) {
    Ok 'This exact build is already active. Nothing to do.'
    return
}

Step 'Taking ownership of seguiemj.ttf'
& takeown.exe /f $Target /a | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "takeown failed with exit code $LASTEXITCODE"
}

& icacls.exe $Target /grant "*S-1-5-32-544:F" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "icacls failed with exit code $LASTEXITCODE"
}
Ok 'Administrators have full control of the current font file.'

Step 'Staging replacement for the next boot'
if (-not ('NotoEmoji.NativeMethods' -as [type])) {
    Add-Type -Namespace NotoEmoji -Name NativeMethods -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, uint dwFlags);
'@
}

$MOVEFILE_REPLACE_EXISTING = 0x1
$MOVEFILE_DELAY_UNTIL_REBOOT = 0x4

Remove-Item -LiteralPath $Staged -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath $BuiltFont -Destination $Staged -Force

if ((Sha $Staged) -ne $BuiltSha) {
    Remove-Item -LiteralPath $Staged -Force -ErrorAction SilentlyContinue
    throw 'Staged font failed SHA256 verification.'
}

$Flags = $MOVEFILE_REPLACE_EXISTING -bor $MOVEFILE_DELAY_UNTIL_REBOOT
if (-not [NotoEmoji.NativeMethods]::MoveFileEx($Staged, $Target, $Flags)) {
    $Code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Remove-Item -LiteralPath $Staged -Force -ErrorAction SilentlyContinue
    throw "MoveFileEx failed with Win32 error $Code."
}
Ok 'Boot-time replacement queued.'

if (-not $NoCacheClear) {
    Step 'Preparing Windows font cache rebuild'

    foreach ($ServiceName in @('FontCache3.0.0.0', 'FontCache')) {
        $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($Service -and $Service.Status -eq 'Running') {
            try {
                Stop-Service -Name $ServiceName -Force -ErrorAction Stop
                Ok "Stopped $ServiceName."
            }
            catch {
                Warn "Could not stop $ServiceName: $($_.Exception.Message)"
            }
        }
    }

    $CacheDir = Join-Path $env:SystemRoot 'ServiceProfiles\LocalService\AppData\Local\FontCache'
    if (Test-Path -LiteralPath $CacheDir) {
        Get-ChildItem -LiteralPath $CacheDir -Force -Recurse -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }

    $FntCache = Join-Path $env:SystemRoot 'System32\FNTCACHE.DAT'
    if (Test-Path -LiteralPath $FntCache) {
        Remove-Item -LiteralPath $FntCache -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $FntCache) {
            [void][NotoEmoji.NativeMethods]::MoveFileEx($FntCache, [NullString]::Value, $MOVEFILE_DELAY_UNTIL_REBOOT)
        }
    }

    foreach ($ServiceName in @('FontCache', 'FontCache3.0.0.0')) {
        if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
            try {
                Start-Service -Name $ServiceName -ErrorAction Stop
            }
            catch {
                Warn "$ServiceName will restart with Windows."
            }
        }
    }

    Ok 'Font cache cleanup requested.'
}

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor Green
Write-Host " Noto Color Emoji is staged, but not active yet." -ForegroundColor Green
Write-Host " Reboot Windows to perform the replacement." -ForegroundColor Green
Write-Host " Restore later with Restore-SegoeEmoji.ps1." -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor Green
Write-Host ""
