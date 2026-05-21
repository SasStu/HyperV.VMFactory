@{
    RootModule        = 'HyperV.VMFactory.psm1'
    ModuleVersion     = '2.1.0'
    GUID              = 'a09f6edf-2c95-458d-8755-1b5d5e85f17b'
    Author            = 'Sascha Stumpler'
    CompanyName       = 'Community'
    Copyright         = '(c) 2026 Sascha Stumpler. All rights reserved.'
    Description       = 'Create and configure Hyper-V virtual machines with tag-based service and environment lifecycle management. Supports dependency-ordered start/stop, remote execution, bulk creation, differencing disks, TPM, nested virtualization, and more.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'New-HyperVVM'
        'New-HyperVVMConfiguration'
        'Set-HyperVVMTag'
        'Get-HyperVVMTag'
        'Get-HyperVVMTopology'
        'Start-HyperVVMService'
        'Stop-HyperVVMService'
        'Start-HyperVVMEnvironment'
        'Stop-HyperVVMEnvironment'
        'Get-HyperVVMMermaidDiagram'
        'Update-HyperVVMTag'
    )
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
    PrivateData        = @{
        PSData = @{
            Tags         = @('Hyper-V', 'VM', 'VirtualMachine', 'HyperV', 'Provisioning', 'Windows', 'Lifecycle', 'Tag', 'Service', 'Environment')
            LicenseUri   = 'https://github.com/SasStu/HyperV.VMFactory/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/SasStu/HyperV.VMFactory'
            ReleaseNotes = 'v2.1.0: Added Get-HyperVVMMermaidDiagram for Mermaid topology diagrams.'
        }
    }
}
