# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`HyperV.VMFactory` is a PowerShell module (v2.1.0, supports PS 5.1+) for creating and configuring Hyper-V virtual machines with tag-based service and environment lifecycle management. Tags stored in VM Notes fields enable dependency-ordered start/stop of multi-VM environments.

## Commands

### Run all tests
```powershell
Invoke-Pester ./tests/Unit -Output Detailed
```

### Run a single test file
```powershell
Invoke-Pester ./tests/Unit/New-HyperVVM.Tests.ps1 -Output Detailed
```

### Run linter
```powershell
Invoke-ScriptAnalyzer -Path ./src -Recurse
```

### Build (copies src to output/, optionally bumps version)
```powershell
./build/build.ps1
./build/build.ps1 -Version '2.2.0'
```

### Import locally during development
```powershell
Import-Module ./src/HyperV.VMFactory/HyperV.VMFactory.psd1
```

### Publish to PSGallery
```powershell
./build/publish.ps1  # Requires $env:PSGALLERY_API_KEY; normally run by CI on version tag push
```

## Architecture

### Module loading order (`.psm1`)
1. **Classes** — loaded first in dependency order: `HyperVVMTag` → `HyperVVMService` → `HyperVVMEnvironment` → `HyperVVMTopology`
2. **Public** — all exported cmdlets
3. **Private** — internal helpers

Classes are also registered as PowerShell type accelerators (`[HyperVVMTag]` etc.) so callers can use them outside module scope. The `OnRemove` handler cleans them up on `Remove-Module`.

### Tag system (VM Notes field)
Tags are stored in the VM's `Notes` property as an appended line:
```
#HVTag:{"Environment":["lab"],"Service":["web"],"DependsOn":["db"]}
```
- `ConvertTo-HyperVVMTagJson` — serializes a `HyperVVMTag` to that format, preserving any existing Notes text
- `ConvertFrom-HyperVVMTag` — parses the `#HVTag:` line back to a `HyperVVMTag` object
- `ConvertFrom-LegacyHVTag` — reads the older `PSHVTag` format; triggers a migration warning
- `Update-HyperVVMTag` — migrates legacy-tagged VMs to the current format

### Topology / lifecycle flow
`Get-HyperVVMTopology` → reads all tagged VMs → groups by Environment → groups by Service → runs `Invoke-TopologicalSort` on service dependency edges → returns a `HyperVVMTopology` object with `StartOrder` per environment.

`Start-HyperVVMEnvironment` / `Stop-HyperVVMEnvironment` consume the topology and iterate `StartOrder` (reversed for stop), delegating each service to `Start-HyperVVMService` / `Stop-HyperVVMService`.

### VM creation
`New-HyperVVM` supports two parameter sets:
- **ByParameter** — `VMName[]`, `Path`, `VMSwitch` plus optional flags
- **ByConfiguration** — accepts `HyperV.VMFactory.Configuration` PSCustomObjects from `New-HyperVVMConfiguration`

Internally it delegates to:
- `New-HyperVVMLocal` — local or CimSession creation (disk via `New-VMDisk`, config via `Set-VMConfiguration`)
- `Invoke-HyperVVMCreationRemote` — serializes config to a hashtable and runs a scriptblock via `Invoke-Command`

Disks use `${VMName}_C.vhdx` (OS) and `${VMName}_D.vhdx` (data) under `<Path>\<VMName>\Virtual Hard Disks\`.

### Key classes
| Class | Fields |
|-------|--------|
| `HyperVVMTag` | `Environment[]`, `Service[]`, `DependsOn[]` |
| `HyperVVMService` | `Name`, `Environment`, `DependsOn[]`, `VM[]` |
| `HyperVVMEnvironment` | `Name`, `Service[]`, `StartOrder[]` |
| `HyperVVMTopology` | `ComputerName`, `Environment[]` |

### Testing conventions
Tests live in `tests/Unit/` (public functions) and `tests/Unit/Private/` (private helpers). Each test file dot-imports the `.psm1` directly and uses `Mock -ModuleName HyperV.VMFactory` to stub all Hyper-V cmdlets and `Assert-HyperVPrerequisite`. No Hyper-V host is needed to run tests.
