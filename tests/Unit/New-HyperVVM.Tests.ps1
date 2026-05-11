BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
    Import-Module $modulePath

    # Mock Hyper-V cmdlets
    Mock -ModuleName HyperV.VMFactory New-VM {
        [PSCustomObject]@{
            VMName = $Name
            VMId   = [guid]::NewGuid()
            Name   = $Name
        }
    }
    Mock -ModuleName HyperV.VMFactory Set-VM {}
    Mock -ModuleName HyperV.VMFactory Connect-VMNetworkAdapter {}
    Mock -ModuleName HyperV.VMFactory New-VHD {
        [PSCustomObject]@{ Path = $Path }
    }
    Mock -ModuleName HyperV.VMFactory Add-VMHardDiskDrive {}
    Mock -ModuleName HyperV.VMFactory Add-VMDvdDrive {}
    Mock -ModuleName HyperV.VMFactory Set-VMFirmware {}
    Mock -ModuleName HyperV.VMFactory Set-VMVideo {}
    Mock -ModuleName HyperV.VMFactory Enable-VMIntegrationService {}
    Mock -ModuleName HyperV.VMFactory Set-VMProcessor {}
    Mock -ModuleName HyperV.VMFactory Set-VMKeyProtector {}
    Mock -ModuleName HyperV.VMFactory Enable-VMTPM {}
    Mock -ModuleName HyperV.VMFactory Start-VM {}
    Mock -ModuleName HyperV.VMFactory Start-Process {}
    Mock -ModuleName HyperV.VMFactory Get-VMDvdDrive { $null }
    Mock -ModuleName HyperV.VMFactory Get-VMHardDiskDrive { $null }
    Mock -ModuleName HyperV.VMFactory Invoke-Command {
        [PSCustomObject]@{ VMName = 'RemoteVM' }
    }

    # Mock prerequisite check to always pass in tests
    Mock -ModuleName HyperV.VMFactory Assert-HyperVPrerequisite {}
    Mock -ModuleName HyperV.VMFactory Set-HyperVVMTag {}
    Mock -ModuleName HyperV.VMFactory Get-VM {
        [PSCustomObject]@{ Name = $Name; Notes = '' }
    }
}

