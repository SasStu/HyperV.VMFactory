BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
    Import-Module $modulePath -Force

    Mock -ModuleName HyperV.VMFactory Assert-HyperVPrerequisite {}
    Mock -ModuleName HyperV.VMFactory Set-VM {}
    Mock -ModuleName HyperV.VMFactory Get-VM {
        [PSCustomObject]@{ Name = $Name; Notes = '' }
    }
}

Describe 'Set-HyperVVMTag' {
    Context 'Writing a new tag' {
        It 'calls Set-VM with Notes containing #HVTag: sentinel' {
            Set-HyperVVMTag -VMName 'VM01' -Environment 'Lab' -Service 'Domain' -DependsOn 'DHCP' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Set-VM -Times 1 -ParameterFilter {
                $Notes -match '#HVTag:'
            }
        }
    }

    Context 'Existing tag without -Force' {
        BeforeAll {
            Mock -ModuleName HyperV.VMFactory Get-VM {
                [PSCustomObject]@{
                    Name  = $Name
                    Notes = '#HVTag:{"Environment":["Old"],"Service":["OldSvc"],"DependsOn":[]}'
                }
            }
        }

        It 'does not call Set-VM' {
            Set-HyperVVMTag -VMName 'VM01' -Environment 'New' -Service 'NewSvc' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Set-VM -Times 0
        }

        It 'emits a warning' {
            { Set-HyperVVMTag -VMName 'VM01' -Environment 'New' -Service 'NewSvc' -Confirm:$false -WarningAction Stop } |
                Should -Throw
        }
    }

    Context 'Existing tag with -Force' {
        BeforeAll {
            Mock -ModuleName HyperV.VMFactory Get-VM {
                [PSCustomObject]@{
                    Name  = $Name
                    Notes = '#HVTag:{"Environment":["Old"],"Service":["OldSvc"],"DependsOn":[]}'
                }
            }
        }

        It 'calls Set-VM and overwrites tag' {
            Set-HyperVVMTag -VMName 'VM01' -Environment 'New' -Force -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Set-VM -Times 1 -ParameterFilter {
                $Notes -match 'New' -and $Notes -notmatch 'Old'
            }
        }
    }

    Context 'Preserving existing Notes content' {
        BeforeAll {
            Mock -ModuleName HyperV.VMFactory Get-VM {
                [PSCustomObject]@{ Name = $Name; Notes = 'Keep this note.' }
            }
        }

        It 'preserves user Notes above the sentinel' {
            Set-HyperVVMTag -VMName 'VM01' -Environment 'Lab' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory Set-VM -Times 1 -ParameterFilter {
                $Notes -match 'Keep this note\.' -and $Notes -match '#HVTag:'
            }
        }
    }
}
