function Stop-HyperVVMService {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByTopology')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $ServiceName,

        [Parameter(Mandatory)]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName = 'ByTopology', Mandatory)]
        [HyperVVMTopology] $Topology,

        [Parameter(ParameterSetName = 'ByComputerName')]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost',

        [Parameter()]
        [switch] $Recurse,

        [Parameter()]
        [switch] $Force
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByComputerName') {
        $Topology = Get-HyperVVMTopology -ComputerName $ComputerName
    }

    $result = [PSCustomObject]@{ Success = @(); Failed = $null }

    $env = $Topology.Environment | Where-Object Name -eq $EnvironmentName
    if (-not $env) { throw "Environment '$EnvironmentName' not found in topology." }

    $service = $env.Service | Where-Object Name -eq $ServiceName
    if (-not $service) { throw "Service '$ServiceName' not found in environment '$EnvironmentName'." }

    if ($Recurse) {
        $dependents = $env.Service | Where-Object { $_.DependsOn -contains $ServiceName }
        foreach ($dep in $dependents) {
            $depResult = Stop-HyperVVMService -ServiceName $dep.Name -EnvironmentName $EnvironmentName `
                -Topology $Topology -Recurse -Force:$Force
            $result.Success += $depResult.Success
            if ($depResult.Failed) {
                $result.Failed = $depResult.Failed
                return $result
            }
        }
    }

    foreach ($vmObj in $service.VM) {
        if ($vmObj.State -eq 'Off') {
            Write-Verbose "VM '$($vmObj.Name)' is already stopped, skipping."
            continue
        }
        if ($PSCmdlet.ShouldProcess($vmObj.Name, 'Stop VM')) {
            try {
                if ($Force) { Stop-VM -Name $vmObj.Name -Force } else { Stop-VM -Name $vmObj.Name }
                $result.Success += $vmObj.Name
            } catch {
                $result.Failed = [PSCustomObject]@{ VMName = $vmObj.Name; Error = $_.ToString() }
                return $result
            }
        }
    }

    return $result
}
