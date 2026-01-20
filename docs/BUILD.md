# Build Script Guide

This document describes how to use `Build.ps1` to build, test, and install the DriveMapper module.

## Overview

`Build.ps1` is the main entry point for:
- module validation and import checks
- running Pester tests
- generating coverage output
- installing the module to the user scope

It also verifies required dependencies (Pester and powershell-yaml) unless you skip the check.

## Usage

```powershell
.\Build.ps1 -Task <TaskName>
```

### Available tasks

- `Clean` - remove log files and temporary test artifacts
- `Build` - validate the module manifest and import the module
- `Test` - run the Pester test suite and generate `Logs\TestResults.xml`
- `Coverage` - run tests with code coverage and generate `Logs\CodeCoverage.xml`
- `Install` - copy the module to the current user PowerShell modules folder
- `All` - run clean, build, test, coverage, and install in order

### Examples

Run only tests:
```powershell
.\Build.ps1 -Task Test
```

Run the full pipeline:
```powershell
.\Build.ps1 -Task All
```

Run build then tests:
```powershell
.\Build.ps1 -Task Build,Test
```

## Parameters

### `-Task`
An array of tasks to execute. Defaults to `Build,Test`.

### `-SkipModuleCheck`
Skips dependency checks for Pester and powershell-yaml.

### `-Force`
Overrides existing installation during the `Install` task.

## Outputs

`Build.ps1` creates or updates these artifacts:
- `Logs\TestResults.xml` (test results)
- `Logs\CodeCoverage.xml` (coverage report, when using `Coverage`)
- `Logs\*.log` (optional logs, cleaned by `Clean`)

## Exit Codes

- `0` when all tasks succeed
- `1` if any task fails

## Notes

- The script uses `AUTOMATED_TESTING=true` during tests to avoid prompts.
- Use `-SkipModuleCheck` if modules are preinstalled and you want a faster run.
