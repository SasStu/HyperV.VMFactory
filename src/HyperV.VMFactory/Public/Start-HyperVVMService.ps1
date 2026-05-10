function Start-HyperVVMService {
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
        [switch] $WaitForHeartbeat
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
        foreach ($dep in $service.DependsOn) {
            $depSvc = $env.Service | Where-Object Name -eq $dep
            if (-not $depSvc) {
                Write-Verbose "Dependency '$dep' not found in topology, skipping."
                continue
            }
            $depResult = Start-HyperVVMService -ServiceName $dep -EnvironmentName $EnvironmentName `
                -Topology $Topology -Recurse -WaitForHeartbeat:$WaitForHeartbeat
            $result.Success += $depResult.Success
            if ($depResult.Failed) {
                $result.Failed = $depResult.Failed
                return $result
            }
        }
    }

    foreach ($vmObj in $service.VM) {
        if ($vmObj.State -eq 'Running') {
            Write-Verbose "VM '$($vmObj.Name)' is already running, skipping."
            continue
        }
        if ($PSCmdlet.ShouldProcess($vmObj.Name, 'Start VM')) {
            try {
                Start-VM -VM $vmObj
                if ($WaitForHeartbeat) { Wait-VM -VM $vmObj -For Heartbeat }
                $result.Success += $vmObj.Name
            } catch {
                $result.Failed = [PSCustomObject]@{ VMName = $vmObj.Name; Error = $_.ToString() }
                return $result
            }
        }
    }

    return $result
}
