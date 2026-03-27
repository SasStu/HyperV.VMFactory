function Set-VMConfiguration {
    <#
    .SYNOPSIS
        Applies post-creation configuration to a Hyper-V VM.

    .DESCRIPTION
        Configures processor count, video resolution, integration services, nested
        virtualization, TPM, guest services, automatic start/stop actions, and disables
        automatic checkpoints on an existing VM.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Object]
        $VM,

        [Parameter()]
        [System.Int32]
        $ProcessorCount = 2,

        [Parameter()]
        [System.Int64]
        $HorizontalResolution = 1920,

        [Parameter()]
        [System.Int64]
        $VerticalResolution = 1080,

        [Parameter()]
        [System.Boolean]
        $NestedVirtualization = $true,

        [Parameter()]
        [System.Boolean]
        $TPM = $true,

        [Parameter()]
        [System.Boolean]
        $GuestServices = $true,

        [Parameter()]
        [ValidateSet('Nothing', 'StartIfRunning', 'Start')]
        [System.String]
        $AutomaticStartAction = 'Nothing',

        [Parameter()]
        [ValidateSet('TurnOff', 'Save', 'ShutDown')]
        [System.String]
        $AutomaticStopAction = 'ShutDown'
    )

    $vmName = $VM.VMName

    Write-Verbose "Configuring VM '$vmName': ProcessorCount=$ProcessorCount"
    Set-VM -VMName $vmName -ProcessorCount $ProcessorCount `
        -AutomaticCheckpointsEnabled:$false `
        -AutomaticStartAction $AutomaticStartAction `
        -AutomaticStopAction $AutomaticStopAction

    Write-Verbose "Setting video resolution to ${HorizontalResolution}x${VerticalResolution}."
    Set-VMVideo -VMName $vmName -ResolutionType Single `
        -HorizontalResolution $HorizontalResolution `
        -VerticalResolution $VerticalResolution

    if ($GuestServices) {
        Write-Verbose "Enabling Guest Service Interface integration service."
        Enable-VMIntegrationService -VMName $vmName -Name 'Guest Service Interface'
    }

    if ($NestedVirtualization) {
        Write-Verbose "Enabling nested virtualization for VM '$vmName'."
        Set-VMProcessor -VMName $vmName -ExposeVirtualizationExtensions:$true
    }

    if ($TPM) {
        Write-Verbose "Enabling vTPM for VM '$vmName'."
        Set-VMKeyProtector -VMName $vmName -NewLocalKeyProtector
        Enable-VMTPM -VMName $vmName
    }
}
