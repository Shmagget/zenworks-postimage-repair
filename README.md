# ZENworks Post-Image Repair

Straight-clone ZENworks imaging helper scripts.

## Files

| File | Purpose |
|------|---------|
| `Install-CloneImage-Autostart.bat` | Run **once on the master** (as Admin) before capture |
| `ZENworks-PostImage-Repair.bat` | Assigns Windows to `C:`, runs `chkdsk C: /f /r /x`, then `sfc /scannow` |
| `SetupComplete.cmd` | Only needed for Sysprep images (not straight clone) |
| `ZENworks-PostImage-Repair-Minimal.bat` | Bare chkdsk + sfc |

## Straight clone setup

1. On the master PC, put `Install-CloneImage-Autostart.bat` and `ZENworks-PostImage-Repair.bat` in the same folder.
2. Right-click `Install-CloneImage-Autostart.bat` → **Run as administrator**.
3. Capture / upload the image with ZENworks.
4. When imaged down, a SYSTEM startup task runs the repair automatically, then removes itself.

Log: `C:\Windows\Temp\ZENworks-PostImage-Repair.log`
