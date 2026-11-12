#!/bin/bash
# Linux IAM Lab - in-VM provisioning. Runs as root, idempotent, safe to re-run.
# Usage: provision.sh <payload-dir>     (payload-dir holds opt/, systemd/, install/)
set -Eeuo pipefail
export HOME="${HOME:-/root}"   # systemd-run starts us without HOME; the ollama CLI requires it
SRC="${1:-/tmp/lab-src}"
LAB=/opt/linux-iam-lab
VAR=/var/lib/linux-iam-lab
ETC=/etc/linux-iam-lab
LOGDIR=/var/log/linux-iam-lab
mkdir -p "$LOGDIR" "$VAR" "$ETC" "$VAR/secrets" "$VAR/keys" "$VAR/evidence"
chmod 700 "$VAR/secrets" "$VAR/keys"
LOG="$LOGDIR/provision.log"
exec > >(tee -a "$LOG") 2>&1
rm -f "$VAR/provision.result"

step() { echo "[STEP] $*"; }
ok()   { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }
on_err() { echo "[ERROR] provisioning failed at line $1: $2"; echo "RESULT=FAIL" > "$VAR/provision.result"; }
trap 'on_err $LINENO "$BASH_COMMAND"' ERR

echo "=== provision started $(date -Is) ==="
[ -f "$SRC/install/settings.env" ] || { echo "[ERROR] $SRC/install/settings.env missing"; echo RESULT=FAIL > "$VAR/provision.result"; exit 1; }
# shellcheck disable=SC1091
. "$SRC/install/settings.env"
IN_WSL=0; grep -qi microsoft /proc/version 2>/dev/null && IN_WSL=1

# ------------------------------------------------------------------ packages
step "Waiting for first-boot setup (cloud-init) to finish"
if command -v cloud-init >/dev/null && [ "$IN_WSL" = 0 ]; then cloud-init status --wait >/dev/null 2>&1 || true; fi
ok "cloud-init finished"

step "Installing Linux packages (OpenSSH, ACL, auditd, SSSD, OpenLDAP, ttyd, tools)"
export DEBIAN_FRONTEND=noninteractive
if [ ! -s "$ETC/ldap-admin.pw" ]; then
  umask 077; printf '%s' "$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | cut -c1-20)" > "$ETC/ldap-admin.pw"; umask 022
fi
LDAPPW="$(cat "$ETC/ldap-admin.pw")"
if ! dpkg -s slapd >/dev/null 2>&1; then
  debconf-set-selections <<EOF
slapd slapd/no_configuration boolean false
slapd slapd/domain string iamlab.test
slapd shared/organization string IAM Lab
slapd slapd/password1 password $LDAPPW
slapd slapd/password2 password $LDAPPW
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
EOF
fi
# The lab is an isolated, localhost-only practice VM restored from a snapshot: background
# upgrades would change the known-good baseline and hold the dpkg lock on slow hosts.
systemctl disable --now unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true
APT="apt-get -y -q -o DPkg::Lock::Timeout=1800 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
PKGS="openssh-server acl attr auditd sssd-ldap sssd-tools libnss-sss libpam-sss slapd ldap-utils ttyd
      python3 jq tree vim nano less man-db bash-completion psmisc lsof curl ca-certificates rsyslog cron
      pamtester openssl sudo passwd login util-linux procps iproute2 zstd"
MISSING=""
# shellcheck disable=SC2086
for p in $PKGS; do dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q '^install ok installed' || MISSING="$MISSING $p"; done
if [ -n "$MISSING" ]; then
  $APT update
  # shellcheck disable=SC2086
  $APT install --no-install-recommends $MISSING
fi
ok "Packages installed"

