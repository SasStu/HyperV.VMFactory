function New-HyperVVMConfiguration {
    <#
    .SYNOPSIS
        Creates a configuration object for New-HyperVVM.

    .DESCRIPTION
        Builds a typed configuration object that can be piped into New-HyperVVM to
        create one or more virtual machines. This enables bulk VM creation by building
        an array of configurations and piping them to New-HyperVVM.

    .PARAMETER VMName
        Name of the virtual machine to create.

    .PARAMETER Path
        Path to the folder where the VM files will be stored.

    .PARAMETER VMSwitch
        Name of the virtual switch to connect the VM to.

    .PARAMETER ParentDisk
        Path to a sysprepped parent disk for creating a differencing OS disk.
        When omitted, a new dynamic disk is created.

    .PARAMETER VMGeneration
        Generation of the VM. Valid values are 1 and 2. Defaults to 2.

    .PARAMETER VMProcessorCount
        Number of virtual processors to assign. Defaults to 2.

    .PARAMETER VMMemoryStartupBytes
        Startup memory in bytes. Defaults to 2GB.

    .PARAMETER OSDiskSizeBytes
        Size of the OS disk in bytes when no ParentDisk is specified. Defaults to 127GB.

    .PARAMETER DataDiskSizeBytes
        Size of the additional data disk in bytes. Defaults to 127GB.

    .PARAMETER AdditionalHDD
        When specified, creates a secondary data disk.

    .PARAMETER DisableNestedVirtualization
        When specified, nested virtualization is not enabled. Nested virtualization is enabled by default.

    .PARAMETER DisableTPM
        When specified, the virtual TPM is not enabled. TPM is enabled by default.

    .PARAMETER DisableGuestServices
        When specified, the Guest Service Interface integration service is not enabled.
        Guest Services are enabled by default.

    .PARAMETER PowerOnVM
        When specified, starts the VM after creation.

    .PARAMETER OpenConsole
        When specified, opens the VM console (vmconnect.exe) after creation.

    .PARAMETER HorizontalResolution
        Horizontal video resolution. Must be an even number. Defaults to 1920.

    .PARAMETER VerticalResolution
        Vertical video resolution. Must be an even number. Defaults to 1080.

    .PARAMETER AutomaticStartAction
        Action when the Hyper-V host starts. Defaults to 'Nothing'.

    .PARAMETER AutomaticStopAction
        Action when the Hyper-V host shuts down. Defaults to 'ShutDown'.

    .PARAMETER AutomaticCheckpointsEnabled
        When specified, enables automatic checkpoints. Disabled by default.

    .PARAMETER ISOPath
        Path to an ISO file to attach as a DVD drive for OS installation.

    .EXAMPLE
        $config = New-HyperVVMConfiguration -VMName 'WebServer01' -Path 'D:\VMs' -VMSwitch 'External'

        Creates a basic VM configuration.

    .EXAMPLE
        $configs = @(
            New-HyperVVMConfiguration -VMName 'DC01' -Path 'D:\VMs' -VMSwitch 'Internal'
            New-HyperVVMConfiguration -VMName 'DC02' -Path 'D:\VMs' -VMSwitch 'Internal' -AdditionalHDD
        )
        New-HyperVVM -Configuration $configs

        Creates multiple VM configurations and pipes them to New-HyperVVM for bulk creation.

    .OUTPUTS
        PSCustomObject with PSTypeName 'HyperV.VMFactory.Configuration'
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $VMName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $VMSwitch,

        [Parameter()]
        [System.String]
        $ParentDisk,

        [Parameter()]
        [ValidateSet(1, 2)]
        [System.Int32]
        $VMGeneration = 2,

        [Parameter()]
        [ValidateRange(1, 128)]
        [System.Int32]
        $VMProcessorCount = 2,

        [Parameter()]
        [System.Int64]
        $VMMemoryStartupBytes = 2GB,

        [Parameter()]
        [System.Int64]
        $OSDiskSizeBytes = 127GB,

        [Parameter()]
        [System.Int64]
        $DataDiskSizeBytes = 127GB,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $AdditionalHDD,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $DisableNestedVirtualization,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $DisableTPM,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $DisableGuestServices,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $PowerOnVM,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $OpenConsole,

        [Parameter()]
        [ValidateScript({
            if ($_ % 2) { throw 'HorizontalResolution must be an even number.' }
            $true
        })]
        [System.Int64]
        $HorizontalResolution = 1920,

        [Parameter()]
        [ValidateScript({
            if ($_ % 2) { throw 'VerticalResolution must be an even number.' }
            $true
        })]
        [System.Int64]
        $VerticalResolution = 1080,

        [Parameter()]
        [ValidateSet('Nothing', 'StartIfRunning', 'Start')]
        [System.String]
        $AutomaticStartAction = 'Nothing',

        [Parameter()]
        [ValidateSet('TurnOff', 'Save', 'ShutDown')]
        [System.String]
        $AutomaticStopAction = 'ShutDown',

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $AutomaticCheckpointsEnabled,

        [Parameter()]
        [System.String]
        $ISOPath
    )

    $config = [PSCustomObject]@{
        PSTypeName            = 'HyperV.VMFactory.Configuration'
        VMName                = $VMName
        Path                  = $Path
        VMSwitch              = $VMSwitch
        ParentDisk            = $ParentDisk
        VMGeneration          = $VMGeneration
        VMProcessorCount      = $VMProcessorCount
        VMMemoryStartupBytes  = $VMMemoryStartupBytes
        OSDiskSizeBytes       = $OSDiskSizeBytes
        DataDiskSizeBytes     = $DataDiskSizeBytes
        AdditionalHDD         = [bool]$AdditionalHDD
        NestedVirtualization  = -not $DisableNestedVirtualization
        TPM                   = -not $DisableTPM
        GuestServices         = -not $DisableGuestServices
        PowerOnVM             = [bool]$PowerOnVM
        OpenConsole           = [bool]$OpenConsole
        HorizontalResolution  = $HorizontalResolution
        VerticalResolution    = $VerticalResolution
        AutomaticStartAction        = $AutomaticStartAction
        AutomaticStopAction         = $AutomaticStopAction
        AutomaticCheckpointsEnabled = [bool]$AutomaticCheckpointsEnabled
        ISOPath               = $ISOPath
    }

    Write-Verbose "Created VM configuration for '$VMName'."
    return $config
}
