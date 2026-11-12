# m06-key-login
do_setup() {
  ensure_keypair btran_laptop
  install -d -m 0755 "$DATA/tickets"
  printf 'IAM-6001 attachment (fictional)\nRequester: Ben Tran (btran)\nKey: btran_laptop (ED25519)\nFingerprint: %s\n' "$(key_fpr "$VAR/keys/btran_laptop.pub")" > "$DATA/tickets/IAM-6001.txt"
  if [ "$RESET" = 1 ]; then
    rm -f /home/btran/.ssh/authorized_keys
    if [ -f "$SH/.ssh/id_ed25519.pub" ] && [ -f "$SH/.ssh/authorized_keys" ]; then
      grep -vF "$(cat "$SH/.ssh/id_ed25519.pub")" "$SH/.ssh/authorized_keys" > "$SH/.ssh/authorized_keys.new" || true
      mv "$SH/.ssh/authorized_keys.new" "$SH/.ssh/authorized_keys"; chown student:student "$SH/.ssh/authorized_keys"; chmod 600 "$SH/.ssh/authorized_keys"
    fi
    rm -f "$SH/.ssh/id_ed25519" "$SH/.ssh/id_ed25519.pub"
  fi
}
do_check() {
  local ak=/home/btran/.ssh/authorized_keys
  [ -f "$ak" ] && pass "btran has an authorized_keys file" || { fail "$ak does not exist yet"; }
  if [ -f "$ak" ]; then
    grep -qF "$(cut -d' ' -f2 "$VAR/keys/btran_laptop.pub")" "$ak" && pass "Ben's verified key is installed" || fail "btran_laptop.pub is not in $ak"
    [ "$(owner_of /home/btran/.ssh)" = "btran:btran" ] && [ "$(perm_of /home/btran/.ssh)" = 700 ] && pass "~btran/.ssh is 700 btran:btran" || fail "~btran/.ssh should be mode 700 owned by btran"
    [ "$(owner_of "$ak")" = "btran:btran" ] && [ "$(perm_of "$ak")" = 600 ] && pass "authorized_keys is 600 btran:btran" || fail "authorized_keys should be mode 600 owned by btran"
  fi
  ssh_key_login btran "$VAR/keys/btran_laptop" && pass "ALLOWED: real SSH login as btran with his key" || fail "SSH login as btran with his key was refused (sudo journalctl -u ssh -n 20)"
  ensure_keypair lab_untrusted
  ssh_key_login btran "$VAR/keys/lab_untrusted" && fail "an unrelated key can log in as btran" || pass "DENIED: an unrelated key cannot log in as btran"
  if [ -f "$SH/.ssh/id_ed25519.pub" ]; then
    pass "you created ~/.ssh/id_ed25519.pub"
    grep -qF "$(cut -d' ' -f2 "$SH/.ssh/id_ed25519.pub")" "$SH/.ssh/authorized_keys" 2>/dev/null && pass "your new public key is authorized for student" || fail "add ~/.ssh/id_ed25519.pub to ~/.ssh/authorized_keys"
    [ -s "$SH/.ssh/authorized_keys" ] && [ "$(wc -l < "$SH/.ssh/authorized_keys")" -ge 2 ] && pass "the Windows lab key is still authorized (you appended, not overwrote)" || fail "~/.ssh/authorized_keys should still contain the Windows lab key as well"
  else
    fail "create your own key pair: ssh-keygen -t ed25519"
  fi
}
do_solve() {
  install -d -m 700 -o btran -g btran /home/btran/.ssh
  install -m 600 -o btran -g btran "$DATA/keys/btran_laptop.pub" /home/btran/.ssh/authorized_keys
  as_user student bash -c '[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N "" -C student@iamlab01 -f ~/.ssh/id_ed25519; grep -qF "$(cut -d" " -f2 ~/.ssh/id_ed25519.pub)" ~/.ssh/authorized_keys || cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys'
}
