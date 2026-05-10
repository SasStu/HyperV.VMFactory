function ConvertFrom-HyperVVMTag {
    [CmdletBinding()]
    [OutputType([HyperVVMTag])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Notes
    )
    $match = [regex]::Match($Notes, '(?m)^#HVTag:(.+)$')
    if (-not $match.Success) {
        return $null
    }
    try {
        $data = $match.Groups[1].Value.Trim() | ConvertFrom-Json
        $tag = [HyperVVMTag]::new()
        $tag.Environment = @($data.Environment | Where-Object { $_ })
        $tag.Service     = @($data.Service     | Where-Object { $_ })
        $tag.DependsOn   = @($data.DependsOn   | Where-Object { $_ })
        return $tag
    } catch {
        Write-Warning "Failed to parse HVTag JSON in VM Notes: $_"
        return $null
    }
}
