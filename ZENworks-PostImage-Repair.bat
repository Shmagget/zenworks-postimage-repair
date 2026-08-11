@echo off
:: =============================================================================
:: ZENworks Post-Image Repair Script
:: -----------------------------------------------------------------------------
:: Purpose (run after ZENworks imaging, before / during first Windows boot):
::   1. Assign the Windows / system volume the letter C:
::   2. Run  chkdsk C: /f /r /x
::   3. Run  sfc /scannow
::
:: Requirements:
::   - Must run elevated (Administrator / SYSTEM)
::   - Prefer first-boot via SetupComplete.cmd, a ZENworks Windows Bundle,
::     or Run Once. Can also be launched manually from WinRE / elevated CMD.
::
:: Deploy options with ZENworks:
::   STRAIGHT CLONE (recommended): run Install-CloneImage-Autostart.bat on the
::     master BEFORE capture. That installs this script + a startup task.
::   Sysprep images: also works via SetupComplete.cmd in the same Scripts folder.
::   Manual: run elevated from WinRE / CMD if needed.
:: =============================================================================

setlocal EnableExtensions EnableDelayedExpansion

:: --- Logging -----------------------------------------------------------------
set "LOGDIR=%SystemRoot%\Temp"
if not exist "%LOGDIR%" set "LOGDIR=%TEMP%"
set "LOG=%LOGDIR%\ZENworks-PostImage-Repair.log"
set "DISKPART_SCRIPT=%TEMP%\zenworks_assign_c.txt"
set "DONEFLAG=%SystemRoot%\Setup\Scripts\ZENworks-PostImage-Repair.done"
set "TASKNAME=ZENworks Post-Image Repair"

call :Log "============================================================"
call :Log "ZENworks Post-Image Repair started: %DATE% %TIME%"
call :Log "Computer: %COMPUTERNAME%  User: %USERNAME%"
call :Log "============================================================"

:: If we already completed on this machine, exit and clean up the task.
if exist "%DONEFLAG%" (
    call :Log "Done-flag found — repair already completed on this PC. Removing startup task."
    schtasks /Delete /TN "%TASKNAME%" /F >> "%LOG%" 2>&1
    endlocal
    exit /b 0
)

:: --- Require elevation -------------------------------------------------------
net session >nul 2>&1
if errorlevel 1 (
    call :Log "ERROR: Script is not elevated. Re-launch as Administrator."
    echo.
    echo This script must be run as Administrator.
    echo Right-click the file and choose "Run as administrator".
    pause
    exit /b 1
)

:: =============================================================================
:: STEP 1: Assign the main Windows volume to C:
:: =============================================================================
call :Log ""
call :Log "STEP 1: Ensuring Windows volume is assigned as C:"

:: If C: already looks like a Windows install, skip reassignment.
if exist "C:\Windows\System32\ntoskrnl.exe" (
    call :Log "C:\Windows\System32 found — C: already points at Windows. Skipping drive reassignment."
    goto :AfterDriveAssign
)

call :Log "C: does not look like Windows. Searching volumes for a Windows install..."

:: Build a diskpart script that:
::  - Lists volumes
::  - Finds the volume that contains \Windows\System32 and assigns it C:
:: We probe common volume letters first, then fall back to diskpart select by number.

set "WINVOL="
for %%L in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
    if exist "%%L:\Windows\System32\ntoskrnl.exe" (
        set "WINVOL=%%L"
        call :Log "Found Windows at %%L:"
        goto :FoundWinVol
    )
)

call :Log "WARNING: Could not locate Windows\System32 on any drive letter."
call :Log "Will still attempt chkdsk on C: if it exists."
goto :AfterDriveAssign

:FoundWinVol
if /I "!WINVOL!"=="C" (
    call :Log "Windows already on C:. No letter change needed."
    goto :AfterDriveAssign
)

call :Log "Reassigning !WINVOL!: to C: via diskpart..."

:: Free C: if something else holds it (rare but happens after imaging).
> "%DISKPART_SCRIPT%" (
    echo select volume !WINVOL!
    echo assign letter=C noerr
)
:: If C: is already taken by a non-Windows volume, remove that letter first.
if exist "C:\" (
    if not exist "C:\Windows\System32\ntoskrnl.exe" (
        call :Log "C: is occupied by a non-Windows volume. Removing letter C first..."
        > "%DISKPART_SCRIPT%" (
            echo select volume C
            echo remove letter=C noerr
            echo select volume !WINVOL!
            echo assign letter=C noerr
        )
    )
)

