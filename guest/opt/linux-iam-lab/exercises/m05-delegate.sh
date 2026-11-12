# m05-delegate
LEGACY=/etc/sudoers.d/40-legacy-helpdesk
RULE=/etc/sudoers.d/50-helpdesk-falcon
do_setup() {
  if [ "$RESET" = 1 ]; then
    rm -f "$RULE"
    printf '# Legacy rule from 2019 - "helpdesk needs to edit hosts" (fictional)\ndpatel ALL=(root) NOPASSWD: /usr/bin/vim /etc/hosts\n' > "$LEGACY"
    chmod 440 "$LEGACY"
  fi
  persona_set_pw dpatel
  faillock --user dpatel --reset 2>/dev/null || true
}
may() { sudo -l -U "$1" "${@:2}" >/dev/null 2>&1; }
do_check() {
  visudo -c >/dev/null 2>&1 && pass "visudo -c: all sudo policy files parse OK" || { fail "visudo -c reports a syntax error - fix it first"; return; }
  [ -e "$LEGACY" ] && fail "legacy rule $LEGACY still exists" || pass "legacy vim rule removed"
  [ -f "$RULE" ] && pass "$RULE exists" || { fail "$RULE does not exist yet"; return; }
  [ "$(perm_of "$RULE")" = 440 ] && [ "$(owner_of "$RULE")" = "root:root" ] && pass "rule file is 0440 root:root" || fail "rule file should be 0440 root:root (visudo creates it that way)"
  grep -qE '^[[:space:]]*%helpdesk' "$RULE" && pass "granted to the helpdesk group" || fail "grant the rule to %helpdesk, not to a single user"
  grep -q NOPASSWD "$RULE" && fail "rule uses NOPASSWD - the ticket requires a password" || pass "password required (no NOPASSWD)"
  may dpatel /usr/bin/systemctl restart falcon-web.service && pass "policy: dpatel may restart falcon-web" || fail "dpatel may not restart falcon-web.service"
  # "view its status" needs no sudo - and as root, systemctl status opens a pager (less: !sh = root shell)
  may dpatel /usr/bin/systemctl status falcon-web.service && fail "dpatel may run systemctl status as root - not needed (it works without sudo) and it opens a pager as root; take it out of the rule" || pass "policy: status is not granted via sudo (it needs none)"
  as_user dpatel systemctl status falcon-web.service --no-pager 2>/dev/null | grep -q 'falcon-web.service' && pass "dpatel can view falcon-web status without sudo" || fail "dpatel cannot view the status with plain systemctl status"
  may dpatel /usr/bin/systemctl stop falcon-web.service && fail "dpatel may STOP falcon-web - too broad" || pass "policy: dpatel may not stop falcon-web"
  may dpatel /usr/bin/systemctl restart ssh.service && fail "dpatel may restart other services - too broad" || pass "policy: dpatel may not restart other services"
  may dpatel /usr/bin/vim /etc/hosts && fail "dpatel may still run vim as root" || pass "policy: dpatel may not run vim as root"
  local before after
  before="$(systemctl show -p MainPID --value falcon-web)"
  sudo_as dpatel /usr/bin/systemctl restart falcon-web.service && after="$(systemctl show -p MainPID --value falcon-web)" || after=""
  if [ -n "$after" ] && [ "$after" != "$before" ]; then pass "ALLOWED as dpatel (real test with his password): restart falcon-web"; else fail "dpatel could not actually restart falcon-web with sudo"; fi
  sudo_as dpatel /usr/bin/systemctl stop falcon-web.service && fail "dpatel actually STOPPED falcon-web" || pass "DENIED as dpatel (real test): stop falcon-web"
  systemctl is-active --quiet falcon-web || systemctl start falcon-web
  sudo_as dpatel /usr/bin/cat /etc/shadow && fail "dpatel could read /etc/shadow via sudo" || pass "DENIED as dpatel (real test): sudo cat /etc/shadow"
}
do_solve() {
  rm -f "$LEGACY"
  printf '# OPS-5002 (status needs no sudo)\nCmnd_Alias FALCON_OPS = /usr/bin/systemctl restart falcon-web.service\nDefaults!FALCON_OPS noexec\n%%helpdesk ALL=(root) FALCON_OPS\n' > "$RULE.tmp"
  chmod 440 "$RULE.tmp"; visudo -cf "$RULE.tmp" >/dev/null && mv "$RULE.tmp" "$RULE"
}
