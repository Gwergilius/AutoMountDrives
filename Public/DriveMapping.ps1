# Public\DriveMapping.ps1
# Public functions with full implementation for testing

# Enhanced logging function
function Write-MountLog {
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogPath = $null
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output with color
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN"  { Write-Host $logEntry -ForegroundColor Yellow }
        "INFO"  { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry }
    }
    
    # Log to file if path provided
    if ($LogPath) {
        try {
            Add-Content -Path $LogPath -Value $logEntry -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

# Ensure drive letter format is correct (X:)
function Format-DriveLetter {
    [CmdletBinding()]
    param([string]$Drive)
    
    try {
        $Drive = $Drive.Trim().ToUpper()
        if ($Drive -notmatch '^[A-Z]:?$') {
            return @{ Success = $false; Message = "Invalid drive letter format: '$Drive'. Use format like 'U' or 'U:'" }
        }
        
        if ($Drive -notmatch ':$') {
            $Drive += ':'
        }
        
        return @{ Success = $true; DriveLetter = $Drive }
    }
    catch {
        return @{ Success = $false; Message = "Error formatting drive letter '$Drive': $($_.Exception.Message)" }
    }
}

# Validate path exists and is accessible
function Test-PathValid {
    [CmdletBinding()]
    param([string]$Path)
    
    try {
        # Check if path is empty or null
        if ([string]::IsNullOrWhiteSpace($Path)) {
            return @{ Valid = $false; Message = "Path cannot be empty or null" }
        }
        
        # Check if path exists
        if (-not (Test-Path -Path $Path -ErrorAction Stop)) {
            return @{ Valid = $false; Message = "Path does not exist: '$Path'" }
        }
        
        # Check if it's a directory
        $item = Get-Item -Path $Path -ErrorAction Stop
        if (-not $item.PSIsContainer) {
            return @{ Valid = $false; Message = "Path is not a directory: '$Path'" }
        }
        
        # Check if accessible (try to list contents)
        try {
            Get-ChildItem -Path $Path -ErrorAction Stop | Out-Null
            return @{ Valid = $true; Message = "Path is valid and accessible" }
        }
        catch {
            return @{ Valid = $false; Message = "Path exists but is not accessible: '$Path'. Error: $($_.Exception.Message)" }
        }
    }
    catch {
        return @{ Valid = $false; Message = "Error validating path '$Path': $($_.Exception.Message)" }
    }
}

# Get current subst mappings
function Get-SubstMappings {
    [CmdletBinding()]
    param()
    
    try {
        $substOutput = & subst 2>&1
        $mappings = @{}
        
        if ($LASTEXITCODE -ne 0) {
            return @{ Success = $false; Mappings = @{}; Message = "subst command returned exit code $LASTEXITCODE" }
        }
        
        foreach ($line in $substOutput) {
            if ($line -and $line.ToString().ToUpper() -match '^([A-Z]:)\\: => (.+)$') {
                $mappings[$matches[1]] = $matches[2]
            }
        }
        
        return @{ Success = $true; Mappings = $mappings; Count = $mappings.Count }
    }
    catch {
        return @{ Success = $false; Mappings = @{}; Message = "Error getting subst mappings: $($_.Exception.Message)" }
    }
}

function Remove-SubstMapping {
    [CmdletBinding()]
    param(
        [string]$DriveLetter,
        [string]$LogPath = $null
    )
    
    try {
        Write-MountLog -Message "Attempting to unmount drive $DriveLetter" -Level "INFO" -LogPath $LogPath
        
        $result = & subst $DriveLetter /D 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-MountLog -Message "Successfully unmounted drive $DriveLetter" -Level "INFO" -LogPath $LogPath
            return $true
        } else {
            Write-MountLog -Message "Failed to unmount drive $DriveLetter. Exit code: $LASTEXITCODE, Output: $result" -Level "ERROR" -LogPath $LogPath
            return $false
        }
    } catch {
        Write-MountLog -Message "Error unmounting drive $DriveLetter`: $($_.Exception.Message)" -Level "ERROR" -LogPath $LogPath
        return $false
    }
}

function Add-SubstMapping {
    [CmdletBinding()]
    param(
        [string]$DriveLetter,
        [string]$Path,
        [string]$LogPath = $null
    )
    
    try {
        Write-MountLog -Message "Attempting to mount '$Path' as drive $DriveLetter" -Level "INFO" -LogPath $LogPath
        
        $result = & subst $DriveLetter $Path 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-MountLog -Message "Successfully mounted '$Path' as drive $DriveLetter" -Level "INFO" -LogPath $LogPath
            return $true
        } else {
            Write-MountLog -Message "Failed to mount '$Path' as drive $DriveLetter. Exit code: $LASTEXITCODE, Output: $result" -Level "ERROR" -LogPath $LogPath
            return $false
        }
    } catch {
        Write-MountLog -Message "Error mounting drive: $($_.Exception.Message)" -Level "ERROR" -LogPath $LogPath
        return $false
    }
}