# ------------------------------------------------------------------ code + settings
step "Installing course, portal and lab tools to $LAB"
mkdir -p "$LAB"
cp -a "$SRC/opt/linux-iam-lab/." "$LAB/"
find "$LAB" -type d -exec chmod 755 {} +
find "$LAB" -type f -exec chmod 644 {} +
find "$LAB" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod 755 {} +
chmod 755 "$LAB/bin/"*
chown -R root:root "$LAB"
ln -sf "$LAB/bin/lab" /usr/local/bin/lab
install -m 0644 "$SRC/install/settings.env" "$ETC/settings.env"
[ -n "${PAYLOAD_SHA256:-}" ] && echo "$PAYLOAD_SHA256" > "$ETC/payload.sha256"
ok "Lab files installed"

step "Creating lab system accounts and groups"
getent group labagent >/dev/null || groupadd --system labagent
getent group diradmins >/dev/null || groupadd --system diradmins
id labportal >/dev/null 2>&1 || useradd --system --home-dir /nonexistent --no-create-home --shell /usr/sbin/nologin --comment "Linux IAM Lab portal" labportal
usermod -aG labagent labportal
if ! id student >/dev/null 2>&1; then
  useradd -m -s /bin/bash -c "Lab Learner" -G sudo,adm student
  passwd -l student >/dev/null
fi
usermod -aG sudo,adm,labagent,diradmins student
getent group systemd-journal >/dev/null && usermod -aG systemd-journal student
if id labctl >/dev/null 2>&1; then
  echo 'labctl ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/00-labctl
  chmod 440 /etc/sudoers.d/00-labctl
fi
install -d -m 700 -o student -g student /home/student/.ssh
if [ -s "$SRC/install/student.pub" ]; then
  touch /home/student/.ssh/authorized_keys
  grep -qF "$(cat "$SRC/install/student.pub")" /home/student/.ssh/authorized_keys || cat "$SRC/install/student.pub" >> /home/student/.ssh/authorized_keys
  chown student:student /home/student/.ssh/authorized_keys; chmod 600 /home/student/.ssh/authorized_keys
fi
[ -s "$ETC/portal.token" ] || echo "${PORTAL_TOKEN:?PORTAL_TOKEN missing}" > "$ETC/portal.token"
[ "$(cat "$ETC/portal.token")" = "$PORTAL_TOKEN" ] || echo "$PORTAL_TOKEN" > "$ETC/portal.token"
[ -s "$ETC/terminal.token" ] || head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$ETC/terminal.token"
chown root:labportal "$ETC/portal.token" "$ETC/terminal.token"; chmod 640 "$ETC/portal.token" "$ETC/terminal.token"
install -m 0600 -o student -g student "$ETC/terminal.token" "$ETC/terminal.token.student"
# install-time copies used by 'lab rescue' (break-glass) if a learner breaks these files
mkdir -p "$VAR/backup"
[ -f "$VAR/backup/sudoers" ] || cp -a /etc/sudoers "$VAR/backup/sudoers"
[ -f "$VAR/backup/sshd_config" ] || cp -a /etc/ssh/sshd_config "$VAR/backup/sshd_config"
chown root:diradmins "$ETC/ldap-admin.pw"; chmod 640 "$ETC/ldap-admin.pw"
ok "Accounts ready (student, labportal, labctl)"

# ------------------------------------------------------------------ boot robustness
# Under VirtualBox on top of Windows' hypervisor the kernel's early IO-APIC timer test can fail
# ("IO-APIC + timer doesn't work") and panic. no_timer_check skips that test (common for VMs).
if [ -d /etc/default/grub.d ] && ! grep -q no_timer_check /etc/default/grub.d/60-linux-iam-lab.cfg 2>/dev/null; then
  echo 'GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT no_timer_check"' > /etc/default/grub.d/60-linux-iam-lab.cfg
  update-grub >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------ hostname resolution
grep -q 'ldap.iamlab.test' /etc/hosts || echo '127.0.0.1 ldap.iamlab.test' >> /etc/hosts
for t in /etc/cloud/templates/hosts.debian.tmpl; do
  [ -f "$t" ] && { grep -q 'ldap.iamlab.test' "$t" || echo '127.0.0.1 ldap.iamlab.test' >> "$t"; }
