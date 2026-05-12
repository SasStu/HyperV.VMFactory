function Invoke-TopologicalSort {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $EdgeList
    )

    $nodeSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($node in $EdgeList.Keys) {
        [void]$nodeSet.Add($node)
        foreach ($dep in $EdgeList[$node]) {
            if (-not [string]::IsNullOrEmpty($dep)) { [void]$nodeSet.Add($dep) }
        }
    }

    $dependents = @{}
    $inDegree   = @{}
    foreach ($node in $nodeSet) {
        $dependents[$node] = [System.Collections.Generic.List[string]]::new()
        $inDegree[$node]   = 0
    }

    foreach ($node in $EdgeList.Keys) {
        foreach ($dep in $EdgeList[$node]) {
            if (-not [string]::IsNullOrEmpty($dep)) {
                $dependents[$dep].Add($node)
                $inDegree[$node]++
            }
        }
    }

    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($node in $nodeSet) {
        if ($inDegree[$node] -eq 0) { $queue.Enqueue($node) }
    }

    $sorted = [System.Collections.Generic.List[string]]::new()
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        $sorted.Add($current)
        foreach ($dependent in $dependents[$current]) {
            $inDegree[$dependent]--
            if ($inDegree[$dependent] -eq 0) { $queue.Enqueue($dependent) }
        }
    }

    if ($sorted.Count -ne $nodeSet.Count) {
        $remaining = $nodeSet | Where-Object { $sorted -notcontains $_ }
        throw "Dependency cycle detected involving: $($remaining -join ', ')"
    }

    return [string[]]$sorted
}
