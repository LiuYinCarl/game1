@echo off
setlocal enabledelayedexpansion

rem ============================================================
rem  One-click packaging: Windows EXE (single file) + macOS APP (zip)
rem  Usage: build.bat  (double-click or run from a terminal)
rem  If Godot is not found automatically, set GODOT_BIN first, e.g.:
rem    set "GODOT_BIN=C:\Tools\Godot_v4.7.2-stable_win64.exe"
rem    build.bat
rem ============================================================

set "ROOT=%~dp0"
set "OUTDIR=%ROOT%builds"
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

rem ---- Locate the Godot executable ----
if defined GODOT_BIN if exist "!GODOT_BIN!" goto :run
set "GODOT_BIN="

rem Godot installed via Steam (default + extra Steam library locations)
if exist "!ProgramFiles(x86)!\Steam\steamapps\common\Godot Engine\godot.exe" set "GODOT_BIN=!ProgramFiles(x86)!\Steam\steamapps\common\Godot Engine\godot.exe"
if not defined GODOT_BIN if exist "%ProgramFiles%\Steam\steamapps\common\Godot Engine\godot.exe" set "GODOT_BIN=%ProgramFiles%\Steam\steamapps\common\Godot Engine\godot.exe"
for %%D in (C D E F G) do (
  if not defined GODOT_BIN if exist "%%D:\Steam\steamapps\common\Godot Engine\godot.exe" set "GODOT_BIN=%%D:\Steam\steamapps\common\Godot Engine\godot.exe"
  if not defined GODOT_BIN if exist "%%D:\SteamLibrary\steamapps\common\Godot Engine\godot.exe" set "GODOT_BIN=%%D:\SteamLibrary\steamapps\common\Godot Engine\godot.exe"
)

rem Standalone download from godotengine.org (zip extracted somewhere)
if not defined GODOT_BIN if exist "%LOCALAPPDATA%\Programs\Godot\Godot.exe" set "GODOT_BIN=%LOCALAPPDATA%\Programs\Godot\Godot.exe"
if not defined GODOT_BIN if exist "%ProgramFiles%\Godot\Godot.exe" set "GODOT_BIN=%ProgramFiles%\Godot\Godot.exe"
if not defined GODOT_BIN if exist "%ProgramFiles(x86)%\Godot\Godot.exe" set "GODOT_BIN=%ProgramFiles(x86)%\Godot\Godot.exe"

rem godot.exe available on PATH
if not defined GODOT_BIN (
  for /f "delims=" %%i in ('where godot.exe 2^>nul') do (
    if not defined GODOT_BIN set "GODOT_BIN=%%i"
  )
)

if not defined GODOT_BIN (
  echo [ERROR] Could not find Godot automatically.
  echo.
  echo Please point GODOT_BIN at your Godot executable and run again, e.g.:
  echo   set "GODOT_BIN=C:\Tools\Godot_v4.7.2-stable_win64.exe"
  echo   build.bat
  echo.
  pause
  exit /b 1
)

:run
echo Using Godot: "!GODOT_BIN!"
echo.

echo ==^> Importing assets...
"!GODOT_BIN!" --headless --path "%ROOT%" --import >nul 2>&1

echo ==^> Exporting Windows: builds\tafang_windows.exe ...
"!GODOT_BIN!" --headless --path "%ROOT%" --export-release "Windows" "%OUTDIR%\tafang_windows.exe"
if errorlevel 1 goto :fail

echo ==^> Exporting macOS: builds\tafang_mac.zip ...
rem Note: exporting macOS works from Windows too, but code signing is not
rem possible here, so the app may require "right-click - Open" on macOS.
"!GODOT_BIN!" --headless --path "%ROOT%" --export-release "macOS" "%OUTDIR%\tafang_mac.zip"
if errorlevel 1 goto :fail

echo.
echo Done. Output files in %OUTDIR%:
dir /b "%OUTDIR%"
echo.
pause
exit /b 0

:fail
echo.
echo [ERROR] Export failed. See messages above.
pause
exit /b 1