done

# ------------------------------------------------------------------ SSH baseline
step "Configuring the SSH server baseline"
cat > /etc/ssh/sshd_config.d/50-linux-iam-lab.conf <<'EOF'
# Linux IAM Lab baseline (managed by provision.sh)
PermitRootLogin no
KbdInteractiveAuthentication no
PasswordAuthentication no
PubkeyAuthentication yes
StrictModes yes
LogLevel VERBOSE
# Password logins are allowed only from inside the VM (used by audit exercises).
Match Address 127.0.0.1,::1
    PasswordAuthentication yes
EOF
sshd -t
systemctl reload ssh 2>/dev/null || systemctl restart ssh 2>/dev/null || true
ok "sshd configuration validated (sshd -t) and reloaded"

# ------------------------------------------------------------------ PAM: faillock + mkhomedir
step "Enabling account lockout (pam_faillock) and home directory creation"
cat > /etc/security/faillock.conf <<'EOF'
# Linux IAM Lab policy: 5 failed passwords within 15 minutes lock the account until an
# administrator resets it (faillock --user NAME --reset). Root is never locked.
# Records are kept in /var/lib/faillock so a lock survives a reboot.
dir = /var/lib/faillock
deny = 5
fail_interval = 900
unlock_time = 0
audit
EOF
install -d -m 0755 /var/lib/faillock
cat > /usr/share/pam-configs/lab-faillock <<'EOF'
Name: Lab: count failed logins (pam_faillock authfail/authsucc)
Default: yes
Priority: 0
Auth-Type: Primary
Auth:
	[default=die]	pam_faillock.so authfail
	sufficient	pam_faillock.so authsucc
EOF
cat > /usr/share/pam-configs/lab-faillock-preauth <<'EOF'
Name: Lab: refuse locked accounts before asking for a password (pam_faillock preauth)
Default: yes
Priority: 1024
Auth-Type: Primary
Auth:
	requisite	pam_faillock.so preauth
EOF
pam-auth-update --package --enable lab-faillock lab-faillock-preauth mkhomedir sss
grep -q pam_faillock /etc/pam.d/common-auth && ok "pam_faillock active in /etc/pam.d/common-auth"

# ------------------------------------------------------------------ OpenLDAP directory with TLS
step "Setting up the lab's own OpenLDAP directory (dc=iamlab,dc=test) with TLS"
TLS=/etc/ldap/tls
mkdir -p "$TLS"
if [ ! -s "$TLS/lab-ca.crt" ]; then
  openssl req -x509 -newkey rsa:3072 -nodes -days 3650 -subj "/CN=IAM Lab Root CA" \
    -keyout "$TLS/lab-ca.key" -out "$TLS/lab-ca.crt" 2>/dev/null
  openssl req -newkey rsa:3072 -nodes -subj "/CN=ldap.iamlab.test" \
    -keyout "$TLS/ldap.key" -out "$TLS/ldap.csr" 2>/dev/null
  printf 'subjectAltName=DNS:ldap.iamlab.test,DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth\n' > "$TLS/ext.cnf"
  openssl x509 -req -in "$TLS/ldap.csr" -CA "$TLS/lab-ca.crt" -CAkey "$TLS/lab-ca.key" -CAcreateserial \
    -days 3650 -extfile "$TLS/ext.cnf" -out "$TLS/ldap.crt" 2>/dev/null
