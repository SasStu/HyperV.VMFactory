function Set-HyperVVMTag {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory, ValueFromPipelineByPropertyName)]
        [string[]] $VMName,

        [Parameter(ParameterSetName = 'ByVM', Mandatory, ValueFromPipeline)]
        [object[]] $VM,

        [Parameter()]
        [string[]] $Environment = @(),

        [Parameter()]
        [string[]] $Service = @(),

        [Parameter()]
        [string[]] $DependsOn = @(),

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
            $existingTag = ConvertFrom-HyperVVMTag -Notes $vmObj.Notes
            if ($existingTag -and -not $Force) {
                Write-Warning "VM '$($vmObj.Name)' already has a tag. Use -Force to overwrite."
                continue
            }
            $tag             = [HyperVVMTag]::new()
            $tag.Environment   = @($Environment | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $tag.Service       = @($Service     | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $tag.DependsOn = @($DependsOn | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $newNotes = ConvertTo-HyperVVMTagJson -Tag $tag -ExistingNotes $vmObj.Notes
            if ($PSCmdlet.ShouldProcess($vmObj.Name, 'Set VM tag')) {
                Set-VM -Name $vmObj.Name -ComputerName $ComputerName -Notes $newNotes
            }
        }
    }
}
