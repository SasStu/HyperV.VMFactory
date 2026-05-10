function New-HyperVVM {
    <#
    .SYNOPSIS
        Creates one or more Hyper-V virtual machines.

    .DESCRIPTION
        Creates Hyper-V virtual machines with configurable OS disks (differencing or new),
        optional data disks, TPM, nested virtualization, and more. Supports remote execution
        via -ComputerName or -CimSession and bulk creation via pipeline input or arrays.

    .PARAMETER VMName
        Name(s) of the virtual machine(s) to create. Accepts an array of strings and
        pipeline input.

    .PARAMETER Path
        Path to the folder where VM files will be stored.

    .PARAMETER VMSwitch
        Name of the virtual switch to connect VMs to.

    .PARAMETER ParentDisk
        Path to a sysprepped parent disk for creating differencing OS disks.
        When omitted, a new dynamic disk is created.

    .PARAMETER VMGeneration
        Generation of the VM. Valid values are 1 and 2. Defaults to 2.

    .PARAMETER VMProcessorCount
        Number of virtual processors. Defaults to 2.

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
        For remote VMs (-ComputerName), a console window is opened for each target host.

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
        Path to an ISO file to attach for OS installation.

    .PARAMETER ComputerName
        Remote Hyper-V host(s) to create VMs on. Uses Invoke-Command for remote execution.

    .PARAMETER Credential
        Credential for authenticating to remote Hyper-V hosts.

    .PARAMETER CimSession
        Existing CIM session(s) to use for remote Hyper-V operations.

    .PARAMETER Configuration
        One or more HyperV.VMFactory.Configuration objects created by New-HyperVVMConfiguration.
        Accepts pipeline input.

    .EXAMPLE
        New-HyperVVM -VMName 'WebServer01' -Path 'D:\VMs' -VMSwitch 'External'

        Creates a single VM with default settings on the local host.

    .EXAMPLE
        'DC01', 'DC02', 'DC03' | New-HyperVVM -Path 'D:\VMs' -VMSwitch 'Internal'

        Creates three VMs via pipeline input with TPM and nested virtualization enabled (default).

    .EXAMPLE
        New-HyperVVM -VMName 'TestVM' -Path 'C:\VMs' -VMSwitch 'Default Switch' `
            -ParentDisk 'C:\Base\Win11.vhdx' -AdditionalHDD -PowerOnVM

        Creates a VM with a differencing disk from a parent image, adds a data disk,
        and starts the VM after creation.

    .EXAMPLE
        $configs = @(
            New-HyperVVMConfiguration -VMName 'App01' -Path 'D:\VMs' -VMSwitch 'External' -AdditionalHDD
            New-HyperVVMConfiguration -VMName 'App02' -Path 'D:\VMs' -VMSwitch 'External' -PowerOnVM
        )
        New-HyperVVM -Configuration $configs

        Creates multiple VMs with different configurations using the -Configuration parameter.

    .EXAMPLE
        New-HyperVVM -VMName 'RemoteVM' -Path 'D:\VMs' -VMSwitch 'External' `
            -ComputerName 'HyperVHost01' -Credential (Get-Credential)

        Creates a VM on a remote Hyper-V host.

    .EXAMPLE
        New-HyperVVM -VMName 'LabVM' -Path 'C:\VMs' -VMSwitch 'Internal' `
            -ISOPath 'C:\ISO\Ubuntu.iso' -VMGeneration 2 -DisableNestedVirtualization -DisableTPM

        Creates a VM configured to boot from an ISO with nested virtualization and TPM disabled.

    .EXAMPLE
        New-HyperVVM -VMName 'DevVM' -Path 'C:\VMs' -VMSwitch 'Default Switch' -PowerOnVM -OpenConsole

        Creates a VM, starts it, and immediately opens the VM console.

    .OUTPUTS
        Microsoft.HyperV.PowerShell.VirtualMachine
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByParameter')]
    [OutputType([System.Object])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline,
            ParameterSetName = 'ByParameter')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $VMName,

        [Parameter(Mandatory, ParameterSetName = 'ByParameter')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter(Mandatory, ParameterSetName = 'ByParameter')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $VMSwitch,

        [Parameter(ParameterSetName = 'ByParameter')]
        [System.String]
        $ParentDisk,

        [Parameter(ParameterSetName = 'ByParameter')]
        [ValidateSet(1, 2)]
        [System.Int32]
        $VMGeneration = 2,

        [Parameter(ParameterSetName = 'ByParameter')]
        [ValidateRange(1, 128)]
        [System.Int32]
        $VMProcessorCount = 2,

        [Parameter(ParameterSetName = 'ByParameter')]
        [System.Int64]
        $VMMemoryStartupBytes = 2GB,

        [Parameter(ParameterSetName = 'ByParameter')]
        [System.Int64]
        $OSDiskSizeBytes = 127GB,

        [Parameter(ParameterSetName = 'ByParameter')]
        [System.Int64]
        $DataDiskSizeBytes = 127GB,

        [Parameter(ParameterSetName = 'ByParameter')]
        [System.Management.Automation.SwitchParameter]
        $AdditionalHDD,

        [Parameter(ParameterSetName = 'ByParameter')]
        [System.Management.Automation.SwitchParameter]
        $DisableNestedVirtualization,

        [Parameter(ParameterSetName = 'ByParameter')]
        [System.Management.Automation.SwitchParameter]
        $DisableTPM,

        [Parameter(ParameterSetName = 'ByParameter')]
        [System.Management.Automation.SwitchParameter]
        $DisableGuestServices,

        [Parameter(ParameterSetName = 'ByParameter')]
        [System.Management.Automation.SwitchParameter]
        $PowerOnVM,

        [Parameter(ParameterSetName = 'ByParameter')]
        [System.Management.Automation.SwitchParameter]
        $OpenConsole,

        [Parameter(ParameterSetName = 'ByParameter')]
        [ValidateScript({
            if ($_ % 2) { throw 'HorizontalResolution must be an even number.' }
            $true
        })]
        [System.Int64]
        $HorizontalResolution = 1920,

        [Parameter(ParameterSetName = 'ByParameter')]
        [ValidateScript({
            if ($_ % 2) { throw 'VerticalResolution must be an even number.' }
            $true
        })]
        [System.Int64]
        $VerticalResolution = 1080,

        [Parameter(ParameterSetName = 'ByParameter')]
        [ValidateSet('Nothing', 'StartIfRunning', 'Start')]
        [System.String]
        $AutomaticStartAction = 'Nothing',

        [Parameter(ParameterSetName = 'ByParameter')]
        [ValidateSet('TurnOff', 'Save', 'ShutDown')]
        [System.String]
        $AutomaticStopAction = 'ShutDown',

        [Parameter(ParameterSetName = 'ByParameter')]
        [System.Management.Automation.SwitchParameter]
        $AutomaticCheckpointsEnabled,

        [Parameter(ParameterSetName = 'ByParameter')]
        [System.String]
        $ISOPath,

        [Parameter(ValueFromPipeline, ParameterSetName = 'ByConfiguration')]
        [PSTypeName('HyperV.VMFactory.Configuration')]
        [System.Object[]]
        $Configuration,

        [Parameter()]
        [System.String[]]
        $ComputerName,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimSession[]]
        $CimSession
    )

    begin {
        if (-not $ComputerName -and -not $CimSession) {
            Assert-HyperVPrerequisite
        }
    }

    process {
        $vmConfigs = @()

        if ($PSCmdlet.ParameterSetName -eq 'ByConfiguration') {
            $vmConfigs = @($Configuration)
        } else {
            foreach ($name in $VMName) {
                $vmConfigs += [PSCustomObject]@{
                    VMName                = $name
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
                    AutomaticStartAction         = $AutomaticStartAction
                    AutomaticStopAction          = $AutomaticStopAction
                    AutomaticCheckpointsEnabled  = [bool]$AutomaticCheckpointsEnabled
                    ISOPath               = $ISOPath
                }
            }
        }

        foreach ($config in $vmConfigs) {
            $currentVMName = $config.VMName
            $target = if ($ComputerName) { $ComputerName -join ', ' } else { 'localhost' }

            if (-not $PSCmdlet.ShouldProcess("VM '$currentVMName' on $target", 'Create')) {
                continue
            }

            if ($ComputerName) {
                $result = Invoke-HyperVVMCreationRemote -Config $config -ComputerName $ComputerName `
                    -Credential $Credential
                if ($result) { $result }
                if ($config.OpenConsole) {
                    foreach ($cn in $ComputerName) {
                        Write-Verbose "Opening VM console for '$currentVMName' on '$cn'."
                        Start-Process -FilePath 'vmconnect.exe' -ArgumentList $cn, $currentVMName
                    }
                }
                continue
            }

            try {
                Write-Verbose "Creating VM '$currentVMName'..."
                $vm = New-HyperVVMLocal -Config $config -CimSession $CimSession
                if ($config.OpenConsole) {
                    $consoleHost = if ($CimSession) { $CimSession[0].ComputerName } else { 'localhost' }
                    Write-Verbose "Opening VM console for '$currentVMName' on '$consoleHost'."
                    Start-Process -FilePath 'vmconnect.exe' -ArgumentList $consoleHost, $currentVMName
                }
                $vm
            } catch {
                Write-Error "Failed to create VM '$currentVMName': $_"
            }
        }
    }
}

