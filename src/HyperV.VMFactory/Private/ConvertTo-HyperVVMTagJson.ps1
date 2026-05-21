function ConvertTo-HyperVVMTagJson {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [HyperVVMTag] $Tag,

        [Parameter()]
        [AllowEmptyString()]
        [string] $ExistingNotes = ''
    )
    $data = [ordered]@{
        Environment = @($Tag.Environment)
        Service     = @($Tag.Service)
        DependsOn   = @($Tag.DependsOn)
    }
    $payload = $data | ConvertTo-Json -Compress -Depth 5
    $tagLine = "#HVTag:$payload"

    # Strip any existing #HVTag: line
    $clean = $ExistingNotes -replace '(?m)^#HVTag:.+(\r?\n)?', ''
    $clean = $clean.TrimEnd()

    if ([string]::IsNullOrWhiteSpace($clean)) {
        return $tagLine
    }
    return "$clean`n`n$tagLine"
}