diskpart /s "%DISKPART_SCRIPT%" >> "%LOG%" 2>&1
set "DP_ERR=!errorlevel!"
call :Log "diskpart exit code: !DP_ERR!"

if exist "C:\Windows\System32\ntoskrnl.exe" (
    call :Log "SUCCESS: Windows is now on C:."
) else (
    call :Log "WARNING: After diskpart, C:\Windows\System32 still not found."
    call :Log "Continuing with chkdsk/sfc using C: as requested."
)

:AfterDriveAssign
if exist "%DISKPART_SCRIPT%" del /f /q "%DISKPART_SCRIPT%" >nul 2>&1

:: =============================================================================
:: STEP 2: chkdsk C: /f /r /x
:: =============================================================================
call :Log ""
call :Log "STEP 2: Running chkdsk C: /f /r /x"
call :Log "NOTE: /r is thorough and can take a long time on large disks."
echo.
echo Running chkdsk C: /f /r /x ...
echo This can take a long time. Do not power off the machine.

:: When C: is the live system volume, chkdsk cannot lock it and will offer
:: to schedule a check on next reboot. Auto-answer YES so imaging is unattended.
echo Y| chkdsk C: /f /r /x >> "%LOG%" 2>&1
set "CHK_ERR=!errorlevel!"
call :Log "chkdsk exit code: !CHK_ERR!"

:: Common exit codes:
::   0 = no errors
::   1 = errors found and fixed
::   2 = cleanup performed (e.g. dirty bit) / or cannot run online (scheduled)
::   3 = could not check / errors not fixed
if !CHK_ERR! EQU 0 (
    call :Log "chkdsk completed with no errors reported."
) else if !CHK_ERR! EQU 1 (
    call :Log "chkdsk found and fixed errors."
) else (
    call :Log "chkdsk returned !CHK_ERR!. If C: was in use, the scan was likely scheduled for next reboot."
    call :Log "Setting BootExecute dirty-volume check to ensure it runs on reboot..."
    :: Ensure Autochk runs on next boot for C:
    chkntfs /c C: >> "%LOG%" 2>&1
)

:: =============================================================================
:: STEP 3: sfc /scannow
:: =============================================================================
call :Log ""
call :Log "STEP 3: Running sfc /scannow"
echo.
echo Running sfc /scannow ...
echo This can also take a long time. Do not power off the machine.

:: sfc needs an online Windows (or use offline flags from WinPE).
:: If we are in a full Windows session with C: as system, this repairs the image.
sfc /scannow >> "%LOG%" 2>&1
set "SFC_ERR=!errorlevel!"
call :Log "sfc exit code: !SFC_ERR!"

if !SFC_ERR! EQU 0 (
    call :Log "sfc completed successfully."
) else (
    call :Log "sfc returned !SFC_ERR!. Review CBS.log if repairs failed:"
    call :Log "  %SystemRoot%\Logs\CBS\CBS.log"
)

:: =============================================================================
:: Finish
:: =============================================================================
call :Log ""
call :Log "============================================================"
call :Log "ZENworks Post-Image Repair finished: %DATE% %TIME%"
call :Log "Log file: %LOG%"
call :Log "============================================================"

:: Mark complete and remove the clone-image startup task so it does not
:: keep running on every boot after a successful repair.
echo Completed %DATE% %TIME%> "%DONEFLAG%"
call :Log "Wrote done-flag: %DONEFLAG%"
schtasks /Delete /TN "%TASKNAME%" /F >> "%LOG%" 2>&1
call :Log "Removed scheduled task (if it existed): %TASKNAME%"

echo.
echo ----------------------------------------------------------
echo Post-image repair finished.
echo Log: %LOG%
echo.
echo If chkdsk could not lock C:, this PC will reboot so the
echo scheduled disk check can run before Windows fully starts.
echo ----------------------------------------------------------
echo.

:: Reboot so a deferred chkdsk (common when C: is locked) actually runs.
:: Safe for unattended imaging; comment out if you do not want auto-reboot.
if not "%CHK_ERR%"=="0" if not "%CHK_ERR%"=="1" (
    call :Log "Rebooting in 60 seconds so scheduled chkdsk can run..."
    shutdown /r /t 60 /c "ZENworks post-image repair: reboot for chkdsk"
)

endlocal
exit /b 0

:: --- Helpers -----------------------------------------------------------------
:Log
echo %~1
>> "%LOG%" echo %~1
goto :eof