fi
chown root:openldap "$TLS/ldap.key"; chmod 640 "$TLS/ldap.key"; chmod 600 "$TLS/lab-ca.key"; chmod 644 "$TLS/lab-ca.crt" "$TLS/ldap.crt"
systemctl enable --now slapd >/dev/null 2>&1 || true
for i in $(seq 1 30); do ldapsearch -Q -Y EXTERNAL -H ldapi:/// -b cn=config -s base dn >/dev/null 2>&1 && break; sleep 1; done
ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF >/dev/null
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: $TLS/lab-ca.crt
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: $TLS/ldap.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: $TLS/ldap.key
EOF
grep -q '^TLS_CACERT' /etc/ldap/ldap.conf 2>/dev/null && sed -i "s|^TLS_CACERT.*|TLS_CACERT $TLS/lab-ca.crt|" /etc/ldap/ldap.conf || echo "TLS_CACERT $TLS/lab-ca.crt" >> /etc/ldap/ldap.conf
grep -q '^URI' /etc/ldap/ldap.conf || printf 'BASE dc=iamlab,dc=test\nURI ldap://ldap.iamlab.test\n' >> /etc/ldap/ldap.conf
# make sure the admin password matches our file (debconf only applies it on first install)
HASH="$(slappasswd -s "$LDAPPW")"
ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF >/dev/null
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: $HASH
EOF
"$LAB/lib/directory-baseline.sh"
ldapwhoami -x -ZZ -H ldap://ldap.iamlab.test -D cn=admin,dc=iamlab,dc=test -y "$ETC/ldap-admin.pw" >/dev/null
ok "Directory online; StartTLS bind as cn=admin verified"

step "Connecting Linux to the directory with SSSD"
cat > /etc/sssd/sssd.conf <<'EOF'
# Linux IAM Lab: SSSD reads identities from the lab's own directory (never from any other server)
[sssd]
services = nss, pam
domains = iamlab.test

[domain/iamlab.test]
id_provider = ldap
auth_provider = ldap
access_provider = simple
simple_allow_groups = linux-login
ldap_uri = ldap://ldap.iamlab.test
ldap_search_base = dc=iamlab,dc=test
ldap_schema = rfc2307
ldap_id_use_start_tls = true
ldap_tls_reqcert = demand
ldap_tls_cacert = /etc/ldap/tls/lab-ca.crt
cache_credentials = false
entry_cache_timeout = 30
enumerate = false
EOF
chmod 600 /etc/sssd/sssd.conf
systemctl enable sssd >/dev/null 2>&1 || true
systemctl restart sssd
sleep 2
getent passwd nwalker >/dev/null && ok "SSSD resolves directory user nwalker" || warn "SSSD did not resolve nwalker yet"

# ------------------------------------------------------------------ audit
step "Enabling auditd"
systemctl enable auditd >/dev/null 2>&1 || true
if systemctl restart auditd 2>/dev/null; then ok "auditd running"; else warn "auditd could not start here (normal inside WSL test containers; works in the VM)"; fi

# ------------------------------------------------------------------ lab baseline data, personas, demo service
step "Creating the fictional company (users, groups, folders, demo service)"
"$LAB/lib/baseline.sh"
ok "Baseline identities and data ready"

step "Preparing every exercise scenario"
for f in "$LAB"/exercises/m*.sh; do
  id="$(basename "$f" .sh)"
  echo "--- setup $id $(date -Is)" >> "$LOGDIR/setup.log"
  "$LAB/lib/exrun.sh" "$id" setup >> "$LOGDIR/setup.log" 2>&1 || { echo "[ERROR] setup failed for $id (see $LOGDIR/setup.log)"; false; }
done
ok "Exercise scenarios prepared"

