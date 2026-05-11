$Classes = @(
    'HyperVVMTag',
    'HyperVVMService',
    'HyperVVMEnvironment',
    'HyperVVMTopology'
) | ForEach-Object { Get-Item "$PSScriptRoot\Classes\$_.ps1" -ErrorAction SilentlyContinue } | Where-Object { $_ }
$Public  = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1"  -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)

foreach ($import in @($Classes + $Public + $Private)) {
    try {
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Register class types as global accelerators so callers can use [HyperVVMTag] etc. outside module scope
$typeAccelerators = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
foreach ($classType in @([HyperVVMTag], [HyperVVMService], [HyperVVMEnvironment], [HyperVVMTopology])) {
    if ($typeAccelerators::Get.ContainsKey($classType.Name)) { $typeAccelerators::Remove($classType.Name) }
    $typeAccelerators::Add($classType.Name, $classType)
}
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    $ta = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    'HyperVVMTag', 'HyperVVMService', 'HyperVVMEnvironment', 'HyperVVMTopology' | ForEach-Object { $ta::Remove($_) }
}

Export-ModuleMember -Function $Public.BaseName
