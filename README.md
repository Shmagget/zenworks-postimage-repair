# ZENworks Post-Image Repair

Helpers for ZENworks imaging (`img makep` / `img restorep`), including **Sysprep generalize** support.

## Files

| File | Purpose |
|------|---------|
| `unattend.xml` | Unattended Sysprep answers (skip OOBE, set timezone, local admin) |
| `Run-Sysprep-Generalize.bat` | Copies `unattend.xml` and runs Sysprep `/generalize /oobe /shutdown` |
| `SetupComplete.cmd` | First-boot hook after Sysprep’d restore |
| `ZENworks-PostImage-Repair.bat` | Assign C:, `chkdsk C: /f /r /x`, `sfc /scannow` |
| `Install-CloneImage-Autostart.bat` | Straight-clone only: bake a startup task before `makep` |
| `ZENworks-PostImage-Repair-Minimal.bat` | Bare chkdsk + sfc |

---

## Recommended: Sysprep generalize (best for Lenovo boot hangs)

### On the master

1. Build Windows + apps as usual.
2. Finish updates, disable Fast Startup, run `powercfg /h off`, clean shutdown habits.
3. Edit `unattend.xml`:
   - Change **`ChangeMe123!`** passwords
   - Adjust **timezone** if needed (`Eastern Standard Time` is set now)
   - If **every target is the same Lenovo model**, you may set `PersistAllDeviceInstalls` to `true`
4. Put these files in one folder, then right-click **`Run-Sysprep-Generalize.bat`** → **Run as administrator**.
5. PC shuts down when Sysprep finishes.
6. Boot **ZENworks imaging** (do not boot Windows) and run:

```text
img makep 10.30.40.200 name-of-image.zmg
```

### On each target

```text
img restorep 10.30.40.200 name-of-image.zmg
```

Windows will specialize/OOBE using `unattend.xml` (mostly silent).  
If you staged `SetupComplete.cmd`, it can run at the end of setup.

---

## Straight clone (no Sysprep)

Only if you are still capturing without Sysprep:

1. Run `Install-CloneImage-Autostart.bat` as Admin on the master.
2. `img makep ...`
3. After `restorep`, the startup task runs **only if Windows boots far enough**.

If the PC sits on the Lenovo logo forever, use Sysprep instead (above), or repair offline from WinRE/USB.

---

## Logs

- Repair script: `C:\Windows\Temp\ZENworks-PostImage-Repair.log`
- Sysprep failures: `C:\Windows\System32\Sysprep\Panther\setupact.log` and `setuperr.log`
