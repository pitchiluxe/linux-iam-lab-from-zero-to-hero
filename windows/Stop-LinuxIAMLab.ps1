<#
.SYNOPSIS
    Stop Linux IAM Lab: gracefully shuts down ONLY the recorded Linux lab VM.
#>
[CmdletBinding()]
param([switch]$Force)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'LinuxIAMLab.Common.ps1')
$log = Start-LabLog 'stop'
$Host.UI.RawUI.WindowTitle = 'Stop Linux IAM Lab'

try {
    Write-Host ''
    Write-Host '  Stop Linux IAM Lab' -ForegroundColor White
    $info = Assert-LabVm
    $state = Get-LabState
    Write-LabLog "Target verified: $($state.VmName) {$($state.VmUuid)}. No other VM will be touched." -Level OK
    if ($info['VMState'] -ne 'running' -and $info['VMState'] -ne 'paused') {
        Write-LabLog "The lab VM is already stopped (state '$($info['VMState'])')" -Level OK
        if (-not $env:LINUXIAMLAB_NONINTERACTIVE) { Start-Sleep -Seconds 5 }
        exit 0
    }
    if ($info['VMState'] -eq 'paused') { Invoke-VBox controlvm $state.VmUuid resume | Out-Null }
    Write-LabLog 'Shutting down Linux cleanly (your files in the VM are kept)' -Level STEP
    $s = Stop-LabVmGraceful -TimeoutMin 4 -ForceIfNeeded:$Force
    if ($s -ne 'poweroff') {
        Write-LabLog 'Linux did not finish shutting down within 4 minutes.' -Level WARN
        $ans = 'n'
        if (-not $env:LINUXIAMLAB_NONINTERACTIVE) { $ans = Read-Host '  Force power-off of the Linux IAM Lab VM only (like pulling its plug)? [y/N]' }
        if ($ans -match '^[yY]') {
            Assert-LabVm | Out-Null
            Invoke-VBox controlvm $state.VmUuid poweroff | Out-Null
            Write-LabLog 'Lab VM powered off' -Level OK
        } else { throw 'Left the lab VM running. Try again, or shut it down from inside Linux with: sudo systemctl poweroff' }
    } else { Write-LabLog 'Lab VM is shut down' -Level OK }
    if (-not $env:LINUXIAMLAB_NONINTERACTIVE) { Start-Sleep -Seconds 5 }
    exit 0
} catch {
    Write-LabLog $_.Exception.Message -Level ERROR
    Write-Host "  Log: $log"
    Pause-IfInteractive
    exit 1
}
