# Tests\DriveMapping.Tests.ps1
# Comprehensive Pester tests for DriveMapping module

BeforeAll {
    # Set automated testing flag to avoid prompts
    $env:AUTOMATED_TESTING = "true"
    
    # Import the module under test
    $ModulePath = Split-Path $PSScriptRoot -Parent
    Import-Module "$ModulePath\DriveMapper.psd1" -Force
    
    # Create test directories
    $TestDrive = New-Item -ItemType Directory -Path "$env:TEMP\DriveMapperTests_$(Get-Random)" -Force
    $ValidTestPath = New-Item -ItemType Directory -Path "$TestDrive\ValidPath" -Force
    $InvalidTestPath = "$TestDrive\InvalidPath"
    
    # Mock external commands to avoid side effects
    Mock subst {
        param($Drive, $Path, $Delete)
        
        # Simulate different subst behaviors
        if ($Delete -eq "/D") {
            # Simulate unmount
            $global:LASTEXITCODE = 0
            return "Successfully unmounted $Drive"
        } elseif ($Path) {
            # Simulate mount
            $global:LASTEXITCODE = 0
            return "Successfully mounted $Drive to $Path"
        } else {
            # Simulate list mappings
            $global:LASTEXITCODE = 0
            return @(
                "Z:\: => C:\SamplePath",
                "Y:\: => D:\AnotherPath"
            )
        }
    } -ModuleName DriveMapper
    
    # Mock Get-ChildItem for access testing to avoid real filesystem access
    Mock Get-ChildItem {
        if ($Path -like "*ValidPath*") {
            return @(@{ Name = "TestFile.txt" })
        } else {
            throw "Access denied"
        }
    } -ModuleName DriveMapper -ParameterFilter { $Path -and $Path -notlike $env:WINDIR }
    
    # Mock Install-Module to avoid real installations
    Mock Install-Module {
        return $true
    } -ModuleName DriveMapper
    
    # Mock Import-Module for powershell-yaml
    Mock Import-Module {
        return $true
    } -ModuleName DriveMapper -ParameterFilter { $Name -eq "powershell-yaml" }
    
    # Mock Get-Module for powershell-yaml
    Mock Get-Module {
        return @{ Name = "powershell-yaml"; Version = "0.4.0" }
    } -ModuleName DriveMapper -ParameterFilter { $Name -eq "powershell-yaml" }
    
    # Mock YAML functions
    Mock ConvertFrom-Yaml {
        # Return clean test data without empty mappings
        return @{
            'Drive-Mapping' = @(
                @{ 'P' = $ValidTestPath.FullName },
                @{ 'R' = $env:WINDIR }
            )
        }
    } -ModuleName DriveMapper
}

