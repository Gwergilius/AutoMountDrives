# DriveMapper PowerShell Module

A Windows PowerShell module for automatic drive mapping using the `subst` command.

## Features

- **Mount-Folder**: map a single folder to a drive letter
- **Start-AutoMount**: automatic mapping from a YAML configuration
- **Enhanced error handling**: structured return objects instead of raw exceptions
- **Comprehensive logging**: colorized console output and optional file logs
- **Pester tests**: automated test suite with coverage support
- **VS Code integration**: tasks for running and debugging tests

## Project Structure

```
DriveMapper/
├── DriveMapper.psd1          # Module manifest
├── DriveMapper.psm1          # Main module file
├── Build.ps1                 # Build and test runner
├── QuickTest.ps1             # Quick verification script
├── Setup.ps1                 # Local setup helper
├── Public/                   # Exported functions
│   └── DriveMapping.ps1
├── Private/                  # Internal helpers
├── Scripts/                  # Production scripts
│   └── Auto-Mount-Drives.ps1
├── Tests/                    # Pester tests
│   └── DriveMapping.Tests.ps1
├── Config/                   # Configuration files
│   └── drive-mappings.yaml
├── Logs/                     # Log files
├── .vscode/                  # VS Code configuration
└── README.md
```

## Requirements

- Windows PowerShell 5.1 or PowerShell 7.x
- Pester 5.0+
- powershell-yaml 0.4.0+

## Installation

### 1. Install VS Code extensions

Open the project in VS Code and install recommended extensions:

```
Ctrl+Shift+P -> Extensions: Show Recommended Extensions
```

Recommended:
- PowerShell
- Pester Test
- YAML
- Code Runner

### 2. Install Pester

```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
```

### 3. Import the module

```powershell
Import-Module ".\DriveMapper.psd1" -Force
```

## Running Tests in VS Code

### Run all tests
1. `Ctrl+Shift+P` -> `Tasks: Run Task`
2. Select: `Run All Pester Tests`

### Run a single test file
1. Open a `.Tests.ps1` file
2. `Ctrl+Shift+P` -> `Tasks: Run Task`
3. Select: `Run Specific Pester Test`

### Code coverage
1. `Ctrl+Shift+P` -> `Tasks: Run Task`
2. Select: `Run Pester Tests with Coverage`

### Debugging
1. Open the test file
2. `F5` -> `PowerShell: Debug Pester Tests`

## Usage

See the detailed usage guide in [docs/USAGE.md][USAGE], including production login/boot setup.

### Start-AutoMount

```powershell
$result = Start-AutoMount -ConfigPath ".\Config\drive-mappings.yaml"

Write-Host "Exit code: $($result.ExitCode)"
Write-Host "Message: $($result.Message)"
```

### Utilities

```powershell
# Drive letter validation
$result = Format-DriveLetter -Drive "p"  # -> "P:"

# Path validation
$result = Test-PathValid -Path "C:\Projects"
if ($result.Valid) { ... }

# Current mappings
$result = Get-SubstMappings
$result.Mappings  # Hashtable: "P:" -> "C:\Projects"
```

## Configuration

### `drive-mappings.yaml`

```yaml
Drive-Mapping:
  - P: "C:/Users/YourName/Projects"
  - R: "C:/Users/YourName/Repos"
  - T: "D:/Tools"
```

## Development

### Build, setup, and quick verification scripts

#### `Build.ps1`

Runs build and test tasks in a single entry point.
See the detailed guide in [docs/BUILD.md][BUILD].

```powershell
# Run tests only
.\Build.ps1 -Task Test

# Full pipeline (clean, build, test, coverage, install)
.\Build.ps1 -Task All
```

#### `QuickTest.ps1`

Runs a fast smoke test to verify core functions without a full suite.

```powershell
.\QuickTest.ps1
```

#### `Setup.ps1`

Bootstraps local development prerequisites and environment defaults.
See the detailed guide in [docs/SETUP.md][SETUP].

```powershell
.\Setup.ps1
```

### Code quality

```powershell
Invoke-ScriptAnalyzer -Path ".\Public" -Settings ".\.vscode\PSScriptAnalyzerSettings.psd1"
```

### Add a new test

1. Add a new `Describe` block to `DriveMapping.Tests.ps1`
2. Use `Mock` to isolate external commands
3. Run with `F5` in debug mode

### Performance tests

```powershell
Invoke-Pester -Path ".\Tests\DriveMapping.Tests.ps1" -Tag "Performance"
```

## Troubleshooting

**Module cannot be imported**
```powershell
Test-ModuleManifest ".\DriveMapper.psd1"
```

**Pester tests fail**
```powershell
Update-Module Pester -Force
```

**Tests ask for user input**
```powershell
$env:AUTOMATED_TESTING = "true"
Import-Module Pester -Force
Invoke-Pester -Path ".\Tests"
Remove-Item Env:AUTOMATED_TESTING -ErrorAction SilentlyContinue
```

**Access denied on subst**
```powershell
Start-Process powershell -Verb runAs
```

### Environment Variables

- `AUTOMATED_TESTING=true`: disables user prompts during tests
- `CI=true`: enables CI mode (also disables prompts)

## Contribution

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m "Add amazing feature"`
4. Push: `git push origin feature/amazing-feature`
5. Open a Pull Request

## License

MIT License - see [LICENSE].

## Support

1. Check the [Issues] page
2. Open a new issue with repro steps and error messages
3. Include your PowerShell version

---

Created by: GergelyToth2 @ EPAM

[//]: #References

[USAGE]: ./docs/USAGE.md
[BUILD]: ./docs/BUILD.md
[SETUP]: ./docs/SETUP.md
[Issues]: ../../issues
[LICENSE]: ./LICENSE.md