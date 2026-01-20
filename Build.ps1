# Build.ps1
# Build and test script for DriveMapper module

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("Clean", "Build", "Test", "Coverage", "Install", "All")]
    [string[]]$Task = @("Build", "Test"),
    
    [switch]$SkipModuleCheck,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

# Get script location
$ProjectRoot = $PSScriptRoot
$ModuleName = "DriveMapper"
$ModulePath = "$ProjectRoot\$ModuleName.psd1"

Write-Information "=== DriveMapper Build Script ===" -InformationAction Continue
Write-Information "Project Root: $ProjectRoot" -InformationAction Continue
Write-Information "Tasks: $($Task -join ', ')" -InformationAction Continue

function Test-RequiredModules {
    Write-Information "Checking required modules..." -InformationAction Continue
    
    $RequiredModules = @(
        @{ Name = "Pester"; MinVersion = "5.0.0" },
        @{ Name = "powershell-yaml"; MinVersion = "0.4.0" }
    )
    
    foreach ($Module in $RequiredModules) {
        $InstalledModule = Get-Module -ListAvailable -Name $Module.Name | 
            Where-Object { $_.Version -ge [version]$Module.MinVersion } | 
            Sort-Object Version -Descending | 
            Select-Object -First 1
            
        if (-not $InstalledModule) {
            Write-Warning "Module $($Module.Name) (min version $($Module.MinVersion)) not found. Installing..."
            try {
                Install-Module -Name $Module.Name -MinimumVersion $Module.MinVersion -Scope CurrentUser -Force -SkipPublisherCheck
                Write-Information "Successfully installed $($Module.Name)" -InformationAction Continue
            }
            catch {
                Write-Error "Failed to install $($Module.Name): $($_.Exception.Message)"
                return $false
            }
        } else {
            Write-Information "$($Module.Name) v$($InstalledModule.Version) - OK" -InformationAction Continue
        }
    }
    return $true
}