AfterAll {
    # Cleanup test directories
    if (Test-Path $TestDrive) {
        Remove-Item $TestDrive -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Remove environment variable
    Remove-Item Env:AUTOMATED_TESTING -ErrorAction SilentlyContinue
    
    # Remove module
    Remove-Module DriveMapper -Force -ErrorAction SilentlyContinue
}

Describe "Format-DriveLetter Function Tests" {
    Context "Valid Drive Letters" {
        It "Should format single letter correctly" {
            $result = Format-DriveLetter -Drive "P"
            $result.Success | Should -Be $true
            $result.DriveLetter | Should -Be "P:"
        }
        
        It "Should format letter with colon correctly" {
            $result = Format-DriveLetter -Drive "P:"
            $result.Success | Should -Be $true
            $result.DriveLetter | Should -Be "P:"
        }
        
        It "Should handle lowercase letters" {
            $result = Format-DriveLetter -Drive "p"
            $result.Success | Should -Be $true
            $result.DriveLetter | Should -Be "P:"
        }
        
        It "Should handle letters with spaces" {
            $result = Format-DriveLetter -Drive " P "
            $result.Success | Should -Be $true
            $result.DriveLetter | Should -Be "P:"
        }
    }
    
    Context "Invalid Drive Letters" {
        It "Should reject invalid characters" {
            $result = Format-DriveLetter -Drive "1"
            $result.Success | Should -Be $false
            $result.Message | Should -Match "Invalid drive letter format"
        }
        
        It "Should reject multiple characters" {
            $result = Format-DriveLetter -Drive "PP"
            $result.Success | Should -Be $false
            $result.Message | Should -Match "Invalid drive letter format"
        }
        
        It "Should reject empty string" {
            $result = Format-DriveLetter -Drive ""
            $result.Success | Should -Be $false
            $result.Message | Should -Match "Invalid drive letter format"
        }
        
        It "Should reject special characters" {
            $result = Format-DriveLetter -Drive "@"
            $result.Success | Should -Be $false
            $result.Message | Should -Match "Invalid drive letter format"
        }
    }
}

Describe "Test-PathValid Function Tests" {
    Context "Valid Paths" {
        It "Should validate existing directory" {
            $result = Test-PathValid -Path $ValidTestPath.FullName
            $result.Valid | Should -Be $true
            $result.Message | Should -Match "Path is valid and accessible"
        }
        
        It "Should validate system directories" {
            # Mock Get-ChildItem to succeed for system directories
            Mock Get-ChildItem {
                return @(@{ Name = "System32" })
            } -ModuleName DriveMapper -ParameterFilter { $Path -like $env:WINDIR }
            
            $result = Test-PathValid -Path $env:WINDIR
            $result.Valid | Should -Be $true
            $result.Message | Should -Match "Path is valid and accessible"
        }
    }
    
    Context "Invalid Paths" {
        It "Should reject non-existent path" {
            $result = Test-PathValid -Path $InvalidTestPath
            $result.Valid | Should -Be $false
            $result.Message | Should -Match "Path does not exist"
        }
        
        It "Should reject empty path" {
            $result = Test-PathValid -Path ""
            $result.Valid | Should -Be $false
            $result.Message | Should -Match "Path cannot be empty or null"
        }
        
        It "Should reject null path" {
            $result = Test-PathValid -Path $null
            $result.Valid | Should -Be $false
            $result.Message | Should -Match "Path cannot be empty or null"
        }
        
        It "Should reject file instead of directory" {
            $testFile = New-Item -ItemType File -Path "$TestDrive\testfile.txt" -Force
            $result = Test-PathValid -Path $testFile.FullName
            $result.Valid | Should -Be $false
            $result.Message | Should -Match "Path is not a directory"
        }
        
        It "Should reject inaccessible directory" {
            $inaccessiblePath = New-Item -ItemType Directory -Path "$TestDrive\InaccessiblePath" -Force
            $result = Test-PathValid -Path $inaccessiblePath.FullName
            $result.Valid | Should -Be $false
            $result.Message | Should -Match "Path exists but is not accessible"
        }
    }
}

Describe "Get-SubstMappings Function Tests" {
    Context "Successful Mapping Retrieval" {
        It "Should parse subst output correctly" {
            $result = Get-SubstMappings
            $result.Success | Should -Be $true
            $result.Count | Should -Be 2
            $result.Mappings["Z:"] | Should -Be "C:\SamplePath"
            $result.Mappings["Y:"] | Should -Be "D:\AnotherPath"
        }
    }
    
    Context "Error Handling" {
        It "Should handle subst command failure" {
            # Mock subst to return error
            Mock subst {
                $global:LASTEXITCODE = 1
                return "Error: Access denied"
            } -ModuleName DriveMapper
            
            $result = Get-SubstMappings
            $result.Success | Should -Be $false
            $result.Message | Should -Match "subst command returned exit code 1"
        }
    }
}

Describe "Mount-Folder Integration Tests" {
    Context "Successful Mounting" {
        It "Should mount valid path successfully" {
            $result = Mount-Folder -Path $ValidTestPath.FullName -DriveLetter "T" -Force
            $result.Success | Should -Be $true
            $result.Message | Should -Match "Successfully mounted"
        }
        
        It "Should handle already mounted drive with same path" {
            # Mock Get-SubstMappings to return existing mapping
            Mock Get-SubstMappings {
                return @{
                    Success = $true
                    Mappings = @{ "T:" = $ValidTestPath.FullName }
                    Count = 1
                }
            } -ModuleName DriveMapper
            
            $result = Mount-Folder -Path $ValidTestPath.FullName -DriveLetter "T" -Force
            $result.Success | Should -Be $true
            $result.Message | Should -Match "already mounted"
        }
        
        It "Should remount drive with different path when forced" {
            # Mock Get-SubstMappings to return different existing mapping
            Mock Get-SubstMappings {
                return @{
                    Success = $true
                    Mappings = @{ "T:" = "C:\DifferentPath" }
                    Count = 1
                }
            } -ModuleName DriveMapper
            
            $result = Mount-Folder -Path $ValidTestPath.FullName -DriveLetter "T" -Force
            $result.Success | Should -Be $true
            $result.Message | Should -Match "Successfully mounted"
        }
    }
    
    Context "Parameter Validation" {
        It "Should handle invalid drive letter" {
            $result = Mount-Folder -Path $ValidTestPath.FullName -DriveLetter "123"
            $result.Success | Should -Be $false
            $result.Message | Should -Match "Invalid drive letter format"
        }
        
        It "Should handle invalid path" {
            $result = Mount-Folder -Path $InvalidTestPath -DriveLetter "T"
            $result.Success | Should -Be $false
            $result.Message | Should -Match "Path does not exist"
        }
    }
    
    Context "Error Handling" {
        It "Should handle subst mount failure" {
            # Mock subst to fail on mount
            Mock subst {
                param($Drive, $Path, $Delete)
                if ($Path -and -not $Delete) {
                    $global:LASTEXITCODE = 1
                    return "Error: Invalid path"
                }
            } -ModuleName DriveMapper
            
            $result = Mount-Folder -Path $ValidTestPath.FullName -DriveLetter "T" -Force
            $result.Success | Should -Be $false
            $result.Message | Should -Match "Mount operation failed"
        }
    }
}

Describe "Start-AutoMount Integration Tests" {
    BeforeAll {
        # Create test config file
        $TestConfig = "$TestDrive\test-config.yaml"
        $ConfigContent = @"
Drive-Mapping:
  - P: "$($ValidTestPath.FullName -replace '\\', '/')"
  - R: "$($env:WINDIR -replace '\\', '/')"
"@
        Set-Content -Path $TestConfig -Value $ConfigContent -Encoding UTF8
    }
    
    Context "Configuration Loading" {
        It "Should handle missing config file" {
            $result = Start-AutoMount -ConfigPath "$TestDrive\missing.yaml"
            $result.Success | Should -Be $false
            $result.ExitCode | Should -Be 1
            $result.Message | Should -Match "Configuration file not found"
        }
        
        It "Should handle valid config file" {
            $result = Start-AutoMount -ConfigPath $TestConfig
            $result.Success | Should -Be $true
            $result.ExitCode | Should -Be 0
            $result.Message | Should -Match "All drive mappings completed successfully"
            $result.SuccessCount | Should -Be 2
            $result.FailCount | Should -Be 0
        }
        
        It "Should handle partial failures" {
            # Mock Mount-Folder to fail for one drive
            $callCount = 0
            Mock Mount-Folder {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return @{ Success = $true; Message = "Success" }
                } else {
                    return @{ Success = $false; Message = "Failed" }
                }
            } -ModuleName DriveMapper
            
            $result = Start-AutoMount -ConfigPath $TestConfig
            $result.Success | Should -Be $false
            $result.ExitCode | Should -Be 2
            $result.Message | Should -Match "Partial success"
            $result.SuccessCount | Should -Be 1
            $result.FailCount | Should -Be 1
        }
    }
}

