<#
.SYNOPSIS
    Installs the Linux IAM Zero-to-Hero Lab: a dedicated Ubuntu Server 24.04 LTS VirtualBox VM,
    the course portal, the Ollama tutor, and three desktop shortcuts.

.DESCRIPTION
    Run from a normal (non-administrator) PowerShell window on the Windows host:

        powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-LinuxIAMLab.ps1

    Safety rules this installer follows:
      * It creates ONE new VM (default name LinuxIAM-Lab01) with its own UUID, disk, NAT engine,
        SSH keys and accounts. It never starts, stops, pauses, snapshots or reconfigures any other VM.
      * It does not enable Windows features, change host networking, create host-only adapters or
        NAT networks, or reboot. If something like that would be needed, it stops and explains.
      * Port forwards bind to 127.0.0.1 only.
      * It is safe to re-run: finished steps are detected and skipped; an interrupted setup resumes.

.PARAMETER PreflightOnly
    Only run the compatibility and resource checks; change nothing.
.PARAMETER MemoryMB
    VM memory. Default 4096. Minimum 3072 (the tutor model needs ~1.5 GB when answering).
.PARAMETER SkipTutorModel
    Do not download the Ollama model during install (the written course and checks still work;
    run 'lab tutor-pull' in the VM later).
.PARAMETER StudentPasswordFile
    Testing/automation only: read the learner password from this file instead of prompting.
.PARAMETER NoShortcuts / NoSshConfig / NoLaunch
    Skip creating desktop shortcuts / adding the 'linux-iam-lab' entry to ~/.ssh/config /
    the "start now?" question at the end.
