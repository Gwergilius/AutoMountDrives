# Setup.ps1
# Quick setup script for DriveMapper PowerShell solution

[CmdletBinding()]
param(
    [switch]$SkipVSCode,
    [switch]$SkipPester,
    [switch]$Force
)

Write-Host "=== DriveMapper PowerShell Solution Setup ===" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = $PSScriptRoot
$ModuleName = "DriveMapper"

# Function to test if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to check PowerShell version
function Test-PowerShellVersion {
    $MinVersion = [version]"5.1"
    $CurrentVersion = $PSVersionTable.PSVersion
    
    Write-Host "PowerShell Version: $CurrentVersion" -ForegroundColor Green
    
    if ($CurrentVersion -lt $MinVersion) {
        Write-Error "PowerShell $MinVersion or later is required. Current version: $CurrentVersion"
        return $false
    }
    return $true
}

# Function to install required modules
function Install-RequiredModules {
    Write-Host "Installing required PowerShell modules..." -ForegroundColor Yellow
    
    $RequiredModules = @(
        @{ Name = "Pester"; MinVersion = "5.0.0" },
        @{ Name = "powershell-yaml"; MinVersion = "0.4.0" },
        @{ Name = "PSScriptAnalyzer"; MinVersion = "1.18.0" }
    )
    
    foreach ($Module in $RequiredModules) {
        try {
            $InstalledModule = Get-Module -ListAvailable -Name $Module.Name | 
                Where-Object { $_.Version -ge [version]$Module.MinVersion } | 
                Sort-Object Version -Descending | 
                Select-Object -First 1
                
            if (-not $InstalledModule) {
                Write-Host "Installing $($Module.Name) v$($Module.MinVersion)..." -ForegroundColor Yellow
                Install-Module -Name $Module.Name -MinimumVersion $Module.MinVersion -Scope CurrentUser -Force -SkipPublisherCheck
                Write-Host "✓ $($Module.Name) installed successfully" -ForegroundColor Green
            } else {
                Write-Host "✓ $($Module.Name) v$($InstalledModule.Version) already installed" -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Failed to install $($Module.Name): $($_.Exception.Message)"
            return $false
        }
    }
    return $true
}

# Function to test VS Code installation
function Test-VSCodeInstalled {
    try {
        $null = Get-Command "code" -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Function to install VS Code extensions
function Install-VSCodeExtensions {
    if (-not (Test-VSCodeInstalled)) {
        Write-Warning "VS Code is not installed or not in PATH. Skipping extension installation."
        return $false
    }
    
    Write-Host "Installing VS Code extensions..." -ForegroundColor Yellow
    
    $Extensions = @(
        "ms-vscode.powershell",
        "pspester.pester-test", 
        "redhat.vscode-yaml",
        "ms-vscode.vscode-json"
    )
    
    foreach ($Extension in $Extensions) {
        try {
            Write-Host "Installing extension: $Extension" -ForegroundColor Yellow
            $result = & code --install-extension $Extension --force 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ $Extension installed successfully" -ForegroundColor Green
            } else {
                Write-Warning "Failed to install $Extension - exit code: $LASTEXITCODE"
            }
        }
        catch {
            Write-Warning "Error installing $Extension`: $($_.Exception.Message)"
        }
    }
    return $true
}

# Function to test module
function Test-Module {
    Write-Host "Testing DriveMapper module..." -ForegroundColor Yellow
    
    try {
        # Test module manifest
        $Manifest = Test-ModuleManifest -Path "$ProjectRoot\$ModuleName.psd1"
        Write-Host "✓ Module manifest is valid" -ForegroundColor Green
        
        # Try to import module
        Import-Module "$ProjectRoot\$ModuleName.psd1" -Force
        $ImportedModule = Get-Module $ModuleName
        Write-Host "✓ Module imported successfully" -ForegroundColor Green
        Write-Host "  Exported functions: $($ImportedModule.ExportedFunctions.Keys -join ', ')" -ForegroundColor Gray
        
        return $true
    }
    catch {
        Write-Error "Module test failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to run quick tests
function Invoke-QuickTest {
    Write-Host "Running quick Pester tests..." -ForegroundColor Yellow
    
    # Set automated testing flag to avoid prompts
    $env:AUTOMATED_TESTING = "true"
    
    try {
        Import-Module Pester -MinimumVersion 5.0.0 -Force
        
        $PesterConfig = New-PesterConfiguration
        $PesterConfig.Run.Path = "$ProjectRoot\Tests"
        $PesterConfig.Output.Verbosity = 'Minimal'
        $PesterConfig.Run.PassThru = $true
        
        $TestResult = Invoke-Pester -Configuration $PesterConfig
        
        if ($TestResult.FailedCount -eq 0) {
            Write-Host "✓ All tests passed! ($($TestResult.PassedCount)/$($TestResult.TotalCount))" -ForegroundColor Green
            return $true
        } else {
            Write-Warning "Some tests failed ($($TestResult.FailedCount)/$($TestResult.TotalCount))"
            return $false
        }
    }
    catch {
        Write-Error "Quick test failed: $($_.Exception.Message)"
        return $false
    }
    finally {
        # Clean up environment variable
        Remove-Item Env:AUTOMATED_TESTING -ErrorAction SilentlyContinue
    }
}

# Main setup process
try {
    # Check PowerShell version
    if (-not (Test-PowerShellVersion)) {
        exit 1
    }
    
    # Check if running as administrator for subst commands
    if (-not (Test-Administrator)) {
        Write-Warning "Not running as Administrator. Some drive mapping features may not work properly."
        Write-Host "For full functionality, run PowerShell as Administrator." -ForegroundColor Yellow
    }
    
    # Install required modules
    if (-not $SkipPester -and -not (Install-RequiredModules)) {
        Write-Error "Failed to install required modules"
        exit 1
    }
    
    # Install VS Code extensions
    if (-not $SkipVSCode) {
        Install-VSCodeExtensions | Out-Null
    }
    
    # Test module
    if (-not (Test-Module)) {
        Write-Error "Module test failed"
        exit 1
    }
    
    # Run quick tests
    if (-not $SkipPester) {
        Invoke-QuickTest | Out-Null
    }
    
    # Success message
    Write-Host ""
    Write-Host "=== Setup completed successfully! ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Open VS Code: code ." -ForegroundColor White
    Write-Host "2. Run all tests: Ctrl+Shift+P → 'Tasks: Run Task' → 'Run All Pester Tests'" -ForegroundColor White
    Write-Host "3. Start debugging: F5 → Select debug configuration" -ForegroundColor White
    Write-Host "4. Build and test: .\Build.ps1 -Task All" -ForegroundColor White
    Write-Host ""
    Write-Host "Module functions available:" -ForegroundColor Cyan
    $ImportedModule = Get-Module $ModuleName -ErrorAction SilentlyContinue
    if ($ImportedModule) {
        $ImportedModule.ExportedFunctions.Keys | ForEach-Object {
            Write-Host "  • $_" -ForegroundColor Gray
        }
    }
    Write-Host ""
    
}
catch {
    Write-Error "Setup failed: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