function Mount-Folder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter,
        
        [switch]$Force,
        
        [string]$LogPath = $null
    )
    
    try {
        Write-MountLog -Message "Starting mount operation for path '$Path' to drive '$DriveLetter'" -Level "INFO" -LogPath $LogPath
        
        # Validate and format drive letter
        $driveResult = Format-DriveLetter -Drive $DriveLetter
        if (-not $driveResult.Success) {
            return @{ Success = $false; Message = $driveResult.Message }
        }
        $DriveLetter = $driveResult.DriveLetter
        
        # Validate path exists and is accessible
        $pathResult = Test-PathValid -Path $Path
        if (-not $pathResult.Valid) {
            return @{ Success = $false; Message = $pathResult.Message }
        }
        
        # Convert to absolute path
        try {
            $Path = (Resolve-Path -Path $Path -ErrorAction Stop).Path
            Write-MountLog -Message "Resolved absolute path: $Path" -Level "INFO" -LogPath $LogPath
        }
        catch {
            $errorMsg = "Error resolving path '$Path': $($_.Exception.Message)"
            Write-MountLog -Message $errorMsg -Level "ERROR" -LogPath $LogPath
            return @{ Success = $false; Message = $errorMsg }
        }
        
        # Check current subst mappings
        $mappingsResult = Get-SubstMappings
        if (-not $mappingsResult.Success) {
            return @{ Success = $false; Message = $mappingsResult.Message }
        }
        
        $currentMappings = $mappingsResult.Mappings
        $driveIsMounted = $currentMappings.ContainsKey($DriveLetter)
        
        if ($driveIsMounted) {
            $currentPath = $currentMappings[$DriveLetter]
            
            # Check if it's already mounted to the same path
            if ($currentPath -eq $Path) {
                Write-MountLog -Message "Drive $DriveLetter is already mounted to '$Path'" -Level "INFO" -LogPath $LogPath
                return @{ Success = $true; Message = "Drive $DriveLetter is already mounted to '$Path'" }
            }
            
            Write-MountLog -Message "Drive $DriveLetter is currently mounted to: '$currentPath'" -Level "WARN" -LogPath $LogPath
            
            if (-not $Force) {
                # In automated scenarios (like tests), we should not prompt
                if ($env:AUTOMATED_TESTING -eq "true" -or $env:CI -eq "true") {
                    Write-MountLog -Message "Automated mode: Skipping user prompt, will remount" -Level "INFO" -LogPath $LogPath
                } else {
                    # Ask for confirmation only in interactive mode
                    $response = Read-Host "Do you want to remount it to '$Path'? (y/N)"
                    if ($response -notmatch '^[yY]$') {
                        Write-MountLog -Message "Operation cancelled by user" -Level "INFO" -LogPath $LogPath
                        return @{ Success = $true; Message = "Operation cancelled by user" }
                    }
                }
            }
            
            # Unmount existing drive
            Write-MountLog -Message "Unmounting existing drive $DriveLetter..." -Level "INFO" -LogPath $LogPath
            if (-not (Remove-SubstMapping -DriveLetter $DriveLetter -LogPath $LogPath)) {
                $errorMsg = "Failed to unmount existing drive $DriveLetter"
                Write-MountLog -Message $errorMsg -Level "ERROR" -LogPath $LogPath
                return @{ Success = $false; Message = $errorMsg }
            }
        }
        
        # Mount the new drive mapping
        if (Add-SubstMapping -DriveLetter $DriveLetter -Path $Path -LogPath $LogPath) {
            Write-MountLog -Message "Mount operation completed successfully!" -Level "INFO" -LogPath $LogPath
            
            # Show current mappings
            $updatedResult = Get-SubstMappings
            if ($updatedResult.Success) {
                Write-MountLog -Message "Current drive mappings:" -Level "INFO" -LogPath $LogPath
                foreach ($mapping in $updatedResult.Mappings.GetEnumerator()) {
                    Write-MountLog -Message "  $($mapping.Key) => $($mapping.Value)" -Level "INFO" -LogPath $LogPath
                }
            }
            
            return @{ Success = $true; Message = "Successfully mounted '$Path' as drive $DriveLetter" }
        } else {
            $errorMsg = "Mount operation failed"
            Write-MountLog -Message $errorMsg -Level "ERROR" -LogPath $LogPath
            return @{ Success = $false; Message = $errorMsg }
        }
    }
    catch {
        $errorMsg = "Unexpected error in Mount-Folder: $($_.Exception.Message)"
        Write-MountLog -Message $errorMsg -Level "ERROR" -LogPath $LogPath
        return @{ Success = $false; Message = $errorMsg; Exception = $_ }
    }
}

