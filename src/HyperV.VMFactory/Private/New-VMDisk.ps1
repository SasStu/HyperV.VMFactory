function New-VMDisk {
    <#
    .SYNOPSIS
        Creates a new virtual hard disk (VHD/VHDX).

    .DESCRIPTION
        Creates either a differencing disk from a parent or a new dynamic disk of the
        specified size. Returns the VHD object.

    .PARAMETER Path
        Full path for the new VHD file.

    .PARAMETER ParentDisk
        Path to the parent disk for creating a differencing disk. When omitted, a new
        dynamic disk is created.

    .PARAMETER SizeBytes
        Size of the new disk in bytes. Only used when ParentDisk is not specified.
        Defaults to 127GB.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([System.Object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter()]
        [System.String]
        $ParentDisk,

        [Parameter()]
        [System.Int64]
        $SizeBytes = 127GB
    )

    if ($ParentDisk) {
        Write-Verbose "Creating differencing disk at '$Path' from parent '$ParentDisk'."
        $vhd = New-VHD -Path $Path -ParentPath $ParentDisk -Differencing
    } else {
        Write-Verbose "Creating dynamic disk at '$Path' with size $([math]::Round($SizeBytes / 1GB, 1)) GB."
        $vhd = New-VHD -Path $Path -Dynamic -SizeBytes $SizeBytes
    }

    return $vhd
}
