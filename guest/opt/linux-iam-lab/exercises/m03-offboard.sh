# m03-offboard
ARCH=/srv/archive/offboarded/cdiaz-home.tar.gz
start_session() {
  systemctl is-active --quiet lab-cdiaz-session 2>/dev/null && return 0
  systemd-run --quiet --unit=lab-cdiaz-session --uid=cdiaz --gid=cdiaz --collect /bin/sleep infinity >/dev/null 2>&1 || true
}
do_setup() {
  if [ "$RESET" = 1 ] || [ ! -f "$VAR/m03-offboard.ready" ]; then
    user_exists cdiaz || ensure_user cdiaz 2004 "Chloe Diaz - HR Generalist" hr
    usermod -U cdiaz 2>/dev/null || true
    usermod -s /bin/bash -G hr,ssh-users cdiaz
    chage -E -1 cdiaz
    persona_set_pw cdiaz
    faillock --user cdiaz --reset
    ensure_keypair cdiaz_laptop
    install -d -o cdiaz -g cdiaz -m 700 /home/cdiaz/.ssh
    install -o cdiaz -g cdiaz -m 600 "$VAR/keys/cdiaz_laptop.pub" /home/cdiaz/.ssh/authorized_keys
    echo "# quarterly HR export (fictional)" > /home/cdiaz/notes.txt; chown cdiaz:cdiaz /home/cdiaz/notes.txt
    printf '30 2 * * 1 /bin/true # weekly HR export (fictional)\n' | crontab -u cdiaz -
    install -d -o root -g hr -m 2770 /srv/hr/policies
    echo "Onboarding policy draft (fictional)" > /srv/hr/policies/onboarding-draft.txt
    echo "Interview notes (fictional)" > /srv/hr/interviews-q4.txt
    chown cdiaz:hr /srv/hr/policies/onboarding-draft.txt /srv/hr/interviews-q4.txt
    chmod 660 /srv/hr/policies/onboarding-draft.txt /srv/hr/interviews-q4.txt
    rm -f "$ARCH"
    touch "$VAR/m03-offboard.ready"
  fi
  start_session
}
do_boot() { user_exists cdiaz && [ "$(getent passwd cdiaz | cut -d: -f7)" = /bin/bash ] && start_session; return 0; }
do_check() {
  user_exists cdiaz && pass "account kept for the 30-day legal hold" || { fail "cdiaz was deleted - policy LV-1 says keep it (Retry exercise)"; return; }
  local sh exp today; sh="$(getent shadow cdiaz)"; exp="$(echo "$sh" | cut -d: -f8)"; today=$(( $(date +%s) / 86400 ))
  case "$(echo "$sh" | cut -d: -f2)" in '!'*|'*'*) pass "password locked";; *) fail "password is not locked (usermod -L)";; esac
  [ -n "$exp" ] && [ "$exp" -le "$today" ] && pass "account expired" || fail "account is not expired (chage -E 0 / usermod -e 1)"
  case "$(getent passwd cdiaz | cut -d: -f7)" in */nologin|*/false) pass "no interactive shell";; *) fail "shell should be /usr/sbin/nologin";; esac
  local g; g="$(id -nG cdiaz | tr ' ' '\n' | grep -vx cdiaz | paste -sd, -)"
  [ -z "$g" ] && pass "no supplementary groups" || fail "still in groups: $g"
  crontab -l -u cdiaz >/dev/null 2>&1 && fail "cdiaz still has a crontab" || pass "crontab removed"
  pgrep -u cdiaz >/dev/null && fail "cdiaz still has running processes ($(pgrep -u cdiaz -l | paste -sd' ' -))" || pass "no running processes"
  if [ -f "$ARCH" ] && tar -tzf "$ARCH" 2>/dev/null | grep -q '^cdiaz/notes.txt$'; then pass "home archived to $ARCH"; else fail "$ARCH missing or does not contain cdiaz/notes.txt"; fi
  local left; left="$(find /srv/hr -user cdiaz 2>/dev/null | wc -l)"
  [ "$left" = 0 ] && pass "no HR files owned by cdiaz" || fail "$left file(s) under /srv/hr still owned by cdiaz"
  [ "$(stat -c %U /srv/hr/interviews-q4.txt 2>/dev/null)" = hlopez ] && pass "HR files handed over to hlopez" || fail "files should now be owned by hlopez"
  ssh_key_login cdiaz "$VAR/keys/cdiaz_laptop" && fail "SSH key login as cdiaz still WORKS" || pass "DENIED: SSH key login as cdiaz"
  pam_login cdiaz "$(persona_pw cdiaz)" && fail "password login as cdiaz still works" || pass "DENIED: password login as cdiaz"
}
do_solve() {
  usermod -L -e 1 -s /usr/sbin/nologin cdiaz
  usermod -G "" cdiaz
  crontab -r -u cdiaz 2>/dev/null || true
  systemctl stop lab-cdiaz-session 2>/dev/null || true
  pkill -KILL -u cdiaz || true
  mkdir -p /srv/archive/offboarded
  tar -czf "$ARCH" -C /home cdiaz
  find /srv/hr -user cdiaz -exec chown hlopez {} +
}