function New-HyperVVMLocal {
    <#
    .SYNOPSIS
        Internal function that creates a VM on the local host or via CimSession.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Object]
        $Config,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimSession[]]
        $CimSession
    )

    $vmName = $Config.VMName
    $vmPath = $Config.Path
    $vhdFolder = Join-Path -Path $vmPath -ChildPath "$vmName\Virtual Hard Disks"
    $vmOSDisk = Join-Path -Path $vhdFolder -ChildPath "${vmName}_C.vhdx"

    # Build New-VM parameters
    $newVMSplat = @{
        Name       = $vmName
        Path       = $vmPath
        Generation = $Config.VMGeneration
        NoVHD      = $true
        MemoryStartupBytes = $Config.VMMemoryStartupBytes
    }
    if ($CimSession) {
        $newVMSplat['CimSession'] = $CimSession
    }

    Write-Verbose "Creating VM '$vmName' (Generation $($Config.VMGeneration))..."
    $vm = New-VM @newVMSplat

    # Connect network adapter
    Write-Verbose "Connecting VM '$vmName' to switch '$($Config.VMSwitch)'."
    $connectSplat = @{ SwitchName = $Config.VMSwitch; VMName = $vm.VMName }
    if ($CimSession) { $connectSplat['CimSession'] = $CimSession }
    Connect-VMNetworkAdapter @connectSplat

    # Create OS disk
    $osDiskSplat = @{ Path = $vmOSDisk }
    if ($Config.ParentDisk) {
        $osDiskSplat['ParentDisk'] = $Config.ParentDisk
    } else {
        $osDiskSplat['SizeBytes'] = $Config.OSDiskSizeBytes
    }
    $null = New-VMDisk @osDiskSplat

    # Attach OS disk
    Write-Verbose "Attaching OS disk to VM '$vmName'."
    Add-VMHardDiskDrive -VMName $vmName -ControllerType SCSI -Path $vmOSDisk

    # Handle boot device (ISO or HDD)
    if ($Config.ISOPath) {
        Write-Verbose "Attaching ISO '$($Config.ISOPath)' and setting as first boot device."
        Add-VMDvdDrive -VMName $vmName -Path $Config.ISOPath
        if ($Config.VMGeneration -eq 2) {
            $firstBootDevice = Get-VMDvdDrive -VMName $vmName
            if ($firstBootDevice) {
                Set-VMFirmware -VMName $vmName -FirstBootDevice $firstBootDevice
            }
        }
    } else {
        if ($Config.VMGeneration -eq 2) {
            $firstBootDevice = Get-VMHardDiskDrive -VMName $vmName
            if ($firstBootDevice) {
                Set-VMFirmware -VMName $vmName -FirstBootDevice $firstBootDevice
            }
        }
    }

    # Apply post-creation configuration
    $configSplat = @{
        VM                    = $vm
        ProcessorCount        = $Config.VMProcessorCount
        HorizontalResolution  = $Config.HorizontalResolution
        VerticalResolution    = $Config.VerticalResolution
        NestedVirtualization  = $Config.NestedVirtualization
        TPM                   = $Config.TPM
        GuestServices         = $Config.GuestServices
        AutomaticStartAction        = $Config.AutomaticStartAction
        AutomaticStopAction         = $Config.AutomaticStopAction
        AutomaticCheckpointsEnabled = $Config.AutomaticCheckpointsEnabled
    }
    Set-VMConfiguration @configSplat

    # Create additional data disk
    if ($Config.AdditionalHDD) {
        $vmDataDisk = Join-Path -Path $vhdFolder -ChildPath "${vmName}_D.vhdx"
        Write-Verbose "Creating additional data disk for VM '$vmName'."
        $null = New-VMDisk -Path $vmDataDisk -SizeBytes $Config.DataDiskSizeBytes
        Add-VMHardDiskDrive -VMName $vmName -Path $vmDataDisk -ControllerType SCSI
    }

    # Power on VM
    if ($Config.PowerOnVM) {
        Write-Verbose "Starting VM '$vmName'."
        Start-VM -VMName $vmName
    }

    return $vm
}

