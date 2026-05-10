BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'
    Import-Module $modulePath -Force

    Mock -ModuleName HyperV.VMFactory Assert-HyperVPrerequisite {}
    Mock -ModuleName HyperV.VMFactory Get-VM {
        @(
            [PSCustomObject]@{ Name = 'DC01';   Notes = '#HVTag:{"Environment":["Lab"],"Service":["Domain"],"DependsOn":["DHCP"]}' },
            [PSCustomObject]@{ Name = 'DHCP01'; Notes = '#HVTag:{"Environment":["Lab"],"Service":["DHCP"],"DependsOn":[]}' },
            [PSCustomObject]@{ Name = 'Web01';  Notes = 'No tag.' }
        )
    }
}

Describe 'Get-HyperVVMTopology' {
    It 'returns a HyperVVMTopology object' {
        $result = Get-HyperVVMTopology -ComputerName 'localhost'
        $result | Should -BeOfType 'HyperVVMTopology'
    }

    It 'ignores untagged VMs' {
        $result = Get-HyperVVMTopology -ComputerName 'localhost'
        $allVMNames = $result.Environment.Service.VM.Name
        $allVMNames | Should -Not -Contain 'Web01'
    }

    It 'builds the correct environment' {
        $result = Get-HyperVVMTopology -ComputerName 'localhost'
        $result.Environment.Name | Should -Contain 'Lab'
    }

    It 'puts DHCP before Domain in StartOrder' {
        $result = Get-HyperVVMTopology -ComputerName 'localhost'
        $lab = $result.Environment | Where-Object Name -eq 'Lab'
        $lab.StartOrder.IndexOf('DHCP') | Should -BeLessThan $lab.StartOrder.IndexOf('Domain')
    }

    It 'sets ComputerName on the topology' {
        $result = Get-HyperVVMTopology -ComputerName 'myhost'
        $result.ComputerName | Should -Be 'myhost'
    }
}
