Describe 'Start-HyperVVMService' {
    BeforeAll {
        $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
        Import-Module $modulePath -Force
        Mock -ModuleName HyperV.VMFactory Assert-HyperVPrerequisite {}
        Mock -ModuleName HyperV.VMFactory Start-VM {}
        Mock -ModuleName HyperV.VMFactory Wait-VM {}
        Mock -ModuleName HyperV.VMFactory Invoke-VMConsole {}

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

        It 'waits for IPAddress by default' {
            $topo = New-TestTopology
            Start-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Wait-VM -Times 1 -ParameterFilter {
                $For -eq 'IPAddress'
            }
        }

        It 'waits for Heartbeat when VMWaitFor is Heartbeat' {
            $topo = New-TestTopology
            Start-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -VMWaitFor Heartbeat -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Wait-VM -Times 1 -ParameterFilter {
                $For -eq 'Heartbeat'
            }
        }

        It 'skips Wait-VM when WaitForVM is false' {
            $topo = New-TestTopology
            Start-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -WaitForVM:$false -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Wait-VM -Times 0
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

    Context 'OpenConsole' {
        It 'opens console for each started VM when OpenConsole is set' {
            $topo = New-TestTopology
            Start-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -OpenConsole -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Invoke-VMConsole -Times 1 -ParameterFilter {
                $VMName -eq 'DHCP01'
            }
        }

        It 'does not open console when OpenConsole is not set' {
            $topo = New-TestTopology
            Start-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Invoke-VMConsole -Times 0
        }

        It 'opens only target service console when Recurse and OpenConsole are set with default TargetOnly scope' {
            $topo = New-TestTopology
            Start-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Recurse -OpenConsole -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Invoke-VMConsole -Times 1 -ParameterFilter {
                $VMName -eq 'DC01'
            }
            Should -Invoke -ModuleName HyperV.VMFactory Invoke-VMConsole -Times 0 -ParameterFilter {
                $VMName -eq 'DHCP01'
            }
        }

        It 'opens consoles for all started VMs when Recurse and OpenConsole are set with AllStarted scope' {
            $topo = New-TestTopology
            Start-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Recurse -OpenConsole -OpenConsoleScope AllStarted -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Invoke-VMConsole -Times 2
        }

        It 'does not open console for dependency VMs when only Recurse is set' {
            $topo = New-TestTopology
            Start-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Recurse -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Invoke-VMConsole -Times 0
        }

        It 'opens console for already-running VM when OpenConsole is set' {
            $topo = New-TestTopology
            $topo.Environment[0].Service[0].VM[0] = [PSCustomObject]@{ Name = 'DHCP01'; State = 'Running' }
            Start-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -OpenConsole -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Invoke-VMConsole -Times 1 -ParameterFilter {
                $VMName -eq 'DHCP01'
            }
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
