<#
.SYNOPSIS
    Removes the Linux IAM Lab: ONLY the VM recorded at install (verified by UUID, name and
    install id), its desktop shortcuts, the 'linux-iam-lab' SSH config entry and the lab's
    data folder. Your exports in Documents\LinuxIAMLab\Exports are kept. Other VMs are never touched.
.PARAMETER Yes
    Skip the typed confirmation (automation/testing).
#>
[CmdletBinding()]
param([switch]$Yes, [switch]$KeepDownloads)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'LinuxIAMLab.Common.ps1')
$log = Start-LabLog 'uninstall'
try {
    $state = Get-LabState
    $paths = Get-LabPaths
    $haveVm = $false
    if ($state -and $state.PSObject.Properties['VmUuid'] -and $state.VmUuid -and (Get-VBoxVmInfo $state.VmUuid)) {
        Assert-LabVm | Out-Null
        $haveVm = $true
        Write-Host "  Will delete VM $($state.VmName) {$($state.VmUuid)} and its disk and snapshots." -ForegroundColor Yellow
    } else {
        Write-Host '  No lab VM is registered; only local files and shortcuts will be removed.'
    }
    Write-Host "  Kept: $($paths.Exports)"
    if (-not $Yes) {
        $c = Read-Host '  Type REMOVE to uninstall the Linux IAM Lab'
        if ($c -cne 'REMOVE') { Write-LabLog 'Cancelled; nothing changed.' -Level OK; exit 0 }
    }
    if ($haveVm) {
        $s = Get-LabVmState
        if ($s -in @('running', 'paused')) {
            Assert-LabVm | Out-Null
            Invoke-VBoxManage controlvm $state.VmUuid poweroff | Out-Null
            Start-Sleep -Seconds 3
        }
        Assert-LabVm | Out-Null
        Invoke-VBoxUnlocked unregistervm $state.VmUuid --delete | Out-Null
        Write-LabLog 'Lab VM, its disk and snapshots deleted' -Level OK
    }
    $desk = [Environment]::GetFolderPath('Desktop')
    foreach ($n in 'Start Linux IAM Lab', 'Stop Linux IAM Lab', 'Reset Linux IAM Lab') {
        Remove-Item -LiteralPath (Join-Path $desk "$n.lnk") -ErrorAction SilentlyContinue
    }
    $userCfg = Join-Path $env:USERPROFILE '.ssh\config'
    if (Test-Path -LiteralPath $userCfg) {
        $t = [IO.File]::ReadAllText($userCfg)
        $t = [regex]::Replace($t, '\n?# >>> Linux IAM Lab \(managed by Install-LinuxIAMLab.ps1\) >>>[\s\S]*?# <<< Linux IAM Lab <<<\n?', "`n")
        [IO.File]::WriteAllText($userCfg, $t, (New-Object Text.ASCIIEncoding))
    }
    Remove-Item -LiteralPath $paths.StudentKey, "$($paths.StudentKey).pub" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force -LiteralPath $paths.Reference -ErrorAction SilentlyContinue
    $keepCache = $KeepDownloads -and (Test-Path $paths.Cache)
    Get-ChildItem -LiteralPath $paths.Data -Force | Where-Object { -not ($keepCache -and $_.Name -eq 'cache') -and $_.Name -ne 'logs' } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-LabLog 'Linux IAM Lab removed (logs kept for reference).' -Level OK
    exit 0
} catch {
    Write-LabLog $_.Exception.Message -Level ERROR
    Pause-IfInteractive
    exit 1
}
