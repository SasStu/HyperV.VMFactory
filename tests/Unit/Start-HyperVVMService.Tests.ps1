Describe 'Start-HyperVVMService' {
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

    Context 'Starting a service' {
        It 'calls Start-VM for each VM in the service' {
            $topo = New-TestTopology
            Start-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Start-VM -Times 1
        }

        It 'returns Success containing the started VM name' {
            $topo = New-TestTopology
            $result = Start-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            $result.Success | Should -Contain 'DHCP01'
        }

        It 'returns Failed as null on success' {
            $topo = New-TestTopology
            $result = Start-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            $result.Failed | Should -BeNullOrEmpty
        }
    }

    Context 'Already running VM' {
        It 'skips already-running VM and does not call Start-VM' {
            $topo = New-TestTopology
            $topo.Environment[0].Service[0].VM[0] = [PSCustomObject]@{ Name = 'DHCP01'; State = 'Running' }
            Start-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Start-VM -Times 0
        }
    }

    Context 'VM start failure' {
        It 'returns structured Failed object on first VM error' {
            $topo = New-TestTopology
            Mock -ModuleName HyperV.VMFactory Start-VM { throw 'Could not start VM' }
            $result = Start-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            $result.Failed | Should -Not -BeNullOrEmpty
            $result.Failed.VMName | Should -Be 'DHCP01'
        }
    }
}
