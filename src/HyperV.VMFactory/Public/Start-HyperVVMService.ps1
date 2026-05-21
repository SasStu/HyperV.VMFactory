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
        [bool] $WaitForVM = $true,

        [Parameter()]
        [ValidateSet('IPAddress', 'Heartbeat')]
        [string] $VMWaitFor = 'IPAddress',

        [Parameter()]
        [int] $WaitTimeoutSeconds = 120
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByComputerName') {
        $Topology = Get-HyperVVMTopology -ComputerName $ComputerName
    }
    $effectiveComputerName = $Topology.ComputerName

    $result = [PSCustomObject]@{ Success = @(); Failed = $null }

    $vmEnv = $Topology.Environment | Where-Object Name -eq $EnvironmentName
    if (-not $vmEnv) { throw "Environment '$EnvironmentName' not found in topology." }

    $service = $vmEnv.Service | Where-Object Name -eq $ServiceName
    if (-not $service) { throw "Service '$ServiceName' not found in environment '$EnvironmentName'." }

    if ($Recurse) {
        foreach ($dep in $service.DependsOn) {
            $depSvc = $vmEnv.Service | Where-Object Name -eq $dep
            if (-not $depSvc) {
                Write-Warning "Service '$ServiceName' has dependency '$dep' which was not found in environment '$EnvironmentName'. Ensure the VM is tagged correctly or run Update-HyperVVMTag."
                continue
            }
            $depParams = @{
                ServiceName        = $dep
                EnvironmentName    = $EnvironmentName
                Topology           = $Topology
                Recurse            = $true
                WaitForVM          = $WaitForVM
                VMWaitFor          = $VMWaitFor
                WaitTimeoutSeconds = $WaitTimeoutSeconds
            }
            $depResult = Start-HyperVVMService @depParams
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
                Start-VM -Name $vmObj.Name -ComputerName $effectiveComputerName
                if ($WaitForVM) {
                    Wait-VM -Name $vmObj.Name -ComputerName $effectiveComputerName -For $VMWaitFor -Timeout $WaitTimeoutSeconds
                }
                $result.Success += $vmObj.Name
            } catch {
                $result.Failed = [PSCustomObject]@{ VMName = $vmObj.Name; Error = $_.ToString() }
                return $result
            }
        }
    }

    return $result
}
