function Wait-HyperVVMOff {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $ComputerName,

        [Parameter(Mandatory)]
        [int] $TimeoutSeconds
    )
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ((Get-VM -Name $Name -ComputerName $ComputerName -ErrorAction SilentlyContinue).State -ne 'Off') {
        if ([datetime]::UtcNow -ge $deadline) {
            throw "VM '$Name' did not reach Off state within $TimeoutSeconds seconds."
        }
        Start-Sleep -Seconds 3
    }
}
