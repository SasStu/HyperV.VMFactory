function Stop-HyperVVMEnvironment {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByTopology')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $EnvironmentName,

        [Parameter(ParameterSetName = 'ByTopology', Mandatory)]
        [HyperVVMTopology] $Topology,

        [Parameter(ParameterSetName = 'ByComputerName')]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost',

        [Parameter()]
        [switch] $Force
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByComputerName') {
        $Topology = Get-HyperVVMTopology -ComputerName $ComputerName
    }

    $env = $Topology.Environment | Where-Object Name -eq $EnvironmentName
    if (-not $env) { throw "Environment '$EnvironmentName' not found in topology." }

    $overall = [PSCustomObject]@{ Success = @(); Failed = $null }

    # Stop in reverse of StartOrder
    $reverseOrder = [string[]]($env.StartOrder | Select-Object)
    [array]::Reverse($reverseOrder)

    foreach ($svcName in $reverseOrder) {
        if (-not $PSCmdlet.ShouldProcess("$EnvironmentName/$svcName", 'Stop service')) { continue }
        $svcResult = Stop-HyperVVMService -ServiceName $svcName -EnvironmentName $EnvironmentName `
            -Topology $Topology -Force:$Force
        $overall.Success += $svcResult.Success
        if ($svcResult.Failed) {
            $overall.Failed = $svcResult.Failed
            return $overall
        }
    }

    return $overall
}
