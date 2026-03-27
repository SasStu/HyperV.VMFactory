# HyperV.VMFactory

A PowerShell module for creating and configuring Hyper-V virtual machines with support for remote execution, bulk creation, differencing disks, TPM, nested virtualization, and more.

## Installation

### From PSGallery

```powershell
Install-Module -Name HyperV.VMFactory -Scope CurrentUser
```

### From Source

```powershell
git clone https://github.com/yourname/HyperV.VMFactory.git
Import-Module ./HyperV.VMFactory/src/HyperV.VMFactory/HyperV.VMFactory.psd1
```

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Hyper-V feature installed (with management tools)
- Administrator privileges (for local VM creation)

## Quick Start

### Create a single VM

```powershell
New-HyperVVM -VMName 'WebServer01' -Path 'D:\VMs' -VMSwitch 'External'
```

### Create a VM from a parent image with a data disk

```powershell
New-HyperVVM -VMName 'AppServer01' -Path 'D:\VMs' -VMSwitch 'External' `
    -ParentDisk 'C:\Base\Win2022.vhdx' -AdditionalHDD -PowerOnVM
```

### Create multiple VMs at once

```powershell
'DC01', 'DC02', 'SQL01' | New-HyperVVM -Path 'D:\VMs' -VMSwitch 'Internal'
```

### Bulk creation with different configurations

```powershell
$configs = @(
    New-HyperVVMConfiguration -VMName 'Web01' -Path 'D:\VMs' -VMSwitch 'External' `
        -VMProcessorCount 4 -VMMemoryStartupBytes 8GB -AdditionalHDD
    New-HyperVVMConfiguration -VMName 'DB01' -Path 'D:\VMs' -VMSwitch 'Internal' `
        -VMProcessorCount 8 -VMMemoryStartupBytes 16GB -AdditionalHDD
    New-HyperVVMConfiguration -VMName 'Dev01' -Path 'D:\VMs' -VMSwitch 'External' `
        -PowerOnVM
)
New-HyperVVM -Configuration $configs
```

### Create a VM on a remote host

```powershell
New-HyperVVM -VMName 'RemoteVM' -Path 'D:\VMs' -VMSwitch 'External' `
    -ComputerName 'HyperVHost01' -Credential (Get-Credential)
```

### Create a VM with ISO for OS installation

```powershell
New-HyperVVM -VMName 'NewInstall' -Path 'D:\VMs' -VMSwitch 'External' `
    -ISOPath 'C:\ISO\Win11_23H2.iso' -PowerOnVM
```

### Preview changes without creating anything

```powershell
New-HyperVVM -VMName 'TestVM' -Path 'D:\VMs' -VMSwitch 'External' -WhatIf
```

## Parameters

### New-HyperVVM

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| VMName | String[] | Yes | - | Name(s) of the VM(s) to create |
| Path | String | Yes | - | Folder for VM files |
| VMSwitch | String | Yes | - | Virtual switch name |
| ParentDisk | String | No | - | Parent disk for differencing OS disk |
| VMGeneration | Int | No | 2 | VM generation (1 or 2) |
| VMProcessorCount | Int | No | 2 | Virtual processor count |
| VMMemoryStartupBytes | Int64 | No | 2GB | Startup memory |
| OSDiskSizeBytes | Int64 | No | 127GB | OS disk size (when no parent disk) |
| DataDiskSizeBytes | Int64 | No | 127GB | Data disk size |
| AdditionalHDD | Switch | No | Off | Create a secondary data disk |
| DisableNestedVirtualization | Switch | No | Off | Disable nested virtualization (enabled by default) |
| DisableTPM | Switch | No | Off | Disable virtual TPM (enabled by default) |
| DisableGuestServices | Switch | No | Off | Disable Guest Service Interface (enabled by default) |
| PowerOnVM | Switch | No | Off | Start VM after creation |
| HorizontalResolution | Int64 | No | 1920 | Video horizontal resolution (even) |
| VerticalResolution | Int64 | No | 1080 | Video vertical resolution (even) |
| AutomaticStartAction | String | No | Nothing | Host start action |
| AutomaticStopAction | String | No | ShutDown | Host stop action |
| ISOPath | String | No | - | ISO file for boot |
| ComputerName | String[] | No | - | Remote Hyper-V host(s) |
| Credential | PSCredential | No | - | Credential for remote access |
| CimSession | CimSession[] | No | - | Existing CIM session(s) |
| Configuration | Object[] | No | - | Configuration objects from New-HyperVVMConfiguration |

### New-HyperVVMConfiguration

Accepts the same VM parameters as `New-HyperVVM` (excluding remote and pipeline parameters) and returns a typed configuration object for use with pipeline-based bulk creation.

## CI/CD

This project uses GitHub Actions for continuous integration and deployment:

- **CI** (`ci.yml`): Runs PSScriptAnalyzer and Pester tests on every push and pull request; uploads NUnit test results and JaCoCo code coverage as artifacts
- **Publish** (`publish.yml`): Publishes to PSGallery when a version tag (`v*`) is pushed

### Publishing a new version

```bash
git tag v1.0.0
git push origin v1.0.0
```

The `PSGALLERY_API_KEY` secret must be configured in the GitHub repository settings under the `PSGallery` environment.

## Development

### Running tests locally

```powershell
Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser
Invoke-Pester ./tests/Unit -Output Detailed
```

### Running the linter

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path ./src -Recurse
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
