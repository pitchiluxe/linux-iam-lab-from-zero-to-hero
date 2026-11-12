<#
.SYNOPSIS
    Reset Linux IAM Lab: explains the reset scope, exports your work, asks you to confirm, and
    restores the known-good practice environment (baseline snapshot of the lab VM only).
.PARAMETER Yes
    Automation/testing: skip the typed confirmation.
.PARAMETER DropProgress
    Do not restore exercise checkmarks after the reset.
#>
[CmdletBinding()]
param([switch]$Yes, [switch]$DropProgress, [switch]$SkipExport)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'LinuxIAMLab.Common.ps1')
$log = Start-LabLog 'reset'
$Host.UI.RawUI.WindowTitle = 'Reset Linux IAM Lab'
$interactive = -not $env:LINUXIAMLAB_NONINTERACTIVE

try {
    $info = Assert-LabVm
    $state = Get-LabState
    $paths = Get-LabPaths
    if (-not $state.PSObject.Properties['BaselineSnapshotUuid'] -or -not $state.BaselineSnapshotUuid) { throw 'No baseline snapshot is recorded. Re-run Install-LinuxIAMLab.ps1.' }

    Write-Host ''
    Write-Host '  RESET LINUX IAM LAB' -ForegroundColor White
    Write-Host '  -------------------------------------------------------------------------------'
    Write-Host '  Only want to redo ONE exercise?  Close this window and use the "Retry exercise"'
    Write-Host '  button in the portal (or type  lab reset <exercise-id>  in Linux). That is faster.'
    Write-Host ''
    Write-Host '  A FULL reset restores the Linux VM to the known-good baseline saved at install:' -ForegroundColor Yellow
    Write-Host '   CLEARED : every change made inside the Linux VM since install - users, groups,'
    Write-Host '             permissions, sudo rules, SSH settings, services you changed or broke,'
    Write-Host '             files in /home/student, shell history, logs.'
    Write-Host '   KEPT    : your exercise checkmarks (restored after the reset unless you say no),'
    Write-Host '             your Linux password (the one you chose at install), everything on Windows,'
    Write-Host '             and all other virtual machines (they are never touched).'
    Write-Host "   EXPORT  : before resetting, your progress, /home/student and evidence files are copied to"
    Write-Host "             $($paths.Exports)"
    Write-Host "  Target VM: $($state.VmName) {$($state.VmUuid)}"
    Write-Host '  -------------------------------------------------------------------------------'

    # 1. Export first
    $exportDir = $null
    if (-not $SkipExport) {
        $running = ($info['VMState'] -eq 'running')
        if (-not $running -and $interactive) {
            $a = Read-Host '  The lab VM is off. Start it briefly to export your work first? [Y/n]'
            if ($a -notmatch '^[nN]') {
                Invoke-VBoxUnlocked startvm $state.VmUuid --type headless | Out-Null
                $running = Wait-LabSsh -TimeoutMin 8
            }
        }
        if ($running) {
            try {
                Write-LabLog 'Exporting progress, learner files and evidence' -Level STEP
                $exportDir = Export-LabLearnerData -Reason 'before-reset'
                Write-LabLog "Exported to $exportDir" -Level OK
            } catch {
                Write-LabLog "Export failed: $($_.Exception.Message)" -Level WARN
                if ($interactive) {
                    $a = Read-Host '  Continue the reset WITHOUT an export? [y/N]'
                    if ($a -notmatch '^[yY]') { throw 'Reset cancelled; nothing was changed.' }
                }
            }
        }
    }

    # 2. Confirm
    if (-not $Yes) {
        if (-not $interactive) { throw 'Non-interactive reset needs -Yes.' }
        $c = Read-Host '  Type RESET (capitals) to restore the baseline, or anything else to cancel'
        if ($c -cne 'RESET') { Write-LabLog 'Reset cancelled. Nothing was changed.' -Level OK; Pause-IfInteractive; exit 0 }
        if (-not $DropProgress) {
            $k = Read-Host '  Restore your exercise checkmarks after the reset? [Y/n]'
            if ($k -match '^[nN]') { $DropProgress = $true }
        }
    }

    # 3. Power off (lab VM only), restore snapshot
    Write-LabLog 'Stopping the lab VM' -Level STEP
    Assert-LabVm | Out-Null
    $s = Stop-LabVmGraceful -TimeoutMin 3 -ForceIfNeeded
    if ($s -notin @('poweroff', 'aborted', 'saved')) { throw "Could not stop the lab VM (state $s)." }
    if ($s -eq 'saved') { Invoke-VBox discardstate $state.VmUuid | Out-Null }
    Write-LabLog 'Restoring the baseline snapshot' -Level STEP
    Assert-LabVm | Out-Null
    Invoke-VBoxUnlocked snapshot $state.VmUuid restore $state.BaselineSnapshotUuid | Out-Null
    Write-LabLog 'Baseline restored' -Level OK

    # 4. Boot and refresh course files if the installed course is newer than the baseline
    Invoke-VBoxUnlocked startvm $state.VmUuid --type (Get-LabConfig).startMode | Out-Null
    if (-not (Wait-LabSsh -TimeoutMin 10)) { throw 'Linux did not come back after the reset.' }
    $guestRoot = Join-Path (Split-Path $PSScriptRoot) 'guest'
    if (Test-Path $guestRoot) {
        $h = Get-LabPayloadHash $guestRoot
        if ($state.PSObject.Properties['BaselinePayloadSha256'] -and $h -ne $state.BaselinePayloadSha256) {
            Write-LabLog 'Applying the newer course files to the restored baseline' -Level STEP
            Publish-LabPayload -GuestRoot $guestRoot -SkipTutorModel -TimeoutMin 30 | Out-Null
        }
    }

    # 5. Restore checkmarks
    if (-not $DropProgress -and $exportDir) {
        $prog = Get-ChildItem -LiteralPath $exportDir -Recurse -Filter 'progress.json' | Select-Object -First 1
        if ($prog) {
            Copy-ToLabVm $prog.FullName '/tmp/progress-import.json'
            Invoke-LabSsh -Command 'sudo -n /opt/linux-iam-lab/bin/lab import-progress /tmp/progress-import.json && rm -f /tmp/progress-import.json' | Out-Null
            Write-LabLog 'Exercise checkmarks restored' -Level OK
        }
    }

    # 6. Verify
    Write-LabLog 'Verifying the restored lab' -Level STEP
    $st = Invoke-LabSsh -Command 'sudo -n /opt/linux-iam-lab/bin/lab selftest' -AllowFailure -TimeoutSec 600
    foreach ($l in ($st.Out -split "`n")) { if ($l.Trim()) { Write-LabLog ('  ' + $l.Trim()) } }
    if ($st.Code -ne 0) { throw 'Self-test after reset failed; see the log.' }
    if (-not (Wait-LabPortal -TimeoutMin 5)) { throw 'Portal did not answer after reset.' }
    Write-LabLog 'Reset complete. The practice environment is back to its known-good state.' -Level OK
    if ($exportDir) { Write-Host "  Your export: $exportDir" }
    if ($interactive) {
        Write-Host '  The Linux IAM Lab window shows the restored desktop (portal + terminal open inside Linux).'
    }
    exit 0
} catch {
    Write-LabLog $_.Exception.Message -Level ERROR
    Write-Host "  Log: $log"
    Pause-IfInteractive
    exit 1
}
