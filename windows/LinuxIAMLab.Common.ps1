<#
.SYNOPSIS
    Shared helpers for the Linux IAM Lab. Dot-source this file.
.DESCRIPTION
    Every lifecycle action goes through Assert-LabVm, which refuses to act unless the
    VirtualBox VM matches the UUID, name and install id recorded in state.json at install
    time. No function in this file enumerates other VMs in order to act on them.
    Keep this file ASCII: Windows PowerShell 5.1 runs it.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:LabRoot = $PSScriptRoot
$script:LabLogFile = $null
$script:PanicRetries = 0

# ---------------------------------------------------------------- config / paths / state

function Expand-LabPath([string]$Path) { return [Environment]::ExpandEnvironmentVariables($Path) }

function Get-LabConfig {
    $cfg = Get-Content -Raw -LiteralPath (Join-Path $script:LabRoot 'lab.config.json') | ConvertFrom-Json
    foreach ($k in 'vmBaseFolder', 'dataDir', 'learnerDir') { $cfg.$k = Expand-LabPath $cfg.$k }
    return $cfg
}

function Get-LabPaths {
    $cfg = Get-LabConfig
    $d = $cfg.dataDir
    $p = [ordered]@{
        Data       = $d
        State      = Join-Path $d 'state.json'
        Logs       = Join-Path $d 'logs'
        Keys       = Join-Path $d 'keys'
        Cache      = Join-Path $d 'cache'
        Seed       = Join-Path $d 'seed'
        App        = Join-Path $d 'app'
        KnownHosts = Join-Path $d 'known_hosts'
        SshConfig  = Join-Path $d 'ssh_config'
        CtlKey     = Join-Path $d 'keys\labctl_ed25519'
        Learner    = $cfg.learnerDir
        Exports    = Join-Path $cfg.learnerDir 'Exports'
        Reference  = Join-Path $cfg.learnerDir 'Reference'
        StudentKey = Join-Path $env:USERPROFILE '.ssh\linux-iam-lab_student_ed25519'
    }
    return [pscustomobject]$p
}

function Initialize-LabFolders {
    $p = Get-LabPaths
    foreach ($d in $p.Data, $p.Logs, $p.Keys, $p.Cache, $p.Seed, $p.Learner, $p.Exports) {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    }
}

function Get-LabState {
    $p = Get-LabPaths
    if (-not (Test-Path -LiteralPath $p.State)) { return $null }
    return (Get-Content -Raw -LiteralPath $p.State | ConvertFrom-Json)
}

