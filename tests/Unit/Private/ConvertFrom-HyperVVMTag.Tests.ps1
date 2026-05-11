using module '..\..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'

Describe 'ConvertFrom-HyperVVMTag' {
    InModuleScope HyperV.VMFactory {
        It 'returns null when Notes is empty' {
            ConvertFrom-HyperVVMTag -Notes '' | Should -BeNullOrEmpty
        }

        It 'returns null when Notes has no #HVTag: sentinel' {
            ConvertFrom-HyperVVMTag -Notes 'Just a note.' | Should -BeNullOrEmpty
        }

        It 'parses Environment correctly' {
            $notes = '#HVTag:{"Environment":["Lab"],"Service":["Domain"],"DependsOn":["DHCP"]}'
            $result = ConvertFrom-HyperVVMTag -Notes $notes
            $result.Environment | Should -Be @('Lab')
        }

        It 'parses multi-value DependsOn correctly' {
            $notes = '#HVTag:{"Environment":["Lab"],"Service":["DC"],"DependsOn":["DHCP","Gateway"]}'
            $result = ConvertFrom-HyperVVMTag -Notes $notes
            $result.DependsOn | Should -Be @('DHCP', 'Gateway')
        }

        It 'returns HyperVVMTag type' {
            $notes = '#HVTag:{"Environment":["Lab"],"Service":["DC"],"DependsOn":[]}'
            $result = ConvertFrom-HyperVVMTag -Notes $notes
            $result | Should -BeOfType 'HyperVVMTag'
        }

        It 'finds #HVTag: line when Notes has content above it' {
            $notes = "My VM notes here.`n`n#HVTag:{`"Environment`":[`"Prod`"],`"Service`":[`"Web`"],`"DependsOn`":[]}"
            $result = ConvertFrom-HyperVVMTag -Notes $notes
            $result.Environment | Should -Be @('Prod')
        }
    }
}
