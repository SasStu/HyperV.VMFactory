# VM Tag & Lifecycle Integration Design

**Date:** 2026-05-10
**Module:** HyperV.VMFactory
**Status:** Approved

---

## Overview

Add VM tagging and lifecycle orchestration to `HyperV.VMFactory`. VMs are tagged with Environment, Service, and DependsOn metadata stored as JSON in the VM Notes field. Tags drive dependency-aware start/stop of VM services and environments. This replaces the old `PSHVTag` module with a clean, well-tested reimplementation that follows the existing module's conventions.

---

## Architecture

The module gains a `Classes/` folder. The `.psm1` is updated to load `Classes/*.ps1` before `Public/` and `Private/`. No new module dependency is introduced.

```
src/HyperV.VMFactory/
├── HyperV.VMFactory.psd1        (updated: new exports, version bump)
├── HyperV.VMFactory.psm1        (updated: load Classes/ first)
├── Classes/
│   ├── HyperVVMTag.ps1
│   ├── HyperVVMService.ps1
│   ├── HyperVVMEnvironment.ps1
│   └── HyperVVMTopology.ps1
├── Private/
│   ├── Assert-HyperVPrerequisite.ps1   (existing, unchanged)
│   ├── New-VMDisk.ps1                  (existing, unchanged)
│   ├── Set-VMConfiguration.ps1         (existing, unchanged)
│   ├── ConvertFrom-HyperVVMTag.ps1     (new)
│   ├── ConvertTo-HyperVVMTagJson.ps1   (new)
│   ├── Get-HyperVVMEdgeList.ps1        (new)
│   └── Invoke-TopologicalSort.ps1      (new)
└── Public/
    ├── New-HyperVVM.ps1                (updated: optional tag params)
    ├── New-HyperVVMConfiguration.ps1   (updated: optional tag params)
    ├── Set-HyperVVMTag.ps1             (new)
    ├── Get-HyperVVMTag.ps1             (new)
    ├── Get-HyperVVMTopology.ps1        (new)
    ├── Start-HyperVVMService.ps1       (new)
    ├── Stop-HyperVVMService.ps1        (new)
    ├── Start-HyperVVMEnvironment.ps1   (new)
    └── Stop-HyperVVMEnvironment.ps1    (new)
```

---

## Data Model

### Tag Storage Format

Tags are stored in the VM's Notes field as a JSON blob preceded by the sentinel `#HVTag:`. Any user-authored content above the sentinel is preserved.

```
My custom VM notes here.

#HVTag:{"Environment":["Lab"],"Service":["Domain"],"DependsOn":["DHCP","Gateway"]}
```

Rules:
- A VM with no `#HVTag:` line is considered untagged.
- All three fields (`Environment`, `Service`, `DependsOn`) are `string[]`. Any may be empty arrays.
- `Set-HyperVVMTag` without `-Force` on an already-tagged VM writes a warning and returns without modifying Notes.
- `Set-HyperVVMTag` with `-Force` replaces the `#HVTag:` line in-place, preserving all other Notes content.

### PowerShell Classes

```powershell
class HyperVVMTag {
    [string[]] $Environment
    [string[]] $Service
    [string[]] $DependsOn
}

class HyperVVMService {
    [string]   $Name
    [string]   $Environment
    [string[]] $DependsOn
    [object[]] $VM          # Microsoft.HyperV.PowerShell.VirtualMachine objects
}

class HyperVVMEnvironment {
    [string]            $Name
    [HyperVVMService[]] $Service
    [string[]]          $StartOrder  # service names in topologically-resolved order
}

class HyperVVMTopology {
    [string]                $ComputerName
    [HyperVVMEnvironment[]] $Environment
}
```

---

## Public Functions

### Tag Management

**`Set-HyperVVMTag`**
- Parameters: `-VMName [string[]]` or `-VM [object[]]`, `-Environment [string[]]`, `-Service [string[]]`, `-DependsOn [string[]]`, `-ComputerName [string]`, `-Force [switch]`
- Writes the `#HVTag:` JSON block into VM Notes. Preserves existing Notes content above the sentinel.
- `SupportsShouldProcess`. Without `-Force`, warns and exits if tag already present.

**`Get-HyperVVMTag`**
- Parameters: `-VMName [string[]]` or `-VM [object[]]`, `-ComputerName [string]`
- Returns `[HyperVVMTag]` for each VM. Returns `$null` for untagged VMs.
- Pipeline-friendly (accepts VM objects from `Get-VM`).

### Topology

**`Get-HyperVVMTopology`**
- Parameters: `-ComputerName [string]` (default: `localhost`)
- Reads all tagged VMs on the host, groups by Environment, builds `[HyperVVMTopology]`.
- Runs `Invoke-TopologicalSort` per environment to populate `StartOrder`.
- Throws descriptively if a dependency cycle is detected.

### Service-Level Lifecycle

**`Start-HyperVVMService`**
- Parameters: `-ServiceName [string]`, `-EnvironmentName [string]`, `-Topology [HyperVVMTopology]` or `-ComputerName [string]`, `-Recurse [switch]`, `-WaitForHeartbeat [switch]`
- When `-ComputerName` is used instead of `-Topology`, calls `Get-HyperVVMTopology` internally.
- With `-Recurse`: starts all `DependsOn` services recursively before starting the target service.
- Already-running VMs are skipped with `Write-Verbose`.
- On first VM failure: stops immediately, returns `[PSCustomObject]@{ Success = [string[]]; Failed = [PSCustomObject]@{ VMName = [string]; Error = [string] } }`.
- On full success: returns the same object with `Failed = $null`.

