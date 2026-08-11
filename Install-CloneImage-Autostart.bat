@echo off
:: =============================================================================
:: Install-CloneImage-Autostart.bat
:: -----------------------------------------------------------------------------
:: FOR STRAIGHT CLONE ZENworks IMAGING
::
:: Run this ONCE on the MASTER PC (elevated) BEFORE you upload/capture the
:: image. It:
::   1. Copies the repair script to C:\Windows\Setup\Scripts\
::   2. Creates a SYSTEM Scheduled Task that runs at every startup until the
::      repair script finishes and removes the task.
::
:: After you image a new PC down from the server, Windows will auto-run the
:: repair (C: assign, chkdsk, sfc) early in boot — no SetupComplete / Sysprep
:: required.
:: =============================================================================

setlocal EnableExtensions

net session >nul 2>&1
if errorlevel 1 (
    echo ERROR: Run this as Administrator.
    pause
    exit /b 1
)

set "SCRIPTDIR=%SystemRoot%\Setup\Scripts"
set "REPAIR_BAT=%SCRIPTDIR%\ZENworks-PostImage-Repair.bat"
set "TASKNAME=ZENworks Post-Image Repair"
set "SRCDIR=%~dp0"

echo.
echo Creating %SCRIPTDIR% ...
mkdir "%SCRIPTDIR%" 2>nul

if not exist "%SRCDIR%ZENworks-PostImage-Repair.bat" (
    echo ERROR: ZENworks-PostImage-Repair.bat not found next to this installer.
    echo Put both files in the same folder and run this again.
    pause
    exit /b 1
)

echo Copying repair script ...
copy /Y "%SRCDIR%ZENworks-PostImage-Repair.bat" "%REPAIR_BAT%" >nul
if errorlevel 1 (
    echo ERROR: Could not copy repair script to %REPAIR_BAT%
    pause
    exit /b 1
)

:: Remove any old task, then create a startup task as SYSTEM.
echo Creating Scheduled Task "%TASKNAME%" ...
schtasks /Delete /TN "%TASKNAME%" /F >nul 2>&1

:: Run at startup as SYSTEM, highest privileges.
:: /DELAY 0000:30 = wait 30 seconds after startup so disks are ready.
schtasks /Create /TN "%TASKNAME%" /SC ONSTART /RU SYSTEM /RL HIGHEST /DELAY 0000:30 /TR "\"%REPAIR_BAT%\"" /F
if errorlevel 1 (
    echo ERROR: schtasks failed. Task was not created.
    pause
    exit /b 1
)

:: Clear any prior "already ran" flag so the NEXT imaged PC will run it.
del /f /q "%SystemRoot%\Setup\Scripts\ZENworks-PostImage-Repair.done" >nul 2>&1

echo.
echo ============================================================
echo  READY FOR IMAGE CAPTURE
echo ============================================================
echo  Script : %REPAIR_BAT%
echo  Task   : %TASKNAME%  (runs as SYSTEM at startup)
echo.
echo  Next steps:
echo   1. Do NOT reboot-run the repair on this master unless you want to.
echo   2. Upload / capture this machine with ZENworks as usual.
echo   3. When you image ANY PC down from that image, the task will run
echo      automatically, then remove itself when finished.
echo ============================================================
echo.
pause
endlocal
exit /b 0
