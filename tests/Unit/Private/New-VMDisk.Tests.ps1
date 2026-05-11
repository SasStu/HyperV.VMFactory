BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
    Import-Module $modulePath
}

Describe 'New-VMDisk' {
    BeforeAll {
        Mock -ModuleName HyperV.VMFactory New-VHD {
            [PSCustomObject]@{ Path = $Path }
        }
    }

    Context 'Differencing disk creation' {
        It 'Should create a differencing disk when ParentDisk is specified' {
            InModuleScope HyperV.VMFactory {
                New-VMDisk -Path 'C:\VMs\Test\test.vhdx' -ParentDisk 'C:\Base\Win11.vhdx'
            }
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName New-VHD -Times 1 -ParameterFilter {
                $ParentPath -eq 'C:\Base\Win11.vhdx' -and $Differencing -eq $true
            }
        }
    }

    Context 'New dynamic disk creation' {
        It 'Should create a dynamic disk when no ParentDisk is specified' {
            InModuleScope HyperV.VMFactory {
                New-VMDisk -Path 'C:\VMs\Test\test.vhdx'
            }
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName New-VHD -Times 1 -ParameterFilter {
                $Dynamic -eq $true -and $SizeBytes -eq 127GB
            }
        }

        It 'Should use custom size when specified' {
            InModuleScope HyperV.VMFactory {
                New-VMDisk -Path 'C:\VMs\Test\test.vhdx' -SizeBytes 256GB
            }
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName New-VHD -Times 1 -ParameterFilter {
                $SizeBytes -eq 256GB
            }
        }
    }

    Context 'Return value' {
        It 'Should return a VHD object' {
            $result = InModuleScope HyperV.VMFactory {
                New-VMDisk -Path 'C:\VMs\Test\test.vhdx'
            }
            $result | Should -Not -BeNullOrEmpty
            $result.Path | Should -Be 'C:\VMs\Test\test.vhdx'
        }
    }
}
