BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
    Import-Module $modulePath -Force
}

Describe 'ConvertTo-HyperVVMTagJson' {
    InModuleScope HyperV.VMFactory {
        BeforeEach {
            $tag = [HyperVVMTag]::new()
            $tag.Environment = @('Lab')
            $tag.Service     = @('Domain')
            $tag.DependsOn   = @('DHCP', 'Gateway')
        }

        It 'output contains #HVTag: sentinel' {
            $result = ConvertTo-HyperVVMTagJson -Tag $tag
            $result | Should -Match '#HVTag:'
        }

        It 'output contains Environment value' {
            $result = ConvertTo-HyperVVMTagJson -Tag $tag
            $result | Should -Match 'Lab'
        }

        It 'preserves existing Notes content above sentinel' {
            $result = ConvertTo-HyperVVMTagJson -Tag $tag -ExistingNotes 'My existing note.'
            $result | Should -Match 'My existing note\.'
            $result | Should -Match '#HVTag:'
        }

        It 'replaces existing #HVTag: line when ExistingNotes already has one' {
            $oldNotes = "Old notes.`n`n#HVTag:{`"Environment`":[`"Old`"],`"Service`":[],`"DependsOn`":[]}"
            $result = ConvertTo-HyperVVMTagJson -Tag $tag -ExistingNotes $oldNotes
            ($result -split '#HVTag:').Count | Should -Be 2
            $result | Should -Match 'Lab'
            $result | Should -Not -Match '"Old"'
        }

        It 'round-trips through ConvertFrom-HyperVVMTag' {
            $output = ConvertTo-HyperVVMTagJson -Tag $tag
            $parsed = ConvertFrom-HyperVVMTag -Notes $output
            $parsed.Environment | Should -Be @('Lab')
            $parsed.DependsOn   | Should -Be @('DHCP', 'Gateway')
        }
    }
}
