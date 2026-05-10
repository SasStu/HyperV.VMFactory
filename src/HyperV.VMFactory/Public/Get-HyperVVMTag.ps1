function Get-HyperVVMTag {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([HyperVVMTag])]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory, ValueFromPipelineByPropertyName)]
        [string[]] $VMName,

        [Parameter(ParameterSetName = 'ByVM', Mandatory, ValueFromPipeline)]
        [object[]] $VM,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost'
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
            ConvertFrom-HyperVVMTag -Notes $vmObj.Notes
        }
    }
}
