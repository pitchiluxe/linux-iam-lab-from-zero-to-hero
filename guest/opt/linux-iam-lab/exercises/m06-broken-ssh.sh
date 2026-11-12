# m06-broken-ssh
HAK=/home/hlopez/.ssh/authorized_keys
do_setup() {
  ensure_keypair hlopez_laptop
  usermod -aG ssh-users hlopez
  if [ "$RESET" = 1 ] || [ ! -f "$VAR/m06-broken-ssh.ready" ]; then
    install -d /home/hlopez/.ssh
    cp "$VAR/keys/hlopez_laptop.pub" "$HAK"
    chown root:root "$HAK"; chmod 666 "$HAK"
    chown hlopez:hlopez /home/hlopez /home/hlopez/.ssh
    chmod 777 /home/hlopez /home/hlopez/.ssh
    ssh_key_login hlopez "$VAR/keys/hlopez_laptop" || true   # leaves the 'bad ownership' line in the log
    touch "$VAR/m06-broken-ssh.ready"
  fi
}
do_check() {
  local hm; hm="$(perm_of /home/hlopez)"
  [ $(( 0$hm & 022 )) = 0 ] && pass "home folder is not group/world-writable (mode $hm)" || fail "/home/hlopez is mode $hm (group/world-writable)"
  [ "$(perm_of /home/hlopez/.ssh)" = 700 ] && [ "$(owner_of /home/hlopez/.ssh)" = "hlopez:hlopez" ] && pass ".ssh is 700 hlopez:hlopez" || fail ".ssh should be 700 owned by hlopez"
  [ "$(perm_of "$HAK")" = 600 ] && [ "$(owner_of "$HAK")" = "hlopez:hlopez" ] && pass "authorized_keys is 600 hlopez:hlopez" || fail "authorized_keys should be 600 owned by hlopez"
  sshd -T 2>/dev/null | grep -qi '^strictmodes yes' && pass "StrictModes is still on" || fail "StrictModes was turned off - turn it back on"
  ssh_key_login hlopez "$VAR/keys/hlopez_laptop" && pass "ALLOWED: real SSH login as hlopez with her key" || fail "hlopez's key login is still refused"
}
do_solve() {
  chmod 750 /home/hlopez; chmod 700 /home/hlopez/.ssh; chown hlopez:hlopez "$HAK"; chmod 600 "$HAK"
}
