function Invoke-VMConsole {
    param(
        [string] $ComputerName,
        [string] $VMName
    )
    $vmconnect = "$env:SystemRoot\System32\vmconnect.exe"
    if (-not (Test-Path $vmconnect)) {
        Write-Warning "vmconnect.exe not found at '$vmconnect'. Hyper-V Manager tools may not be installed."
        return
    }
    $server = if ($ComputerName -in 'localhost', '127.0.0.1', '.') { $env:COMPUTERNAME } else { $ComputerName }
    Write-Verbose "Opening console: $vmconnect $server $VMName"
    try {
        Start-Process -FilePath $vmconnect -ArgumentList $server, $VMName -ErrorAction Stop
    } catch {
        Write-Warning "Failed to open VM console for '$VMName' on '$ComputerName': $_"
    }
}
