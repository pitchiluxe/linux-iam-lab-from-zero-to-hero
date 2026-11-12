#!/bin/bash
# Fictional company "Northwind Labs" used by every exercise. All names and data are fake.
# Idempotent: creates what is missing, never deletes learner work.
set -euo pipefail
. /opt/linux-iam-lab/lib/common.sh

# Role groups (GIDs 3001+)
ensure_group finance     3001
ensure_group hr          3002
ensure_group engineering 3003
ensure_group helpdesk    3004
ensure_group auditors    3005
ensure_group proj-falcon 3006
ensure_group webops      3007
ensure_group ssh-users   3008

# People (UIDs 2001+). Each gets a private group of the same name (UPG).
ensure_user aokafor 2001 "Amara Okafor - Finance Manager"        finance
ensure_user jkim    2002 "Jae Kim - Finance Analyst"             finance
ensure_user btran   2003 "Ben Tran - Software Engineer"          engineering,proj-falcon,ssh-users
ensure_user cdiaz   2004 "Chloe Diaz - HR Generalist"            hr
ensure_user hlopez  2005 "Hana Lopez - HR Manager"               hr,ssh-users
ensure_user dpatel  2006 "Dev Patel - Helpdesk Analyst"          helpdesk
ensure_user rmorgan 2007 "Riley Morgan - Internal Auditor"       auditors
ensure_user enovak  2008 "Eli Novak - Platform Engineer"         engineering
ensure_user kwright 2009 "Kai Wright - Contractor (ended)"       proj-falcon
usermod -aG ssh-users student
id labctl >/dev/null 2>&1 && usermod -aG ssh-users labctl

# Service accounts: system UIDs, no login shell, no usable password
id svc-falcon >/dev/null 2>&1 || useradd --system --home-dir /opt/falcon-web --no-create-home --shell /usr/sbin/nologin --comment "Falcon web service" svc-falcon
id svc-backup >/dev/null 2>&1 || useradd --system --home-dir /var/backups/lab --create-home --shell /usr/sbin/nologin --comment "Nightly backup job" svc-backup

# Folders
install -d -m 0755 /srv /srv/projects /srv/archive
install -d -o root -g finance -m 2770 /srv/finance
install -d -o root -g hr      -m 2770 /srv/hr
install -d -o root -g proj-falcon -m 2770 /srv/projects/falcon
[ -f /srv/finance/budget-2027.csv ] || { printf 'cost_center,owner,amount\nCC-100,aokafor,125000\nCC-200,jkim,48000\n' > /srv/finance/budget-2027.csv; chown aokafor:finance /srv/finance/budget-2027.csv; chmod 660 /srv/finance/budget-2027.csv; }
[ -f /srv/projects/falcon/README.md ] || { echo "# Project Falcon - internal web app (fictional)" > /srv/projects/falcon/README.md; chown btran:proj-falcon /srv/projects/falcon/README.md; chmod 664 /srv/projects/falcon/README.md; }
install -d -m 0755 "$DATA" "$DATA/keys" "$DATA/tickets" "$DATA/logs" "$DATA/handbook"

# Demo service owned by a service account (used in modules 2, 5 and the capstone)
install -d -o root -g root -m 0755 /opt/falcon-web
echo '<h1>Falcon web (lab demo)</h1>' > /opt/falcon-web/index.html
cat > /etc/systemd/system/falcon-web.service <<'EOF'
[Unit]
Description=Falcon web demo app (Linux IAM Lab)
After=network.target

[Service]
User=svc-falcon
Group=svc-falcon
ExecStart=/usr/bin/python3 -m http.server 8000 --bind 127.0.0.1 --directory /opt/falcon-web
Restart=on-failure
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now falcon-web.service >/dev/null 2>&1 || true

# Former contractor: account expired, kept for investigation exercises
chage -E 2025-12-31 kwright

# Persistent faillock records (see /etc/security/faillock.conf)
install -d -m 0755 /var/lib/faillock

# Student convenience
student_dir "$SH/lab"
cat > /etc/profile.d/linux-iam-lab.sh <<'EOF'
# Linux IAM Lab: make the Linux prompt unmistakable (green user@host, blue path).
if [ -n "$BASH_VERSION" ] && [ "$(id -un)" = "student" ]; then
  PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
  export HISTTIMEFORMAT='%F %T  '
  export HISTSIZE=5000 HISTFILESIZE=10000
  shopt -s histappend
  PROMPT_COMMAND='history -a'
fi
EOF
cat > /etc/motd <<'EOF'

  Linux IAM Lab - you are on the LINUX VM (iamlab01), not Windows.
  Course portal: the browser window on this desktop (or type: lab portal).   Help: lab help
  All people, companies and data in this lab are fictional.

EOF
