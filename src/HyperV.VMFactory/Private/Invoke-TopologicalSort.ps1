function Invoke-TopologicalSort {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $EdgeList
    )

    $allNodes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($node in $EdgeList.Keys) {
        [void]$allNodes.Add($node)
        foreach ($dep in $EdgeList[$node]) {
            if (-not [string]::IsNullOrEmpty($dep)) { [void]$allNodes.Add($dep) }
        }
    }

    $dependents = @{}
    $inDegree   = @{}
    foreach ($node in $allNodes) {
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
    foreach ($node in $allNodes) {
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

    if ($sorted.Count -ne $allNodes.Count) {
        $remaining = $allNodes | Where-Object { $sorted -notcontains $_ }
        throw "Dependency cycle detected involving: $($remaining -join ', ')"
    }

    return [string[]]$sorted
}
