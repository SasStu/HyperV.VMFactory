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

Describe 'Stop-HyperVVMEnvironment' {
    It 'stops all services in the environment' {
        $topo = New-TestTopology
        Stop-HyperVVMEnvironment -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
        Should -Invoke -ModuleName HyperV.VMFactory Stop-VM -Times 2
    }

    It 'stops services in reverse StartOrder (Domain before DHCP)' {
        $topo = New-TestTopology
        $stopOrder = [System.Collections.Generic.List[string]]::new()
        Mock -ModuleName HyperV.VMFactory Stop-VM { $stopOrder.Add($VM.Name) }
        Stop-HyperVVMEnvironment -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
        $stopOrder.IndexOf('DC01') | Should -BeLessThan $stopOrder.IndexOf('DHCP01')
    }

    It 'throws when environment not found' {
        $topo = New-TestTopology
        { Stop-HyperVVMEnvironment -EnvironmentName 'NonExistent' -Topology $topo -Confirm:$false } | Should -Throw
    }
}