Describe "Write-MountLog Function Tests" {
    Context "Logging Functionality" {
        It "Should write log message with default level" {
            # Capture Write-Host output
            $output = Write-MountLog -Message "Test message" 6>&1
            $output | Should -Match "Test message"
            $output | Should -Match "INFO"
        }
        
        It "Should write log message with specific level" {
            $output = Write-MountLog -Message "Error message" -Level "ERROR" 6>&1
            $output | Should -Match "Error message"
            $output | Should -Match "ERROR"
        }
        
        It "Should write to log file when path provided" {
            $logFile = "$TestDrive\test.log"
            Write-MountLog -Message "File test" -LogPath $logFile
            
            Test-Path $logFile | Should -Be $true
            $content = Get-Content $logFile
            $content | Should -Match "File test"
        }
    }
}

Describe "Performance Tests" {
    Context "Function Performance" {
        It "Format-DriveLetter should execute quickly" {
            $elapsed = Measure-Command {
                1..100 | ForEach-Object {
                    Format-DriveLetter -Drive "P"
                }
            }
            $elapsed.TotalMilliseconds | Should -BeLessThan 1000
        }
        
        It "Test-PathValid should execute quickly for valid paths" {
            $elapsed = Measure-Command {
                1..10 | ForEach-Object {
                    Test-PathValid -Path $ValidTestPath.FullName
                }
            }
            $elapsed.TotalMilliseconds | Should -BeLessThan 5000
        }
    }
}

Describe "Edge Case Tests" {
    Context "Boundary Values" {
        It "Should handle all valid drive letters" {
            $letters = @('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 
                         'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z')
            
            foreach ($letter in $letters) {
                $result = Format-DriveLetter -Drive $letter
                $result.Success | Should -Be $true
                $result.DriveLetter | Should -Be "${letter}:"
            }
        }
        
        It "Should handle very long path names" {
            $longPath = "C:\" + ("VeryLongDirectoryName" * 10)
            $result = Test-PathValid -Path $longPath
            $result.Valid | Should -Be $false
            $result.Message | Should -Match "Path does not exist"
        }
        
        It "Should handle automated testing environment" {
            # Verify automated testing flag is set (should be set in BeforeAll)
            $env:AUTOMATED_TESTING | Should -Be "true"
        }
    }
}