# ------------------------------------------------------------------ Ollama (tutor)
step "Installing Ollama (the local tutor) - private to this VM"
ASSETS=/var/tmp/lab-assets
ARC="$ASSETS/ollama-linux-amd64.tar.zst"
if [ -s "$ARC" ]; then
  # Verified on Windows; verify again here against the same release's checksum list.
  want="$(grep 'ollama-linux-amd64.tar.zst$' "$ASSETS/ollama-sha256sum.txt" | awk '{print $1}')"
  have="$(sha256sum "$ARC" | awk '{print $1}')"
  [ -n "$want" ] && [ "$want" = "$have" ] || { echo "[ERROR] Ollama archive checksum mismatch in the VM"; false; }
  if [ "$(cat /usr/local/lib/ollama/.lab-archive-sha256 2>/dev/null)" != "$have" ] || ! /usr/local/bin/ollama --version >/dev/null 2>&1; then
    rm -rf /usr/local/lib/ollama /usr/local/bin/ollama
    tar --zstd -xf "$ARC" -C /usr/local
    echo "$have" > /usr/local/lib/ollama/.lab-archive-sha256
  fi
  id ollama >/dev/null 2>&1 || useradd -r -s /bin/false -U -m -d /usr/share/ollama ollama
  cat > /etc/systemd/system/ollama.service <<'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=default.target
EOF
  ok "Ollama installed from the verified archive copied from Windows"
elif ! /usr/local/bin/ollama --version >/dev/null 2>&1 && ! command -v ollama >/dev/null; then
  curl -fsSL https://ollama.com/install.sh -o /tmp/ollama-install.sh
  sh /tmp/ollama-install.sh </dev/null
fi
# Tutor model copied from Windows: place the verified blobs + manifest where Ollama looks.
if [ -s "$ASSETS/manifest.json" ] && [ -s "$ASSETS/model.env" ]; then
  . "$ASSETS/model.env"
  MD=/usr/share/ollama/.ollama/models
  install -d -o ollama -g ollama "$MD" "$MD/blobs" "$MD/manifests/registry.ollama.ai/$MODEL_REPO"
  for b in "$ASSETS"/blobs/sha256-*; do
    hex="${b##*/sha256-}"
    [ "$(sha256sum "$b" | awk '{print $1}')" = "$hex" ] || { echo "[ERROR] model layer $hex corrupted in transit"; false; }
    install -m 0644 -o ollama -g ollama "$b" "$MD/blobs/"
  done
  install -m 0644 -o ollama -g ollama "$ASSETS/manifest.json" "$MD/manifests/registry.ollama.ai/$MODEL_REPO/$MODEL_TAG"
  chown -R ollama:ollama /usr/share/ollama/.ollama
fi
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/10-linux-iam-lab.conf <<'EOF'
[Service]
# Listen on the VM's loopback only. Nothing outside the VM can reach the model.
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_KEEP_ALIVE=20m"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
EOF
systemctl daemon-reload
systemctl enable ollama >/dev/null 2>&1 || true
systemctl restart ollama
for i in $(seq 1 30); do curl -fs http://127.0.0.1:11434/api/version >/dev/null 2>&1 && break; sleep 1; done
OVER="$(ollama --version 2>/dev/null || true)"
ok "Ollama ${OVER##* } listening on 127.0.0.1:11434"
# model_present: no 'cmd | grep -q' pipes here - under pipefail an early-exiting grep makes the pipe "fail"
model_present() { local l; for _ in $(seq 1 20); do l="$(ollama list 2>/dev/null || true)"; [ -n "$l" ] && break; sleep 2; done; awk '{print $1}' <<< "$l" | grep -x "$OLLAMA_MODEL" >/dev/null; }
if [ "${SKIP_TUTOR_MODEL:-0}" != 1 ]; then
  if ! model_present; then
    step "Downloading tutor model $OLLAMA_MODEL (about 1 GB, one time)"
    ollama pull "$OLLAMA_MODEL" 2>&1 | tr '\r' '\n' | grep -vE '^\s*$' | awk 'NR%40==1' || true
    model_present
  fi
  ok "Tutor model $OLLAMA_MODEL present"
else
  warn "Tutor model download skipped; run 'sudo lab tutor-pull' later"
fi

