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
| AutomaticCheckpointsEnabled | Switch | No | Off | Enable automatic checkpoints (disabled by default) |
| Environment | String[] | No | - | Tag the VM with one or more environment names |
| Service | String[] | No | - | Tag the VM with one or more service names |
| DependsOn | String[] | No | - | Tag the VM's service dependencies (other service names) |
| ISOPath | String | No | - | ISO file for boot |
| ComputerName | String[] | No | - | Remote Hyper-V host(s) |
| Credential | PSCredential | No | - | Credential for remote access |
| CimSession | CimSession[] | No | - | Existing CIM session(s) |
| Configuration | Object[] | No | - | Configuration objects from New-HyperVVMConfiguration |

### New-HyperVVMConfiguration

Accepts the same VM parameters as `New-HyperVVM` (excluding remote and pipeline parameters) and returns a typed configuration object for use with pipeline-based bulk creation.

## Tag-based lifecycle management

VMs are grouped into services and environments via tags stored in the VM `Notes` field. Once tagged, services can be started and stopped in dependency order.

### Tag a VM

```powershell
Set-HyperVVMTag -VMName 'DC01' -Environment 'Lab' -Service 'Domain' -DependsOn 'DHCP'
Set-HyperVVMTag -VMName 'DHCP01' -Environment 'Lab' -Service 'DHCP'
```

### Inspect the topology

```powershell
$topo = Get-HyperVVMTopology
```

### Start a single service (and wait for it)

```powershell
Start-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo
```

### Start a service and automatically start its dependencies first

```powershell
Start-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Recurse
```

### Start a service and open a VM console window

```powershell
# Open console for the target service's VMs only (default when -OpenConsole is used with -Recurse)
Start-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Recurse -OpenConsole

# Open console for every VM started, including recursed dependencies
Start-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Recurse -OpenConsole -OpenConsoleScope AllStarted

# Open console without recursing dependencies
Start-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -OpenConsole
```

### Start all services in an environment in dependency order

```powershell
Start-HyperVVMEnvironment -EnvironmentName 'Lab' -Topology $topo

# Open a console for every VM as it starts
Start-HyperVVMEnvironment -EnvironmentName 'Lab' -Topology $topo -OpenConsole
```

### Stop a service or environment

```powershell
Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo
Stop-HyperVVMEnvironment -EnvironmentName 'Lab' -Topology $topo
```

### Visualize the topology as a Mermaid diagram

```powershell
# All environments
Get-HyperVVMTopology | Get-HyperVVMMermaidDiagram

# One environment
Get-HyperVVMTopology | Get-HyperVVMMermaidDiagram -Environment 'Lab'
```

## Lifecycle function parameters

### Start-HyperVVMService

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| ServiceName | String | Yes | - | Name of the service to start |
| EnvironmentName | String | Yes | - | Environment the service belongs to |
| Topology | HyperVVMTopology | Yes* | - | Topology object from `Get-HyperVVMTopology` |
| ComputerName | String | No | localhost | Hyper-V host (resolves topology automatically) |
| Recurse | Switch | No | Off | Start dependency services first |
| WaitForVM | Bool | No | `$true` | Wait for each VM after starting |
| VMWaitFor | String | No | IPAddress | Wait condition: `IPAddress` or `Heartbeat` |
| WaitTimeoutSeconds | Int | No | 120 | Timeout in seconds for `WaitForVM` |
| OpenConsole | Switch | No | Off | Open a VMConnect window for each started VM |
| OpenConsoleScope | String | No | TargetOnly | `TargetOnly` — console for the target service only; `AllStarted` — console for every VM started including recursed dependencies |

\* `Topology` is mandatory in the `ByTopology` parameter set; `ComputerName` is used in `ByComputerName`.

### Start-HyperVVMEnvironment

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| EnvironmentName | String | Yes | - | Name of the environment to start |
| Topology | HyperVVMTopology | Yes* | - | Topology object from `Get-HyperVVMTopology` |
| ComputerName | String | No | localhost | Hyper-V host (resolves topology automatically) |
| WaitForVM | Bool | No | `$true` | Wait for each VM after starting |
| VMWaitFor | String | No | IPAddress | Wait condition: `IPAddress` or `Heartbeat` |
| WaitTimeoutSeconds | Int | No | 120 | Timeout in seconds for `WaitForVM` |
| OpenConsole | Switch | No | Off | Open a VMConnect window for each started VM |
| OpenConsoleScope | String | No | TargetOnly | `TargetOnly` or `AllStarted` — same as `Start-HyperVVMService` |

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
