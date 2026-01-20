# Module manifest for DriveMapper
@{
    RootModule = 'DriveMapper.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'GergelyToth2'
    CompanyName = 'EPAM'
    Copyright = '(c) 2026. All rights reserved.'
    Description = 'PowerShell module for automatic drive mapping using subst command'
    PowerShellVersion = '5.1'
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Mount-Folder',
        'Start-AutoMount',
        'Get-SubstMappings',
        'Test-PathValid',
        'Format-DriveLetter',
        'Write-MountLog',
        'Get-DriveMappingsFromYaml',
        'Add-SubstMapping',
        'Remove-SubstMapping',
        'Clean-OldLogEntries'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            Tags = @('Drive', 'Mount', 'Subst', 'FileSystem')
            ReleaseNotes = 'Initial release with enhanced error handling'
        }
    }
}
