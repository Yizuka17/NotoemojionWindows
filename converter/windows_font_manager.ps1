[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('install','restore')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'

$ConverterDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Split-Path -Parent $ConverterDir
$BuiltFont = Join-Path $RepoRoot 'fonts\SegoeUIEmoji.ttf'
$Target = Join-Path $env:SystemRoot 'Fonts\seguiemj.ttf'
$BackupDir = 'C:\FontBackup\NotoEmojiOnWindows'
$BackupFont = Join-Path $BackupDir 'seguiemj_original.ttf'

function Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Ok([string]$Message) {
    Write-Host "    $Message" -ForegroundColor Green
}

function Warn([string]$Message) {
    Write-Host "    $Message" -ForegroundColor Yellow
}

function Sha([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Require-Admin {
    $Principal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        throw 'Run this script as Administrator.'
    }
}

function Ensure-NativeMethods {
    if (-not ('NotoEmoji.NativeMethods' -as [type])) {
        Add-Type -Namespace NotoEmoji -Name NativeMethods -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, uint dwFlags);
'@
    }
}

function Grant-FontAccess {
    & takeown.exe /f $Target /a | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "takeown failed with exit code $LASTEXITCODE"
    }

    & icacls.exe $Target /grant "*S-1-5-32-544:F" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "icacls failed with exit code $LASTEXITCODE"
    }
}

function Clear-FontCache {
    Step 'Preparing font cache rebuild'

    foreach ($ServiceName in @('FontCache3.0.0.0', 'FontCache')) {
        $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($Service -and $Service.Status -eq 'Running') {
            try {
                Stop-Service -Name $ServiceName -Force -ErrorAction Stop
            }
            catch {
                Warn "Could not stop $ServiceName."
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
            Ensure-NativeMethods
            [void][NotoEmoji.NativeMethods]::MoveFileEx(
                $FntCache,
                [NullString]::Value,
                0x4
            )
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

function Stage-Replacement([string]$Source, [string]$Suffix) {
    Ensure-NativeMethods
    Grant-FontAccess

    $Staged = "$Target.$Suffix"
    Remove-Item -LiteralPath $Staged -Force -ErrorAction SilentlyContinue
    Copy-Item -LiteralPath $Source -Destination $Staged -Force

    if ((Sha $Staged) -ne (Sha $Source)) {
        Remove-Item -LiteralPath $Staged -Force -ErrorAction SilentlyContinue
        throw 'Staged font failed SHA256 verification.'
    }

    $Flags = 0x1 -bor 0x4
    if (-not [NotoEmoji.NativeMethods]::MoveFileEx($Staged, $Target, $Flags)) {
        $Code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Remove-Item -LiteralPath $Staged -Force -ErrorAction SilentlyContinue
        throw "MoveFileEx failed with Win32 error $Code."
    }
}

Require-Admin

if (-not (Test-Path -LiteralPath $Target)) {
    throw "System emoji font not found: $Target"
}

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

if ($Action -eq 'install') {
    if (-not (Test-Path -LiteralPath $BuiltFont)) {
        throw "Converted font not found: $BuiltFont"
    }

    Step 'Backing up original Segoe UI Emoji'
    if (-not (Test-Path -LiteralPath $BackupFont)) {
        Copy-Item -LiteralPath $Target -Destination $BackupFont -Force
        if ((Sha $BackupFont) -ne (Sha $Target)) {
            Remove-Item -LiteralPath $BackupFont -Force -ErrorAction SilentlyContinue
            throw 'Backup verification failed.'
        }
        Ok "Backup saved to $BackupFont"
    }
    else {
        Ok 'Existing backup preserved.'
    }

    Step 'Staging Noto replacement'
    Stage-Replacement -Source $BuiltFont -Suffix 'noto-new'

    reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" /v "Segoe UI Emoji (TrueType)" /t REG_SZ /d "seguiemj.ttf" /f | Out-Null

    Clear-FontCache
    Ok 'Noto Color Emoji is staged. Reboot Windows to apply it.'
}
else {
    if (-not (Test-Path -LiteralPath $BackupFont)) {
        throw "Original backup not found: $BackupFont"
    }

    Step 'Staging original Segoe UI Emoji'
    Stage-Replacement -Source $BackupFont -Suffix 'restore'

    reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" /v "Segoe UI Emoji (TrueType)" /t REG_SZ /d "seguiemj.ttf" /f | Out-Null

    Clear-FontCache
    Ok 'Original Segoe UI Emoji is staged. Reboot Windows to restore it.'
}
