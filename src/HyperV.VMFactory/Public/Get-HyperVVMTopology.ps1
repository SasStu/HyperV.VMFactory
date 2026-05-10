function Get-HyperVVMTopology {
    [CmdletBinding()]
    [OutputType([HyperVVMTopology])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost'
    )
    Assert-HyperVPrerequisite -ComputerName $ComputerName

    $taggedVMs = Get-VM -ComputerName $ComputerName | ForEach-Object {
        $tag = ConvertFrom-HyperVVMTag -Notes $_.Notes
        if ($tag) { [PSCustomObject]@{ VM = $_; Tag = $tag } }
    }

    $envNames = $taggedVMs |
        ForEach-Object { $_.Tag.Environment } |
        Where-Object { $_ } |
        Select-Object -Unique

    $environments = foreach ($envName in $envNames) {
        $envVMs = $taggedVMs | Where-Object { $_.Tag.Environment -contains $envName }

        $serviceNames = $envVMs |
            ForEach-Object { $_.Tag.Service } |
            Where-Object { $_ } |
            Select-Object -Unique

        $services = foreach ($svcName in $serviceNames) {
            $svcEntries = $envVMs | Where-Object { $_.Tag.Service -contains $svcName }
            $dependsOn  = $svcEntries |
                ForEach-Object { $_.Tag.DependsOn } |
                Where-Object { $_ } |
                Select-Object -Unique

            $svc             = [HyperVVMService]::new()
            $svc.Name        = $svcName
            $svc.Environment = $envName
            $svc.DependsOn   = @($dependsOn)
            $svc.VM          = @($svcEntries.VM)
            $svc
        }

        $tmpEnv            = [HyperVVMEnvironment]::new()
        $tmpEnv.Name       = $envName
        $tmpEnv.Service    = @($services)
        $tmpEnv.StartOrder = @()
        $edgeList   = Get-HyperVVMEdgeList -Environment $tmpEnv
        $startOrder = Invoke-TopologicalSort -EdgeList $edgeList

        $env            = [HyperVVMEnvironment]::new()
        $env.Name       = $envName
        $env.Service    = @($services)
        $env.StartOrder = @($startOrder)
        $env
    }

    $topology              = [HyperVVMTopology]::new()
    $topology.ComputerName = $ComputerName
    $topology.Environment  = @($environments)
    $topology
}