function Invoke-Clean {
    Write-Information "Cleaning build artifacts..." -InformationAction Continue
    
    # Clean log files
    if (Test-Path "$ProjectRoot\Logs") {
        Get-ChildItem "$ProjectRoot\Logs\*.log" | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    
    # Clean temp test files
    Get-ChildItem $env:TEMP -Filter "DriveMapperTests_*" -Directory -ErrorAction SilentlyContinue | 
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Information "Clean completed." -InformationAction Continue
}

function Invoke-Build {
    Write-Information "Building module..." -InformationAction Continue
    
    # Test module manifest
    try {
        $Manifest = Test-ModuleManifest -Path $ModulePath
        Write-Information "Module manifest test - PASSED" -InformationAction Continue
        Write-Information "Module: $($Manifest.Name) v$($Manifest.Version)" -InformationAction Continue
    }
    catch {
        Write-Error "Module manifest test failed: $($_.Exception.Message)"
        return $false
    }
    
    # Try to import module
    try {
        Import-Module $ModulePath -Force
        $ImportedModule = Get-Module $ModuleName
        Write-Information "Module import - PASSED" -InformationAction Continue
        Write-Information "Exported functions: $($ImportedModule.ExportedFunctions.Count)" -InformationAction Continue
    }
    catch {
        Write-Error "Module import failed: $($_.Exception.Message)"
        return $false
    }
    
    Write-Information "Build completed successfully." -InformationAction Continue
    return $true
}

function Invoke-Test {
    Write-Information "Running Pester tests..." -InformationAction Continue
    
    $hadAutomatedTesting = Test-Path Env:AUTOMATED_TESTING
    $originalAutomatedTesting = $env:AUTOMATED_TESTING
    
    # Set automated testing flag to avoid prompts
    $env:AUTOMATED_TESTING = "true"
    
    # Import Pester
    try {
        Import-Module Pester -MinimumVersion 5.0.0 -Force
    }
    catch {
        Write-Error "Failed to import Pester: $($_.Exception.Message)"
        return $false
    }
    
    # Configure Pester
    $PesterConfig = New-PesterConfiguration
    $PesterConfig.Run.Path = "$ProjectRoot\Tests"
    $PesterConfig.Run.PassThru = $true
    $PesterConfig.Output.Verbosity = 'Detailed'
    $PesterConfig.TestResult.Enabled = $true
    $PesterConfig.TestResult.OutputPath = "$ProjectRoot\Logs\TestResults.xml"
    
    # Create logs directory if it doesn't exist
    if (-not (Test-Path "$ProjectRoot\Logs")) {
        New-Item -ItemType Directory -Path "$ProjectRoot\Logs" -Force | Out-Null
    }
    
    # Run tests
    try {
        $TestResult = Invoke-Pester -Configuration $PesterConfig
        
        Write-Information "Test Summary:" -InformationAction Continue
        Write-Information "  Total: $($TestResult.TotalCount)" -InformationAction Continue
        Write-Information "  Passed: $($TestResult.PassedCount)" -InformationAction Continue
        Write-Information "  Failed: $($TestResult.FailedCount)" -InformationAction Continue
        Write-Information "  Duration: $($TestResult.Duration)" -InformationAction Continue
        
        # Check if any tests failed
        if ($TestResult.FailedCount -gt 0) {
            Write-Error "❌ $($TestResult.FailedCount) tests failed. Check the output above for details."
            return $false
        }
        
        Write-Information "✅ All $($TestResult.PassedCount) tests passed!" -InformationAction Continue
        return $true
    }
    catch {
        Write-Error "Test execution failed: $($_.Exception.Message)"
        return $false
    }
    finally {
        if ($hadAutomatedTesting) {
            $env:AUTOMATED_TESTING = $originalAutomatedTesting
        } else {
            Remove-Item Env:AUTOMATED_TESTING -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-Coverage {
    Write-Information "Running tests with code coverage..." -InformationAction Continue
    
    $hadAutomatedTesting = Test-Path Env:AUTOMATED_TESTING
    $originalAutomatedTesting = $env:AUTOMATED_TESTING
    
    # Set automated testing flag to avoid prompts
    $env:AUTOMATED_TESTING = "true"
    
    try {
        # Import Pester
        Import-Module Pester -MinimumVersion 5.0.0 -Force
        
        # Configure Pester with code coverage
        $PesterConfig = New-PesterConfiguration
    $PesterConfig.Run.Path = "$ProjectRoot\Tests"
    $PesterConfig.Run.PassThru = $true
        $PesterConfig.Output.Verbosity = 'Detailed'
        $PesterConfig.CodeCoverage.Enabled = $true
        $PesterConfig.CodeCoverage.Path = @(
            "$ProjectRoot\Public\*.ps1",
            "$ProjectRoot\Scripts\*.ps1"
        )
        $PesterConfig.CodeCoverage.OutputPath = "$ProjectRoot\Logs\CodeCoverage.xml"
        
        # Create logs directory if it doesn't exist
        if (-not (Test-Path "$ProjectRoot\Logs")) {
            New-Item -ItemType Directory -Path "$ProjectRoot\Logs" -Force | Out-Null
        }
        
        # Run tests with coverage
        $TestResult = Invoke-Pester -Configuration $PesterConfig
        
        Write-Information "Coverage Summary:" -InformationAction Continue
        Write-Information "  Total Commands: $($TestResult.CodeCoverage.NumberOfCommandsAnalyzed)" -InformationAction Continue
        Write-Information "  Commands Executed: $($TestResult.CodeCoverage.NumberOfCommandsExecuted)" -InformationAction Continue
        Write-Information "  Coverage Percentage: $([math]::Round($TestResult.CodeCoverage.CoveragePercent, 2))%" -InformationAction Continue
        
        Write-Information "Test Results:" -InformationAction Continue
        Write-Information "  Total: $($TestResult.TotalCount)" -InformationAction Continue
        Write-Information "  Passed: $($TestResult.PassedCount)" -InformationAction Continue
        Write-Information "  Failed: $($TestResult.FailedCount)" -InformationAction Continue
        
        if ($TestResult.FailedCount -gt 0) {
            Write-Error "❌ $($TestResult.FailedCount) tests failed during coverage analysis."
            return $false
        }
        
        return $true
    }
    catch {
        Write-Error "Coverage test failed: $($_.Exception.Message)"
        return $false
    }
    finally {
        if ($hadAutomatedTesting) {
            $env:AUTOMATED_TESTING = $originalAutomatedTesting
        } else {
            Remove-Item Env:AUTOMATED_TESTING -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-Install {
    Write-Information "Installing module to user scope..." -InformationAction Continue
    
    $UserModulesPath = "$env:USERPROFILE\Documents\PowerShell\Modules\$ModuleName"
    
    if (Test-Path $UserModulesPath) {
        if ($Force) {
            Remove-Item $UserModulesPath -Recurse -Force
            Write-Information "Removed existing installation." -InformationAction Continue
        } else {
            Write-Warning "Module already installed. Use -Force to overwrite."
            return $false
        }
    }
    
    # Copy module files
    New-Item -ItemType Directory -Path $UserModulesPath -Force | Out-Null
    Copy-Item -Path "$ProjectRoot\*" -Destination $UserModulesPath -Recurse -Exclude @(".git", "Tests", "Logs")
    
    Write-Information "Module installed to: $UserModulesPath" -InformationAction Continue
    Write-Information "You can now use: Import-Module $ModuleName" -InformationAction Continue
    
    return $true
}

# Main execution
$Success = $true

# Check required modules unless skipped
if (-not $SkipModuleCheck) {
    if (-not (Test-RequiredModules)) {
        $Success = $false
    }
}

# Execute tasks
if ($Success) {
    foreach ($CurrentTask in $Task) {
        Write-Information "`n--- Executing task: $CurrentTask ---" -InformationAction Continue
        
        $TaskResult = switch ($CurrentTask) {
            "Clean"     { Invoke-Clean; $true }
            "Build"     { Invoke-Build }
            "Test"      { Invoke-Test }
            "Coverage"  { Invoke-Coverage }
            "Install"   { Invoke-Install }
            "All"       { 
                (Invoke-Clean) -and 
                (Invoke-Build) -and 
                (Invoke-Test) -and 
                (Invoke-Coverage) -and
                (Invoke-Install)
            }
        }
        
        if (-not $TaskResult) {
            Write-Error "Task $CurrentTask failed!"
            $Success = $false
            break
        }
    }
}

# Final result
if ($Success) {
    Write-Information "`n=== Build SUCCEEDED ===" -InformationAction Continue
    exit 0
} else {
    Write-Error "`n=== Build FAILED ==="
    exit 1
}
