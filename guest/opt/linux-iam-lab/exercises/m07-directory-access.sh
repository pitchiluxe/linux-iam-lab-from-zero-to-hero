# m07-directory-access
LM() { ldapmodify -x -ZZ -H ldap://ldap.iamlab.test -D cn=admin,dc=iamlab,dc=test -y "$ETC/ldap-admin.pw" "$@"; }
LS() { ldapsearch -LLL -x -ZZ -H ldap://ldap.iamlab.test -b dc=iamlab,dc=test "$@" 2>/dev/null; }
members() { LS '(cn=linux-login)' memberUid | sed -n 's/^memberUid: //p'; }
do_setup() {
  if [ "$RESET" = 1 ]; then
    local u
    for u in pshah tcole; do
      if members | grep -qx "$u"; then
        printf 'dn: cn=linux-login,ou=groups,dc=iamlab,dc=test\nchangetype: modify\ndelete: memberUid\nmemberUid: %s\n' "$u" | LM >/dev/null
      fi
    done
    sss_cache -E 2>/dev/null || true
  fi
  pam_login pshah "$(persona_pw pshah)" || true   # leaves the access-denied line in the log
  faillock --user pshah --reset 2>/dev/null || true
}
do_check() {
  members | grep -qx pshah && pass "pshah is a member of directory group linux-login" || fail "pshah is not in cn=linux-login (directory)"
  members | grep -qx tcole && fail "tcole was added to linux-login" || pass "tcole is not in linux-login"
  grep -q '^simple_allow_groups = linux-login$' /etc/sssd/sssd.conf && pass "SSSD access rule unchanged" || fail "/etc/sssd/sssd.conf was changed - fix access in the directory instead"
  grep -q '^pshah:' /etc/passwd && fail "a LOCAL pshah account exists - remove it (userdel pshah)" || pass "no local shadow account for pshah"
  sss_cache -E 2>/dev/null || true
  pam_login pshah "$(persona_pw pshah)" && pass "ALLOWED: real password login for pshah (auth + account through SSSD)" || fail "pshah still cannot log in (sss_cache -E?)"
  pam_login tcole "$(persona_pw tcole)" && fail "tcole CAN log in" || pass "DENIED: tcole (correct password, not authorized)"
  faillock --user tcole --reset 2>/dev/null || true
}
do_solve() {
  members | grep -qx pshah || printf 'dn: cn=linux-login,ou=groups,dc=iamlab,dc=test\nchangetype: modify\nadd: memberUid\nmemberUid: pshah\n' | LM >/dev/null
  sss_cache -E
}