function Invoke-HyperVVMCreationRemote {
    <#
    .SYNOPSIS
        Internal function that creates a VM on a remote Hyper-V host via Invoke-Command.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Object]
        $Config,

        [Parameter(Mandatory)]
        [System.String[]]
        $ComputerName,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    # Convert config to hashtable for serialization
    $configHash = @{
        VMName                = $Config.VMName
        Path                  = $Config.Path
        VMSwitch              = $Config.VMSwitch
        ParentDisk            = $Config.ParentDisk
        VMGeneration          = $Config.VMGeneration
        VMProcessorCount      = $Config.VMProcessorCount
        VMMemoryStartupBytes  = $Config.VMMemoryStartupBytes
        OSDiskSizeBytes       = $Config.OSDiskSizeBytes
        DataDiskSizeBytes     = $Config.DataDiskSizeBytes
        AdditionalHDD         = $Config.AdditionalHDD
        NestedVirtualization  = $Config.NestedVirtualization
        TPM                   = $Config.TPM
        GuestServices         = $Config.GuestServices
        PowerOnVM             = $Config.PowerOnVM
        HorizontalResolution  = $Config.HorizontalResolution
        VerticalResolution    = $Config.VerticalResolution
        AutomaticStartAction        = $Config.AutomaticStartAction
        AutomaticStopAction         = $Config.AutomaticStopAction
        AutomaticCheckpointsEnabled = $Config.AutomaticCheckpointsEnabled
        ISOPath               = $Config.ISOPath
    }

    $scriptBlock = {
        param($VMConfig)

        $vmName = $VMConfig.VMName
        $vmPath = $VMConfig.Path
        $vhdFolder = Join-Path -Path $vmPath -ChildPath "$vmName\Virtual Hard Disks"
        $vmOSDisk = Join-Path -Path $vhdFolder -ChildPath "${vmName}_C.vhdx"

        # Create VM
        $newVMSplat = @{
            Name               = $vmName
            Path               = $vmPath
            Generation         = $VMConfig.VMGeneration
            NoVHD              = $true
            MemoryStartupBytes = $VMConfig.VMMemoryStartupBytes
        }
        $vm = New-VM @newVMSplat

        # Connect network
        Connect-VMNetworkAdapter -SwitchName $VMConfig.VMSwitch -VMName $vm.VMName

        # Create OS disk
        if ($VMConfig.ParentDisk) {
            New-VHD -Path $vmOSDisk -ParentPath $VMConfig.ParentDisk -Differencing
        } else {
            New-VHD -Path $vmOSDisk -Dynamic -SizeBytes $VMConfig.OSDiskSizeBytes
        }

        Add-VMHardDiskDrive -VM $vm -ControllerType SCSI -Path $vmOSDisk

        # Boot device
        if ($VMConfig.ISOPath) {
            Add-VMDvdDrive -VM $vm -Path $VMConfig.ISOPath
            if ($VMConfig.VMGeneration -eq 2) {
                Set-VMFirmware -VM $vm -FirstBootDevice (Get-VMDvdDrive -VM $vm)
            }
        } else {
            if ($VMConfig.VMGeneration -eq 2) {
                Set-VMFirmware -VM $vm -FirstBootDevice (Get-VMHardDiskDrive -VM $vm)
            }
        }

        # Configure VM
        Set-VM -VM $vm -ProcessorCount $VMConfig.VMProcessorCount `
            -AutomaticCheckpointsEnabled:$VMConfig.AutomaticCheckpointsEnabled `
            -AutomaticStartAction $VMConfig.AutomaticStartAction `
            -AutomaticStopAction $VMConfig.AutomaticStopAction

        Set-VMVideo -VM $vm -ResolutionType Single `
            -HorizontalResolution $VMConfig.HorizontalResolution `
            -VerticalResolution $VMConfig.VerticalResolution

        if ($VMConfig.GuestServices) {
            Enable-VMIntegrationService -VM $vm -Name 'Guest Service Interface'
        }

        if ($VMConfig.NestedVirtualization) {
            Set-VMProcessor -VM $vm -ExposeVirtualizationExtensions:$true
        }

        if ($VMConfig.TPM) {
            Set-VMKeyProtector -VM $vm -NewLocalKeyProtector
            Enable-VMTPM -VM $vm
        }

        # Additional data disk
        if ($VMConfig.AdditionalHDD) {
            $vmDataDisk = Join-Path -Path $vhdFolder -ChildPath "${vmName}_D.vhdx"
            New-VHD -Path $vmDataDisk -Dynamic -SizeBytes $VMConfig.DataDiskSizeBytes
            Add-VMHardDiskDrive -VM $vm -Path $vmDataDisk -ControllerType SCSI
        }

        # Power on
        if ($VMConfig.PowerOnVM) {
            Start-VM -VM $vm
        }

        return $vm
    }

    $invokeParams = @{
        ComputerName = $ComputerName
        ScriptBlock  = $scriptBlock
        ArgumentList = @(, $configHash)
    }
    if ($Credential) {
        $invokeParams['Credential'] = $Credential
    }

    Write-Verbose "Creating VM '$($Config.VMName)' on remote host(s): $($ComputerName -join ', ')"
    Invoke-Command @invokeParams
}
