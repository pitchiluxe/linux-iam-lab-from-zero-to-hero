# m02-processes-services
do_setup() {
  systemctl enable --now falcon-web.service >/dev/null 2>&1 || true
  student_dir "$SH/lab"; student_dir "$SH/lab/m02"
  if [ "$RESET" = 1 ]; then as_student rm -f -- "$SH/lab/m02/falcon.txt"; fi
}
do_check() {
  local F="$SH/lab/m02/falcon.txt"
  [ -f "$F" ] || { fail "$F does not exist yet"; return; }
  expect_answer "$F" user "$(systemctl show -p User --value falcon-web)" "service account"
  expect_answer "$F" pid "$(systemctl show -p MainPID --value falcon-web)" "main PID (changes after every restart)"
  expect_answer "$F" port 8000 "listening TCP port"
  expect_answer "$F" state "$(systemctl show -p ActiveState --value falcon-web)" "running state"
  expect_answer "$F" boot "$(systemctl is-enabled falcon-web 2>/dev/null)" "starts at boot"
}
do_solve() {
  local pid; pid="$(systemctl show -p MainPID --value falcon-web)"
  as_user student bash -c "mkdir -p ~/lab/m02; printf 'user=svc-falcon\npid=$pid\nport=8000\nstate=active\nboot=enabled\n' > ~/lab/m02/falcon.txt"
}