#>
[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [int]$MemoryMB = 0,
    [int]$Cpus = 0,
    [switch]$SkipTutorModel,
    [string]$StudentPasswordFile,
    [switch]$NoShortcuts,
    [switch]$NoSshConfig,
    [switch]$NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows\LinuxIAMLab.Common.ps1')

$cfg = Get-LabConfig
if ($MemoryMB -gt 0) { $cfg.memoryMB = $MemoryMB }
if ($Cpus -gt 0) { $cfg.cpus = $Cpus }
$paths = Get-LabPaths
$log = Start-LabLog 'install'
$started = Get-Date

Write-Host ''
Write-Host '  Linux IAM Zero-to-Hero Lab - installer' -ForegroundColor White
Write-Host '  You are typing in: WINDOWS POWERSHELL (the host).' -ForegroundColor Blue
Write-Host "  Log file: $log"
Write-Host '  This creates one new, separate VirtualBox VM. Your other VMs are never touched.'

# =====================================================================================
# 1. Preflight
# =====================================================================================
function Test-Preflight {
    Write-LabLog 'Checking compatibility and resources (no changes yet)' -Level STEP
    $fail = New-Object System.Collections.Generic.List[string]
    $state = Get-LabState
    $vmExists = $false
    $vmRunning = $false
    if ($state -and $state.PSObject.Properties['VmUuid'] -and $state.VmUuid) {
        $i = Get-VBoxVmInfo $state.VmUuid
        if ($i) { $vmExists = $true; $vmRunning = ($i['VMState'] -eq 'running') }
    }

    if (-not [Environment]::Is64BitOperatingSystem) { $fail.Add('A 64-bit Windows is required.') }
    $os = Get-CimInstance Win32_OperatingSystem
    Write-LabLog "Windows: $($os.Caption) build $($os.BuildNumber)"
    if ([int]$os.BuildNumber -lt 17763) { $fail.Add('Windows 10 1809 or newer is required (for built-in OpenSSH, curl and tar).') }

    $vbox = Find-VBoxManage
    if (-not $vbox) {
        $fail.Add('Oracle VirtualBox 7.x is not installed. Install it from https://www.virtualbox.org/wiki/Downloads, then re-run this installer.')
    } else {
        $ver = (Invoke-NativeRaw -FilePath $vbox -Arguments '--version').Out.Trim()
        Write-LabLog "VirtualBox: $ver ($vbox)" -Level OK
        if ($ver -notmatch '^(\d+)\.' -or [int]$Matches[1] -lt 7) { $fail.Add("VirtualBox $ver is too old; version 7.0 or newer is required.") }
        $r = Invoke-VBoxManage list hostinfo
        if ($r.Code -ne 0) { $fail.Add('VBoxManage cannot talk to the VirtualBox service as this user. Open VirtualBox once, then re-run.') }
    }

    foreach ($t in @(@('ssh', (Get-SshExe)), @('scp', (Get-ScpExe)), @('ssh-keygen', (Get-SshKeygenExe)),
            @('curl', (Find-Tool 'curl.exe' @("$env:WINDIR\System32\curl.exe"))), @('tar', (Find-Tool 'tar.exe' @("$env:WINDIR\System32\tar.exe"))))) {
        if (-not $t[1]) { $fail.Add("$($t[0]).exe not found. Install the Windows 'OpenSSH Client' optional feature (Settings > System > Optional features).") }
        else { Write-LabLog "$($t[0]): $($t[1])" -Quiet }
    }

    $cs = Get-CimInstance Win32_ComputerSystem
    if ($cs.HypervisorPresent) {
        Write-LabLog 'Windows hypervisor is active: VirtualBox will run through Hyper-V (slower, but supported). Nothing will be changed.' -Level WARN
    }
    Write-LabLog ("Host: {0} logical CPUs, {1:N1} GB RAM" -f $cs.NumberOfLogicalProcessors, ($cs.TotalPhysicalMemory / 1GB))
    if ($cfg.cpus -ge $cs.NumberOfLogicalProcessors) { $cfg.cpus = [Math]::Max(1, $cs.NumberOfLogicalProcessors - 1) }
    if ($cs.HypervisorPresent -and $cfg.cpus -gt 1) { Write-LabLog 'Windows hypervisor active: using 1 vCPU (multi-vCPU Linux guests hang at boot under VirtualBox+Hyper-V)' -Level WARN; $cfg.cpus = 1 }

    if ($cfg.memoryMB -lt $cfg.minMemoryMB) { $fail.Add("MemoryMB must be at least $($cfg.minMemoryMB).") }
    $availMB = [int](Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue
    $commit = (Get-Counter '\Memory\Committed Bytes', '\Memory\Commit Limit').CounterSamples
    $headMB = [int](($commit[1].CookedValue - $commit[0].CookedValue) / 1MB)
    Write-LabLog "Memory available now: $availMB MB; commit headroom: $headMB MB; lab VM needs $($cfg.memoryMB) MB"
    if (-not $vmRunning) {
        $need = $cfg.memoryMB + 1024
        if ($availMB -lt $need -or $headMB -lt $need) {
            $msg = ("Not enough free memory right now: the lab VM needs {0} MB plus 1024 MB headroom, but only {1} MB is available (commit headroom {2} MB). " +
                "Close some applications and re-run. This installer will NOT stop or pause your other VMs to make room. " +
                "You may also try -MemoryMB {3} (minimum).") -f $cfg.memoryMB, $availMB, $headMB, $cfg.minMemoryMB
            $fail.Add($msg)
        } else { Write-LabLog 'Memory check passed' -Level OK }
    }

    $drive = [IO.Path]::GetPathRoot($cfg.vmBaseFolder)
    $free = (Get-PSDrive -Name $drive.Substring(0, 1)).Free / 1GB
    Write-LabLog ("Free disk on {0}: {1:N1} GB (need {2} GB)" -f $drive, $free, $cfg.minFreeDiskGB)
    if (-not $vmExists -and $free -lt $cfg.minFreeDiskGB) { $fail.Add("Need at least $($cfg.minFreeDiskGB) GB free on $drive.") }

    foreach ($kv in @(@('SshPort', 'ssh'), @('PortalPort', 'portal'), @('TerminalPort', 'terminal'))) {
        $recorded = Get-LabStateValue $kv[0]
        if ($recorded -and $vmExists) { continue }
        $port = [int]$cfg.hostPorts.($kv[1])
        $tries = 0
        while (-not (Test-PortFree $port) -and $tries -lt 20) { $port++; $tries++ }
        if (-not (Test-PortFree $port)) { $fail.Add("No free localhost port near $($cfg.hostPorts.($kv[1])) for $($kv[1]).") }
        else { $script:PlannedPorts[$kv[0]] = $port }
    }

    $gpg = Find-Tool 'gpg.exe' @('C:\Program Files\Git\usr\bin\gpg.exe', 'C:\Program Files (x86)\GnuPG\bin\gpg.exe', 'C:\Program Files\GnuPG\bin\gpg.exe')
    if ($gpg) { Write-LabLog "gpg found ($gpg): the Ubuntu image signature will be verified" -Level OK }
    else { Write-LabLog 'gpg not found: the image will be verified by SHA-256 from the HTTPS checksum list only. Install Git for Windows or Gpg4win for signature checks.' -Level WARN }
    $script:Gpg = $gpg

    if ($fail.Count -gt 0) {
        Write-LabLog 'Preflight found problems. Nothing was changed.' -Level ERROR
        foreach ($f in $fail) { Write-LabLog $f -Level ERROR }
        return $false
    }
    Write-LabLog 'Preflight passed' -Level OK
    return $true
}

$script:PlannedPorts = @{}
$script:Gpg = $null
if (-not (Test-Preflight)) { Pause-IfInteractive; exit 2 }
if ($PreflightOnly) { Write-LabLog 'PreflightOnly: stopping here.' -Level OK; exit 0 }

try {
    # =====================================================================================
    # 2. Identity and state (recorded BEFORE the VM exists, so an interrupted run can resume)
    # =====================================================================================
    Write-LabLog 'Recording lab identity' -Level STEP
    if (-not (Get-LabStateValue 'InstallId')) { Set-LabStateValue 'InstallId' ([guid]::NewGuid().ToString()) | Out-Null }
    if (-not (Get-LabStateValue 'VmUuid')) { Set-LabStateValue 'VmUuid' ([guid]::NewGuid().ToString()) | Out-Null }
    if (-not (Get-LabStateValue 'VmName')) { Set-LabStateValue 'VmName' $cfg.vmName | Out-Null }
    if (-not (Get-LabStateValue 'PortalToken')) { Set-LabStateValue 'PortalToken' (Get-RandomToken) | Out-Null }
    foreach ($k in $script:PlannedPorts.Keys) { Set-LabStateValue $k $script:PlannedPorts[$k] | Out-Null }
    Set-LabStateValue 'InstallerVersion' '1.0.0' | Out-Null
    $state = Get-LabState
    Write-LabLog "VM name $($state.VmName), UUID $($state.VmUuid), ports ssh=$($state.SshPort) portal=$($state.PortalPort) terminal=$($state.TerminalPort)" -Level OK

    # =====================================================================================
    # 3. Keys (automation key, learner key, pinned VM host key)
    # =====================================================================================
    Write-LabLog 'Creating SSH keys for this lab' -Level STEP
    $keygen = Get-SshKeygenExe
    function New-LabKey([string]$Path, [string]$Comment) {
        if (Test-Path -LiteralPath $Path) { return }
        $dir = Split-Path $Path
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $r = Invoke-NativeRaw -FilePath $keygen -Arguments ('-q -t ed25519 -N "" -C {0} -f {1}' -f (Quote-Arg $Comment), (Quote-Arg $Path))
        if ($r.Code -ne 0 -or -not (Test-Path -LiteralPath $Path)) { throw "ssh-keygen failed: $($r.Err)" }
    }
    New-LabKey $paths.CtlKey 'labctl@linux-iam-lab-host'
    New-LabKey $paths.StudentKey 'student@linux-iam-lab-host'
    $hostKey = Join-Path $paths.Keys 'vm_host_ed25519'
    New-LabKey $hostKey 'root@iamlab01'
    $hostPub = (Get-Content -Raw -LiteralPath "$hostKey.pub").Trim()
    $hostPubNoComment = ($hostPub -split ' ')[0..1] -join ' '
    [IO.File]::WriteAllText($paths.KnownHosts, "linux-iam-lab $hostPubNoComment`n", (New-Object Text.ASCIIEncoding))
    $fp = (Invoke-NativeRaw -FilePath $keygen -Arguments ('-lf {0}' -f (Quote-Arg "$hostKey.pub"))).Out.Trim()
    Set-LabStateValue 'HostKeyFingerprint' (($fp -split ' ')[1]) | Out-Null
    Write-LabSshConfig
    Write-LabLog "VM host key fingerprint (pinned): $(($fp -split ' ')[1])" -Level OK

    # =====================================================================================
    # 4. Download and verify Ubuntu Server LTS cloud image
    # =====================================================================================
    Write-LabLog "Downloading and verifying Ubuntu Server $($cfg.ubuntuRelease) cloud image" -Level STEP
    $curl = Find-Tool 'curl.exe' @("$env:WINDIR\System32\curl.exe")
    $img = Join-Path $paths.Cache $cfg.imageFile
    $sums = Join-Path $paths.Cache 'SHA256SUMS'
    $sig = Join-Path $paths.Cache 'SHA256SUMS.gpg'
    foreach ($pair in @(@('SHA256SUMS', $sums), @('SHA256SUMS.gpg', $sig))) {
        $r = Invoke-NativeRaw -FilePath $curl -Arguments ('-fsSL --retry 3 -o {0} {1}' -f (Quote-Arg $pair[1]), "$($cfg.imageBaseUrl)/$($pair[0])") -TimeoutSec 120
        if ($r.Code -ne 0) { throw "Could not download $($pair[0]) from $($cfg.imageBaseUrl): $($r.Err)" }
    }
    if ($script:Gpg) {
        $gh = Join-Path $paths.Cache ("gnupg-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $gh | Out-Null
        try {
            $env:GNUPGHOME = $gh
            $keyFile = Join-Path $PSScriptRoot ("windows\" + $cfg.signingKeyFile)
            # Git for Windows ships an MSYS gpg that wants /c/... paths; Gpg4win wants C:\... paths.
            $msys = $script:Gpg -match '\\usr\\bin\\gpg\.exe$'
            $gp = { param($p) if ($msys) { '/' + $p.Substring(0, 1).ToLower() + ($p.Substring(2) -replace '\\', '/') } else { $p } }
            $ghU = & $gp $gh
            Invoke-NativeRaw -FilePath $script:Gpg -Arguments ('--homedir {0} --batch --quiet --import {1}' -f (Quote-Arg $ghU), (Quote-Arg (& $gp $keyFile))) | Out-Null
            $v = Invoke-NativeRaw -FilePath $script:Gpg -Arguments ('--homedir {0} --batch --status-fd 1 --verify {1} {2}' -f (Quote-Arg $ghU), (Quote-Arg (& $gp $sig)), (Quote-Arg (& $gp $sums)))
            if ($v.Out -notmatch ("VALIDSIG " + $cfg.signingKeyFingerprint)) { throw "SHA256SUMS signature check FAILED. Output: $($v.Out) $($v.Err)" }
            Write-LabLog "Checksum list signed by Ubuntu cloud image key $($cfg.signingKeyFingerprint)" -Level OK
        } finally {
            Remove-Item Env:\GNUPGHOME -ErrorAction SilentlyContinue
            Remove-Item -Recurse -Force -LiteralPath $gh -ErrorAction SilentlyContinue
        }
    }
    $line = (Get-Content -LiteralPath $sums) | Where-Object { $_ -match ("[ *]" + [regex]::Escape($cfg.imageFile) + '$') } | Select-Object -First 1
    if (-not $line) { throw "$($cfg.imageFile) is not listed in SHA256SUMS." }
    $expected = ($line -split '\s+')[0].ToLower()
    $haveGood = (Test-Path -LiteralPath $img) -and ((Get-FileHash -Algorithm SHA256 -LiteralPath $img).Hash.ToLower() -eq $expected)
    if ($haveGood) {
        Write-LabLog 'Cached image already verified; skipping download' -Level OK
    } else {
        $part = "$img.part"
        Write-LabLog "Downloading $($cfg.imageFile) (about 600 MB; resumes if interrupted)"
        $t0 = Get-Date
        $p = Start-Process -FilePath $curl -ArgumentList @('-fL', '--retry', '5', '--retry-delay', '5', '-C', '-', '-o', "`"$part`"", "$($cfg.imageBaseUrl)/$($cfg.imageFile)") -NoNewWindow -Wait -PassThru
        if ($p.ExitCode -ne 0) { throw "Download failed (curl exit $($p.ExitCode)). Re-run the installer to resume." }
        $got = (Get-FileHash -Algorithm SHA256 -LiteralPath $part).Hash.ToLower()
        if ($got -ne $expected) { Remove-Item -Force -LiteralPath $part; throw "Image SHA-256 mismatch (expected $expected, got $got). The partial file was deleted; re-run to download again." }
        Move-Item -Force -LiteralPath $part -Destination $img
        Write-LabLog ("Image downloaded and verified in {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds) -Level OK
    }
    Set-LabStateValue 'ImageSha256' $expected | Out-Null

    # =====================================================================================
    # 5. cloud-init seed ISO (NoCloud datasource, volume label CIDATA)
    # =====================================================================================
    Write-LabLog 'Building the cloud-init seed disc' -Level STEP
    $seedIso = Join-Path $paths.Seed 'linux-iam-lab-seed.iso'
    $seedDir = Join-Path $paths.Seed 'cidata'
    if (Test-Path $seedDir) { Remove-Item -Recurse -Force $seedDir }
    New-Item -ItemType Directory -Force -Path $seedDir | Out-Null
    $ctlPub = (Get-Content -Raw -LiteralPath "$($paths.CtlKey).pub").Trim()
    $stuPub = (Get-Content -Raw -LiteralPath "$($paths.StudentKey).pub").Trim()
    $hostPriv = (Get-Content -LiteralPath $hostKey) | ForEach-Object { "      $_" }
    $ud = @"
#cloud-config
hostname: $($cfg.guestHostname)
fqdn: $($cfg.guestHostname).iamlab.test
prefer_fqdn_over_hostname: false
manage_etc_hosts: true
ssh_pwauth: false
disable_root: true
ssh_deletekeys: true
ssh_genkeytypes: []
ssh_keys:
  ed25519_private: |
$($hostPriv -join "`n")
  ed25519_public: $hostPub
users:
  - name: labctl
    gecos: Lab automation account - do not modify
    shell: /bin/bash
    lock_passwd: true
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    ssh_authorized_keys:
      - $ctlPub
  - name: student
    gecos: Lab Learner
    shell: /bin/bash
    lock_passwd: true
    groups: [sudo, adm, systemd-journal]
    ssh_authorized_keys:
      - $stuPub
growpart:
  mode: auto
  devices: ['/']
timezone: Etc/UTC
"@
    [IO.File]::WriteAllText((Join-Path $seedDir 'user-data'), ($ud -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $seedDir 'meta-data'), "instance-id: linux-iam-lab-$($state.InstallId)`nlocal-hostname: $($cfg.guestHostname)`n", (New-Object Text.UTF8Encoding($false)))

    $isoTmp = "$seedIso.tmp"
    New-LabSeedIso -SourceDir $seedDir -IsoPath $isoTmp
    Remove-Item -Recurse -Force $seedDir   # contains the VM host private key
    $state = Get-LabState
    $vmInfo = Get-VBoxVmInfo $state.VmUuid
    $isoAttached = $vmInfo -and (($vmInfo.Values | Where-Object { $_ -like '*linux-iam-lab-seed.iso' }) -ne $null)
    if ($isoAttached) { Remove-Item -Force $isoTmp; Write-LabLog 'Seed disc already attached to the lab VM; keeping it' -Level OK }
    else { Move-Item -Force $isoTmp $seedIso; Write-LabLog 'Seed disc ready' -Level OK }

    # =====================================================================================
    # 6. Create the dedicated VM (own UUID, own folder, own NAT engine)
    # =====================================================================================
    Write-LabLog 'Creating the dedicated Linux VM' -Level STEP
    $vmDir = Join-Path $cfg.vmBaseFolder $state.VmName   # disk, serial log (VirtualBox keeps the .vbox under basefolder\group\name)
    $vdi = Join-Path $vmDir "$($state.VmName).vdi"
    if (-not $vmInfo) {
        # A VM with our name but another UUID is someone else's: stop.
        $byName = Get-VBoxVmInfo $state.VmName
        if ($byName) { throw "A VM named '$($state.VmName)' already exists with UUID $($byName['UUID']) and is not recorded as this lab. Refusing to touch it. Rename it or change vmName in windows\lab.config.json." }
        if (Test-Path -LiteralPath $vmDir) {
            $leftover = Get-ChildItem -LiteralPath $vmDir -Force | Where-Object { $_.Name -notlike "$($state.VmName)*" }
            if ($leftover) { throw "Folder $vmDir contains files this lab did not create. Refusing to reuse it." }
            Write-LabLog 'Removing an incomplete VM folder left by an interrupted install'
            Invoke-VBoxManage closemedium disk $vdi | Out-Null
            Remove-Item -Recurse -Force -LiteralPath $vmDir
        }
        Invoke-VBox createvm --name $state.VmName --uuid $state.VmUuid --groups $cfg.vmGroup --basefolder $cfg.vmBaseFolder --ostype $cfg.osType --register | Out-Null
        Invoke-VBox setextradata $state.VmUuid 'LinuxIAMLab/InstallId' $state.InstallId | Out-Null
        Invoke-VBox setextradata $state.VmUuid 'LinuxIAMLab/Purpose' 'Linux IAM Zero-to-Hero Lab (managed by Install-LinuxIAMLab.ps1)' | Out-Null
        Write-LabLog "Registered VM $($state.VmName) {$($state.VmUuid)}" -Level OK
    } else {
        Assert-LabVm | Out-Null
        Write-LabLog 'Lab VM already exists and its identity is verified' -Level OK
    }
    $vmInfo = Assert-LabVm
    $uuid = $state.VmUuid
    if ($vmInfo['VMState'] -in @('poweroff', 'aborted')) {
        Invoke-VBox modifyvm $uuid --memory $cfg.memoryMB --cpus $cfg.cpus --vram $cfg.vramMB --graphicscontroller vmsvga `
            --audio-enabled off --usb-ohci off --usb-ehci off --usb-xhci off --clipboard-mode disabled --drag-and-drop disabled `
            --boot1 disk --boot2 dvd --boot3 none --boot4 none --rtc-use-utc on --ioapic on --paravirt-provider $cfg.paravirtProvider `
            --nic1 nat --nic-type1 virtio --cable-connected1 on --nic2 none --nic3 none --nic4 none `
            --uart1 0x3F8 4 --uart-mode1 file (Join-Path $vmDir 'serial-console.log') | Out-Null
        foreach ($rule in @('lab-ssh', 'lab-portal', 'lab-terminal')) { Invoke-VBoxManage modifyvm $uuid --natpf1 delete $rule | Out-Null }
        Invoke-VBox modifyvm $uuid --natpf1 "lab-ssh,tcp,127.0.0.1,$($state.SshPort),,22" | Out-Null
        Invoke-VBox modifyvm $uuid --natpf1 "lab-portal,tcp,127.0.0.1,$($state.PortalPort),,8080" | Out-Null
        Invoke-VBox modifyvm $uuid --natpf1 "lab-terminal,tcp,127.0.0.1,$($state.TerminalPort),,7681" | Out-Null
        Write-LabLog "VM settings: $($cfg.memoryMB) MB RAM, $($cfg.cpus) vCPU, private NAT, localhost-only port forwards" -Level OK

        $vmInfo = Get-VBoxVmInfo $uuid
        if (-not ($vmInfo.Keys | Where-Object { $_ -like 'storagecontrollername*' } | Where-Object { $vmInfo[$_] -eq 'SATA' })) {
            Invoke-VBox storagectl $uuid --name SATA --add sata --controller IntelAhci --portcount 2 --hostiocache on | Out-Null
        }
        if (-not $vmInfo.ContainsKey('SATA-0-0') -or $vmInfo['SATA-0-0'] -eq 'none') {
            if (-not (Test-Path -LiteralPath $vdi)) {
                Write-LabLog 'Converting the cloud image to a VirtualBox disk'
                Invoke-VBox clonemedium disk $img $vdi --format VDI | Out-Null
                Invoke-VBox modifymedium disk $vdi --resize ($cfg.diskGB * 1024) | Out-Null
            }
            Invoke-VBox storageattach $uuid --storagectl SATA --port 0 --device 0 --type hdd --medium $vdi | Out-Null
            Write-LabLog "System disk attached ($($cfg.diskGB) GB dynamic)" -Level OK
        }
        if (-not (Get-LabStateValue 'Provisioned') -and (Test-Path -LiteralPath $seedIso)) {
            Invoke-VBox storageattach $uuid --storagectl SATA --port 1 --device 0 --type dvddrive --medium $seedIso | Out-Null
        }
    }

    # =====================================================================================
    # 7. Boot and wait for cloud-init / SSH
    # =====================================================================================
    Write-LabLog 'Starting the lab VM (headless) and waiting for SSH' -Level STEP
    $vmState = Get-LabVmState
    if ($vmState -in @('poweroff', 'aborted', 'saved')) { Invoke-VBoxUnlocked startvm $uuid --type headless | Out-Null }
    elseif ($vmState -eq 'paused') { Invoke-VBox controlvm $uuid resume | Out-Null }
    if (-not (Wait-LabSsh -TimeoutMin 25 -FirstBoot:(-not (Get-LabStateValue 'Provisioned')))) {
        throw "Linux did not accept SSH within 25 minutes. See the boot log: $(Join-Path $vmDir 'serial-console.log'). Re-run the installer to resume."
    }
    Write-LabLog 'SSH is up; host key matched the pinned key' -Level OK
    Invoke-LabSsh -Command 'cloud-init status --wait >/dev/null 2>&1; cloud-init status' -AllowFailure -TimeoutSec 900 | Out-Null

    # =====================================================================================
    # 8. Push the course payload and provision inside the VM
    # =====================================================================================
    Write-LabLog 'Installing the course, portal, tutor and lab services inside the VM' -Level STEP
    Write-LabLog 'First install downloads Linux packages inside the VM; Ollama and the tutor model (about 2.5 GB) are fetched on Windows and copied in.'
    $tutorDir = $null
    if (-not $SkipTutorModel) {
        Write-LabLog 'Fetching Ollama and the tutor model on Windows (verified, resumable)'
        $tutorDir = Save-LabTutorAssets
    }
    $payloadHash = Publish-LabPayload -GuestRoot (Join-Path $PSScriptRoot 'guest') -SkipTutorModel:$SkipTutorModel -TimeoutMin $cfg.provisionTimeoutMin -TutorDir $tutorDir
    Set-LabStateValue 'Provisioned' $true | Out-Null
    Set-LabStateValue 'PayloadSha256' $payloadHash | Out-Null
    Write-LabLog 'Course, portal, tutor and lab services installed' -Level OK

    # =====================================================================================
    # 9. Learner password (chosen by the learner; never stored on Windows or in logs)
    # =====================================================================================
    $pwSet = Invoke-LabSsh -Command 'test -f /var/lib/linux-iam-lab/student-password-set && echo YES || echo NO'
    if ($pwSet.Out -match 'NO') {
        Write-LabLog "Choose the password for your Linux account 'student'" -Level STEP
        Write-Host '    You will type this when Linux asks for your password (for example with sudo).'
        Write-Host '    It is set inside the VM only. It is not saved on Windows or written to any log.'
        $plain = $null
        if ($StudentPasswordFile) {
            $plain = (Get-Content -Raw -LiteralPath $StudentPasswordFile).Trim()
        } else {
            while ($true) {
                $a = Read-Host '    New Linux password for student (min 8 characters)' -AsSecureString
                $b = Read-Host '    Type it again' -AsSecureString
                $pa = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($a))
                $pb = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($b))
                if ($pa -ne $pb) { Write-Host '    The two entries differ. Try again.' -ForegroundColor Yellow; continue }
                if ($pa.Length -lt 8 -or $pa -match '[:\r\n]') { Write-Host '    Use at least 8 characters and no colon.' -ForegroundColor Yellow; continue }
                $plain = $pa; break
            }
        }
        Invoke-LabSsh -Command 'sudo -n chpasswd && sudo -n passwd -u student >/dev/null && sudo -n touch /var/lib/linux-iam-lab/student-password-set && echo DONE' -InputText ("student:" + $plain + "`n") | Out-Null
        $plain = $null
        Write-LabLog 'Password for student set inside the VM' -Level OK
    }

    # =====================================================================================
    # 10. Self-test inside the VM
    # =====================================================================================
    Write-LabLog 'Running the lab self-test inside the VM' -Level STEP
    $st = Invoke-LabSsh -Command 'sudo -n /opt/linux-iam-lab/bin/lab selftest' -AllowFailure -TimeoutSec 600
    foreach ($l in ($st.Out -split "`n")) { if ($l.Trim()) { Write-LabLog ("  " + $l.Trim()) } }
    if ($st.Code -ne 0) { throw 'The in-VM self-test failed. See the lines above and the log.' }
    if (-not (Wait-LabPortal -TimeoutMin 3)) { throw "The portal did not answer on http://127.0.0.1:$($state.PortalPort)." }
    Write-LabLog 'Portal reachable from Windows through the localhost port forward' -Level OK

    # =====================================================================================
    # 11. Known-good baseline snapshot (of the lab VM only)
    # =====================================================================================
    $snapUuid = Get-LabStateValue 'BaselineSnapshotUuid'
    $haveSnap = $false
    if ($snapUuid) { $haveSnap = ((Invoke-VBoxManage snapshot $uuid showvminfo $snapUuid).Code -eq 0) }
    if (-not $haveSnap) {
        Write-LabLog 'Saving the known-good baseline (powered-off snapshot of the lab VM)' -Level STEP
        Invoke-LabSsh -Command 'sudo -n touch /etc/cloud/cloud-init.disabled; sudo -n sync' -AllowFailure | Out-Null
        Assert-LabVm | Out-Null
        $s = Stop-LabVmGraceful -TimeoutMin 4 -ForceIfNeeded
        if ($s -ne 'poweroff') { throw "Could not power off the lab VM for the baseline snapshot (state $s)." }
        Invoke-VBoxUnlocked storageattach $uuid --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive | Out-Null
        Invoke-VBoxUnlocked snapshot $uuid take $cfg.baselineSnapshot --description "Known-good Linux IAM Lab baseline. Install id $($state.InstallId)" | Out-Null
        $si = Invoke-VBox snapshot $uuid list --machinereadable
        if ($si -match 'CurrentSnapshotUUID="([^"]+)"') { Set-LabStateValue 'BaselineSnapshotUuid' $Matches[1] | Out-Null }
        Set-LabStateValue 'BaselinePayloadSha256' $payloadHash | Out-Null
        Remove-Item -Force -LiteralPath $seedIso -ErrorAction SilentlyContinue
        Write-LabLog "Baseline snapshot '$($cfg.baselineSnapshot)' saved" -Level OK
    } else {
        Write-LabLog 'Baseline snapshot already exists; keeping it (Reset refreshes course files if they changed)' -Level OK
    }

    # =====================================================================================
    # 12. App copy, reference library, shortcuts, SSH config entry
    # =====================================================================================
    Write-LabLog 'Installing shortcuts and the offline reference library' -Level STEP
    if (Test-Path $paths.App) { Remove-Item -Recurse -Force $paths.App }
    New-Item -ItemType Directory -Force -Path $paths.App | Out-Null
    Copy-Item -Recurse -Force (Join-Path $PSScriptRoot 'windows') $paths.App
    Copy-Item -Recurse -Force (Join-Path $PSScriptRoot 'guest') $paths.App
    Copy-Item -Force (Join-Path $PSScriptRoot 'Install-LinuxIAMLab.ps1') $paths.App
    if (Test-Path $paths.Reference) { Remove-Item -Recurse -Force $paths.Reference }
    New-Item -ItemType Directory -Force -Path $paths.Reference | Out-Null
    Copy-Item -Recurse -Force (Join-Path $PSScriptRoot 'docs\offline\*') $paths.Reference -ErrorAction SilentlyContinue
    Copy-Item -Force (Join-Path $PSScriptRoot 'guest\opt\linux-iam-lab\course\reference\*.md') $paths.Reference -ErrorAction SilentlyContinue
    Write-LabLog "Offline reference: $($paths.Reference)" -Level OK

    if (-not $NoShortcuts) {
        $desk = [Environment]::GetFolderPath('Desktop')
        $wsh = New-Object -ComObject WScript.Shell
        $ps = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $defs = @(
            @('Start Linux IAM Lab', 'Start-LinuxIAMLab.ps1', 'Starts the dedicated Linux IAM Lab VM and opens the course portal', 137),
            @('Stop Linux IAM Lab', 'Stop-LinuxIAMLab.ps1', 'Gracefully shuts down only the Linux IAM Lab VM', 27),
            @('Reset Linux IAM Lab', 'Reset-LinuxIAMLab.ps1', 'Explains, confirms and restores the known-good Linux IAM Lab practice environment', 238)
        )
        foreach ($d in $defs) {
            $lnk = $wsh.CreateShortcut((Join-Path $desk "$($d[0]).lnk"))
            $lnk.TargetPath = $ps
            $lnk.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $paths.App "windows\$($d[1])"))
            $lnk.WorkingDirectory = Join-Path $paths.App 'windows'
            $lnk.Description = $d[2]
            $lnk.IconLocation = "$env:WINDIR\System32\shell32.dll,$($d[3])"
            $lnk.Save()
            Write-LabLog "Desktop shortcut: $($d[0])" -Level OK
        }
    }

    if (-not $NoSshConfig) {
        $sshDir = Join-Path $env:USERPROFILE '.ssh'
        $userCfg = Join-Path $sshDir 'config'
        $begin = '# >>> Linux IAM Lab (managed by Install-LinuxIAMLab.ps1) >>>'
        $end = '# <<< Linux IAM Lab <<<'
        $block = @(
            $begin,
            'Host linux-iam-lab',
            '    HostName 127.0.0.1',
            "    Port $($state.SshPort)",
            '    User student',
            ('    IdentityFile "{0}"' -f (ConvertTo-SshPath $paths.StudentKey)),
            '    IdentitiesOnly yes',
            '    HostKeyAlias linux-iam-lab',
            ('    UserKnownHostsFile "{0}"' -f (ConvertTo-SshPath $paths.KnownHosts)),
            '    StrictHostKeyChecking yes',
            $end
        ) -join "`n"
        $existing = ''
        if (Test-Path -LiteralPath $userCfg) { $existing = [IO.File]::ReadAllText($userCfg) }
        $pattern = [regex]::Escape($begin) + '[\s\S]*?' + [regex]::Escape($end)
        if ($existing -match $pattern) { $new = [regex]::Replace($existing, $pattern, $block.Replace('$', '$$')) }
        else { $new = $existing.TrimEnd() + $(if ($existing.Trim()) { "`n`n" } else { '' }) + $block + "`n" }
        [IO.File]::WriteAllText($userCfg, ($new -replace "`r`n", "`n"), (New-Object Text.ASCIIEncoding))
        Write-LabLog "Added 'Host linux-iam-lab' to $userCfg (manual SSH: ssh linux-iam-lab)" -Level OK
    }

    Set-LabStateValue 'InstalledAt' (Get-Date).ToString('s') | Out-Null
    Set-LabStateValue 'Phase' 'complete' | Out-Null
    $mins = ((Get-Date) - $started).TotalMinutes
    Write-LabLog ("Installation complete in {0:N0} minutes" -f $mins) -Level STEP
    Write-Host ''
    Write-Host '  Desktop shortcuts: Start Linux IAM Lab, Stop Linux IAM Lab, Reset Linux IAM Lab' -ForegroundColor Green
    Write-Host "  Manual SSH from Windows Terminal:  ssh linux-iam-lab" -ForegroundColor Green
    Write-Host "  VM host key fingerprint:           $($state.HostKeyFingerprint)"
    Write-Host "  Offline reference:                 $($paths.Reference)"
    Write-Host "  Install log:                       $log"
    Write-Host ''
    if (-not $NoLaunch -and [Environment]::UserInteractive -and -not $env:LINUXIAMLAB_NONINTERACTIVE) {
        $ans = Read-Host '  Start the lab now? [Y/n]'
        if ($ans -notmatch '^[nN]') { & (Join-Path $paths.App 'windows\Start-LinuxIAMLab.ps1') }
    }
    exit 0
} catch {
    Write-LabLog ("Install stopped: " + $_.Exception.Message) -Level ERROR
    Write-LabLog ($_.ScriptStackTrace) -Quiet
    try {
        if (Get-LabStateValue 'VmUuid') {
            $vmlog = Invoke-LabSsh -Command 'sudo -n tail -n 60 /var/log/linux-iam-lab/provision.log' -AllowFailure -TimeoutSec 20
            if ($vmlog.Code -eq 0) { Write-LabLog ("Last VM provisioning lines:`n" + $vmlog.Out) -Quiet }
        }
    } catch { }
    Write-Host ''
    Write-Host '  The installer stopped safely. Nothing outside the lab VM was changed.' -ForegroundColor Yellow
    Write-Host '  Fix the problem shown above, then run the same command again: finished steps are skipped.' -ForegroundColor Yellow
    Write-Host "  Log: $log"
    Pause-IfInteractive
    exit 1
}
