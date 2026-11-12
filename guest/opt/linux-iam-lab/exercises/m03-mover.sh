# m03-mover
do_setup() {
  install -d -m 0755 /srv/lab03
  install -d -o root -g engineering -m 2770 /srv/lab03/engineering-design
  install -d -o root -g webops -m 2770 /srv/lab03/webops-runbooks
  [ -f /srv/lab03/engineering-design/falcon-architecture.md ] || { echo "# Falcon architecture (fictional)" > /srv/lab03/engineering-design/falcon-architecture.md; chgrp engineering /srv/lab03/engineering-design/falcon-architecture.md; chmod 660 /srv/lab03/engineering-design/falcon-architecture.md; }
  [ -f /srv/lab03/webops-runbooks/restart-falcon.md ] || { echo "# Runbook: restart Falcon (fictional)" > /srv/lab03/webops-runbooks/restart-falcon.md; chgrp webops /srv/lab03/webops-runbooks/restart-falcon.md; chmod 660 /srv/lab03/webops-runbooks/restart-falcon.md; }
  if [ "$RESET" = 1 ]; then
    usermod -G engineering,proj-falcon,ssh-users btran
  fi
}
do_check() {
  in_group btran engineering && fail "btran is still in engineering" || pass "btran removed from engineering"
  in_group btran webops && pass "btran added to webops" || fail "btran is not in webops"
  in_group btran proj-falcon && pass "kept proj-falcon" || fail "btran lost proj-falcon (usermod -G without -a?)"
  in_group btran ssh-users && pass "kept ssh-users" || fail "btran lost ssh-users (usermod -G without -a?)"
  can btran ls /srv/lab03/webops-runbooks && pass "ALLOWED as btran: list webops-runbooks" || fail "btran cannot list /srv/lab03/webops-runbooks"
  cannot btran ls /srv/lab03/engineering-design && pass "DENIED as btran: list engineering-design" || fail "btran can still list /srv/lab03/engineering-design"
}
do_solve() {
  gpasswd -d btran engineering >/dev/null 2>&1 || true
  usermod -aG webops btran
}
