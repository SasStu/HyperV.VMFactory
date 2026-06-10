# Changelog

All notable changes to the HyperVVM module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.2.0] - 2026-06-05

### Added

- `-OpenConsole` switch on `Start-HyperVVMService` and
  `Start-HyperVVMEnvironment` - opens a VMConnect window for each VM after it
  starts
- `-OpenConsoleScope` parameter on `Start-HyperVVMService` and
  `Start-HyperVVMEnvironment` (`TargetOnly` | `AllStarted`, default
  `TargetOnly`) - controls whether consoles are opened for the target service's
  VMs only or for every VM started including recursed dependencies

## [2.1.0] - 2026-05-12

### Added

- `Get-HyperVVMMermaidDiagram` — renders an environment's dependency topology as
  a Mermaid flowchart string, suitable for embedding in Markdown or piping to a
  renderer
- `Update-HyperVVMTag` — migrates VMs tagged with the legacy `PSHVTag` format to
  the current `HVTag` JSON format
- `ConvertFrom-LegacyHVTag` (private) — reads the older `PSHVTag` Notes format
  and issues a deprecation warning; called automatically by `Get-HyperVVMTag`
  when a legacy tag is detected

## [2.0.0] - 2026-05-10

### Added

- Tag-based lifecycle management via the VM `Notes` field
  - `HyperVVMTag`, `HyperVVMService`, `HyperVVMEnvironment`, `HyperVVMTopology`
    classes, registered as PowerShell type accelerators
  - `Set-HyperVVMTag` — tag a VM with `Environment`, `Service`, and `DependsOn`
    values
  - `Get-HyperVVMTag` — retrieve parsed tag data from a VM's Notes field
  - `Get-HyperVVMTopology` — build a full topology from all tagged VMs,
    including dependency-ordered `StartOrder` per environment
  - `Start-HyperVVMService` — start all VMs in a service; supports
    `-Recurse` (start dependencies first), `-WaitForVM`, `-VMWaitFor`
    (`IPAddress` | `Heartbeat`), and `-WaitTimeoutSeconds`
  - `Stop-HyperVVMService` — stop all VMs in a service with optional `-Recurse`
  - `Start-HyperVVMEnvironment` — start all services in an environment in
    topological dependency order
  - `Stop-HyperVVMEnvironment` — stop all services in an environment in reverse
    dependency order
- `-Environment`, `-Service`, `-DependsOn` parameters on `New-HyperVVM` and
  `New-HyperVVMConfiguration` — tag a VM at creation time
- `-AutomaticCheckpointsEnabled` switch on `New-HyperVVM` and
  `New-HyperVVMConfiguration` — enables automatic checkpoints when specified,
  disabled by default

## [1.0.0] - 2026-03-26

### Added

- `New-HyperVVM` function for creating Hyper-V virtual machines
  - Support for differencing disks from parent images
  - Optional additional data disk creation
  - TPM and nested virtualization support (enabled by default)
  - ISO boot support with automatic boot order configuration
  - Configurable video resolution, processor count, and memory
  - Automatic start/stop action configuration
  - ShouldProcess support (`-WhatIf`, `-Confirm`)
- `New-HyperVVMConfiguration` function for building VM configuration objects
  - Enables bulk VM creation via pipeline
- Remote execution support
  - `-ComputerName` parameter using `Invoke-Command`
  - `-CimSession` parameter for direct CIM session passthrough
  - `-Credential` parameter for remote authentication
- Bulk VM creation
  - Array input: `New-HyperVVM -VMName 'VM1', 'VM2', 'VM3' ...`
  - Pipeline input: `'VM1', 'VM2' | New-HyperVVM ...`
  - Configuration pipeline: `$configs | New-HyperVVM`
- GitHub Actions CI/CD
  - PSScriptAnalyzer linting on every push
  - Pester v5 unit tests with code coverage
  - Automated publishing to PSGallery on version tags
- Pester v5 unit test suite with mocked Hyper-V cmdlets
