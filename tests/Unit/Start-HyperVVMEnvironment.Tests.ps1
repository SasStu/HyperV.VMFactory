Describe 'Start-HyperVVMEnvironment' {
    BeforeAll {
        $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
        Import-Module $modulePath -Force
        Mock -ModuleName HyperV.VMFactory Assert-HyperVPrerequisite {}
        Mock -ModuleName HyperV.VMFactory Start-VM {}
        Mock -ModuleName HyperV.VMFactory Wait-VM {}

        function script:New-TestTopology {
            $dhcpVM = [PSCustomObject]@{ Name = 'DHCP01'; State = 'Off' }
            $dcVM   = [PSCustomObject]@{ Name = 'DC01';   State = 'Off' }
            $dhcpSvc = [HyperVVMService]::new(); $dhcpSvc.Name = 'DHCP';   $dhcpSvc.Environment = 'Lab'; $dhcpSvc.DependsOn = @();       $dhcpSvc.VM = @($dhcpVM)
            $dcSvc   = [HyperVVMService]::new(); $dcSvc.Name   = 'Domain'; $dcSvc.Environment   = 'Lab'; $dcSvc.DependsOn   = @('DHCP'); $dcSvc.VM   = @($dcVM)
            $env = [HyperVVMEnvironment]::new(); $env.Name = 'Lab'; $env.Service = @($dhcpSvc, $dcSvc); $env.StartOrder = @('DHCP', 'Domain')
            $topo = [HyperVVMTopology]::new(); $topo.ComputerName = 'localhost'; $topo.Environment = @($env)
            $topo
        }
    }

    It 'starts all services in the environment' {
        $topo = New-TestTopology
        Start-HyperVVMEnvironment -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
        Should -Invoke -ModuleName HyperV.VMFactory Start-VM -Times 2
    }

    It 'starts services in StartOrder (DHCP before Domain)' {
        $topo = New-TestTopology
        $startOrder = [System.Collections.Generic.List[string]]::new()
        Mock -ModuleName HyperV.VMFactory Start-VM { $startOrder.Add($Name) }
        Start-HyperVVMEnvironment -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
        $startOrder.IndexOf('DHCP01') | Should -BeLessThan $startOrder.IndexOf('DC01')
    }

    It 'stops on first service failure and returns structured result' {
        $topo = New-TestTopology
        Mock -ModuleName HyperV.VMFactory Start-VM { throw 'Could not start' }
        $result = Start-HyperVVMEnvironment -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
        $result.Failed | Should -Not -BeNullOrEmpty
    }

    It 'throws when environment not found' {
        $topo = New-TestTopology
        { Start-HyperVVMEnvironment -EnvironmentName 'NonExistent' -Topology $topo -Confirm:$false } | Should -Throw
    }
}
