function Assert-HyperVPrerequisite {
    <#
    .SYNOPSIS
        Validates that Hyper-V prerequisites are met.

    .DESCRIPTION
        Checks that the Hyper-V PowerShell module is available and that the current
        session is running with elevated (Administrator) privileges.

    .PARAMETER ComputerName
        Optional remote computer name. When specified, checks are described in error
        messages but not performed remotely (the remote session handles availability).
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [System.String]
        $ComputerName
    )

    $target = if ($ComputerName) { $ComputerName } else { 'localhost' }

    if (-not $ComputerName) {
        if (-not (Get-Module -ListAvailable -Name 'Hyper-V')) {
            $errorMessage = "The Hyper-V PowerShell module is not available on $target. " +
                'Install the Hyper-V feature including management tools.'
            throw $errorMessage
        }

        $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        if ((-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) -and (-not ($currentPrincipal.IsInRole('Hyper-V Administrators')))) {
            throw 'This function requires elevated (Administrator) privileges. Please run PowerShell as Administrator or as a member of the Hyper-V Administrators group.'
        }
    }

    Write-Verbose "Hyper-V prerequisites validated for target '$target'."
}
