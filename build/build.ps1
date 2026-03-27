[CmdletBinding()]
param(
    [Parameter()]
    [System.String]
    $Version,

    [Parameter()]
    [System.String]
    $OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath '..\output\HyperV.VMFactory')
)

$sourcePath = Join-Path -Path $PSScriptRoot -ChildPath '..\src\HyperV.VMFactory'

# Clean and create output directory
if (Test-Path $OutputPath) {
    Remove-Item -Path $OutputPath -Recurse -Force
}
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null

# Copy module files
Copy-Item -Path "$sourcePath\*" -Destination $OutputPath -Recurse -Force

# Update version in manifest if specified
if ($Version) {
    $manifestPath = Join-Path -Path $OutputPath -ChildPath 'HyperV.VMFactory.psd1'
    $content = Get-Content -Path $manifestPath -Raw
    $content = $content -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion     = '$Version'"
    Set-Content -Path $manifestPath -Value $content -NoNewline
    Write-Host "Updated module version to $Version"
}

Write-Host "Build complete. Output: $OutputPath"
