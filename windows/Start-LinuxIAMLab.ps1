<#
.SYNOPSIS
    Start Linux IAM Lab: starts ONLY the recorded lab VM, waits until the lab is ready and
    opens the course portal in your browser.
#>
[CmdletBinding()]
param([switch]$NoBrowser, [switch]$Browser, [switch]$Headless)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'LinuxIAMLab.Common.ps1')
$log = Start-LabLog 'start'
$Host.UI.RawUI.WindowTitle = 'Start Linux IAM Lab'

try {
    Write-Host ''
    Write-Host '  Start Linux IAM Lab' -ForegroundColor White
    Write-Host '  (This window is WINDOWS POWERSHELL. Linux commands go in the portal terminal or "ssh linux-iam-lab".)' -ForegroundColor Blue
    $cfg = Get-LabConfig
    $info = Assert-LabVm
    $state = Get-LabState
    Write-LabLog "Target verified: $($state.VmName) {$($state.VmUuid)}" -Level OK
    $vmState = $info['VMState']
    switch ($vmState) {
        'running' { Write-LabLog 'The lab VM is already running' -Level OK }
        'paused' { Invoke-VBox controlvm $state.VmUuid resume | Out-Null; Write-LabLog 'Resumed the lab VM' -Level OK }
        default {
            $availMB = [int](Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue
            $vmMem = [int]$info['memory']
            if ($availMB -lt ($vmMem + 512)) {
                Write-LabLog "Only $availMB MB of memory is free and the lab VM uses $vmMem MB. Windows may become slow." -Level WARN
                Write-LabLog 'Close some applications if you can. This script never stops your other VMs.' -Level WARN
            }
            Write-LabLog "Starting the lab VM (state was '$vmState')" -Level STEP
            $mode = if ($Headless) { 'headless' } else { $cfg.startMode }
            Invoke-VBoxUnlocked startvm $state.VmUuid --type $mode | Out-Null
            if ($mode -eq 'gui') { Write-LabLog 'The Linux IAM Lab window is opening: it logs in as student and opens the course portal and a Linux terminal inside Linux' -Level OK }
        }
    }
    Write-LabLog 'Waiting for Linux and the lab services' -Level STEP
    if (-not (Wait-LabSsh -TimeoutMin 10)) { throw 'Linux did not become reachable within 10 minutes.' }
    Write-LabLog 'Linux is up (SSH host key matches the pinned key)' -Level OK
    $r = Invoke-LabSsh -Command 'sudo -n systemctl start lab-agent lab-portal lab-terminal >/dev/null 2>&1; sudo -n /opt/linux-iam-lab/bin/lab status --brief' -AllowFailure -TimeoutSec 60
    if ($r.Out) { foreach ($l in ($r.Out -split "`n")) { if ($l.Trim()) { Write-LabLog $l.Trim() } } }
    if (-not (Wait-LabPortal -TimeoutMin 5)) { throw 'The course portal did not answer within 5 minutes.' }
    # Warm up the tutor in the background so the first question does not also pay the model load.
    $model = (Get-LabConfig).ollamaModel
    Invoke-LabSsh -Command ("nohup curl -s -m 600 http://127.0.0.1:11434/api/generate -d '{""model"":""$model"",""keep_alive"":""30m""}' >/dev/null 2>&1 &") -AllowFailure -TimeoutSec 20 | Out-Null
    Write-LabLog 'Course portal is ready' -Level OK
    $url = Get-PortalUrl
    $openHost = ($Browser -or $cfg.openHostBrowser -or $Headless) -and -not $NoBrowser
    if ($openHost) { Start-Process $url }
    Write-Host ''
    Write-Host  '  Work inside the Linux IAM Lab window (VirtualBox): course portal + Linux terminal are open there.' -ForegroundColor Green
    Write-Host ('  Optional from Windows: portal http://127.0.0.1:{0}/  (run this script with -Browser)' -f $state.PortalPort)
    Write-Host  '  Manual SSH:  open Windows Terminal and type   ssh linux-iam-lab' -ForegroundColor Green
    Write-Host  '  When done:   double-click "Stop Linux IAM Lab"'
    Write-Host ''
    Write-Host '  This window closes in 15 seconds.'
    if (-not $env:LINUXIAMLAB_NONINTERACTIVE) { Start-Sleep -Seconds 15 }
    exit 0
} catch {
    Write-LabLog $_.Exception.Message -Level ERROR
    Write-Host "  Log: $log"
    Write-Host '  Tip: if Linux itself is broken, use "Reset Linux IAM Lab".'
    Pause-IfInteractive
    exit 1
}
