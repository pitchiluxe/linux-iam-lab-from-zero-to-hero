#!/bin/bash
# Security regression tests (run as root inside the lab VM):
#   sudo bash /opt/linux-iam-lab/tests/run-security-regression.sh
# Each test plays a learner who tries to turn a lab action that runs as root
# (exercise check, retry, export) against the system, and asserts it fails.
set -u
. /opt/linux-iam-lab/lib/common.sh
EXRUN=/opt/linux-iam-lab/lib/exrun.sh
P=0; F=0
ok()  { echo "ok   - $*"; P=$((P+1)); }
bad() { echo "FAIL - $*"; F=$((F+1)); }
S() { as_student bash -c "$1"; }   # act as the learner

# --- 1. m08 check runs the learner's script: it must not get real root --------------
S 'mkdir -p ~/bin; cat > ~/bin/access-report.sh' <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
touch /etc/sec-test-pwned 2>/dev/null || true
touch /home/student/sec-test-pwned 2>/dev/null || true
cp /bin/bash /var/tmp/sec-test-rootbash 2>/dev/null && chmod 4755 /var/tmp/sec-test-rootbash 2>/dev/null || true
echo 'student ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-sec-test 2>/dev/null || true
systemctl start falcon-web >/dev/null 2>&1 && touch "$1/systemctl-worked" || true
cat /etc/linux-iam-lab/portal.token.student > "$1/token" 2>/dev/null || true
ls /var/lib/linux-iam-lab/keys > "$1/keys" 2>/dev/null || true
echo "$1/x"
EOF
S 'chmod +x ~/bin/access-report.sh'
$EXRUN m08-access-report check >/dev/null 2>&1
[ ! -e /etc/sec-test-pwned ] && ok "m08: learner script cannot write /etc" || bad "m08: wrote /etc"
[ ! -e /home/student/sec-test-pwned ] && ok "m08: learner script cannot write as root in /home" || bad "m08: wrote /home as root"
[ ! -e /var/tmp/sec-test-rootbash ] && ok "m08: no setuid root shell left behind" || bad "m08: setuid shell created"
[ ! -e /etc/sudoers.d/99-sec-test ] && ok "m08: cannot add a sudo rule" || bad "m08: sudo rule added"
[ -z "$(ls /var/lib/lab-check 2>/dev/null | grep run-)" ] && ok "m08: sandbox folder cleaned up" || bad "m08: sandbox folder left"
rw="$(sandbox_dir)"
out="$(sandbox_root "$rw" 60 bash -c 'systemctl is-system-running >/dev/null 2>&1 && echo SYSTEMD; cat /etc/linux-iam-lab/portal.token.student 2>/dev/null && echo TOKEN; ls /var/lib/linux-iam-lab/keys 2>/dev/null | grep -q . && echo KEYS; cat /home/labctl/.ssh/authorized_keys 2>/dev/null && echo LABCTL; getent hosts 1.1.1.1 >/dev/null; (exec 3<>/dev/tcp/127.0.0.1/22) 2>/dev/null && echo NET; echo done' 2>/dev/null)"
rm -rf "$rw"
[ "$out" = done ] && ok "sandbox: no systemd, lab token, lab keys, labctl keys or network" || bad "sandbox leaked: $(echo "$out" | paste -sd' ' -)"
rm -f /etc/sec-test-pwned /home/student/sec-test-pwned /var/tmp/sec-test-rootbash /etc/sudoers.d/99-sec-test
# the real solution must still pass inside the sandbox
S 'rm -f ~/bin/access-report.sh'; $EXRUN m08-access-report solve >/dev/null 2>&1
$EXRUN m08-access-report check >/tmp/sec-m08.txt 2>&1 && ok "m08: correct script still passes in the sandbox" || { bad "m08: correct script fails in the sandbox"; cat /tmp/sec-m08.txt; }

# --- 2. m06 retry rewrote ~/.ssh/authorized_keys as root ----------------------------
cp -p /etc/hosts /tmp/sec-hosts.bak
S 'ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519 <<<y >/dev/null 2>&1; cp ~/.ssh/authorized_keys ~/.ssh/ak.bak; rm -f ~/.ssh/authorized_keys; ln -s /etc/hosts ~/.ssh/authorized_keys'
$EXRUN m06-key-login reset >/dev/null 2>&1
cmp -s /etc/hosts /tmp/sec-hosts.bak && [ "$(stat -c %U /etc/hosts)" = root ] && ok "m06 retry: symlinked authorized_keys does not touch /etc/hosts" || bad "m06 retry: /etc/hosts changed"
S 'rm -f ~/.ssh/authorized_keys; mv ~/.ssh/ak.bak ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys'

# --- 3. retry created/chowned folders under ~/lab as root -----------------------------
S 'mv ~/lab ~/lab.sec-bak; ln -s /etc ~/lab'
$EXRUN m01-orientation reset >/dev/null 2>&1
[ "$(stat -c %U /etc)" = root ] && [ ! -e /etc/m01 ] && ok "retry: ~/lab -> /etc symlink does not create or chown in /etc" || bad "retry: /etc touched via ~/lab symlink"
rmdir /etc/m01 2>/dev/null; S 'rm -f ~/lab; mv ~/lab.sec-bak ~/lab'

# --- 4. export wrote a fixed /tmp path as root -----------------------------------------
cp -p /etc/hostname /tmp/sec-hostname.bak
rm -f /tmp/lab-export.tar.gz; S 'ln -s /etc/hostname /tmp/lab-export.tar.gz'
/opt/linux-iam-lab/bin/lab export-bundle /tmp/lab-export.tar.gz >/dev/null 2>&1
cmp -s /etc/hostname /tmp/sec-hostname.bak && ok "export: planted symlink at the output path is replaced, not written through" || bad "export: /etc/hostname overwritten"
[ ! -L /tmp/lab-export.tar.gz ] && [ "$(stat -c '%a %U' /tmp/lab-export.tar.gz)" = "600 labctl" ] && ok "export: output is mode 600, owner labctl" || bad "export: output mode/owner is $(stat -c '%a %U' /tmp/lab-export.tar.gz 2>&1)"
tar -tzf /tmp/lab-export.tar.gz | grep -q 'export/student-home.tar.gz' && ok "export: bundle still contains the learner's home" || bad "export: bundle incomplete"
ls -d /tmp/lab-export-* >/dev/null 2>&1 && bad "export: staging folder left behind" || ok "export: staging folder removed"
rm -f /tmp/lab-export.tar.gz

echo; echo "security regression: $P passed, $F failed"
[ "$F" = 0 ]
