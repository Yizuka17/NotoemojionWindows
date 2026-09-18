@echo off
setlocal
cd /d "%~dp0"
where uv >nul 2>nul
if %errorlevel%==0 (
    uv run --project "%~dp0converter" python -m emoji_win %*
    exit /b %errorlevel%
)
set "PYTHONPATH=%~dp0converter;%PYTHONPATH%"
py -m emoji_win %*
exit /b %errorlevel%