function Start-AutoMount {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = $null,
        [string]$LogPath = $null
    )
    
    # Set default paths if not provided
    if (-not $ConfigPath) { $ConfigPath = "$script:ConfigPath\drive-mappings.yaml" }
    if (-not $LogPath) { $LogPath = "$script:LogPath\auto-mount.log" }
    
    $hadAutomatedTesting = Test-Path Env:AUTOMATED_TESTING
    $originalAutomatedTesting = $env:AUTOMATED_TESTING
    
    try {
        Write-MountLog -Message "Starting Auto-Mount-Drives script" -Level "INFO" -LogPath $LogPath
        Write-MountLog -Message "Configuration: Config=$ConfigPath, Log=$LogPath" -Level "INFO" -LogPath $LogPath
        
        # Check if config file exists
        if (-not (Test-Path -Path $ConfigPath)) {
            $errorMsg = "Configuration file not found: $ConfigPath"
            Write-MountLog -Message $errorMsg -Level "ERROR" -LogPath $LogPath
            return @{ Success = $false; ExitCode = 1; Message = $errorMsg }
        }
        
        # Load drive mappings
        try {
            $rawDriveMappings = Get-DriveMappingsFromYaml -YamlPath $ConfigPath -LogPath $LogPath
            $DriveMappings = @($rawDriveMappings) | Where-Object {
                $_ -and
                -not [string]::IsNullOrWhiteSpace($_.Drive) -and
                -not [string]::IsNullOrWhiteSpace($_.Path)
            }
            $skippedMappings = @($rawDriveMappings).Count - $DriveMappings.Count
            if ($skippedMappings -gt 0) {
                Write-MountLog -Message "Skipping $skippedMappings invalid drive mappings" -Level "WARN" -LogPath $LogPath
            }
            if (-not $DriveMappings -or $DriveMappings.Count -eq 0) {
                $errorMsg = "No valid drive mappings found in configuration file"
                Write-MountLog -Message $errorMsg -Level "ERROR" -LogPath $LogPath
                return @{ Success = $false; ExitCode = 1; Message = $errorMsg }
            }
        } catch {
            $errorMsg = "Critical error loading drive mappings: $($_.Exception.Message)"
            Write-MountLog -Message $errorMsg -Level "ERROR" -LogPath $LogPath
            return @{ Success = $false; ExitCode = 1; Message = $errorMsg }
        }
        
        # Process each drive mapping
        $totalMappings = $DriveMappings.Count
        $successCount = 0
        $failCount = 0
        
        Write-MountLog -Message "Processing $totalMappings drive mappings..." -Level "INFO" -LogPath $LogPath
        
        # Ensure automated mode for the full run, but restore afterward
        $env:AUTOMATED_TESTING = "true"
        
        foreach ($mapping in $DriveMappings) {
            $path = $mapping.Path
            $drive = $mapping.Drive
            
            Write-MountLog -Message "Processing mapping $($successCount + $failCount + 1)/$totalMappings : $drive => $path" -Level "INFO" -LogPath $LogPath
            
            try {
                $result = Mount-Folder -Path $path -DriveLetter $drive -Force -LogPath $LogPath
                
                if ($result.Success) {
                    $successCount++
                    Write-MountLog -Message "Successfully mounted $drive => $path" -Level "INFO" -LogPath $LogPath
                } else {
                    $failCount++
                    Write-MountLog -Message "Failed to mount $drive => $path : $($result.Message)" -Level "ERROR" -LogPath $LogPath
                }
            }
            catch {
                $failCount++
                Write-MountLog -Message "Exception mounting $drive => $path : $($_.Exception.Message)" -Level "ERROR" -LogPath $LogPath
            }
            
            # Small delay between mounts to avoid conflicts
            Start-Sleep -Milliseconds 500
        }
        
        # Summary
        Write-MountLog -Message "Drive mapping completed. Success: $successCount, Failed: $failCount, Total: $totalMappings" -Level "INFO" -LogPath $LogPath
        
        # Display current mappings
        try {
            Write-MountLog -Message "Current drive mappings:" -Level "INFO" -LogPath $LogPath
            $substOutput = & subst 2>&1
            if ($LASTEXITCODE -eq 0 -and $substOutput) {
                foreach ($line in $substOutput) {
                    if ($line -and $line.ToString().Trim()) {
                        Write-MountLog -Message "  $line" -Level "INFO" -LogPath $LogPath
                    }
                }
            } else {
                Write-MountLog -Message "  No drive mappings found or subst command failed" -Level "INFO" -LogPath $LogPath
            }
        }
        catch {
            Write-MountLog -Message "Error retrieving current drive mappings: $($_.Exception.Message)" -Level "WARN" -LogPath $LogPath
        }
        
        # Return appropriate exit code and result
        if ($failCount -eq 0) {
            Write-MountLog -Message "All drive mappings completed successfully" -Level "INFO" -LogPath $LogPath
            return @{ Success = $true; ExitCode = 0; Message = "All drive mappings completed successfully"; SuccessCount = $successCount; FailCount = $failCount }
        } elseif ($successCount -gt 0) {
            Write-MountLog -Message "Partial success: Some drive mappings failed" -Level "WARN" -LogPath $LogPath
            return @{ Success = $false; ExitCode = 2; Message = "Partial success: Some drive mappings failed"; SuccessCount = $successCount; FailCount = $failCount }
        } else {
            Write-MountLog -Message "All drive mappings failed" -Level "ERROR" -LogPath $LogPath
            return @{ Success = $false; ExitCode = 1; Message = "All drive mappings failed"; SuccessCount = $successCount; FailCount = $failCount }
        }
    }
    catch {
        $errorMsg = "Fatal error in Start-AutoMount: $($_.Exception.Message)"
        Write-MountLog -Message $errorMsg -Level "ERROR" -LogPath $LogPath
        return @{ Success = $false; ExitCode = 1; Message = $errorMsg; Exception = $_ }
    }
    finally {
        if ($hadAutomatedTesting) {
            $env:AUTOMATED_TESTING = $originalAutomatedTesting
        } else {
            Remove-Item Env:AUTOMATED_TESTING -ErrorAction SilentlyContinue
        }
        Write-MountLog -Message "Auto-Mount-Drives script execution finished" -Level "INFO" -LogPath $LogPath
    }
}

