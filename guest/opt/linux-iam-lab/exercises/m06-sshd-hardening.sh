# m06-sshd-hardening
HC=/etc/ssh/sshd_config.d/10-hardening.conf
eff() { sshd -T -C "user=$1,host=laptop,addr=10.0.2.2" 2>/dev/null | grep -i "^$2 " | cut -d' ' -f2- | tr 'A-Z' 'a-z'; }
do_setup() {
  ensure_keypair aokafor_ws; ensure_keypair jkim_ws
  local u
  for u in aokafor jkim; do
    install -d -m 700 -o "$u" -g "$u" "/home/$u/.ssh"
    install -m 600 -o "$u" -g "$u" "$VAR/keys/${u}_ws.pub" "/home/$u/.ssh/authorized_keys"
  done
  usermod -aG ssh-users student; id labctl >/dev/null 2>&1 && usermod -aG ssh-users labctl
  if [ "$RESET" = 1 ]; then
    rm -f "$HC"
    gpasswd -d aokafor ssh-users >/dev/null 2>&1 || true
    sshd -t && systemctl reload ssh
  fi
}
do_check() {
  sshd -t 2>/dev/null && pass "sshd -t: configuration is valid" || { fail "sshd -t reports an error: $(sshd -t 2>&1 | head -1)"; return; }
  [ -f "$HC" ] && pass "$HC exists" || fail "$HC does not exist yet"
  [ "$(eff jkim permitrootlogin)" = no ] && pass "PermitRootLogin no" || fail "PermitRootLogin is $(eff jkim permitrootlogin)"
  [ "$(eff jkim maxauthtries)" = 3 ] && pass "MaxAuthTries 3" || fail "MaxAuthTries is $(eff jkim maxauthtries)"
  [ "$(eff jkim logingracetime)" = 30 ] && pass "LoginGraceTime 30" || fail "LoginGraceTime is $(eff jkim logingracetime)"
  [ "$(eff jkim x11forwarding)" = no ] && pass "X11Forwarding no" || fail "X11Forwarding is $(eff jkim x11forwarding)"
  [ "$(eff jkim allowgroups)" = ssh-users ] && pass "AllowGroups ssh-users" || fail "AllowGroups is '$(eff jkim allowgroups)'"
  in_group aokafor ssh-users && pass "aokafor is in ssh-users" || fail "add aokafor to ssh-users"
  in_group jkim ssh-users && fail "jkim must not be in ssh-users" || pass "jkim is not in ssh-users"
  systemctl reload ssh 2>/dev/null; sleep 1
  ssh_key_login aokafor "$VAR/keys/aokafor_ws" && pass "ALLOWED: real SSH login as aokafor" || fail "aokafor cannot log in over SSH"
  ssh_key_login jkim "$VAR/keys/jkim_ws" && fail "jkim CAN log in over SSH" || pass "DENIED: real SSH login as jkim (not in ssh-users)"
  in_group labctl ssh-users && in_group student ssh-users && pass "lab administrators (labctl, student) keep SSH access" || fail "student or labctl is no longer in ssh-users"
}
do_solve() {
  usermod -aG ssh-users aokafor
  printf '# SEC-6003 SSH baseline\nPermitRootLogin no\nMaxAuthTries 3\nLoginGraceTime 30\nX11Forwarding no\nAllowGroups ssh-users\n' > "$HC"
  sshd -t && systemctl reload ssh
}
