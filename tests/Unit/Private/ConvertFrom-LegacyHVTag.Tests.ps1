using module '..\..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'

Describe 'ConvertFrom-LegacyHVTag' {
    InModuleScope HyperV.VMFactory {
        Context 'No legacy tag present' {
            It 'Should return null for empty notes' {
                ConvertFrom-LegacyHVTag -Notes '' | Should -BeNullOrEmpty
            }

            It 'Should return null for notes with no XML tags' {
                ConvertFrom-LegacyHVTag -Notes 'Just some free text.' | Should -BeNullOrEmpty
            }

            It 'Should return null for new-format HVTag notes' {
                $notes = '#HVTag:{"Environment":["PI-LAB"],"Service":["BeyondInsight"],"DependsOn":["Domain"]}'
                ConvertFrom-LegacyHVTag -Notes $notes | Should -BeNullOrEmpty
            }
        }

        Context 'Single-value legacy tags' {
            It 'Should parse Env, Service, and DependsOn' {
                $notes = '<Env>PI-LAB</Env><Service>BeyondInsight</Service><DependsOn>Domain</DependsOn>'
                $result = ConvertFrom-LegacyHVTag -Notes $notes
                $result | Should -Not -BeNullOrEmpty
                $result.Environment | Should -Be @('PI-LAB')
                $result.Service     | Should -Be @('BeyondInsight')
                $result.DependsOn   | Should -Be @('Domain')
            }

            It 'Should parse tags even when surrounded by free text' {
                $notes = "Some description`n<Env>Production</Env><Service>WebApp</Service><DependsOn>SQL</DependsOn>`nMore text"
                $result = ConvertFrom-LegacyHVTag -Notes $notes
                $result.Environment | Should -Be @('Production')
                $result.Service     | Should -Be @('WebApp')
                $result.DependsOn   | Should -Be @('SQL')
            }
        }

        Context 'Multi-value legacy tags' {
            It 'Should collect multiple Env tags into an array' {
                $notes = '<Env>PI-LAB</Env><Env>Staging</Env><Service>WebApp</Service><DependsOn>Domain</DependsOn>'
                $result = ConvertFrom-LegacyHVTag -Notes $notes
                $result.Environment | Should -Be @('PI-LAB', 'Staging')
            }
        }

        Context 'Partial tags' {
            It 'Should return a tag object when only some fields are present' {
                $result = ConvertFrom-LegacyHVTag -Notes '<Env>PI-LAB</Env>'
                $result | Should -Not -BeNullOrEmpty
                $result.Environment | Should -Be @('PI-LAB')
                $result.Service     | Should -BeNullOrEmpty
                $result.DependsOn   | Should -BeNullOrEmpty
            }
        }
    }
}