# ------------------------------------------------------------------ services
step "Starting the lab agent, course portal and web terminal"
# Ubuntu's ttyd package starts its own ttyd.service (a 'login' prompt on 127.0.0.1:7681).
# The lab runs its own terminal service on that port instead.
systemctl disable --now ttyd.service >/dev/null 2>&1 || true
install -m 0644 "$SRC/systemd/"*.service /etc/systemd/system/
systemctl daemon-reload
[ -f "$VAR/progress.json" ] || echo '{"exercises":{},"lessons":{},"events":[]}' > "$VAR/progress.json"
chown root:labagent "$VAR/progress.json"; chmod 640 "$VAR/progress.json"
touch "$LOGDIR/agent.log"; chmod 640 "$LOGDIR/agent.log"
systemctl enable lab-agent lab-portal lab-terminal >/dev/null 2>&1
systemctl restart lab-agent lab-portal lab-terminal
sleep 2
ok "Services started"

# ------------------------------------------------------------------ desktop (work INSIDE the Linux VM)
step "Installing the Linux desktop (XFCE), autologin as student, in-VM browser and terminal"
DESK="xfce4 xfce4-terminal xfce4-panel xfdesktop4 xfwm4 thunar lightdm lightdm-gtk-greeter
      xserver-xorg-core xserver-xorg-video-vmware xserver-xorg-video-fbdev xserver-xorg-input-libinput
      dbus-x11 at-spi2-core epiphany-browser virtualbox-guest-x11 fonts-dejavu-core adwaita-icon-theme"
MISSING=""
# shellcheck disable=SC2086
for p in $DESK; do dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q '^install ok installed' || MISSING="$MISSING $p"; done
if [ -n "$MISSING" ]; then
  $APT -o Acquire::Retries=5 update
  # shellcheck disable=SC2086
  $APT -o Acquire::Retries=5 install --no-install-recommends $MISSING
fi
getent group autologin >/dev/null || groupadd --system autologin
usermod -aG autologin student
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-linux-iam-lab.conf <<'EOF'
# Linux IAM Lab: the VM window opens straight into the learner's desktop.
[Seat:*]
autologin-user=student
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
EOF
install -m 0600 -o student -g student "$ETC/portal.token" "$ETC/portal.token.student"
install -d -o student -g student /home/student/.config /home/student/.config/autostart
cat > /home/student/.config/autostart/linux-iam-lab.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Linux IAM Lab
Comment=Open the course portal and a Linux terminal
Exec=/opt/linux-iam-lab/bin/lab-desktop-start
X-GNOME-Autostart-enabled=true
EOF
for n in "Course Portal|Open the Linux IAM Lab course portal|/opt/linux-iam-lab/bin/lab-desktop-start portal|web-browser" \
         "Lab Terminal|Linux terminal for the lab exercises|xfce4-terminal --title=\"Linux IAM Lab - student@iamlab01\"|utilities-terminal"; do
  IFS='|' read -r name cmt exe icon <<< "$n"
  f="/usr/share/applications/linux-iam-lab-$(echo "$name" | tr 'A-Z ' 'a-z-').desktop"
  printf '[Desktop Entry]\nType=Application\nName=%s\nComment=%s\nExec=%s\nIcon=%s\nCategories=Education;\n' "$name" "$cmt" "$exe" "$icon" > "$f"
done
# no screen lock or blanking in a practice VM
install -d -o student -g student /home/student/.config/xfce4 /home/student/.config/xfce4/xfconf /home/student/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /home/student/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="lock-screen-suspend-hibernate" type="bool" value="false"/>
  </property>
</channel>
EOF
chown -R student:student /home/student/.config
systemctl set-default graphical.target >/dev/null
systemctl enable lightdm >/dev/null 2>&1 || true
ok "Desktop ready: the VM window logs in as student and opens the portal + a terminal"

# ------------------------------------------------------------------ verify
step "Verifying the installation"
"$LAB/bin/lab" selftest
rm -rf /var/tmp/lab-assets /var/tmp/lab-src /tmp/ollama-install.sh   # keep the baseline snapshot small
echo "RESULT=OK" > "$VAR/provision.result"
echo "=== provision finished $(date -Is) ==="
