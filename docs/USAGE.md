# Usage Guide

This document explains how to use DriveMapper in production and during development.

## Production usage (login/boot task)

The recommended production setup is to run the auto-mount script on user logon.
This ensures drives are mapped every time the user signs in.

### Option A: Task Scheduler (recommended)

1. Open **Task Scheduler**.
2. Create a new task.
3. **General** tab:
   - Name: `DriveMapper Auto Mount`
   - Run only when user is logged on
4. **Triggers** tab:
   - New trigger: **At log on**
5. **Actions** tab:
   - New action: **Start a program**
   - Program/script: `powershell.exe`
   - Add arguments:
     ```text
     -NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\DriveMapper\Scripts\Auto-Mount-Drives.ps1"
     ```
6. **Conditions** tab:
   - Optional: Disable "Start the task only if the computer is on AC power"
7. Save the task.

### Option B: Startup folder (simple)

1. Create a `.cmd` file in the Windows startup folder:
   - `Win+R` -> `shell:startup`
2. Use the following content:
   ```cmd
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\DriveMapper\Scripts\Auto-Mount-Drives.ps1"
   ```
3. Save and verify after next logon.

### Configuration path

By default the script reads:

```
Config\drive-mappings.yaml
```

You can override it by editing the script or calling the module directly:

```powershell
Start-AutoMount -ConfigPath ".\Config\drive-mappings.yaml"
```

## Development usage

### Direct module usage

```powershell
Import-Module ".\DriveMapper.psd1" -Force

Mount-Folder -Path "C:\Projects" -DriveLetter "P" -Force
Start-AutoMount -ConfigPath ".\Config\drive-mappings.yaml"
```

### Quick verification

```powershell
.\QuickTest.ps1
```

### Full test suite

```powershell
.\Build.ps1 -Task Test
```
