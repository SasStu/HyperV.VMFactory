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
        [switch] $Force,

        [Parameter()]
        [bool] $WaitForVM = $true,

        [Parameter()]
        [int] $WaitTimeoutSeconds = 120,

        # Tracks services stopped in this call-chain so the dependency-safety check ignores them.
        [Parameter(DontShow)]
        [System.Collections.Generic.HashSet[string]] $StoppedServiceNames,

        # False when recursing upward through dependents; prevents cascading down into their own DependsOn chains.
        [Parameter(DontShow)]
        [bool] $StopDependencies = $true
    )

    if (-not $StoppedServiceNames) {
        $StoppedServiceNames = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase)
    }

    if ($PSCmdlet.ParameterSetName -eq 'ByComputerName') {
        $Topology = Get-HyperVVMTopology -ComputerName $ComputerName
    }
    $effectiveComputerName = $Topology.ComputerName

    $result = [PSCustomObject]@{ Success = @(); Failed = $null }

    $vmEnv = $Topology.Environment | Where-Object Name -eq $EnvironmentName
    if (-not $vmEnv) { throw "Environment '$EnvironmentName' not found in topology." }

    $service = $vmEnv.Service | Where-Object Name -eq $ServiceName
    if (-not $service) { throw "Service '$ServiceName' not found in environment '$EnvironmentName'." }

    # Step 1: stop dependents first (services that DependsOn this one and still have running VMs)
    if ($Recurse) {
        $dependents = $vmEnv.Service | Where-Object {
            $_.DependsOn -contains $ServiceName -and
            -not $StoppedServiceNames.Contains($_.Name) -and
            ($_.VM | Where-Object { $_.State -ne 'Off' })
        }
        foreach ($dep in $dependents) {
            $depParams = @{
                ServiceName         = $dep.Name
                EnvironmentName     = $EnvironmentName
                Topology            = $Topology
                Recurse             = $true
                Force               = $Force
                WaitForVM           = $WaitForVM
                WaitTimeoutSeconds  = $WaitTimeoutSeconds
                StoppedServiceNames = $StoppedServiceNames
                StopDependencies    = $false
            }
            $depResult = Stop-HyperVVMService @depParams
            $result.Success += $depResult.Success
            if ($depResult.Failed) {
                $result.Failed = $depResult.Failed
                return $result
            }
        }
    }

    # Step 2: stop this service's VMs
    foreach ($vmObj in $service.VM) {
        if ($vmObj.State -eq 'Off') {
            Write-Verbose "VM '$($vmObj.Name)' is already stopped, skipping."
            continue
        }
        if ($PSCmdlet.ShouldProcess($vmObj.Name, 'Stop VM')) {
            try {
                $stopSplat = @{ Name = $vmObj.Name; ComputerName = $effectiveComputerName }
                if ($Force) { $stopSplat.Force = $true }
                Stop-VM @stopSplat
                if ($WaitForVM) {
                    Wait-HyperVVMOff -Name $vmObj.Name -ComputerName $effectiveComputerName -TimeoutSeconds $WaitTimeoutSeconds
                }
                $result.Success += $vmObj.Name
            } catch {
                $result.Failed = [PSCustomObject]@{ VMName = $vmObj.Name; Error = $_.ToString() }
                return $result
            }
        }
    }
    $StoppedServiceNames.Add($ServiceName) | Out-Null

    # Step 3: with -Recurse, stop dependencies (this service's DependsOn) if no other running service still needs them
    if ($Recurse -and $StopDependencies) {
        foreach ($depName in $service.DependsOn) {
            if ($StoppedServiceNames.Contains($depName)) { continue }

            $otherRunningDependents = $vmEnv.Service | Where-Object {
                $_.Name -ne $ServiceName -and
                -not $StoppedServiceNames.Contains($_.Name) -and
                $_.DependsOn -contains $depName -and
                ($_.VM | Where-Object { $_.State -ne 'Off' })
            }

            if ($otherRunningDependents) {
                Write-Verbose "Skipping '$depName': still needed by $($otherRunningDependents.Name -join ', ')"
                continue
            }

            $depParams = @{
                ServiceName         = $depName
                EnvironmentName     = $EnvironmentName
                Topology            = $Topology
                Recurse             = $true
                Force               = $Force
                WaitForVM           = $WaitForVM
                WaitTimeoutSeconds  = $WaitTimeoutSeconds
                StoppedServiceNames = $StoppedServiceNames
                StopDependencies    = $true
            }
            $depResult = Stop-HyperVVMService @depParams
            $result.Success += $depResult.Success
            if ($depResult.Failed) {
                $result.Failed = $depResult.Failed
                return $result
            }
        }
    }

    return $result
}
