# Auto-Mount-Drives.ps1 - Production script using DriveMapper module
# Automatically mount drives at system startup using the Public API

param(
    [string]$ConfigPath = $null,
    [string]$LogPath = $null
)

# Determine script and module paths
$ScriptFolder = $PSScriptRoot
$ModuleRoot = Split-Path $ScriptFolder -Parent

# Set default paths relative to script location
if (-not $ConfigPath) {
    $ConfigPath = "$ModuleRoot\Config\drive-mappings.yaml"
}

if (-not $LogPath) {
    $LogPath = "$ModuleRoot\Logs\auto-mount.log"
}

# Ensure log directory exists
$logDir = Split-Path -Path $LogPath -Parent
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

try {
    # Import the DriveMapper module
    $ModuleManifest = "$ModuleRoot\DriveMapper.psd1"
    
    if (-not (Test-Path -Path $ModuleManifest)) {
        Write-Error "DriveMapper module not found at: $ModuleManifest"
        exit 1
    }
    
    Import-Module $ModuleManifest -Force -ErrorAction Stop
    
    # Use the Public API function Start-AutoMount
    $result = Start-AutoMount -ConfigPath $ConfigPath -LogPath $LogPath
    
    # Exit with appropriate code based on result
    if ($result.Success) {
        exit $result.ExitCode
    } else {
        Write-Error "Auto-Mount failed: $($result.Message)"
        exit $result.ExitCode
    }
}
catch {
    Write-Error "Failed to import DriveMapper module or execute Start-AutoMount: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
finally {
    # Clean up module if needed
    Remove-Module DriveMapper -Force -ErrorAction SilentlyContinue
}
