@echo off
:: =============================================================================
:: Run-Sysprep-Generalize.bat
:: -----------------------------------------------------------------------------
:: Copies unattend.xml into Sysprep and generalizes this master for ZENworks
:: imaging. After the PC shuts down, boot ZENworks and run:
::   img makep 10.30.40.200 name-of-image.zmg
:: Do NOT let Windows boot again before makep.
:: =============================================================================

setlocal EnableExtensions

net session >nul 2>&1
if errorlevel 1 (
    echo ERROR: Run this as Administrator.
    pause
    exit /b 1
)

set "SRC=%~dp0unattend.xml"
set "DEST=%SystemRoot%\System32\Sysprep\unattend.xml"
set "SYSPREP=%SystemRoot%\System32\Sysprep\sysprep.exe"

if not exist "%SRC%" (
    echo ERROR: unattend.xml not found next to this script:
    echo   %SRC%
    pause
    exit /b 1
)

if not exist "%SYSPREP%" (
    echo ERROR: sysprep.exe not found at %SYSPREP%
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  SYSPREP GENERALIZE FOR ZENworks
echo ============================================================
echo  1. Copies unattend.xml to:
echo       %DEST%
echo  2. Runs: sysprep /generalize /oobe /shutdown /unattend:...
echo  3. PC will SHUT DOWN when finished.
echo  4. Boot ZENworks imaging next and run img makep.
echo.
echo  Edit passwords / timezone in unattend.xml BEFORE continuing
echo  if you have not already.
echo ============================================================
echo.
pause

echo Copying unattend.xml ...
copy /Y "%SRC%" "%DEST%" >nul
if errorlevel 1 (
    echo ERROR: Could not copy unattend.xml
    pause
    exit /b 1
)

:: Optional: also stage SetupComplete for first boot after restorep
if exist "%~dp0SetupComplete.cmd" (
    mkdir "%SystemRoot%\Setup\Scripts" 2>nul
    copy /Y "%~dp0SetupComplete.cmd" "%SystemRoot%\Setup\Scripts\SetupComplete.cmd" >nul
)
if exist "%~dp0ZENworks-PostImage-Repair.bat" (
    mkdir "%SystemRoot%\Setup\Scripts" 2>nul
    copy /Y "%~dp0ZENworks-PostImage-Repair.bat" "%SystemRoot%\Setup\Scripts\ZENworks-PostImage-Repair.bat" >nul
)

echo Starting Sysprep. The machine will shut down when done...
"%SYSPREP%" /generalize /oobe /shutdown /unattend:"%DEST%"
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
    echo.
    echo Sysprep failed with exit code %ERR%.
    echo Check logs:
    echo   %SystemRoot%\System32\Sysprep\Panther\setupact.log
    echo   %SystemRoot%\System32\Sysprep\Panther\setuperr.log
    pause
    exit /b %ERR%
)

endlocal
exit /b 0
