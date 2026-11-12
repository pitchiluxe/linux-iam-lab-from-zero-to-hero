<#
.SYNOPSIS
    Copies your exercise progress, /home/student and capstone evidence out of the lab VM into
    Documents\LinuxIAMLab\Exports\<timestamp>-manual. The VM must be running.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'LinuxIAMLab.Common.ps1')
$log = Start-LabLog 'export'
try {
    $info = Assert-LabVm
    if ($info['VMState'] -ne 'running') { throw 'Start the lab first (Start Linux IAM Lab).' }
    $dir = Export-LabLearnerData -Reason 'manual'
    Write-LabLog "Exported to $dir" -Level OK
    Start-Process explorer.exe $dir
    exit 0
} catch {
    Write-LabLog $_.Exception.Message -Level ERROR
    Pause-IfInteractive
    exit 1
}
