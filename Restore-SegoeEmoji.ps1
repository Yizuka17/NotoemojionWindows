<#
.SYNOPSIS
    Restore the original Windows Segoe UI Emoji font from this project's backup.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$Base       = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BackupFont = Join-Path $Base 'backup\seguiemj-ORIGINAL.ttf'
$Target     = Join-Path $env:SystemRoot 'Fonts\seguiemj.ttf'
$Staged     = Join-Path $env:SystemRoot 'Fonts\seguiemj.ttf.restore'

function Step([string]$Message) { Write-Host ""; Write-Host "==> $Message" -ForegroundColor Cyan }
function Ok([string]$Message)   { Write-Host "    $Message" -ForegroundColor Green }
function Warn([string]$Message) { Write-Host "    $Message" -ForegroundColor Yellow }
function Sha([string]$Path)     { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

Step 'Checking Administrator privileges'
$Principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    throw 'Run PowerShell as Administrator and try again.'
}

if (-not (Test-Path -LiteralPath $BackupFont)) {
    throw "Backup not found: $BackupFont"
}
if (-not (Test-Path -LiteralPath $Target)) {
    throw "System emoji font not found: $Target"
}

$BackupSha = Sha $BackupFont
$CurrentSha = Sha $Target
if ($BackupSha -eq $CurrentSha) {
    Ok 'The backed-up Segoe UI Emoji font is already active.'
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

if (-not ('NotoEmoji.NativeMethods' -as [type])) {
    Add-Type -Namespace NotoEmoji -Name NativeMethods -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, uint dwFlags);
'@
}

$MOVEFILE_REPLACE_EXISTING = 0x1
$MOVEFILE_DELAY_UNTIL_REBOOT = 0x4

Step 'Staging original Segoe UI Emoji for the next boot'
Remove-Item -LiteralPath $Staged -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath $BackupFont -Destination $Staged -Force

if ((Sha $Staged) -ne $BackupSha) {
    Remove-Item -LiteralPath $Staged -Force -ErrorAction SilentlyContinue
    throw 'Staged restore file failed SHA256 verification.'
}

$Flags = $MOVEFILE_REPLACE_EXISTING -bor $MOVEFILE_DELAY_UNTIL_REBOOT
if (-not [NotoEmoji.NativeMethods]::MoveFileEx($Staged, $Target, $Flags)) {
    $Code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Remove-Item -LiteralPath $Staged -Force -ErrorAction SilentlyContinue
    throw "MoveFileEx failed with Win32 error $Code."
}
Ok 'Restore queued for the next boot.'

Step 'Preparing Windows font cache rebuild'
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

Write-Host ""
Write-Host "Original Segoe UI Emoji is staged. Reboot Windows to restore it." -ForegroundColor Green
Write-Host ""
