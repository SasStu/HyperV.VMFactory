using module '..\..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'

Describe 'Invoke-TopologicalSort' {
    InModuleScope HyperV.VMFactory {
        It 'returns single node with no dependencies' {
            $result = Invoke-TopologicalSort -EdgeList @{ A = @() }
            $result | Should -Be @('A')
        }

        It 'puts dependency before dependent (linear chain)' {
            $result = Invoke-TopologicalSort -EdgeList @{ A = @(); B = @('A') }
            $result.IndexOf('A') | Should -BeLessThan $result.IndexOf('B')
        }

        It 'resolves diamond dependency correctly' {
            $edgeList = @{ A = @(); B = @('A'); C = @('A'); D = @('B', 'C') }
            $result = Invoke-TopologicalSort -EdgeList $edgeList
            $result.IndexOf('A') | Should -BeLessThan $result.IndexOf('B')
            $result.IndexOf('A') | Should -BeLessThan $result.IndexOf('C')
            $result.IndexOf('B') | Should -BeLessThan $result.IndexOf('D')
            $result.IndexOf('C') | Should -BeLessThan $result.IndexOf('D')
        }

        It 'throws on cycle' {
            { Invoke-TopologicalSort -EdgeList @{ A = @('B'); B = @('A') } } | Should -Throw '*cycle*'
        }

        It 'includes nodes only referenced as dependencies' {
            $result = Invoke-TopologicalSort -EdgeList @{ Domain = @('Gateway') }
            $result | Should -Contain 'Gateway'
            $result | Should -Contain 'Domain'
            $result.IndexOf('Gateway') | Should -BeLessThan $result.IndexOf('Domain')
        }
    }
}
