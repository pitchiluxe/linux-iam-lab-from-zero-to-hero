#!/bin/bash
# Loads the lab's disposable directory (dc=iamlab,dc=test). Fictional people only.
# Idempotent. With --reset, people/groups are deleted and recreated to the baseline.
set -euo pipefail
. /opt/linux-iam-lab/lib/common.sh
BASE="dc=iamlab,dc=test"
ADM="cn=admin,$BASE"
PWF="$ETC/ldap-admin.pw"
L() { local c=$1; shift; "$c" -x -ZZ -H ldap://ldap.iamlab.test -D "$ADM" -y "$PWF" "$@"; }

if [ "${1:-}" = "--reset" ]; then
  for dn in $(L ldapsearch -LLL -b "$BASE" "(|(objectClass=posixAccount)(objectClass=posixGroup)(objectClass=organizationalUnit))" dn 2>/dev/null | sed -n 's/^dn: //p' | awk '{print length, $0}' | sort -rn | cut -d' ' -f2-); do
    L ldapdelete "$dn" >/dev/null 2>&1 || true
  done
fi

dirpw() { # user -> ssha hash of the persona password (creates it if needed)
  local u=$1 pw
  pw="$(persona_pw "$u")"
  if [ -z "$pw" ]; then
    pw="Dir-$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | cut -c1-10)-7"
    touch "$VAR/secrets/personas.env"; chmod 600 "$VAR/secrets/personas.env"
    echo "$u=$pw" >> "$VAR/secrets/personas.env"
  fi
  slappasswd -s "$pw"
}

exists() { L ldapsearch -LLL -b "$1" -s base dn >/dev/null 2>&1; }

add() { L ldapadd >/dev/null; }

exists "ou=people,$BASE" || add <<EOF
dn: ou=people,$BASE
objectClass: organizationalUnit
ou: people

dn: ou=groups,$BASE
objectClass: organizationalUnit
ou: groups
EOF

person() { # uid uidNumber "Given" "Sur" title
  local u=$1 n=$2 g=$3 s=$4 t=$5
  exists "uid=$u,ou=people,$BASE" && return 0
  add <<EOF
dn: uid=$u,ou=people,$BASE
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: $u
cn: $g $s
givenName: $g
sn: $s
title: $t
mail: $u@iamlab.test
uidNumber: $n
gidNumber: 10000
homeDirectory: /home/$u
loginShell: /bin/bash
userPassword: $(dirpw "$u")
EOF
}
group() { # cn gidNumber members...
  local cn=$1 n=$2; shift 2
  exists "cn=$cn,ou=groups,$BASE" && return 0
  { echo "dn: cn=$cn,ou=groups,$BASE"; echo "objectClass: posixGroup"; echo "cn: $cn"; echo "gidNumber: $n"
    for m in "$@"; do echo "memberUid: $m"; done; } | add
}

group dir-staff       10000
person nwalker  10001 Nadia  Walker "Site Reliability Engineer"
person pshah    10002 Priya  Shah   "Finance Systems Analyst"
person tcole    10003 Tomas  Cole   "Marketing Coordinator"
person mfischer 10004 Mia    Fischer "Security Engineer"
group linux-login     10010 nwalker mfischer
group dir-engineering 10011 nwalker tcole
group dir-finance     10012 pshah
group dir-security    10013 mfischer
