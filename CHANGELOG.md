# Changelog

All notable changes to the HyperVVM module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `-AutomaticCheckpointsEnabled` switch parameter on `New-HyperVVM` and `New-HyperVVMConfiguration` - enables automatic checkpoints when specified, disabled by default

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
