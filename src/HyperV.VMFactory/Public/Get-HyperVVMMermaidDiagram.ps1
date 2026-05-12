function Get-HyperVVMMermaidDiagram {
    [CmdletBinding(DefaultParameterSetName = 'ByComputerName')]
    [OutputType([string])]
    param(
        [Parameter(ParameterSetName = 'ByTopology', ValueFromPipeline)]
        [HyperVVMTopology] $Topology,

        [Parameter(ParameterSetName = 'ByComputerName')]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost',

        [Parameter()]
        [string[]] $Environment,

        [Parameter()]
        [string[]] $Service,

        [Parameter()]
        [string] $OutputPath
    )

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'ByComputerName') {
            $Topology = Get-HyperVVMTopology -ComputerName $ComputerName
        }

        $envList = $Topology.Environment
        if ($Environment) {
            $envList = @($envList | Where-Object { $Environment -contains $_.Name })
        }
        if ($Service) {
            $envList = @(foreach ($env in $envList) {
                $svcFiltered = @($env.Service | Where-Object { $Service -contains $_.Name })
                if ($svcFiltered.Count -gt 0) {
                    $e            = [HyperVVMEnvironment]::new()
                    $e.Name       = $env.Name
                    $e.Service    = $svcFiltered
                    $e.StartOrder = @($env.StartOrder | Where-Object { $Service -contains $_ })
                    $e
                }
            })
        }

        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('graph TD')

        foreach ($env in $envList) {
            $envId = 'ENV_' + ($env.Name -replace '[^a-zA-Z0-9]', '_')
            $lines.Add("  subgraph ${envId}[""$($env.Name)""]")

            foreach ($svc in $env.Service) {
                $svcId = "${envId}_SVC_" + ($svc.Name -replace '[^a-zA-Z0-9]', '_')
                $lines.Add("    ${svcId}[(""$($svc.Name)"")]")

                foreach ($vm in $svc.VM) {
                    $vmId = "${envId}_VM_" + ($vm.Name -replace '[^a-zA-Z0-9]', '_')
                    $lines.Add("    ${vmId}[""$($vm.Name)""] -.->|member| ${svcId}")
                }
            }

            foreach ($svc in $env.Service) {
                $svcId = "${envId}_SVC_" + ($svc.Name -replace '[^a-zA-Z0-9]', '_')
                foreach ($dep in $svc.DependsOn) {
                    if ($env.Service | Where-Object Name -eq $dep) {
                        $depId = "${envId}_SVC_" + ($dep -replace '[^a-zA-Z0-9]', '_')
                        $lines.Add("    ${depId} -->|depends| ${svcId}")
                    }
                }
            }

            $lines.Add('  end')
        }

        $diagram = $lines -join "`n"

        if ($OutputPath) {
            Set-Content -Path $OutputPath -Value $diagram -Encoding UTF8
        }

        $diagram
    }
}
