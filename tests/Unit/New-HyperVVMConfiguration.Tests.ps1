BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
    Import-Module $modulePath -Force
}

Describe 'New-HyperVVMConfiguration' {
    Context 'Configuration object creation' {
        It 'Should return an object with PSTypeName HyperV.VMFactory.Configuration' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch'
            $config.PSTypeNames | Should -Contain 'HyperV.VMFactory.Configuration'
        }

        It 'Should set all mandatory properties correctly' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'D:\VMs' -VMSwitch 'External'
            $config.VMName | Should -Be 'TestVM'
            $config.Path | Should -Be 'D:\VMs'
            $config.VMSwitch | Should -Be 'External'
        }

        It 'Should apply correct defaults' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch'
            $config.VMGeneration | Should -Be 2
            $config.VMProcessorCount | Should -Be 2
            $config.VMMemoryStartupBytes | Should -Be 2GB
            $config.OSDiskSizeBytes | Should -Be 127GB
            $config.DataDiskSizeBytes | Should -Be 127GB
            $config.AdditionalHDD | Should -Be $false
            $config.NestedVirtualization | Should -Be $true
            $config.TPM | Should -Be $true
            $config.GuestServices | Should -Be $true
            $config.PowerOnVM | Should -Be $false
            $config.HorizontalResolution | Should -Be 1920
            $config.VerticalResolution | Should -Be 1080
            $config.AutomaticStartAction | Should -Be 'Nothing'
            $config.AutomaticStopAction | Should -Be 'ShutDown'
        }

        It 'Should set optional properties when specified' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'External' `
                -ParentDisk 'C:\Base\Win11.vhdx' `
                -VMGeneration 1 `
                -VMProcessorCount 4 `
                -VMMemoryStartupBytes 4GB `
                -AdditionalHDD `
                -PowerOnVM `
                -ISOPath 'C:\ISO\test.iso'
            $config.ParentDisk | Should -Be 'C:\Base\Win11.vhdx'
            $config.VMGeneration | Should -Be 1
            $config.VMProcessorCount | Should -Be 4
            $config.VMMemoryStartupBytes | Should -Be 4GB
            $config.AdditionalHDD | Should -Be $true
            $config.PowerOnVM | Should -Be $true
            $config.ISOPath | Should -Be 'C:\ISO\test.iso'
        }
    }

    Context 'Disable switch parameters' {
        It 'Should set NestedVirtualization to false when -DisableNestedVirtualization is specified' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -DisableNestedVirtualization
            $config.NestedVirtualization | Should -Be $false
        }

        It 'Should set TPM to false when -DisableTPM is specified' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -DisableTPM
            $config.TPM | Should -Be $false
        }

        It 'Should set GuestServices to false when -DisableGuestServices is specified' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -DisableGuestServices
            $config.GuestServices | Should -Be $false
        }
    }

    Context 'Validation' {
        It 'Should reject odd horizontal resolution' {
            { New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -HorizontalResolution 1921 } | Should -Throw
        }

        It 'Should reject odd vertical resolution' {
            { New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -VerticalResolution 1081 } | Should -Throw
        }

        It 'Should reject invalid VMGeneration' {
            { New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -VMGeneration 3 } | Should -Throw
        }
    }
}
