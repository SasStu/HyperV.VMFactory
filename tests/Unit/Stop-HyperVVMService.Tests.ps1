Describe 'Stop-HyperVVMService' {
    BeforeAll {
        $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
        Import-Module $modulePath -Force
        Mock -ModuleName HyperV.VMFactory Assert-HyperVPrerequisite {}
        Mock -ModuleName HyperV.VMFactory Stop-VM {}
        Mock -ModuleName HyperV.VMFactory Wait-HyperVVMOff {}
        Mock -ModuleName HyperV.VMFactory Get-VM { [PSCustomObject]@{ State = 'Off' } }

        # Base topology: DHCP <- Domain (Domain depends on DHCP)
        function script:New-TestTopology {
            $dhcpVM = [PSCustomObject]@{ Name = 'DHCP01'; State = 'Running' }
            $dcVM   = [PSCustomObject]@{ Name = 'DC01';   State = 'Running' }

            $dhcpSvc = [HyperVVMService]::new(); $dhcpSvc.Name = 'DHCP';   $dhcpSvc.Environment = 'Lab'; $dhcpSvc.DependsOn = @();       $dhcpSvc.VM = @($dhcpVM)
            $dcSvc   = [HyperVVMService]::new(); $dcSvc.Name   = 'Domain'; $dcSvc.Environment   = 'Lab'; $dcSvc.DependsOn   = @('DHCP'); $dcSvc.VM   = @($dcVM)

            $env = [HyperVVMEnvironment]::new(); $env.Name = 'Lab'; $env.Service = @($dhcpSvc, $dcSvc); $env.StartOrder = @('DHCP', 'Domain')
            $topo = [HyperVVMTopology]::new(); $topo.ComputerName = 'localhost'; $topo.Environment = @($env)
            $topo
        }

        # Extended topology: DHCP <- Domain, DHCP <- ICA  (both Domain and ICA depend on DHCP)
        function script:New-SharedDependencyTopology {
            $dhcpVM = [PSCustomObject]@{ Name = 'DHCP01'; State = 'Running' }
            $dcVM   = [PSCustomObject]@{ Name = 'DC01';   State = 'Running' }
            $icaVM  = [PSCustomObject]@{ Name = 'ICA01';  State = 'Running' }

            $dhcpSvc = [HyperVVMService]::new(); $dhcpSvc.Name = 'DHCP';   $dhcpSvc.Environment = 'Lab'; $dhcpSvc.DependsOn = @();       $dhcpSvc.VM = @($dhcpVM)
            $dcSvc   = [HyperVVMService]::new(); $dcSvc.Name   = 'Domain'; $dcSvc.Environment   = 'Lab'; $dcSvc.DependsOn   = @('DHCP'); $dcSvc.VM   = @($dcVM)
            $icaSvc  = [HyperVVMService]::new(); $icaSvc.Name  = 'ICA';    $icaSvc.Environment  = 'Lab'; $icaSvc.DependsOn  = @('DHCP'); $icaSvc.VM  = @($icaVM)

            $env = [HyperVVMEnvironment]::new(); $env.Name = 'Lab'; $env.Service = @($dhcpSvc, $dcSvc, $icaSvc); $env.StartOrder = @()
            $topo = [HyperVVMTopology]::new(); $topo.ComputerName = 'localhost'; $topo.Environment = @($env)
            $topo
        }
    }

    Context 'Stopping a service' {
        It 'calls Stop-VM for each running VM' {
            $topo = New-TestTopology
            Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Stop-VM -Times 1
        }

        It 'passes ComputerName to Stop-VM' {
            $topo = New-TestTopology
            Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Stop-VM -Times 1 -ParameterFilter {
                $ComputerName -eq 'localhost'
            }
        }

        It 'waits for Off state by default' {
            $topo = New-TestTopology
            Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Wait-HyperVVMOff -Times 1
        }

        It 'skips wait when WaitForVM is false' {
            $topo = New-TestTopology
            Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -WaitForVM:$false -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Wait-HyperVVMOff -Times 0
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

        It 'returns Success containing the stopped VM name' {
            $topo = New-TestTopology
            $result = Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            $result.Success | Should -Contain 'DC01'
        }

        It 'returns Failed as null on success' {
            $topo = New-TestTopology
            $result = Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            $result.Failed | Should -BeNullOrEmpty
        }
    }

    Context 'VM stop failure' {
        It 'returns structured Failed object on first VM error' {
            $topo = New-TestTopology
            Mock -ModuleName HyperV.VMFactory Stop-VM { throw 'Could not stop VM' }
            $result = Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Confirm:$false
            $result.Failed | Should -Not -BeNullOrEmpty
            $result.Failed.VMName | Should -Be 'DC01'
        }
    }

    Context '-Recurse stops dependents first' {
        It 'stops Domain before DHCP when stopping DHCP with -Recurse' {
            $topo = New-TestTopology
            $stopOrder = [System.Collections.Generic.List[string]]::new()
            Mock -ModuleName HyperV.VMFactory Stop-VM { $stopOrder.Add($Name) }
            Stop-HyperVVMService -ServiceName 'DHCP' -EnvironmentName 'Lab' -Topology $topo -Recurse -Confirm:$false
            $stopOrder.IndexOf('DC01') | Should -BeLessThan $stopOrder.IndexOf('DHCP01')
        }
    }

    Context '-Recurse stops unused dependencies after' {
        It 'stops DHCP after Domain when no other service depends on DHCP' {
            $topo = New-TestTopology
            $stopOrder = [System.Collections.Generic.List[string]]::new()
            Mock -ModuleName HyperV.VMFactory Stop-VM { $stopOrder.Add($Name) }
            Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Recurse -Confirm:$false
            $stopOrder | Should -Contain 'DHCP01'
            $stopOrder.IndexOf('DC01') | Should -BeLessThan $stopOrder.IndexOf('DHCP01')
        }

        It 'does not stop DHCP when another running service (ICA) still depends on it' {
            $topo = New-SharedDependencyTopology
            Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Recurse -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Stop-VM -Times 1 -ParameterFilter { $Name -eq 'DC01' }
            Should -Invoke -ModuleName HyperV.VMFactory Stop-VM -Times 0 -ParameterFilter { $Name -eq 'DHCP01' }
        }

        It 'stops DHCP when the only other dependent (ICA) is already off' {
            $topo = New-SharedDependencyTopology
            $topo.Environment[0].Service[2].VM[0] = [PSCustomObject]@{ Name = 'ICA01'; State = 'Off' }
            $stopOrder = [System.Collections.Generic.List[string]]::new()
            Mock -ModuleName HyperV.VMFactory Stop-VM { $stopOrder.Add($Name) }
            Stop-HyperVVMService -ServiceName 'Domain' -EnvironmentName 'Lab' -Topology $topo -Recurse -Confirm:$false
            $stopOrder | Should -Contain 'DHCP01'
        }
    }
}
