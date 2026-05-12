function Update-HyperVVMTag {
    <#
    .SYNOPSIS
        Migrates legacy XML-format PSHVTag entries to the current JSON-based HVTag format.
    .DESCRIPTION
        Reads <Env>, <Service>, and <DependsOn> XML tags from a VM's Notes field and rewrites
        them as a #HVTag:{JSON} line understood by Get-HyperVVMTag and Set-HyperVVMTag.

        VMs that already carry a new-format tag are skipped unless -Force is specified.
    .EXAMPLE
        Get-VM | Update-HyperVVMTag -WhatIf
    .EXAMPLE
        Update-HyperVVMTag -VMName 'BeyondInsight-01' -Force
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory, ValueFromPipelineByPropertyName)]
        [string[]] $VMName,

        [Parameter(ParameterSetName = 'ByVM', Mandatory, ValueFromPipeline)]
        [object[]] $VM,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost',

        [Parameter()]
        [switch] $Force
    )
    Begin {
        Assert-HyperVPrerequisite -ComputerName $ComputerName
    }
    Process {
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $VM = foreach ($name in $VMName) {
                $found = Get-VM -Name $name -ComputerName $ComputerName -ErrorAction SilentlyContinue
                if (-not $found) {
                    Write-Error "VM '$name' not found on '$ComputerName'."
                    continue
                }
                $found
            }
        }
        foreach ($vmObj in $VM) {
            $legacyTag = ConvertFrom-LegacyHVTag -Notes $vmObj.Notes
            if (-not $legacyTag) {
                Write-Verbose "VM '$($vmObj.Name)' has no legacy PSHVTag - skipping."
                continue
            }
            $existingTag = ConvertFrom-HyperVVMTag -Notes $vmObj.Notes
            if ($existingTag -and -not $Force) {
                Write-Warning "VM '$($vmObj.Name)' already has a new-format HVTag. Use -Force to overwrite."
                continue
            }
            $strippedNotes = $vmObj.Notes `
                -replace '<Env>[^<]*</Env>',         '' `
                -replace '<Service>[^<]*</Service>',   '' `
                -replace '<DependsOn>[^<]*</DependsOn>', ''
            $strippedNotes = $strippedNotes.Trim()
            $newNotes = ConvertTo-HyperVVMTagJson -Tag $legacyTag -ExistingNotes $strippedNotes
            if ($PSCmdlet.ShouldProcess($vmObj.Name, 'Migrate legacy PSHVTag to new HVTag format')) {
                Set-VM -Name $vmObj.Name -ComputerName $ComputerName -Notes $newNotes
            }
        }
    }
}
