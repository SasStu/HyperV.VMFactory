using module '..\..\src\HyperV.VMFactory\HyperV.VMFactory.psm1'

BeforeAll {
    Mock -ModuleName HyperV.VMFactory Assert-HyperVPrerequisite {}
    Mock -ModuleName HyperV.VMFactory Get-VM {
        @(
            [PSCustomObject]@{ Name = 'vm-db-01';  Notes = '#HVTag:{"Environment":["Production"],"Service":["database"],"DependsOn":[]}' },
            [PSCustomObject]@{ Name = 'vm-api-01'; Notes = '#HVTag:{"Environment":["Production"],"Service":["api-service"],"DependsOn":["database"]}' },
            [PSCustomObject]@{ Name = 'vm-stg-01'; Notes = '#HVTag:{"Environment":["Staging"],"Service":["database"],"DependsOn":[]}' }
        )
    }

    function New-TestTopology {
        $vm1 = [PSCustomObject]@{ Name = 'vm-db-01' }
        $vm2 = [PSCustomObject]@{ Name = 'vm-api-01' }

        $svcDb             = [HyperVVMService]::new()
        $svcDb.Name        = 'database'
        $svcDb.Environment = 'Production'
        $svcDb.DependsOn   = @()
        $svcDb.VM          = @($vm1)

        $svcApi             = [HyperVVMService]::new()
        $svcApi.Name        = 'api-service'
        $svcApi.Environment = 'Production'
        $svcApi.DependsOn   = @('database')
        $svcApi.VM          = @($vm2)

        $env            = [HyperVVMEnvironment]::new()
        $env.Name       = 'Production'
        $env.Service    = @($svcDb, $svcApi)
        $env.StartOrder = @('database', 'api-service')

        $topology              = [HyperVVMTopology]::new()
        $topology.ComputerName = 'localhost'
        $topology.Environment  = @($env)
        $topology
    }
}

Describe 'Get-HyperVVMMermaidDiagram' {

    Context 'diagram structure - pipeline input' {
        It 'returns a string' {
            $result = New-TestTopology | Get-HyperVVMMermaidDiagram
            $result | Should -BeOfType [string]
        }

        It 'starts with graph TD' {
            $result = New-TestTopology | Get-HyperVVMMermaidDiagram
            $result | Should -Match '^graph TD'
        }

        It 'contains subgraph for each environment' {
            $result = New-TestTopology | Get-HyperVVMMermaidDiagram
            $result | Should -Match 'subgraph ENV_Production\["Production"\]'
        }

        It 'contains scoped cylinder node for each service' {
            $result = New-TestTopology | Get-HyperVVMMermaidDiagram
            $result | Should -Match 'ENV_Production_SVC_database\[\('
        }

        It 'contains scoped rectangle node for each VM' {
            $result = New-TestTopology | Get-HyperVVMMermaidDiagram
            $result | Should -Match 'ENV_Production_VM_vm_db_01\["vm-db-01"\]'
        }

        It 'contains dotted membership edge from VM to its service' {
            $result = New-TestTopology | Get-HyperVVMMermaidDiagram
            $result | Should -Match 'ENV_Production_VM_vm_db_01.*-\..*>.*ENV_Production_SVC_database'
        }

        It 'contains solid dependency edge from dependency to dependent service' {
            $result = New-TestTopology | Get-HyperVVMMermaidDiagram
            $result | Should -Match 'ENV_Production_SVC_database.*-->.*ENV_Production_SVC_api_service'
        }

        It 'sanitises spaces and special chars in node IDs' {
            $vm = [PSCustomObject]@{ Name = 'my vm 01' }

            $svc             = [HyperVVMService]::new()
            $svc.Name        = 'my service'
            $svc.Environment = 'my env'
            $svc.DependsOn   = @()
            $svc.VM          = @($vm)

            $env            = [HyperVVMEnvironment]::new()
            $env.Name       = 'my env'
            $env.Service    = @($svc)
            $env.StartOrder = @('my service')

            $t              = [HyperVVMTopology]::new()
            $t.ComputerName = 'localhost'
            $t.Environment  = @($env)

            $result = $t | Get-HyperVVMMermaidDiagram
            $result | Should -Match 'ENV_my_env_SVC_my_service'
            $result | Should -Match 'ENV_my_env_VM_my_vm_01'
        }

        It 'returns graph TD with no environments when topology is empty' {
            $t              = [HyperVVMTopology]::new()
            $t.ComputerName = 'localhost'
            $t.Environment  = @()

            $result = $t | Get-HyperVVMMermaidDiagram
            $result | Should -Be 'graph TD'
        }
    }

    Context '-ComputerName fetches topology internally' {
        It 'uses Get-VM when ComputerName is provided' {
            $result = Get-HyperVVMMermaidDiagram -ComputerName 'localhost'
            $result | Should -Match 'ENV_Production'
            $result | Should -Match 'ENV_Staging'
        }
    }

    Context '-Environment filter' {
        It 'includes only the specified environment' {
            $result = Get-HyperVVMMermaidDiagram -ComputerName 'localhost' -Environment 'Production'
            $result | Should -Match 'ENV_Production'
            $result | Should -Not -Match 'ENV_Staging'
        }

        It 'drops environments not in the filter' {
            $result = Get-HyperVVMMermaidDiagram -ComputerName 'localhost' -Environment 'Staging'
            $result | Should -Not -Match 'ENV_Production'
        }
    }

    Context '-Service filter' {
        It 'includes only the specified service' {
            $result = Get-HyperVVMMermaidDiagram -ComputerName 'localhost' -Service 'database'
            $result | Should -Match 'SVC_database'
            $result | Should -Not -Match 'SVC_api_service'
        }

        It 'drops environments that become empty after service filtering' {
            Mock -ModuleName HyperV.VMFactory Get-VM {
                @(
                    [PSCustomObject]@{ Name = 'vm-web-01'; Notes = '#HVTag:{"Environment":["Production"],"Service":["web"],"DependsOn":[]}' },
                    [PSCustomObject]@{ Name = 'vm-db-01';  Notes = '#HVTag:{"Environment":["Staging"],"Service":["database"],"DependsOn":[]}' }
                )
            }
            $result = Get-HyperVVMMermaidDiagram -ComputerName 'localhost' -Service 'web'
            $result | Should -Match 'ENV_Production'
            $result | Should -Not -Match 'ENV_Staging'
        }
    }

    Context '-OutputPath' {
        It 'writes the diagram to the specified file' {
            $tmp = [System.IO.Path]::GetTempFileName()
            try {
                $result = New-TestTopology | Get-HyperVVMMermaidDiagram -OutputPath $tmp
                $content = Get-Content -Path $tmp -Raw
                $content.Trim() | Should -Be $result.Trim()
            } finally {
                Remove-Item $tmp -ErrorAction SilentlyContinue
            }
        }

        It 'still returns the diagram string to the pipeline when OutputPath is set' {
            $tmp = [System.IO.Path]::GetTempFileName()
            try {
                $result = New-TestTopology | Get-HyperVVMMermaidDiagram -OutputPath $tmp
                $result | Should -Match '^graph TD'
            } finally {
                Remove-Item $tmp -ErrorAction SilentlyContinue
            }
        }
    }
}
