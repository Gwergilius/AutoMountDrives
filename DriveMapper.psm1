# DriveMapper PowerShell Module
# Main module file that exports public functions

using namespace System.Management.Automation

# Import the script files
$ScriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent

# Import private functions (helper functions)
Get-ChildItem -Path "$ScriptPath\Private\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

# Import public functions
Get-ChildItem -Path "$ScriptPath\Public\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

# Set module variables
$script:ModulePath = $ScriptPath
$script:ConfigPath = "$ScriptPath\Config"
$script:LogPath = "$ScriptPath\Logs"

# Ensure log directory exists
if (-not (Test-Path $script:LogPath)) {
    New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null
}

# Export public functions
Export-ModuleMember -Function @(
    'Mount-Folder',
    'Start-AutoMount', 
    'Get-SubstMappings',
    'Test-PathValid',
    'Format-DriveLetter',
    'Write-MountLog',
    'Get-DriveMappingsFromYaml',
    'Add-SubstMapping',
    'Remove-SubstMapping'
)