Describe 'New-HyperVVM' {
    Context 'Basic VM creation with mandatory parameters' {
        It 'Should create a VM with mandatory parameters' {
            $result = New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.VMName | Should -Be 'TestVM'
        }

        It 'Should call New-VM with correct parameters' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName New-VM -Times 1 -ParameterFilter {
                $Name -eq 'TestVM' -and $Path -eq 'C:\VMs' -and $Generation -eq 2 -and $NoVHD -eq $true
            }
        }

        It 'Should connect the VM to the specified switch' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'MySwitch' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Connect-VMNetworkAdapter -Times 1 -ParameterFilter {
                $SwitchName -eq 'MySwitch'
            }
        }
    }

    Context 'OS disk creation' {
        It 'Should create a new dynamic disk when no ParentDisk is specified' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName New-VHD -Times 1 -ParameterFilter {
                $Path -like '*TestVM_C.vhdx' -and $Dynamic -eq $true
            }
        }

        It 'Should create a differencing disk when ParentDisk is specified' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -ParentDisk 'C:\Base\Win11.vhdx' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName New-VHD -Times 1 -ParameterFilter {
                $Path -like '*TestVM_C.vhdx' -and $ParentPath -eq 'C:\Base\Win11.vhdx'
            }
        }

        It 'Should attach the OS disk to the VM via SCSI' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Add-VMHardDiskDrive -Times 1 -ParameterFilter {
                $ControllerType -eq 'SCSI' -and $Path -like '*TestVM_C.vhdx'
            }
        }
    }

    Context 'Additional data disk' {
        It 'Should NOT create a data disk by default' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName New-VHD -Times 1
        }

        It 'Should create a data disk when -AdditionalHDD is specified' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -AdditionalHDD -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName New-VHD -Times 2
        }
    }

    Context 'TPM and nested virtualization defaults' {
        It 'Should enable TPM by default' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VMKeyProtector -Times 1
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Enable-VMTPM -Times 1
        }

        It 'Should enable nested virtualization by default' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VMProcessor -Times 1 -ParameterFilter {
                $ExposeVirtualizationExtensions -eq $true
            }
        }

        It 'Should enable Guest Services by default' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Enable-VMIntegrationService -Times 1 -ParameterFilter {
                $Name -eq 'Guest Service Interface'
            }
        }

        It 'Should NOT enable TPM when -DisableTPM is specified' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -DisableTPM -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Enable-VMTPM -Times 0
        }

        It 'Should NOT enable nested virtualization when -DisableNestedVirtualization is specified' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -DisableNestedVirtualization -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VMProcessor -Times 0 -ParameterFilter {
                $ExposeVirtualizationExtensions -eq $true
            }
        }

        It 'Should NOT enable Guest Services when -DisableGuestServices is specified' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -DisableGuestServices -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Enable-VMIntegrationService -Times 0
        }
    }

    Context 'Power on VM' {
        It 'Should NOT start the VM by default' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Start-VM -Times 0
        }

        It 'Should start the VM when -PowerOnVM is specified' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -PowerOnVM -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Start-VM -Times 1
        }
    }

    Context 'Open console' {
        It 'Should NOT open the console by default' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Start-Process -Times 0
        }

        It 'Should open the console when -OpenConsole is specified' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -OpenConsole -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Start-Process -Times 1 -ParameterFilter {
                $FilePath -eq 'vmconnect.exe' -and $ArgumentList -contains 'localhost' -and $ArgumentList -contains 'TestVM'
            }
        }

        It 'Should open a console per remote host when -OpenConsole and -ComputerName are specified' {
            New-HyperVVM -VMName 'RemoteVM' -Path 'D:\VMs' -VMSwitch 'External' `
                -ComputerName 'Host01', 'Host02' -OpenConsole -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Start-Process -Times 2 -ParameterFilter {
                $FilePath -eq 'vmconnect.exe'
            }
        }
    }

    Context 'ISO boot' {
        It 'Should attach ISO and set boot device when ISOPath is specified' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -ISOPath 'C:\ISO\Win11.iso' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Add-VMDvdDrive -Times 1 -ParameterFilter {
                $Path -eq 'C:\ISO\Win11.iso'
            }
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Get-VMDvdDrive -Times 1
        }

        It 'Should boot from HDD when no ISO is specified' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Add-VMDvdDrive -Times 0
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Get-VMHardDiskDrive -Times 1
        }
    }

    Context 'WhatIf support' {
        It 'Should not create any VM when -WhatIf is specified' {
            New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' -WhatIf
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName New-VM -Times 0
        }
    }

    Context 'Bulk creation with array input' {
        It 'Should create multiple VMs when given an array of names' {
            New-HyperVVM -VMName 'VM1', 'VM2', 'VM3' -Path 'C:\VMs' -VMSwitch 'TestSwitch' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName New-VM -Times 3
        }
    }

    Context 'Pipeline input with configuration objects' {
        It 'Should accept configuration objects via -Configuration parameter' {
            $configs = @(
                New-HyperVVMConfiguration -VMName 'PipeVM1' -Path 'C:\VMs' -VMSwitch 'TestSwitch'
                New-HyperVVMConfiguration -VMName 'PipeVM2' -Path 'C:\VMs' -VMSwitch 'TestSwitch'
            )
            New-HyperVVM -Configuration $configs -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName New-VM -Times 2
        }
    }

    Context 'Remote execution' {
        It 'Should use Invoke-Command when -ComputerName is specified' {
            New-HyperVVM -VMName 'RemoteVM' -Path 'D:\VMs' -VMSwitch 'External' `
                -ComputerName 'HyperVHost01' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Invoke-Command -Times 1 -ParameterFilter {
                $ComputerName -contains 'HyperVHost01'
            }
        }

        It 'Should skip local prerequisite check when targeting remote host' {
            New-HyperVVM -VMName 'RemoteVM' -Path 'D:\VMs' -VMSwitch 'External' `
                -ComputerName 'HyperVHost01' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Assert-HyperVPrerequisite -Times 0
        }
    }

    Context 'Tag parameters on ByParameter set' {
        It 'calls Set-HyperVVMTag when -Environment is provided' {
            New-HyperVVM -VMName 'VM01' -Path 'C:\VMs' -VMSwitch 'Test' -Environment 'Lab' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Set-HyperVVMTag -Times 1
        }

        It 'does not call Set-HyperVVMTag when no tag params provided' {
            New-HyperVVM -VMName 'VM01' -Path 'C:\VMs' -VMSwitch 'Test' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Set-HyperVVMTag -Times 0
        }
    }

    Context 'Tag parameters via Configuration' {
        It 'calls Set-HyperVVMTag when config has TagEnvironment' {
            $config = New-HyperVVMConfiguration -VMName 'VM01' -Path 'C:\VMs' -VMSwitch 'Test' -Environment 'Lab'
            New-HyperVVM -Configuration $config -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Set-HyperVVMTag -Times 1
        }
    }

    Context 'VM Generation 1' {
        It 'Should create a Generation 1 VM when specified' {
            New-HyperVVM -VMName 'Gen1VM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -VMGeneration 1 -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName New-VM -Times 1 -ParameterFilter {
                $Generation -eq 1
            }
        }

        It 'Should not call Set-VMFirmware for Generation 1 VMs' {
            New-HyperVVM -VMName 'Gen1VM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -VMGeneration 1 -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VMFirmware -Times 0
        }
    }
}