# Function to load drive mappings from YAML file
function Get-DriveMappingsFromYaml {
    [CmdletBinding()]
    param(
        [string]$YamlPath,
        [string]$LogPath = $null
    )
    
    try {
        Write-MountLog -Message "Loading drive mappings from: $YamlPath" -Level "INFO" -LogPath $LogPath
        
        # Check if powershell-yaml module is available
        $yamlModule = Get-Module -ListAvailable -Name powershell-yaml
        if (-not $yamlModule) {
            Write-MountLog -Message "powershell-yaml module not found. Attempting to install..." -Level "WARN" -LogPath $LogPath
            try {
                Install-Module -Name powershell-yaml -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
                Import-Module powershell-yaml -ErrorAction Stop
                Write-MountLog -Message "powershell-yaml module installed successfully" -Level "INFO" -LogPath $LogPath
            } catch {
                $errorMsg = "Failed to install powershell-yaml module: $($_.Exception.Message)"
                Write-MountLog -Message $errorMsg -Level "ERROR" -LogPath $LogPath
                throw $errorMsg
            }
        } else {
            try {
                Import-Module powershell-yaml -ErrorAction Stop
            }
            catch {
                $errorMsg = "Failed to import powershell-yaml module: $($_.Exception.Message)"
                Write-MountLog -Message $errorMsg -Level "ERROR" -LogPath $LogPath
                throw $errorMsg
            }
        }
        
        # Read and parse YAML content
        $yamlContent = Get-Content -Path $YamlPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($yamlContent)) {
            throw "YAML file is empty or contains only whitespace"
        }
        
        $yamlData = ConvertFrom-Yaml -Yaml $yamlContent -ErrorAction Stop
        
        if (-not $yamlData -or -not $yamlData.'Drive-Mapping') {
            throw "Invalid YAML structure. Expected 'Drive-Mapping' section not found"
        }
        
        # Process drive mappings
        $driveMappings = $yamlData.'Drive-Mapping'
        $mappings = @()
        $processedCount = 0
        
        foreach ($mapping in $driveMappings) {
            try {
                if ($mapping -is [hashtable]) {
                    foreach ($key in $mapping.Keys) {
                        # Skip empty or null keys
                        if ([string]::IsNullOrWhiteSpace($key)) {
                            Write-MountLog -Message "Skipping empty drive letter" -Level "WARN" -LogPath $LogPath
                            continue
                        }
                        
                        $driveLetter = "${key}:"
                        $path = $mapping.$key
                        
                        # Skip empty or null paths
                        if ([string]::IsNullOrWhiteSpace($path)) {
                            Write-MountLog -Message "Skipping drive $key - empty path" -Level "WARN" -LogPath $LogPath
                            continue
                        }
                        
                        # Convert forward slashes to backslashes for Windows paths
                        $windowsPath = $path -replace '/', '\'
                        
                        $mappings += @{
                            Drive = $driveLetter
                            Path = $windowsPath
                        }
                        $processedCount++
                        Write-MountLog -Message "Processed mapping: $driveLetter -> $windowsPath" -Level "INFO" -LogPath $LogPath
                    }
                } else {
                    # Handle cases where mapping is not a hashtable
                    Write-MountLog -Message "Skipping invalid mapping (not a hashtable): $($mapping)" -Level "WARN" -LogPath $LogPath
                }
            }
            catch {
                Write-MountLog -Message "Error processing drive mapping: $($_.Exception.Message)" -Level "ERROR" -LogPath $LogPath
            }
        }
        
        Write-MountLog -Message "Successfully loaded $processedCount drive mappings from YAML" -Level "INFO" -LogPath $LogPath
        return $mappings
        
    }
    catch {
        $errorMsg = "Failed to load drive mappings from '$YamlPath': $($_.Exception.Message)"
        Write-MountLog -Message $errorMsg -Level "ERROR" -LogPath $LogPath
        throw $errorMsg
    }
}
