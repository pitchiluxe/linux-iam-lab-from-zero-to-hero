#!/bin/bash
# Runs INSIDE the disposable WSL test distro as root. Mirrors what Install-LinuxIAMLab.ps1 does over SSH:
# stage the payload in /var/tmp/lab-src, add per-install settings, start provision.sh as a transient unit.
# Usage: stage-and-provision.sh <project-dir-under-/mnt/c> <student-pubkey-file> [skip-model]
set -euo pipefail
PROJ="$1"; PUB="$2"; SKIP="${3:-0}"
rm -rf /var/tmp/lab-src; mkdir -p /var/tmp/lab-src/install
cp -a "$PROJ/guest/." /var/tmp/lab-src/
find /var/tmp/lab-src -type f -exec sed -i 's/\r$//' {} +
cat > /var/tmp/lab-src/install/settings.env <<EOF
PORTAL_TOKEN=wsltest$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')
OLLAMA_MODEL=qwen2.5:1.5b
SKIP_TUTOR_MODEL=$SKIP
HOST_SSH_PORT=22
HOST_PORTAL_PORT=8080
HOST_TERMINAL_PORT=7681
HOST_KEY_FINGERPRINT=n/a-wsl-test
PAYLOAD_SHA256=wsl-test
EOF
cp "$PUB" /var/tmp/lab-src/install/student.pub
systemctl reset-failed lab-provision.service >/dev/null 2>&1 || true
rm -f /var/lib/linux-iam-lab/provision.result
systemd-run --unit=lab-provision --description="Linux IAM Lab provisioning (WSL test)" --property=TimeoutStartSec=infinity /bin/bash /var/tmp/lab-src/provision.sh /var/tmp/lab-src
echo STARTED
