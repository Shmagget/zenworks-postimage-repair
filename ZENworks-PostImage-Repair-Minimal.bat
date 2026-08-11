@echo off
:: Minimal ZENworks post-image repair (exact steps requested).
:: Run elevated. Prefer ZENworks-PostImage-Repair.bat for logging + safer C: assign.

echo Y| chkdsk C: /f /r /x
sfc /scannow
