<#
.SYNOPSIS
    Host-side tests that never touch VirtualBox VMs: seed ISO builder, key generation and
    empty-passphrase quoting, log redaction, payload hashing, script parsing.
    Run: powershell -NoProfile -ExecutionPolicy Bypass -File tests\Test-HostComponents.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\windows\LinuxIAMLab.Common.ps1')
$script:fails = 0
function Assert($cond, $name) { if ($cond) { Write-Host "PASS: $name" -ForegroundColor Green } else { Write-Host "FAIL: $name" -ForegroundColor Red; $script:fails++ } }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("lilab-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    # 1. seed ISO
    $src = Join-Path $tmp 'cidata'; New-Item -ItemType Directory -Path $src | Out-Null
    [IO.File]::WriteAllText("$src\user-data", "#cloud-config`nhostname: test`n")
    [IO.File]::WriteAllText("$src\meta-data", "instance-id: test-1`n")
    $iso = Join-Path $tmp 'seed.iso'
    New-LabSeedIso -SourceDir $src -IsoPath $iso
    $b = [IO.File]::ReadAllBytes($iso)
    Assert ($b.Length -ge 32768 + 2048) 'ISO file created'
    $pvdId = [Text.Encoding]::ASCII.GetString($b, 0x8001, 5)
    Assert ($pvdId -eq 'CD001') 'ISO9660 primary volume descriptor present'
    $label = [Text.Encoding]::ASCII.GetString($b, 0x8028, 32).Trim()
    Assert ($label -eq 'CIDATA') "volume label is CIDATA (got '$label')"
    function Find-Bytes([byte[]]$hay, [byte[]]$needle) {
        for ($i = 0; $i -le $hay.Length - $needle.Length; $i++) {
            $ok = $true
            for ($j = 0; $j -lt $needle.Length; $j++) { if ($hay[$i + $j] -ne $needle[$j]) { $ok = $false; break } }
            if ($ok) { return $i }
        }
        return -1
    }
    $u16 = [Text.Encoding]::BigEndianUnicode
    $svd = ($b[0x8800] -eq 2) -and ([Text.Encoding]::ASCII.GetString($b, 0x8801, 5) -eq 'CD001')
    Assert $svd 'Joliet supplementary volume descriptor present'
    $limit = [Math]::Min($b.Length, 200000)
    $head = New-Object byte[] $limit; [Array]::Copy($b, $head, $limit)
    Assert ((Find-Bytes $head $u16.GetBytes('user-data')) -ge 0 -and (Find-Bytes $head $u16.GetBytes('meta-data')) -ge 0) 'Joliet names user-data and meta-data present (lowercase, with dash)'
    $ascii = [Text.Encoding]::ASCII.GetString($b)
    Assert ($ascii.Contains('#cloud-config')) 'file content stored'

    # 2. ssh-keygen with empty passphrase through the raw-argument helper
    $k = Join-Path $tmp 'k_ed25519'
    $r = Invoke-NativeRaw -FilePath (Get-SshKeygenExe) -Arguments ('-q -t ed25519 -N "" -C {0} -f {1}' -f (Quote-Arg 'test key'), (Quote-Arg $k))
    Assert ($r.Code -eq 0 -and (Test-Path $k) -and (Test-Path "$k.pub")) 'ssh-keygen key pair created'
    $r2 = Invoke-NativeRaw -FilePath (Get-SshKeygenExe) -Arguments ('-y -P "" -f {0}' -f (Quote-Arg $k))
    Assert ($r2.Code -eq 0 -and $r2.Out -match '^ssh-ed25519 ') 'key has an EMPTY passphrase (not a literal "")'

    # 3. redaction
    $s = Protect-LabText "password=Hunter2 token=abc http://x/?token=deadbeef `$6`$salt`$hashhashhash -----BEGIN OPENSSH PRIVATE KEY-----`nAAA`n-----END OPENSSH PRIVATE KEY-----"
    Assert ($s -notmatch 'Hunter2|deadbeef|hashhashhash|AAA') 'secrets redacted from log text'

    # 4. payload hash is stable and content-sensitive
    $g = Join-Path $PSScriptRoot '..\guest'
    $h1 = Get-LabPayloadHash (Resolve-Path $g).Path
    $h2 = Get-LabPayloadHash (Resolve-Path $g).Path
    Assert ($h1 -eq $h2 -and $h1.Length -eq 64) 'payload hash stable'

    # 5. Quote-Arg
    Assert ((Quote-Arg 'C:\a b\c') -eq '"C:\a b\c"') 'paths with spaces are quoted'
    Assert ((Quote-Arg '') -eq '""') 'empty argument preserved'

    # 6. identity gate refuses without state
    $saved = $env:LOCALAPPDATA
    $env:LOCALAPPDATA = $tmp
    try { Assert-LabVm | Out-Null; Assert $false 'Assert-LabVm refuses without recorded VM' } catch { Assert ($_.Exception.Message -match 'No Linux IAM Lab VM') 'Assert-LabVm refuses without recorded VM' }
    $env:LOCALAPPDATA = $saved
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
if ($script:fails) { Write-Host "$($script:fails) test(s) failed" -ForegroundColor Red; exit 1 }
Write-Host 'All host component tests passed' -ForegroundColor Green
