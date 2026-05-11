BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
    Import-Module $modulePath
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
            $config.OpenConsole | Should -Be $false
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

        It 'Should set OpenConsole to true when -OpenConsole is specified' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -OpenConsole
            $config.OpenConsole | Should -Be $true
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

    Context 'Tag parameters' {
        It 'Should set Environment when specified' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -Environment 'Lab', 'Prod'
            $config.Environment | Should -Be @('Lab', 'Prod')
        }

        It 'Should set Service when specified' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -Service 'Domain', 'Web'
            $config.Service | Should -Be @('Domain', 'Web')
        }

        It 'Should set DependsOn when specified' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch' `
                -DependsOn 'Domain'
            $config.DependsOn | Should -Be @('Domain')
        }

        It 'Should default Environment to null when not specified' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch'
            $config.Environment | Should -BeNullOrEmpty
        }

        It 'Should default Service to null when not specified' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch'
            $config.Service | Should -BeNullOrEmpty
        }

        It 'Should default DependsOn to null when not specified' {
            $config = New-HyperVVMConfiguration -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'TestSwitch'
            $config.DependsOn | Should -BeNullOrEmpty
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
