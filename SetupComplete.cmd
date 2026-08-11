@echo off
:: =============================================================================
:: SetupComplete.cmd — ZENworks / Sysprep first-boot hook
:: -----------------------------------------------------------------------------
:: Place this file on the imaged machine as:
::   C:\Windows\Setup\Scripts\SetupComplete.cmd
::
:: Windows runs it automatically (as SYSTEM) at the end of setup / first boot
:: after an image is applied. Keep ZENworks-PostImage-Repair.bat in the same
:: folder, OR adjust REPAIR_BAT below to the path you use in the image.
:: =============================================================================

set "REPAIR_BAT=%~dp0ZENworks-PostImage-Repair.bat"

if not exist "%REPAIR_BAT%" (
    set "REPAIR_BAT=%SystemRoot%\Setup\Scripts\ZENworks-PostImage-Repair.bat"
)

if exist "%REPAIR_BAT%" (
    call "%REPAIR_BAT%"
) else (
    echo ZENworks-PostImage-Repair.bat not found.>>"%SystemRoot%\Temp\ZENworks-PostImage-Repair.log"
)

exit /b 0
