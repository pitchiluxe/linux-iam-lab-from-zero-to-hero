# m06-revoke-key
EAK=/home/enovak/.ssh/authorized_keys
RK=/etc/ssh/revoked_keys
do_setup() {
  ensure_keypair enovak_laptop; ensure_keypair enovak_tablet
  usermod -aG ssh-users enovak
  install -d -m 0755 "$DATA/tickets"
  printf 'SEC-6004 (fictional)\nUser: enovak\nStolen device key: enovak_laptop\nFingerprint: %s\n' "$(key_fpr "$VAR/keys/enovak_laptop.pub")" > "$DATA/tickets/SEC-6004.txt"
  if [ "$RESET" = 1 ] || [ ! -f "$VAR/m06-revoke-key.ready" ]; then
    install -d -m 700 -o enovak -g enovak /home/enovak/.ssh
    cat "$VAR/keys/enovak_laptop.pub" "$VAR/keys/enovak_tablet.pub" > "$EAK"
    chown enovak:enovak "$EAK"; chmod 600 "$EAK"
    rm -f /etc/ssh/sshd_config.d/20-revoked-keys.conf
    if [ -f "$RK" ]; then grep -vF "$(cut -d' ' -f2 "$VAR/keys/enovak_laptop.pub")" "$RK" > "$RK.new" || true; mv "$RK.new" "$RK"; chmod 644 "$RK"; fi
    sshd -t && systemctl reload ssh 2>/dev/null || true
    touch "$VAR/m06-revoke-key.ready"
  fi
}
do_check() {
  local stolen tablet; stolen="$(cut -d' ' -f2 "$VAR/keys/enovak_laptop.pub")"; tablet="$(cut -d' ' -f2 "$VAR/keys/enovak_tablet.pub")"
  grep -qF "$stolen" "$EAK" && fail "the stolen key is still in $EAK" || pass "stolen key removed from enovak's authorized_keys"
  grep -qF "$tablet" "$EAK" && pass "tablet key kept" || fail "the tablet key was removed too"
  [ -f "$RK" ] && grep -qF "$stolen" "$RK" && pass "stolen key listed in $RK" || fail "add the stolen public key to $RK"
  sshd -t 2>/dev/null && pass "sshd -t: config valid" || fail "sshd -t reports an error"
  [ "$(sshd -T 2>/dev/null | awk 'tolower($1)=="revokedkeys"{print $2}')" = "$RK" ] && pass "RevokedKeys $RK is active" || fail "RevokedKeys is not set to $RK"
  ssh_key_login enovak "$VAR/keys/enovak_tablet" && pass "ALLOWED: real SSH login with the tablet key" || fail "the tablet key cannot log in"
  ssh_key_login enovak "$VAR/keys/enovak_laptop" && fail "the stolen laptop key CAN still log in" || pass "DENIED: real SSH login with the stolen key"
  # simulate someone re-adding the stolen key by mistake
  cp -p "$EAK" "$EAK.labcheck"
  cat "$VAR/keys/enovak_laptop.pub" >> "$EAK"
  ssh_key_login enovak "$VAR/keys/enovak_laptop" && fail "after re-adding it, the stolen key works (RevokedKeys not effective)" || pass "DENIED even after the key was re-added by mistake (RevokedKeys works)"
  mv "$EAK.labcheck" "$EAK"
}
do_solve() {
  sed -i '/enovak_laptop$/d' "$EAK"
  touch "$RK"; grep -qF "$(cut -d' ' -f2 "$VAR/keys/enovak_laptop.pub")" "$RK" || cat "$DATA/keys/enovak_laptop.pub" >> "$RK"; chmod 644 "$RK"
  echo "RevokedKeys $RK" > /etc/ssh/sshd_config.d/20-revoked-keys.conf
  sshd -t && systemctl reload ssh
}