function Save-LabState($State) {
    $p = Get-LabPaths
    $tmp = "$($p.State).tmp"
    ($State | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $tmp -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $p.State -Force
}

function Set-LabStateValue([string]$Name, $Value) {
    $s = Get-LabState
    if (-not $s) { $s = [pscustomobject]@{} }
    if ($s.PSObject.Properties[$Name]) { $s.$Name = $Value } else { $s | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
    Save-LabState $s
    return $s
}

function Get-LabStateValue([string]$Name) {
    $s = Get-LabState
    if ($s -and $s.PSObject.Properties[$Name]) { return $s.$Name }
    return $null
}

# ---------------------------------------------------------------- logging (with redaction)

function Protect-LabText([string]$Text) {
    if (-not $Text) { return $Text }
    $t = $Text
    $t = [regex]::Replace($t, '-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----', '[REDACTED PRIVATE KEY]')
    $t = [regex]::Replace($t, '(?i)(password|passwd|token|secret)(\s*[:=]\s*)\S+', '$1$2[REDACTED]')
    $t = [regex]::Replace($t, '\$(1|5|6|y|2b)\$[^\s:]+', '[REDACTED HASH]')
    $t = [regex]::Replace($t, '(?i)([?&]token=)[A-Za-z0-9_-]+', '$1[REDACTED]')
    return $t
}

function Start-LabLog([string]$Name) {
    Initialize-LabFolders
    $p = Get-LabPaths
    $script:LabLogFile = Join-Path $p.Logs ("{0}-{1}.log" -f $Name, (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Write-LabLog "=== $Name started by $env:USERNAME on $env:COMPUTERNAME (PowerShell $($PSVersionTable.PSVersion)) ==="
    # keep the 30 newest logs
    Get-ChildItem -LiteralPath $p.Logs -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -Skip 30 |
        Remove-Item -Force -ErrorAction SilentlyContinue
    return $script:LabLogFile
}

function Write-LabLog([string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR', 'STEP', 'OK')][string]$Level = 'INFO', [switch]$Quiet) {
    $safe = Protect-LabText $Message
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $safe
    if ($script:LabLogFile) { Add-Content -LiteralPath $script:LabLogFile -Value $line -Encoding UTF8 }
    if ($Quiet) { return }
    switch ($Level) {
        'STEP' { Write-Host "`n==> $safe" -ForegroundColor Cyan }
        'OK' { Write-Host "    [ok] $safe" -ForegroundColor Green }
        'WARN' { Write-Host "    [warning] $safe" -ForegroundColor Yellow }
        'ERROR' { Write-Host "    [error] $safe" -ForegroundColor Red }
        default { Write-Host "    $safe" }
    }
}

# ---------------------------------------------------------------- native process helper

function Invoke-NativeRaw {
    <#
        Runs an exe with a raw argument string (no PowerShell re-quoting, so "" really is an
        empty argument on 5.1 and 7.x alike). Returns Code/Out/Err. Optional stdin text is
        written to the process and never appears on a command line or in the log.
    #>
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$Arguments = '',
        [string]$InputText = $null,
        [int]$TimeoutSec = 600
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    # .NET Framework builds the stdin writer from [Console]::InputEncoding and writes its BOM at once;
    # use BOM-less UTF-8 while starting the process.
    $prevIn = $null
    try { $prevIn = [Console]::InputEncoding; [Console]::InputEncoding = New-Object Text.UTF8Encoding($false) } catch { }
    try { $proc = [System.Diagnostics.Process]::Start($psi) }
    finally { if ($prevIn) { try { [Console]::InputEncoding = $prevIn } catch { } } }
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    # Write raw UTF-8 bytes (no BOM): the .NET Framework StreamWriter used by Windows PowerShell 5.1
    # would otherwise prepend U+FEFF, which turns "student:..." into an unknown user for chpasswd.
    $bs = $proc.StandardInput.BaseStream
    if ($InputText) {
        $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($InputText)
        $bs.Write($bytes, 0, $bytes.Length)
        $bs.Flush()
    }
    $bs.Close()
    if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
        try { $proc.Kill() } catch { }
        return [pscustomobject]@{ Code = 124; Out = ''; Err = "Timed out after $TimeoutSec s" }
    }
    $proc.WaitForExit()
    return [pscustomobject]@{ Code = $proc.ExitCode; Out = $outTask.Result; Err = $errTask.Result }
}

function Quote-Arg([string]$s) {
    if ($s -eq '') { return '""' }
    if ($s -notmatch '[\s"]') { return $s }
    return '"' + ($s -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

function Find-Tool([string]$Name, [string[]]$Extra = @()) {
    $c = Get-Command $Name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($e in $Extra) { if (Test-Path -LiteralPath $e) { return $e } }
    return $null
}

# ---------------------------------------------------------------- VirtualBox

function Find-VBoxManage {
    $cands = @()
    if ($env:VBOX_MSI_INSTALL_PATH) { $cands += (Join-Path $env:VBOX_MSI_INSTALL_PATH 'VBoxManage.exe') }
    try {
        $reg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Oracle\VirtualBox' -ErrorAction Stop
        if ($reg.InstallDir) { $cands += (Join-Path $reg.InstallDir 'VBoxManage.exe') }
    } catch { }
    $cands += 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
    foreach ($c in $cands) { if (Test-Path -LiteralPath $c) { return $c } }
    return $null
}

function Invoke-VBoxManage {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $vbox = Find-VBoxManage
    if (-not $vbox) { throw 'VBoxManage.exe not found. Install Oracle VirtualBox 7.x first.' }
    $argString = ($Arguments | ForEach-Object { Quote-Arg $_ }) -join ' '
    $r = Invoke-NativeRaw -FilePath $vbox -Arguments $argString -TimeoutSec 900
    Write-LabLog ("VBoxManage {0} -> exit {1}" -f ($Arguments -join ' '), $r.Code) -Quiet
    if ($r.Code -ne 0 -and $r.Err) { Write-LabLog ("VBoxManage stderr: " + $r.Err.Trim()) -Quiet }
    return $r
}

function Invoke-VBox {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $r = Invoke-VBoxManage @Arguments
    if ($r.Code -ne 0) { throw ("VBoxManage {0} failed (exit {1}): {2}" -f $Arguments[0], $r.Code, ($r.Err + $r.Out).Trim()) }
    return $r.Out
}

function Get-VBoxVmInfo([string]$Id) {
    # Returns a hashtable of 'showvminfo --machinereadable' or $null if the VM does not exist.
    $r = Invoke-VBoxManage showvminfo $Id --machinereadable
    if ($r.Code -ne 0) { return $null }
    $h = @{}
    foreach ($line in ($r.Out -split "`r?`n")) {
        if ($line -match '^"?([^"=]+)"?="?(.*?)"?$') { $h[$Matches[1]] = $Matches[2] }
    }
    return $h
}

function Get-VBoxExtraData([string]$Id, [string]$Key) {
    $r = Invoke-VBoxManage getextradata $Id $Key
    if ($r.Code -ne 0) { return $null }
    if ($r.Out -match 'Value:\s*(.+)') { return $Matches[1].Trim() }
    return $null
}

function Assert-LabVm {
    <#
        Identity gate used by every lifecycle script. Returns the VM info hashtable only when
        UUID, name and the install-id extradata all match what install recorded.
    #>
    $state = Get-LabState
    if (-not $state -or -not $state.PSObject.Properties['VmUuid'] -or -not $state.VmUuid) {
        throw 'No Linux IAM Lab VM is recorded on this PC. Run Install-LinuxIAMLab.ps1 first.'
    }
    $info = Get-VBoxVmInfo $state.VmUuid
    if (-not $info) { throw "The recorded lab VM ($($state.VmUuid)) no longer exists in VirtualBox. Re-run Install-LinuxIAMLab.ps1." }
    if ($info['UUID'] -ne $state.VmUuid) { throw "Refusing to act: VM UUID mismatch (expected $($state.VmUuid), got $($info['UUID']))." }
    if ($info['name'] -ne $state.VmName) { throw "Refusing to act: VM $($state.VmUuid) is named '$($info['name'])', expected '$($state.VmName)'." }
    $tag = Get-VBoxExtraData $state.VmUuid 'LinuxIAMLab/InstallId'
    if ($tag -ne $state.InstallId) { throw "Refusing to act: VM $($state.VmUuid) does not carry this lab's install id." }
    return $info
}

function Get-LabVmState {
    $state = Get-LabState
    $info = Get-VBoxVmInfo $state.VmUuid
    if (-not $info) { return 'missing' }
    return $info['VMState']
}

# ---------------------------------------------------------------- SSH to the lab VM

function Get-SshExe { return (Find-Tool 'ssh.exe' @("$env:WINDIR\System32\OpenSSH\ssh.exe")) }
function Get-ScpExe { return (Find-Tool 'scp.exe' @("$env:WINDIR\System32\OpenSSH\scp.exe")) }
function Get-SshKeygenExe { return (Find-Tool 'ssh-keygen.exe' @("$env:WINDIR\System32\OpenSSH\ssh-keygen.exe")) }

function ConvertTo-SshPath([string]$p) { return ($p -replace '\\', '/') }

function Write-LabSshConfig {
    # Private ssh config used by the automation account (labctl). Host key is pinned.
    $p = Get-LabPaths
    $cfg = Get-LabConfig
    $port = (Get-LabStateValue 'SshPort'); if (-not $port) { $port = $cfg.hostPorts.ssh }
    $lines = @(
        'Host linux-iam-lab-ctl',
        '    HostName 127.0.0.1',
        "    Port $port",
        '    User labctl',
        ('    IdentityFile "{0}"' -f (ConvertTo-SshPath $p.CtlKey)),
        '    IdentitiesOnly yes',
        '    HostKeyAlias linux-iam-lab',
        ('    UserKnownHostsFile "{0}"' -f (ConvertTo-SshPath $p.KnownHosts)),
        '    StrictHostKeyChecking yes',
        '    BatchMode yes',
        '    ConnectTimeout 8',
        '    ServerAliveInterval 15',
        '    LogLevel ERROR'
    )
    [IO.File]::WriteAllText($p.SshConfig, (($lines -join "`n") + "`n"), (New-Object Text.ASCIIEncoding))
}

function Invoke-LabSsh {
    param([Parameter(Mandatory)][string]$Command, [string]$InputText = $null, [int]$TimeoutSec = 300, [switch]$AllowFailure)
    $p = Get-LabPaths
    $sshArgs = '-F {0} linux-iam-lab-ctl {1}' -f (Quote-Arg $p.SshConfig), (Quote-Arg $Command)
    $r = Invoke-NativeRaw -FilePath (Get-SshExe) -Arguments $sshArgs -InputText $InputText -TimeoutSec $TimeoutSec
    Write-LabLog ("ssh labctl: {0} -> exit {1}" -f $Command, $r.Code) -Quiet
    if ($r.Code -ne 0 -and -not $AllowFailure) {
        throw ("Command in the lab VM failed (exit {0}): {1}`n{2}" -f $r.Code, $Command, (Protect-LabText ($r.Err + $r.Out).Trim()))
    }
    return $r
}

function Copy-ToLabVm([string]$LocalPath, [string]$RemotePath) {
    $p = Get-LabPaths
    $sshArgs = '-F {0} -q {1} {2}' -f (Quote-Arg $p.SshConfig), (Quote-Arg $LocalPath), (Quote-Arg "linux-iam-lab-ctl:$RemotePath")
    $r = Invoke-NativeRaw -FilePath (Get-ScpExe) -Arguments $sshArgs -TimeoutSec 900
    if ($r.Code -ne 0) { throw "Copy to the lab VM failed: $($r.Err.Trim())" }
}

function Copy-FromLabVm([string]$RemotePath, [string]$LocalPath) {
    $p = Get-LabPaths
    $sshArgs = '-F {0} -q {1} {2}' -f (Quote-Arg $p.SshConfig), (Quote-Arg "linux-iam-lab-ctl:$RemotePath"), (Quote-Arg $LocalPath)
    $r = Invoke-NativeRaw -FilePath (Get-ScpExe) -Arguments $sshArgs -TimeoutSec 900
    if ($r.Code -ne 0) { throw "Copy from the lab VM failed: $($r.Err.Trim())" }
}

function Wait-LabSsh([int]$TimeoutMin = 20, [switch]$FirstBoot) {
    $deadline = (Get-Date).AddMinutes($TimeoutMin)
    $n = 0
    while ((Get-Date) -lt $deadline) {
        $r = Invoke-LabSsh -Command 'echo ready' -AllowFailure -TimeoutSec 30
        if ($r.Code -eq 0 -and $r.Out -match 'ready') { return $true }
        if ($r.Err -match 'REMOTE HOST IDENTIFICATION HAS CHANGED|Host key verification failed') {
            # On the very first boot sshd may answer for a moment before cloud-init installs the
            # pinned host key; never accept the other key, just keep waiting.
            if (-not $FirstBoot) {
                throw 'The lab VM presented an unexpected SSH host key. Refusing to continue (see README: Troubleshooting > host key).'
            }
            Write-LabLog 'Host key not yet the pinned one (first boot); waiting' -Quiet
        }
        $n++
        if ($n % 4 -eq 0) {
            Write-Host ("    waiting for Linux to boot ({0})" -f (Get-Date -Format HH:mm:ss))
            if (Repair-LabBootPanic) { $deadline = $deadline.AddMinutes(5) }
        }
        Start-Sleep -Seconds 10
    }
    return $false
}

function Repair-LabBootPanic {
    <#
        On this kind of host (VirtualBox on top of Hyper-V) a Linux boot can occasionally panic in
        early timer setup. If the lab VM's serial console shows a kernel panic, power-cycle THE LAB
        VM ONLY (identity verified), at most 3 times per session.
    #>
    if ($script:PanicRetries -ge 3) { return $false }
    $cfg = Get-LabConfig
    $state = Get-LabState
    $log = Join-Path (Join-Path $cfg.vmBaseFolder $state.VmName) 'serial-console.log'
    if (-not (Test-Path -LiteralPath $log)) { return $false }
    $tail = ''
    try { $tail = [IO.File]::ReadAllText($log) } catch { return $false }
    if ($tail -notmatch 'end Kernel panic') { return $false }
    $script:PanicRetries++
    Write-LabLog "Linux hit a boot-time kernel panic (known VirtualBox-on-Hyper-V timer issue); restarting the lab VM (attempt $($script:PanicRetries) of 3)" -Level WARN
    Assert-LabVm | Out-Null
    Invoke-VBoxManage controlvm $state.VmUuid poweroff | Out-Null
    Start-Sleep -Seconds 3
    Invoke-VBoxUnlocked startvm $state.VmUuid --type headless | Out-Null
    return $true
}

function Wait-LabPortal([int]$TimeoutMin = 10) {
    $port = Get-LabStateValue 'PortalPort'
    $deadline = (Get-Date).AddMinutes($TimeoutMin)
    while ((Get-Date) -lt $deadline) {
        try {
            $resp = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$port/api/health" -TimeoutSec 5
            if ($resp.StatusCode -eq 200) { return $true }
        } catch { }
        Start-Sleep -Seconds 5
    }
    return $false
}

function Stop-LabVmGraceful([int]$TimeoutMin = 4, [switch]$ForceIfNeeded) {
    # Only ever called after Assert-LabVm. Acts on the recorded UUID only.
    $state = Get-LabState
    $vmState = Get-LabVmState
    if ($vmState -in @('poweroff', 'aborted', 'saved', 'missing')) { return $vmState }
    Write-LabLog 'Asking Linux to shut down (systemctl poweroff)'
    Invoke-LabSsh -Command 'sudo -n systemctl poweroff' -AllowFailure -TimeoutSec 30 | Out-Null
    $deadline = (Get-Date).AddMinutes($TimeoutMin)
    $pressed = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5
        $vmState = Get-LabVmState
        if ($vmState -eq 'poweroff') { return 'poweroff' }
        if (-not $pressed -and ((Get-Date) -gt $deadline.AddMinutes(-$TimeoutMin + 1))) {
            Write-LabLog 'Sending ACPI power button to the lab VM'
            Invoke-VBoxManage controlvm $state.VmUuid acpipowerbutton | Out-Null
            $pressed = $true
        }
    }
    if ($ForceIfNeeded) {
        Write-LabLog 'Lab VM did not stop in time; powering off the lab VM only' -Level WARN
        Invoke-VBoxManage controlvm $state.VmUuid poweroff | Out-Null
        Start-Sleep -Seconds 3
        return (Get-LabVmState)
    }
    return (Get-LabVmState)
}

function Test-PortFree([int]$Port) {
    $l = $null
    try {
        $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
        $l.Start()
        return $true
    } catch { return $false } finally { if ($l) { $l.Stop() } }
}

function Get-PortalUrl {
    $s = Get-LabState
    return ('http://127.0.0.1:{0}/?token={1}' -f $s.PortalPort, $s.PortalToken)
}

function Get-RandomToken([int]$Bytes = 20) {
    $b = New-Object byte[] $Bytes
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($b) } finally { $rng.Dispose() }
    return (($b | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Invoke-VBoxUnlocked {
    # Retries while VirtualBox still holds the session lock it keeps briefly after power-off.
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $deadline = (Get-Date).AddMinutes(2)
    while ($true) {
        $r = Invoke-VBoxManage @Arguments
        if ($r.Code -eq 0) { return $r.Out }
        $locked = ($r.Err + $r.Out) -match 'already locked|is locked|VBOX_E_INVALID_OBJECT_STATE'
        if (-not $locked -or (Get-Date) -gt $deadline) {
            throw ("VBoxManage {0} failed (exit {1}): {2}" -f $Arguments[0], $r.Code, ($r.Err + $r.Out).Trim())
        }
        Start-Sleep -Seconds 3
    }
}

function Export-LabLearnerData {
    <# Copies progress, learner home and evidence out of the VM. Returns the folder. #>
    param([string]$Reason = 'manual')
    $p = Get-LabPaths
    $dir = Join-Path $p.Exports ("{0}-{1}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $Reason)
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Invoke-LabSsh -Command 'sudo -n /opt/linux-iam-lab/bin/lab export-bundle /tmp/lab-export.tar.gz' -TimeoutSec 300 | Out-Null
    $tgz = Join-Path $dir 'lab-export.tar.gz'
    Copy-FromLabVm '/tmp/lab-export.tar.gz' $tgz
    Invoke-LabSsh -Command 'sudo -n rm -f /tmp/lab-export.tar.gz' -AllowFailure | Out-Null
    $tar = Find-Tool 'tar.exe' @("$env:WINDIR\System32\tar.exe")
    if ($tar) { Invoke-NativeRaw -FilePath $tar -Arguments ('-xzf {0} -C {1}' -f (Quote-Arg $tgz), (Quote-Arg $dir)) | Out-Null }
    return $dir
}

function Get-LabPayloadHash([string]$GuestRoot) {
    # Content hash of the guest payload: relative path + bytes of every file, sorted.
    $sha = [Security.Cryptography.SHA256]::Create()
    $ms = New-Object IO.MemoryStream
    $files = Get-ChildItem -Recurse -File -LiteralPath $GuestRoot | Sort-Object { $_.FullName.Substring($GuestRoot.Length).Replace('\', '/') }
    foreach ($f in $files) {
        $rel = [Text.Encoding]::UTF8.GetBytes($f.FullName.Substring($GuestRoot.Length).Replace('\', '/'))
        $ms.Write($rel, 0, $rel.Length)
        $c = [IO.File]::ReadAllBytes($f.FullName); $ms.Write($c, 0, $c.Length)
    }
    return (($sha.ComputeHash($ms.ToArray()) | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Save-LabTutorAssets {
    <#
        Downloads Ollama for Linux and the tutor model ON WINDOWS (fast, resumable), verifies
        them (Ollama: sha256sum.txt of the same GitHub release; model: the registry's sha256
        digests), and returns the folder. The VM's nested NAT is slow and drops long downloads.
    #>
    $cfg = Get-LabConfig
    $paths = Get-LabPaths
    $dir = Join-Path $paths.Cache 'tutor'
    New-Item -ItemType Directory -Force -Path (Join-Path $dir 'blobs') | Out-Null
    $curl = Find-Tool 'curl.exe' @("$env:WINDIR\System32\curl.exe")
    function Get-Url([string]$Url, [string]$Out) {
        $p = Start-Process -FilePath $curl -ArgumentList @('-fL', '--retry', '5', '--retry-delay', '5', '-C', '-', '-o', "`"$Out`"", $Url) -NoNewWindow -Wait -PassThru
        if ($p.ExitCode -ne 0) { throw "Download failed (curl exit $($p.ExitCode)): $Url. Re-run to resume." }
    }
    # --- Ollama runtime
    $rel = 'https://github.com/ollama/ollama/releases/latest/download'
    $sumsFile = Join-Path $dir 'ollama-sha256sum.txt'
    $r = Invoke-NativeRaw -FilePath $curl -Arguments ('-fsSL --retry 3 -o {0} {1}' -f (Quote-Arg $sumsFile), "$rel/sha256sum.txt") -TimeoutSec 120
    if ($r.Code -ne 0) { throw "Could not download Ollama checksums: $($r.Err)" }
    $line = (Get-Content -LiteralPath $sumsFile) | Where-Object { $_ -match 'ollama-linux-amd64\.tar\.zst$' } | Select-Object -First 1
    if (-not $line) { throw 'ollama-linux-amd64.tar.zst not listed in the Ollama release checksums.' }
    $want = ($line -split '\s+')[0].ToLower()
    $arc = Join-Path $dir 'ollama-linux-amd64.tar.zst'
    $ok = (Test-Path $arc) -and ((Get-FileHash -Algorithm SHA256 -LiteralPath $arc).Hash.ToLower() -eq $want)
    if (-not $ok) {
        Write-LabLog 'Downloading Ollama for Linux (about 1.5 GB) on Windows'
        if ((Test-Path $arc) -and -not (Test-Path "$arc.part")) { Move-Item -Force $arc "$arc.part" }
        Get-Url "$rel/ollama-linux-amd64.tar.zst" "$arc.part"
        $got = (Get-FileHash -Algorithm SHA256 -LiteralPath "$arc.part").Hash.ToLower()
        if ($got -ne $want) { Remove-Item -Force "$arc.part"; throw "Ollama archive SHA-256 mismatch; deleted. Re-run to download again." }
        Move-Item -Force "$arc.part" $arc
    }
    Write-LabLog "Ollama archive verified (sha256 $($want.Substring(0,16))...)" -Level OK
    # --- tutor model from the Ollama registry
    $name, $tag = $cfg.ollamaModel -split ':', 2
    if (-not $tag) { $tag = 'latest' }
    $repo = if ($name -match '/') { $name } else { "library/$name" }
    $manifest = Join-Path $dir 'manifest.json'
    $r = Invoke-NativeRaw -FilePath $curl -Arguments ('-fsSL --retry 3 -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -o {0} {1}' -f (Quote-Arg $manifest), "https://registry.ollama.ai/v2/$repo/manifests/$tag") -TimeoutSec 120
    if ($r.Code -ne 0) { throw "Could not download the model manifest for $($cfg.ollamaModel): $($r.Err)" }
    $m = Get-Content -Raw -LiteralPath $manifest | ConvertFrom-Json
    $layers = @($m.config) + @($m.layers)
    foreach ($l in $layers) {
        $hex = $l.digest -replace '^sha256:', ''
        $blob = Join-Path $dir "blobs\sha256-$hex"
        if ((Test-Path $blob) -and ((Get-FileHash -Algorithm SHA256 -LiteralPath $blob).Hash.ToLower() -eq $hex)) { continue }
        if ($l.size -gt 10MB) { Write-LabLog ("Downloading tutor model layer ({0:N0} MB)" -f ($l.size / 1MB)) }
        Get-Url "https://registry.ollama.ai/v2/$repo/blobs/$($l.digest)" "$blob.part"
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath "$blob.part").Hash.ToLower() -ne $hex) { Remove-Item -Force "$blob.part"; throw "Model layer $hex failed its SHA-256 check." }
        Move-Item -Force "$blob.part" $blob
    }
    [IO.File]::WriteAllText((Join-Path $dir 'model.env'), "MODEL_REPO=$repo`nMODEL_TAG=$tag`n", (New-Object Text.ASCIIEncoding))
    Write-LabLog "Tutor model $($cfg.ollamaModel) verified ($($layers.Count) layers)" -Level OK
    return $dir
}

function Copy-LabTutorAssets([string]$Dir) {
    <#
        Moves the verified tutor files into the VM WITHOUT the network: they are packed into a
        virtual DVD (ISO9660 + Joliet, short names + map file), inserted into the lab VM's DVD drive,
        copied at disk speed, then ejected. VirtualBox NAT on top of Hyper-V manages only ~1 MB/s.
    #>
    $state = Get-LabState
    $paths = Get-LabPaths
    $have = Invoke-LabSsh -Command 'cat /var/tmp/lab-assets/.complete 2>/dev/null; true' -AllowFailure
    $stage = Join-Path $paths.Cache 'tutor-iso'
    if (Test-Path $stage) { Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    Get-ChildItem -LiteralPath $stage -File | Remove-Item -Force -ErrorAction SilentlyContinue
    $map = New-Object System.Collections.Generic.List[string]
    $i = 0
    foreach ($f in @(Get-ChildItem -LiteralPath $Dir -File) + @(Get-ChildItem -LiteralPath (Join-Path $Dir 'blobs') -File)) {
        if ($f.Name -like '*.part') { continue }
        $short = 'f{0:D2}.bin' -f $i; $i++
        $rel = if ($f.DirectoryName -like '*\blobs') { "blobs/$($f.Name)" } else { $f.Name }
        $map.Add("$short $rel")
        New-Item -ItemType HardLink -Path (Join-Path $stage $short) -Target $f.FullName | Out-Null
    }
    $mapText = ($map -join "`n") + "`n"
    [IO.File]::WriteAllText((Join-Path $stage 'MAP.TXT'), $mapText, (New-Object Text.ASCIIEncoding))
    if ($have.Out -and $have.Out.Trim() -eq ($map -join ';').Length.ToString()) { Write-LabLog 'Tutor files already inside the VM' -Level OK; Remove-Item -Recurse -Force $stage; return }
    $iso = Join-Path $paths.Cache 'lab-tutor-assets.iso'
    Write-LabLog 'Packing Ollama and the tutor model into a virtual disc'
    if (Test-Path $iso) { Remove-Item -Force $iso }
    New-LabSeedIso -SourceDir $stage -IsoPath $iso -VolumeName 'LABASSETS'
    Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
    Invoke-LabSsh -Command 'sudo -n touch /etc/cloud/cloud-init.disabled' | Out-Null   # seed disc no longer needed
    Invoke-VBox storageattach $state.VmUuid --storagectl SATA --port 1 --device 0 --type dvddrive --medium $iso --forceunmount | Out-Null
    try {
        Write-LabLog 'Copying the tutor files from the virtual disc into the VM'
        $cmd = 'set -e; for i in $(seq 1 30); do sudo -n blkid -L LABASSETS >/dev/null 2>&1 && break; sleep 2; done; ' +
            'sudo -n mkdir -p /mnt/lab-assets /var/tmp/lab-assets/blobs; sudo -n mount -o ro "$(sudo -n blkid -L LABASSETS)" /mnt/lab-assets; ' +
            'while read -r s r; do [ -n "$s" ] && sudo -n cp "/mnt/lab-assets/$s" "/var/tmp/lab-assets/$r"; done < /mnt/lab-assets/MAP.TXT; ' +
            'sudo -n umount /mnt/lab-assets; echo ' + ($map -join ';').Length + ' | sudo -n tee /var/tmp/lab-assets/.complete >/dev/null; du -sh /var/tmp/lab-assets'
        $r = Invoke-LabSsh -Command $cmd -TimeoutSec 1800
        Write-LabLog ("Tutor files copied: " + $r.Out.Trim()) -Level OK
    } finally {
        Invoke-VBoxManage storageattach $state.VmUuid --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive --forceunmount | Out-Null
        Remove-Item -Force $iso -ErrorAction SilentlyContinue
    }
}
function Publish-LabPayload {
    <#
        Packs guest\ plus per-install settings, copies it into the VM and runs provision.sh as a
        transient systemd unit (so an SSH drop or a closed window does not kill it). Polls the
        VM log until it reports RESULT=OK or RESULT=FAIL. Returns the payload hash.
    #>
    param([Parameter(Mandatory)][string]$GuestRoot, [switch]$SkipTutorModel, [int]$TimeoutMin = 120, [string]$TutorDir)
    $paths = Get-LabPaths
    $cfg = Get-LabConfig
    $state = Get-LabState
    $stage = Join-Path $paths.Cache 'payload'
    if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    Copy-Item -Recurse -Force -Path (Join-Path $GuestRoot '*') -Destination $stage
    $inst = Join-Path $stage 'install'
    New-Item -ItemType Directory -Force -Path $inst | Out-Null
    $hash = Get-LabPayloadHash $GuestRoot
    $settings = @(
        "PORTAL_TOKEN=$($state.PortalToken)",
        "OLLAMA_MODEL=$($cfg.ollamaModel)",
        "SKIP_TUTOR_MODEL=$([int][bool]$SkipTutorModel)",
        "HOST_SSH_PORT=$($state.SshPort)",
        "HOST_PORTAL_PORT=$($state.PortalPort)",
        "HOST_TERMINAL_PORT=$($state.TerminalPort)",
        "HOST_KEY_FINGERPRINT=$($state.HostKeyFingerprint)",
        "PAYLOAD_SHA256=$hash"
    )
    [IO.File]::WriteAllText((Join-Path $inst 'settings.env'), (($settings -join "`n") + "`n"), (New-Object Text.ASCIIEncoding))
    Copy-Item -LiteralPath "$($paths.StudentKey).pub" -Destination (Join-Path $inst 'student.pub')
    $tgz = Join-Path $paths.Cache 'payload.tar.gz'
    $tar = Find-Tool 'tar.exe' @("$env:WINDIR\System32\tar.exe")
    $r = Invoke-NativeRaw -FilePath $tar -Arguments ('-czf {0} -C {1} .' -f (Quote-Arg $tgz), (Quote-Arg $stage))
    if ($r.Code -ne 0) { throw "Packing the course payload failed: $($r.Err)" }
    Remove-Item -Recurse -Force $stage
    Copy-ToLabVm $tgz '/tmp/linux-iam-lab-payload.tar.gz'
    if ($TutorDir) { Copy-LabTutorAssets $TutorDir }
    $bootstrap = 'set -e; sudo -n rm -rf /tmp/lab-src; sudo -n mkdir -p /tmp/lab-src; ' +
        'sudo -n tar -xzf /tmp/linux-iam-lab-payload.tar.gz -C /tmp/lab-src; ' +
        'sudo -n find /tmp/lab-src -type f -exec sed -i "s/\r$//" {} +; ' +
        'sudo -n systemctl reset-failed lab-provision.service >/dev/null 2>&1 || true; ' +
        'if systemctl is-active --quiet lab-provision.service; then echo ALREADY_RUNNING; else ' +
        'sudo -n rm -f /var/lib/linux-iam-lab/provision.result; ' +
        'sudo -n systemd-run --unit=lab-provision --description="Linux IAM Lab provisioning" --property=TimeoutStartSec=infinity /bin/bash /tmp/lab-src/provision.sh /tmp/lab-src; echo STARTED; fi'
    $r = Invoke-LabSsh -Command $bootstrap -TimeoutSec 300
    Write-LabLog ('Provisioning: ' + $r.Out.Trim()) -Quiet
    $deadline = (Get-Date).AddMinutes($TimeoutMin)
    $shown = 0
    $result = ''
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 10
        $tailCmd = "sudo -n tail -n +$($shown + 1) /var/log/linux-iam-lab/provision.log 2>/dev/null; echo __STATE__; systemctl is-active lab-provision.service; cat /var/lib/linux-iam-lab/provision.result 2>/dev/null; true"
        $t = Invoke-LabSsh -Command $tailCmd -AllowFailure -TimeoutSec 60
        if ($t.Code -ne 0 -or $t.Out -notmatch '__STATE__') { continue }
        $parts = $t.Out -split '__STATE__'
        $new = @(($parts[0] -split "`n") | Where-Object { $_ -ne '' })
        foreach ($l in $new) {
            Write-LabLog ('  vm> ' + $l) -Quiet
            if ($l -match '^\[(STEP|OK|WARN|ERROR)\] (.*)') {
                $c = @{ STEP = 'Cyan'; OK = 'Green'; WARN = 'Yellow'; ERROR = 'Red' }[$Matches[1]]
                Write-Host ('    vm> ' + (Protect-LabText $Matches[2])) -ForegroundColor $c
            }
        }
        $shown += $new.Count
        $st = $parts[1]
        if ($st -match 'RESULT=OK') { $result = 'OK'; break }
        if ($st -match 'RESULT=FAIL') { $result = 'FAIL'; break }
        if ($st -match '(?m)^\s*(inactive|failed)\s*$') {
            Start-Sleep -Seconds 3
            $t2 = Invoke-LabSsh -Command 'cat /var/lib/linux-iam-lab/provision.result 2>/dev/null; true' -AllowFailure
            if ($t2.Out -match 'RESULT=OK') { $result = 'OK' } else { $result = 'FAIL' }
            break
        }
    }
    if (-not $result) { $result = 'TIMEOUT' }
    if ($result -ne 'OK') { throw "Provisioning inside the VM did not finish ($result). Details are in the log; re-run to resume." }
    return $hash
}

function New-LabSeedIso {
    <#
        Builds a cloud-init NoCloud seed ISO (ISO9660 + Joliet, volume label CIDATA) from a folder
        with Windows' built-in IMAPI2 COM component - no extra tools needed.
    #>
    param([Parameter(Mandatory)][string]$SourceDir, [Parameter(Mandatory)][string]$IsoPath, [string]$VolumeName = 'CIDATA')
    if (-not ('LinuxIamLab.IsoWriter' -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Runtime.InteropServices.ComTypes;
namespace LinuxIamLab {
  public static class IsoWriter {
    public static void Write(string path, object stream, int blockSize, int totalBlocks) {
      IStream s = (IStream)stream;
      byte[] buf = new byte[blockSize];
      using (FileStream fs = File.Create(path)) {
        for (int i = 0; i < totalBlocks; i++) {
          s.Read(buf, blockSize, IntPtr.Zero);
          fs.Write(buf, 0, blockSize);
        }
      }
    }
  }
}
"@
    }
    $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
    $fsi.FileSystemsToCreate = 3   # ISO9660 + Joliet (Linux reads the Joliet names)
    $fsi.VolumeName = $VolumeName
    $fsi.FreeMediaBlocks = 0      # no CD/DVD size cap (the tutor disc is ~2.5 GB)
    $fsi.Root.AddTree($SourceDir, $false)
    $res = $fsi.CreateResultImage()
    $stream = $res.ImageStream
    try { [LinuxIamLab.IsoWriter]::Write($IsoPath, $stream, $res.BlockSize, $res.TotalBlocks) }
    finally {
        # IMAPI keeps the source files open until its COM objects are released.
        foreach ($o in @($stream, $res, $fsi)) { if ($o) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($o) } }
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    }
}

function Pause-IfInteractive([string]$Message = 'Press Enter to close this window') {
    if ([Environment]::UserInteractive -and -not $env:LINUXIAMLAB_NONINTERACTIVE) {
        try { [void](Read-Host $Message) } catch { }
    }
}
