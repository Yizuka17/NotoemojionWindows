@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b 0
)

:MENU
cls
echo =======================================
echo Noto Emoji on Windows - Font Manager
echo =======================================
echo.
echo 1. DOWNLOAD  - Get Google's Windows-compatible Noto font
echo 2. CONVERT   - Build fonts\SegoeUIEmoji.ttf
echo 3. INSTALL   - Stage converted font for next reboot
echo 4. RESTORE   - Stage original Segoe UI Emoji for next reboot
echo 5. DIAGNOSE  - Inspect converted font
echo 6. Exit
echo.
set /p choice="Enter your choice (1-6): "

if "%choice%"=="1" goto DOWNLOAD
if "%choice%"=="2" goto CONVERT
if "%choice%"=="3" goto INSTALL
if "%choice%"=="4" goto RESTORE
if "%choice%"=="5" goto DIAGNOSE
if "%choice%"=="6" goto END
goto MENU

:DOWNLOAD
call "%~dp0..\emoji-win.bat" download
pause
goto MENU

:CONVERT
call "%~dp0..\emoji-win.bat" convert
pause
goto MENU

:INSTALL
if not exist "%~dp0..\fonts\SegoeUIEmoji.ttf" (
    echo Converted font not found. Building it first...
    call "%~dp0..\emoji-win.bat" convert
    if errorlevel 1 (
        echo Conversion failed.
        pause
        goto MENU
    )
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows_font_manager.ps1" -Action install
pause
goto MENU

:RESTORE
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows_font_manager.ps1" -Action restore
pause
goto MENU

:DIAGNOSE
if not exist "%~dp0..\fonts\SegoeUIEmoji.ttf" (
    echo Converted font not found.
) else (
    call "%~dp0..\emoji-win.bat" diagnose "%~dp0..\fonts\SegoeUIEmoji.ttf"
)
pause
goto MENU

:END
endlocal
exit /b 0