**`Stop-HyperVVMService`**
- Parameters: `-ServiceName [string]`, `-EnvironmentName [string]`, `-Topology [HyperVVMTopology]` or `-ComputerName [string]`, `-Recurse [switch]`, `-Force [switch]`
- With `-Recurse`: stops services that depend on this one first (reverse topological order), then stops this service.
- `-Force` passes `-Force` to `Stop-VM` (immediate power-off). Default is graceful shutdown (`-Save` not used; `Stop-VM` without `-Force` requests OS shutdown).
- `SupportsShouldProcess`.

### Environment-Level Lifecycle

**`Start-HyperVVMEnvironment`**
- Parameters: `-EnvironmentName [string]`, `-Topology [HyperVVMTopology]` or `-ComputerName [string]`, `-WaitForHeartbeat [switch]`
- Iterates `Environment.StartOrder`, calls `Start-HyperVVMService` for each service in order.
- Stops on first service failure and returns structured result.

**`Stop-HyperVVMEnvironment`**
- Parameters: `-EnvironmentName [string]`, `-Topology [HyperVVMTopology]` or `-ComputerName [string]`, `-Force [switch]`
- Iterates `Environment.StartOrder` in reverse order, calls `Stop-HyperVVMService` for each.

### Updated Existing Functions

Both `New-HyperVVM` and `New-HyperVVMConfiguration` gain optional tag parameters:
- `-Environment [string[]]`, `-Service [string[]]`, `-DependsOn [string[]]`

When any tag parameter is provided, `New-HyperVVM` calls `Set-HyperVVMTag` on the created VM after creation. `New-HyperVVMConfiguration` stores the values on the config object so `New-HyperVVM` can act on them at creation time.

---

## Private Helpers

| File | Responsibility |
|---|---|
| `ConvertFrom-HyperVVMTag.ps1` | Finds `#HVTag:` line in a Notes string, deserializes JSON → `[HyperVVMTag]`. Returns `$null` if no sentinel found. |
| `ConvertTo-HyperVVMTagJson.ps1` | Serializes `[HyperVVMTag]` → JSON string. Builds full Notes value: preserves content above sentinel, replaces/appends `#HVTag:` line. |
| `Get-HyperVVMEdgeList.ps1` | Builds `@{ ServiceName = @('Dep1','Dep2') }` edge hashtable from a `[HyperVVMEnvironment]`. |
| `Invoke-TopologicalSort.ps1` | Kahn's algorithm on an edge hashtable. Returns `[string[]]` of service names in start order. Throws `"Dependency cycle detected involving: ..."` if graph has a cycle. |

---

## Error Handling

- All public functions call `Assert-HyperVPrerequisite` at the top.
- `Set-HyperVVMTag` without `-Force` on an already-tagged VM: `Write-Warning`, return without modification.
- `Start-HyperVVMService` / `Stop-HyperVVMService`: fail-fast on first VM error, return structured `{ Success; Failed }` object.
- `Invoke-TopologicalSort`: throws on cycle with a message naming the involved services.
- `Get-HyperVVMTopology`: propagates cycle error from `Invoke-TopologicalSort` — caller must handle.

---

## Testing

All tests follow the existing pattern: `BeforeAll` with `Import-Module`, `Mock -ModuleName HyperV.VMFactory`, `Describe/Context/It`. New test files in `tests/Unit/`:

| File | Key scenarios |
|---|---|
| `Set-HyperVVMTag.Tests.ps1` | Tag written correctly; existing Notes content preserved; `-Force` overwrites; no-force emits warning and skips |
| `Get-HyperVVMTag.Tests.ps1` | Parses tag correctly; returns `$null` for untagged VM; handles multi-value fields |
| `Get-HyperVVMTopology.Tests.ps1` | Topology built from tagged VMs; `StartOrder` correctly resolved; untagged VMs ignored |
| `Start-HyperVVMService.Tests.ps1` | Deps started before target with `-Recurse`; already-running VM skipped with verbose; first failure returns structured result |
| `Stop-HyperVVMService.Tests.ps1` | Dependents stopped first with `-Recurse`; graceful vs force shutdown |
| `Start-HyperVVMEnvironment.Tests.ps1` | All services started in `StartOrder`; stops on first service failure |
| `Stop-HyperVVMEnvironment.Tests.ps1` | All services stopped in reverse `StartOrder` |
| `Invoke-TopologicalSort.Tests.ps1` | Correct ordering for linear chain; correct ordering for diamond dependency; throws on cycle |
| `New-HyperVVM.Tests.ps1` | Updated: tag params passed → `Set-HyperVVMTag` called; no tag params → `Set-HyperVVMTag` not called |
| `New-HyperVVMConfiguration.Tests.ps1` | Updated: tag fields present on config object when params provided |

---

## Module Manifest Updates

- `ModuleVersion`: bump to `2.0.0` (new public API surface)
- `FunctionsToExport`: add all 8 new public functions
- `Description`: updated to mention tag-based lifecycle management
- `PrivateData.PSData.Tags`: add `'Lifecycle'`, `'Tag'`, `'Service'`, `'Environment'`
