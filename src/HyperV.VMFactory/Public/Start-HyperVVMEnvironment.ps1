function Start-HyperVVMEnvironment {
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
        [switch] $WaitForHeartbeat
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByComputerName') {
        $Topology = Get-HyperVVMTopology -ComputerName $ComputerName
    }

    $env = $Topology.Environment | Where-Object Name -eq $EnvironmentName
    if (-not $env) { throw "Environment '$EnvironmentName' not found in topology." }

    $overall = [PSCustomObject]@{ Success = @(); Failed = $null }

    foreach ($svcName in $env.StartOrder) {
        $svcResult = Start-HyperVVMService -ServiceName $svcName -EnvironmentName $EnvironmentName `
            -Topology $Topology -WaitForHeartbeat:$WaitForHeartbeat
        $overall.Success += $svcResult.Success
        if ($svcResult.Failed) {
            $overall.Failed = $svcResult.Failed
            return $overall
        }
    }

    return $overall
}
