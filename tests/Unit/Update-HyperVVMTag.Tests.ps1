BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
    Import-Module $modulePath

    Mock -ModuleName HyperV.VMFactory Assert-HyperVPrerequisite {}
    Mock -ModuleName HyperV.VMFactory Set-VM {}
}

Describe 'Update-HyperVVMTag' {
    Context 'VM with legacy tag' {
        BeforeAll {
            Mock -ModuleName HyperV.VMFactory Get-VM {
                [PSCustomObject]@{
                    Name  = $Name
                    Notes = '<Env>PI-LAB</Env><Service>BeyondInsight</Service><DependsOn>Domain</DependsOn>'
                }
            }
        }

        It 'Should call Set-VM with new-format notes' {
            Update-HyperVVMTag -VMName 'BeyondInsight-01' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VM -Times 1 -ParameterFilter {
                $Notes -match '#HVTag:' -and
                $Notes -match 'PI-LAB' -and
                $Notes -match 'BeyondInsight' -and
                $Notes -match 'Domain'
            }
        }

        It 'Should not include legacy XML tags in new notes' {
            Update-HyperVVMTag -VMName 'BeyondInsight-01' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VM -Times 1 -ParameterFilter {
                $Notes -notmatch '<Env>' -and $Notes -notmatch '<Service>' -and $Notes -notmatch '<DependsOn>'
            }
        }

        It 'Should map Env to Environment in new-format JSON' {
            Update-HyperVVMTag -VMName 'BeyondInsight-01' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VM -Times 1 -ParameterFilter {
                $Notes -match '"Environment"'
            }
        }
    }

    Context 'VM with no legacy tag' {
        BeforeAll {
            Mock -ModuleName HyperV.VMFactory Get-VM {
                [PSCustomObject]@{ Name = $Name; Notes = 'Some plain notes.' }
            }
        }

        It 'Should not call Set-VM when no legacy tag is found' {
            Update-HyperVVMTag -VMName 'PlainVM' -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VM -Times 0
        }
    }

    Context 'VM already has new-format tag' {
        BeforeAll {
            Mock -ModuleName HyperV.VMFactory Get-VM {
                [PSCustomObject]@{
                    Name  = $Name
                    Notes = "<Env>PI-LAB</Env>`n#HVTag:{`"Environment`":[`"PI-LAB`"],`"Service`":[],`"DependsOn`":[]}"
                }
            }
        }

        It 'Should skip and warn when new tag exists and -Force not specified' {
            Update-HyperVVMTag -VMName 'BeyondInsight-01' -Confirm:$false 3>&1 | Out-Null
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VM -Times 0
        }

        It 'Should overwrite when -Force is specified' {
            Update-HyperVVMTag -VMName 'BeyondInsight-01' -Force -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VM -Times 1
        }
    }

    Context 'VM not found' {
        BeforeAll {
            Mock -ModuleName HyperV.VMFactory Get-VM { $null }
        }

        It 'Should write an error when VM is not found' {
            { Update-HyperVVMTag -VMName 'Ghost' -Confirm:$false -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'WhatIf support' {
        BeforeAll {
            Mock -ModuleName HyperV.VMFactory Get-VM {
                [PSCustomObject]@{
                    Name  = $Name
                    Notes = '<Env>PI-LAB</Env><Service>BeyondInsight</Service><DependsOn>Domain</DependsOn>'
                }
            }
        }

        It 'Should not call Set-VM when -WhatIf is specified' {
            Update-HyperVVMTag -VMName 'BeyondInsight-01' -WhatIf
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VM -Times 0
        }
    }

    Context 'Direct -VM parameter input' {
        It 'Should accept VM objects via -VM parameter' {
            $vmObj = [PSCustomObject]@{
                Name  = 'PipelineVM'
                Notes = '<Env>Staging</Env><Service>API</Service><DependsOn>DB</DependsOn>'
            }
            Update-HyperVVMTag -VM $vmObj -Confirm:$false
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VM -Times 1 -ParameterFilter {
                $Notes -match 'Staging' -and $Notes -match 'API'
            }
        }
    }
}
