function ConvertFrom-LegacyHVTag {
    [CmdletBinding()]
    [OutputType([HyperVVMTag])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Notes
    )
    if ($Notes -notmatch '<Env>|<Service>|<DependsOn>') {
        return $null
    }
    $tag = [HyperVVMTag]::new()
    $tag.Environment = @([regex]::Matches($Notes, '<Env>([^<]*)</Env>')       | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ })
    $tag.Service     = @([regex]::Matches($Notes, '<Service>([^<]*)</Service>') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ })
    $tag.DependsOn   = @([regex]::Matches($Notes, '<DependsOn>([^<]*)</DependsOn>') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ })
    return $tag
}
