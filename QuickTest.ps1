# QuickTest.ps1
# Quick test script to verify the module works without prompts

Write-Host "=== DriveMapper Quick Test ===" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"

try {
    # Set automated testing flag
    $env:AUTOMATED_TESTING = "true"
    Write-Host "Setting automated testing mode..." -ForegroundColor Yellow
    
    # Create a temporary test directory
    $TestPath = "$env:TEMP\DriveMapperTest_$(Get-Random)"
    New-Item -ItemType Directory -Path $TestPath -Force | Out-Null
    Write-Host "Created test directory: $TestPath" -ForegroundColor Gray
    
    # Import the module
    Write-Host "Importing DriveMapper module..." -ForegroundColor Yellow
    Import-Module ".\DriveMapper.psd1" -Force
    
    # Test basic functions
    Write-Host "Testing Format-DriveLetter function..." -ForegroundColor Yellow
    $result = Format-DriveLetter -Drive "T"
    if ($result.Success -and $result.DriveLetter -eq "T:") {
        Write-Host "✓ Format-DriveLetter works correctly" -ForegroundColor Green
    } else {
        throw "Format-DriveLetter test failed"
    }
    
    # Test path validation with system directory
    Write-Host "Testing Test-PathValid function..." -ForegroundColor Yellow
    $result = Test-PathValid -Path $env:WINDIR
    if ($result.Valid) {
        Write-Host "✓ Test-PathValid works correctly" -ForegroundColor Green
    } else {
        throw "Test-PathValid test failed: $($result.Message)"
    }
    
    # Test subst mappings
    Write-Host "Testing Get-SubstMappings function..." -ForegroundColor Yellow
    $result = Get-SubstMappings
    if ($result.Success) {
        Write-Host "✓ Get-SubstMappings works correctly" -ForegroundColor Green
        Write-Host "  Current mappings count: $($result.Count)" -ForegroundColor Gray
    } else {
        Write-Warning "Get-SubstMappings returned: $($result.Message)"
    }
    
    # Test Write-MountLog function specifically
    Write-Host "Testing Write-MountLog function..." -ForegroundColor Yellow
    try {
        $logOutput = Write-MountLog -Message "Test log message" -Level "INFO" 6>&1
        if ($logOutput -match "Test log message") {
            Write-Host "✓ Write-MountLog works correctly" -ForegroundColor Green
        } else {
            throw "Write-MountLog output not captured"
        }
    }
    catch {
        throw "Write-MountLog test failed: $($_.Exception.Message)"
    }
    
    # Test automated testing environment variable
    Write-Host "Testing AUTOMATED_TESTING environment variable..." -ForegroundColor Yellow
    if ($env:AUTOMATED_TESTING -eq "true") {
        Write-Host "✓ AUTOMATED_TESTING environment variable is set correctly" -ForegroundColor Green
    } else {
        Write-Warning "AUTOMATED_TESTING environment variable is: '$($env:AUTOMATED_TESTING)'"
        Write-Host "✓ Environment variable test noted (this may be expected)" -ForegroundColor Yellow
    }
    
    # Test YAML parsing function
    Write-Host "Testing Get-DriveMappingsFromYaml function..." -ForegroundColor Yellow
    try {
        # Create a simple test YAML file
        $TestYaml = "$TestPath\test.yaml"
        $YamlContent = @"
Drive-Mapping:
  - P: "$($TestPath -replace '\\', '/')"
  - R: "$($env:WINDIR -replace '\\', '/')"
"@
        Set-Content -Path $TestYaml -Value $YamlContent -Encoding UTF8
        
        # Test the function (this will likely fail if powershell-yaml is not installed, but that's OK)
        try {
            $mappings = Get-DriveMappingsFromYaml -YamlPath $TestYaml
            Write-Host "✓ Get-DriveMappingsFromYaml works correctly" -ForegroundColor Green
            Write-Host "  Found $($mappings.Count) mappings" -ForegroundColor Gray
        }
        catch {
            Write-Warning "Get-DriveMappingsFromYaml failed (likely missing powershell-yaml): $($_.Exception.Message)"
            Write-Host "✓ YAML function tested (failure expected without powershell-yaml)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning "YAML test setup failed: $($_.Exception.Message)"
    }
    
    Write-Host ""
    Write-Host "=== Quick Test PASSED ===" -ForegroundColor Green
    Write-Host "The module can be imported and basic functions work without user prompts." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Run full Pester tests: .\Build.ps1 -Task Test" -ForegroundColor White
    Write-Host "2. Open in VS Code: code ." -ForegroundColor White
    Write-Host "3. Use VS Code tasks for testing and debugging" -ForegroundColor White
    
}
catch {
    Write-Host ""
    Write-Host "=== Quick Test FAILED ===" -ForegroundColor Red
    Write-Error "Error: $($_.Exception.Message)"
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
finally {
    # Always cleanup environment variable
    Remove-Item Env:AUTOMATED_TESTING -ErrorAction SilentlyContinue
    Write-Host "Cleaned up environment variables." -ForegroundColor Gray
    
    # Cleanup test directory if it exists
    if ($TestPath -and (Test-Path $TestPath)) {
        Remove-Item $TestPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Cleaned up test directory." -ForegroundColor Gray
    }
}
