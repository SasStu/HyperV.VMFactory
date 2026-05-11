BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
    Import-Module $modulePath

    Mock -ModuleName HyperV.VMFactory Set-VM {}
    Mock -ModuleName HyperV.VMFactory Set-VMVideo {}
    Mock -ModuleName HyperV.VMFactory Enable-VMIntegrationService {}
    Mock -ModuleName HyperV.VMFactory Set-VMProcessor {}
    Mock -ModuleName HyperV.VMFactory Set-VMKeyProtector {}
    Mock -ModuleName HyperV.VMFactory Enable-VMTPM {}
}

Describe 'Set-VMConfiguration' {
    BeforeAll {
        $script:fakeVM = [PSCustomObject]@{ VMName = 'TestVM'; VMId = [guid]::NewGuid() }
    }

    Context 'Default configuration' {
        It 'Should apply processor count and auto-actions' {
            InModuleScope HyperV.VMFactory -Parameters @{ VM = $script:fakeVM } {
                param($VM)
                Set-VMConfiguration -VM $VM
            }
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VM -Times 1 -ParameterFilter {
                $VMName -eq 'TestVM' -and
                $ProcessorCount -eq 2 -and
                $AutomaticStartAction -eq 'Nothing' -and
                $AutomaticStopAction -eq 'ShutDown'
            }
        }

        It 'Should set default video resolution' {
            InModuleScope HyperV.VMFactory -Parameters @{ VM = $script:fakeVM } {
                param($VM)
                Set-VMConfiguration -VM $VM
            }
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VMVideo -Times 1 -ParameterFilter {
                $VMName -eq 'TestVM' -and
                $HorizontalResolution -eq 1920 -and $VerticalResolution -eq 1080
            }
        }

        It 'Should enable Guest Service Interface' {
            InModuleScope HyperV.VMFactory -Parameters @{ VM = $script:fakeVM } {
                param($VM)
                Set-VMConfiguration -VM $VM
            }
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Enable-VMIntegrationService -Times 1 -ParameterFilter {
                $VMName -eq 'TestVM' -and $Name -eq 'Guest Service Interface'
            }
        }

        It 'Should enable nested virtualization by default' {
            InModuleScope HyperV.VMFactory -Parameters @{ VM = $script:fakeVM } {
                param($VM)
                Set-VMConfiguration -VM $VM
            }
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VMProcessor -Times 1 -ParameterFilter {
                $ExposeVirtualizationExtensions -eq $true
            }
        }

        It 'Should enable TPM by default' {
            InModuleScope HyperV.VMFactory -Parameters @{ VM = $script:fakeVM } {
                param($VM)
                Set-VMConfiguration -VM $VM
            }
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VMKeyProtector -Times 1
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Enable-VMTPM -Times 1
        }
    }

    Context 'Custom configuration' {
        It 'Should skip nested virtualization when disabled' {
            InModuleScope HyperV.VMFactory -Parameters @{ VM = $script:fakeVM } {
                param($VM)
                Set-VMConfiguration -VM $VM -NestedVirtualization $false
            }
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VMProcessor -Times 0 -ParameterFilter {
                $ExposeVirtualizationExtensions -eq $true
            }
        }

        It 'Should skip TPM when disabled' {
            InModuleScope HyperV.VMFactory -Parameters @{ VM = $script:fakeVM } {
                param($VM)
                Set-VMConfiguration -VM $VM -TPM $false
            }
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VMKeyProtector -Times 0
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Enable-VMTPM -Times 0
        }

        It 'Should apply custom processor count' {
            InModuleScope HyperV.VMFactory -Parameters @{ VM = $script:fakeVM } {
                param($VM)
                Set-VMConfiguration -VM $VM -ProcessorCount 8
            }
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VM -Times 1 -ParameterFilter {
                $ProcessorCount -eq 8
            }
        }

        It 'Should apply custom resolution' {
            InModuleScope HyperV.VMFactory -Parameters @{ VM = $script:fakeVM } {
                param($VM)
                Set-VMConfiguration -VM $VM -HorizontalResolution 2560 -VerticalResolution 1440
            }
            Should -Invoke -ModuleName HyperV.VMFactory -CommandName Set-VMVideo -Times 1 -ParameterFilter {
                $HorizontalResolution -eq 2560 -and $VerticalResolution -eq 1440
            }
        }
    }
}
