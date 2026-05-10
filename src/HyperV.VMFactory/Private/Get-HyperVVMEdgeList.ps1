function Get-HyperVVMEdgeList {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [HyperVVMEnvironment] $Environment
    )
    $edgeList = @{}
    foreach ($service in $Environment.Service) {
        $edgeList[$service.Name] = @($service.DependsOn | Where-Object { $_ })
    }
    return $edgeList
}
