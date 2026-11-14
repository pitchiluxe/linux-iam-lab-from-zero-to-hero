# m07-ldap-basics
B=dc=iamlab,dc=test
L() { local c=$1; shift; "$c" -x -ZZ -H ldap://ldap.iamlab.test -D "cn=admin,$B" -y "$ETC/ldap-admin.pw" "$@"; }
LS() { ldapsearch -LLL -x -ZZ -H ldap://ldap.iamlab.test "$@" 2>/dev/null; }
has() { LS -b "$1" -s base "${2:-(objectClass=*)}" dn | grep -q '^dn:'; }   # dn [filter]
attr() { LS -b "$1" -s base '(objectClass=*)' "$2" | sed -n "s/^$2: //p"; }
do_setup() {
  student_dir "$SH/lab"; student_dir "$SH/lab/m07"
  if [ "$RESET" = 1 ]; then
    local dn
    for dn in "uid=rlopez,ou=iam,$B" "cn=iam-analysts,ou=iam,$B" "ou=iam,$B"; do
      L ldapdelete "$dn" >/dev/null 2>&1 || true
    done
    as_student find "$SH/lab/m07" -maxdepth 1 \( -name '*.ldif' -o -name 'iam-verify.txt' \) -delete 2>/dev/null || true
    sss_cache -E 2>/dev/null || true
  fi
}
do_check() {
  has "ou=iam,$B" '(objectClass=organizationalUnit)' && pass "OU ou=iam exists" || { fail "ou=iam,$B does not exist (or is not an organizationalUnit)"; return; }
  local U="uid=rlopez,ou=iam,$B" G="cn=iam-analysts,ou=iam,$B"
  if has "$U" '(&(objectClass=inetOrgPerson)(objectClass=posixAccount))'; then
    pass "user entry $U exists (inetOrgPerson + posixAccount)"
    [ "$(attr "$U" uidNumber)" = 10020 ] && pass "uidNumber 10020" || fail "uidNumber should be 10020"
    [ "$(attr "$U" gidNumber)" = 10000 ] && pass "gidNumber 10000 (dir-staff)" || fail "gidNumber should be 10000"
    [ "$(attr "$U" homeDirectory)" = /home/rlopez ] && pass "homeDirectory /home/rlopez" || fail "homeDirectory should be /home/rlopez"
    [ "$(attr "$U" cn)" = "Rosa Lopez" ] && pass "cn Rosa Lopez" || fail "cn should be 'Rosa Lopez'"
  else
    fail "$U missing, or missing objectClass inetOrgPerson/posixAccount"
  fi
  if has "$G" '(objectClass=posixGroup)'; then
    pass "group entry $G exists (posixGroup)"
    [ "$(attr "$G" gidNumber)" = 10020 ] && pass "group gidNumber 10020" || fail "group gidNumber should be 10020"
    attr "$G" memberUid | grep -qx rlopez && pass "rlopez is a memberUid of iam-analysts" || fail "add memberUid: rlopez to the group"
  else
    fail "$G missing (or not a posixGroup)"
  fi
  sss_cache -E 2>/dev/null || true
  [ "$(getent -s sss passwd rlopez | cut -d: -f3)" = 10020 ] && pass "Linux resolves rlopez through SSSD (getent passwd)" || fail "getent passwd rlopez does not show UID 10020 yet"
  in_group rlopez iam-analysts && pass "id rlopez shows iam-analysts" || fail "id rlopez does not list iam-analysts"
  local F="$SH/lab/m07/iam-verify.txt"
  if [ -f "$F" ]; then
    as_student grep -qx "dn: $U" "$F" && as_student grep -qx "dn: $G" "$F" \
      && pass "ldapsearch evidence saved in $F" || fail "$F should contain the ldapsearch output with both dn: lines"
  else
    fail "$F does not exist yet (save your ldapsearch verification)"
  fi
  [ -z "$(as_student find "$SH/lab/m07" -maxdepth 1 -name '*.ldif' 2>/dev/null)" ] \
    && pass "temporary LDIF files cleaned up" || fail "remove the temporary .ldif files from ~/lab/m07"
}
do_solve() {
  local U="uid=rlopez,ou=iam,$B" G="cn=iam-analysts,ou=iam,$B"
  has "ou=iam,$B" || printf 'dn: ou=iam,%s\nobjectClass: organizationalUnit\nou: iam\n' "$B" | L ldapadd >/dev/null
  has "$U" || printf 'dn: %s\nobjectClass: inetOrgPerson\nobjectClass: posixAccount\nuid: rlopez\ncn: Rosa Lopez\ngivenName: Rosa\nsn: Lopez\ntitle: IAM Analyst\nmail: rlopez@iamlab.test\nuidNumber: 10020\ngidNumber: 10000\nhomeDirectory: /home/rlopez\nloginShell: /bin/bash\n' "$U" | L ldapadd >/dev/null
  has "$G" || printf 'dn: %s\nobjectClass: posixGroup\ncn: iam-analysts\ngidNumber: 10020\nmemberUid: rlopez\n' "$G" | L ldapadd >/dev/null
  as_user student bash -c "mkdir -p ~/lab/m07; rm -f ~/lab/m07/*.ldif; ldapsearch -LLL -x -ZZ -H ldap://ldap.iamlab.test -b ou=iam,$B dn > ~/lab/m07/iam-verify.txt"
  sss_cache -E
}
