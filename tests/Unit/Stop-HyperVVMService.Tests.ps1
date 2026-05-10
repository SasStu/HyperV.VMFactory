BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
    Import-Module $modulePath -Force

    Mock -ModuleName HyperV.VMFactory Assert-HyperVPrerequisite {}
    Mock -ModuleName HyperV.VMFactory Stop-VM {}

    function script:New-TestTopology {
        $dhcpVM = [PSCustomObject]@{ Name = 'DHCP01'; State = 'Running' }
        $dcVM   = [PSCustomObject]@{ Name = 'DC01';   State = 'Running' }

        $dhcpSvc = [HyperVVMService]::new(); $dhcpSvc.Name = 'DHCP';   $dhcpSvc.Environment = 'Lab'; $dhcpSvc.DependsOn = @();       $dhcpSvc.VM = @($dhcpVM)
        $dcSvc   = [HyperVVMService]::new(); $dcSvc.Name   = 'Domain'; $dcSvc.Environment   = 'Lab'; $dcSvc.DependsOn   = @('DHCP'); $dcSvc.VM   = @($dcVM)

        $env = [HyperVVMEnvironment]::new(); $env.Name = 'Lab'; $env.Service = @($dhcpSvc, $dcSvc); $env.StartOrder = @('DHCP', 'Domain')
        $topo = [HyperVVMTopology]::new(); $topo.ComputerName = 'localhost'; $topo.Environment = @($env)
        $topo
    }
}

Describe 'Stop-HyperVVMService' {
    Context 'Stopping a service' {
        It 'calls Stop-VM for each running VM' {
            $topo = New-TestTopology
            Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Stop-VM -Times 1
        }

        It 'skips already-stopped VMs' {
            $topo = New-TestTopology
            $topo.Environment[0].Service[1].VM[0] = [PSCustomObject]@{ Name = 'DC01'; State = 'Off' }
            Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Stop-VM -Times 0
        }

        It 'passes -Force to Stop-VM when -Force is specified' {
            $topo = New-TestTopology
            Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Force -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Stop-VM -Times 1 -ParameterFilter { $Force -eq $true }
        }
    }

    Context '-Recurse stops dependents first' {
        It 'stops Domain before DHCP when stopping DHCP with -Recurse' {
            $topo = New-TestTopology
            $stopOrder = [System.Collections.Generic.List[string]]::new()
            Mock -ModuleName HyperV.VMFactory Stop-VM { $stopOrder.Add($VM.Name) }
            Stop-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -Recurse -Confirm:$false
            $stopOrder.IndexOf('DC01') | Should -BeLessThan $stopOrder.IndexOf('DHCP01')
        }
    }
}
