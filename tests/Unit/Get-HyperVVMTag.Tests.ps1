BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
    Import-Module $modulePath -Force

    Mock -ModuleName HyperV.VMFactory Assert-HyperVPrerequisite {}
}

Describe 'Get-HyperVVMTag' {
    Context 'Tagged VM' {
        BeforeAll {
            Mock -ModuleName HyperV.VMFactory Get-VM {
                [PSCustomObject]@{
                    Name  = $Name
                    Notes = '#HVTag:{"Environment":["Lab"],"Service":["Domain"],"DependsOn":["DHCP","Gateway"]}'
                }
            }
        }

        It 'returns a HyperVVMTag object' {
            $result = Get-HyperVVMTag -VMName 'VM01'
            $result | Should -BeOfType 'HyperVVMTag'
        }

        It 'returns correct Environment' {
            $result = Get-HyperVVMTag -VMName 'VM01'
            $result.Environment | Should -Be @('Lab')
        }

        It 'returns correct multi-value DependsOn' {
            $result = Get-HyperVVMTag -VMName 'VM01'
            $result.DependsOn | Should -Be @('DHCP', 'Gateway')
        }
    }

    Context 'Untagged VM' {
        BeforeAll {
            Mock -ModuleName HyperV.VMFactory Get-VM {
                [PSCustomObject]@{ Name = $Name; Notes = 'No tag here.' }
            }
        }

        It 'returns null' {
            Get-HyperVVMTag -VMName 'VM01' | Should -BeNullOrEmpty
        }
    }
}
