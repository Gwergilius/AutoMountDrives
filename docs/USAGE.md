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

### Configuration file format

The configuration file uses YAML format and contains two main sections:

#### Drive Mappings

The `Drive-Mapping` section defines which drive letters should be mapped to which paths. Each mapping is specified as a list item with the format:

```yaml
Drive-Mapping:
  - <DriveLetter>: "<Path>"
```

**Format details:**
- **Drive Letter**: A single letter (A-Z) without the colon. The colon (`:`) will be added automatically.
- **Path**: The absolute path to the directory that should be mapped. Can use forward slashes (`/`) or backslashes (`\`), but forward slashes are recommended for cross-platform compatibility.

**Example:**
```yaml
Drive-Mapping:
  - P: "C:/Users/Username/Projects"
  - R: "C:/Users/Username/source/repos"
  - W: "D:/Work/ImportantProject"
  - T: "D:/OneDrive - Personal/Source"
```

**Important notes:**
- Each drive letter can only be mapped once
- Drive letters must be valid Windows drive letters (A-Z)
- Paths must be absolute (full paths starting with drive letter)
- Paths with spaces should be enclosed in quotes
- **Path format:**
  - **Forward slashes (`/`) are recommended**: `"C:/Users/Projects"` - These are automatically converted to backslashes
  - **Backslashes (`\`) require escaping in YAML**: `"C:\\Users\\Projects"` - In YAML quoted strings, backslash is an escape character, so you need double backslash (`\\`) to get a single backslash
  - Both formats work, but forward slashes are simpler and don't require escaping
- Empty or invalid mappings will be skipped with a warning

#### Log Retention Configuration

The `Log-Retention-Days` setting (optional) specifies how many days of log entries to keep:

```yaml
Log-Retention-Days: 30
```

**Default value:** If not specified, defaults to 30 days.

**Complete example:**
```yaml
# Log retention configuration (in days)
# Older log entries will be removed on startup
Log-Retention-Days: 30

Drive-Mapping:
  - P: "C:/Users/Username/Projects"
  - R: "C:/Users/Username/source/repos"
  - W: "D:/Work/ImportantProject"
  - T: "D:/OneDrive - Personal/Source"
  - V: "D:/OneDrive - Personal/Source/Subfolder"
```

## Log Management

DriveMapper automatically manages log files to prevent them from growing indefinitely. On each startup, the module removes log entries older than the configured retention period.

### Log Retention Configuration

The log retention period can be configured in the `drive-mappings.yaml` file:

```yaml
# Log retention configuration (in days)
# Older log entries will be removed on startup
Log-Retention-Days: 30

Drive-Mapping:
  - P: "C:/Projects"
  - R: "D:/Repos"
```

**Default value:** If `Log-Retention-Days` is not specified or is invalid, the default retention period is **30 days**.

**Behavior:**
- On each startup, `Start-AutoMount` automatically cleans the log file
- Only entries older than the configured retention period are removed
- Recent entries within the retention period are preserved
- The cleanup happens before processing drive mappings

### Manual Log Cleanup

You can manually clean log files using the `Clean-OldLogEntries` function:

```powershell
Import-Module ".\DriveMapper.psd1" -Force

# Clean log file with default 30 days retention
Clean-OldLogEntries -LogPath ".\Logs\auto-mount.log" -RetentionDays 30

# Clean with custom retention period
Clean-OldLogEntries -LogPath ".\Logs\auto-mount.log" -RetentionDays 7
```

**Parameters:**
- `-LogPath` (Mandatory): Path to the log file to clean
- `-RetentionDays` (Optional): Number of days to retain log entries. Default is 30 days.

**Return value:**
The function returns an object with the following properties:
- `Success`: Boolean indicating if the cleanup was successful
- `RemovedCount`: Number of log entries removed
- `KeptCount`: Number of log entries kept

**Example:**
```powershell
$result = Clean-OldLogEntries -LogPath ".\Logs\auto-mount.log" -RetentionDays 14
if ($result.Success) {
    Write-Host "Removed $($result.RemovedCount) old entries, kept $($result.KeptCount) entries"
}
```

### Log File Location

By default, logs are written to:

```
Logs\auto-mount.log
```

You can override the log path when calling `Start-AutoMount`:

```powershell
Start-AutoMount -ConfigPath ".\Config\drive-mappings.yaml" -LogPath ".\Custom\Path\custom.log"
```

### Log Format

Log entries follow this format:

```
[yyyy-MM-dd HH:mm:ss] [LEVEL] Message
```

Example:
```
[2026-01-20 15:30:45] [INFO] Starting Auto-Mount-Drives script
[2026-01-20 15:30:45] [INFO] Cleaning log entries older than 30 days...
[2026-01-20 15:30:45] [INFO] Log cleanup completed. Removed 15 old entries, kept 42 entries.
[2026-01-20 15:30:46] [INFO] Successfully mounted P: => C:\Projects
```

The cleanup function parses the timestamp from each log entry and removes entries older than the retention period.

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
