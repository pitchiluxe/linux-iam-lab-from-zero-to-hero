# m07-group-lifecycle
B=dc=iamlab,dc=test
L() { local c=$1; shift; "$c" -x -ZZ -H ldap://ldap.iamlab.test -D "cn=admin,$B" -y "$ETC/ldap-admin.pw" "$@"; }
LS() { ldapsearch -LLL -x -ZZ -H ldap://ldap.iamlab.test "$@" 2>/dev/null; }
has() { LS -b "$1" -s base dn | grep -q '^dn:'; }
ATLAS="cn=proj-atlas,ou=groups,$B"
TMP="cn=tmp-migration,ou=groups,$B"
add_tmp() { has "$TMP" || printf 'dn: %s\nobjectClass: posixGroup\ncn: tmp-migration\ngidNumber: 10019\ndescription: Temporary - 2025 server migration (expired)\nmemberUid: tcole\n' "$TMP" | L ldapadd >/dev/null; }
do_setup() {
  if [ "$RESET" = 1 ]; then
    L ldapdelete "$ATLAS" >/dev/null 2>&1 || true
    add_tmp
    sss_cache -E 2>/dev/null || true
  elif ! has "$ATLAS"; then
    add_tmp   # first start: plant the expired group (not re-planted once the ticket is done)
  fi
}
do_check() {
  sss_cache -E 2>/dev/null || true
  if has "$ATLAS"; then
    pass "group $ATLAS exists"
    LS -b "$ATLAS" -s base '(objectClass=posixGroup)' dn | grep -q '^dn:' && pass "objectClass posixGroup" || fail "proj-atlas must be a posixGroup"
    [ "$(LS -b "$ATLAS" -s base '(objectClass=*)' gidNumber | sed -n 's/^gidNumber: //p')" = 10014 ] && pass "gidNumber 10014" || fail "gidNumber should be 10014"
    [ -n "$(LS -b "$ATLAS" -s base '(objectClass=*)' description | sed -n 's/^description: //p')" ] && pass "group has a description (owner/purpose)" || fail "add a description: line explaining the group"
    local m; m="$(LS -b "$ATLAS" -s base '(objectClass=*)' memberUid | sed -n 's/^memberUid: //p' | sort | paste -sd, -)"
    [ "$m" = "mfischer,nwalker" ] && pass "members are exactly mfischer and nwalker" || fail "members should be exactly mfischer and nwalker (found: ${m:-none})"
  else
    fail "$ATLAS does not exist yet"
  fi
  grep -q '^proj-atlas:' /etc/group && fail "a LOCAL group proj-atlas exists in /etc/group - remove it (groupdel), use the directory" || pass "no local copy of the group"
  [ "$(getent -s sss group proj-atlas | cut -d: -f3)" = 10014 ] && pass "Linux resolves proj-atlas through SSSD" || fail "getent group proj-atlas does not show GID 10014 (sss_cache -E?)"
  in_group nwalker proj-atlas && in_group mfischer proj-atlas && pass "id nwalker / id mfischer list proj-atlas" || fail "id nwalker and id mfischer should both list proj-atlas"
  in_group tcole proj-atlas && fail "tcole is in proj-atlas" || true
  has "$TMP" && fail "expired group cn=tmp-migration still exists - delete it" || pass "expired group tmp-migration removed from the directory"
  getent group tmp-migration >/dev/null && fail "Linux still resolves tmp-migration (sss_cache -E)" || pass "Linux no longer resolves tmp-migration"
}
do_solve() {
  has "$ATLAS" || printf 'dn: %s\nobjectClass: posixGroup\ncn: proj-atlas\ngidNumber: 10014\ndescription: Project Atlas engineers - owner Nadia Walker\nmemberUid: nwalker\nmemberUid: mfischer\n' "$ATLAS" | L ldapadd >/dev/null
  L ldapdelete "$TMP" >/dev/null 2>&1 || true
  sss_cache -E
}
