# Setup Script Guide

This document describes how to use `Setup.ps1` to prepare a local development environment for DriveMapper.

## Overview

`Setup.ps1` is intended for a quick local bootstrap:
- validates prerequisites
- prepares a local environment for running tests and scripts
- ensures the module can be imported cleanly

It is safe to rerun if you need to repair a local setup.

## Usage

```powershell
.\Setup.ps1
```

## What it does

The script typically performs the following steps:

1. Verifies that PowerShell version requirements are met.
2. Ensures required modules are available (e.g., Pester and powershell-yaml).
3. Creates any needed folders (such as `Logs`).
4. Imports the DriveMapper module to confirm a clean load.

## When to run it

- After cloning the repository for the first time
- When running tests on a new machine
- After updating PowerShell modules

## Troubleshooting

If the script reports missing modules, install them and rerun:

```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
Install-Module -Name powershell-yaml -Force -SkipPublisherCheck -Scope CurrentUser
```

If import fails, validate the manifest:

```powershell
Test-ModuleManifest ".\DriveMapper.psd1"
```
