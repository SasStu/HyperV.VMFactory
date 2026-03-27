[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [System.String]
    $ApiKey,

    [Parameter()]
    [System.String]
    $ModulePath = (Join-Path -Path $PSScriptRoot -ChildPath '..\output\HyperV.VMFactory'),

    [Parameter()]
    [System.String]
    $Repository = 'PSGallery'
)

# Build if output doesn't exist
if (-not (Test-Path $ModulePath)) {
    Write-Host 'Output not found. Running build first...'
    & (Join-Path -Path $PSScriptRoot -ChildPath 'build.ps1')
}

# Validate manifest
$manifestPath = Join-Path -Path $ModulePath -ChildPath 'HyperV.VMFactory.psd1'
Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
Write-Host "Module manifest validated: $manifestPath"

# Publish
Publish-Module -Path $ModulePath -NuGetApiKey $ApiKey -Repository $Repository -Verbose
Write-Host "Module published to $Repository successfully."
