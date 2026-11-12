# m04-acl
RV=/srv/hr/reviews
REVIEW=$RV/2026-q4-reviews.txt
SAL=/srv/hr/salaries-2026.txt
do_setup() {
  install -d -o root -g hr -m 2770 /srv/hr
  if [ "$RESET" = 1 ] || [ ! -d "$RV" ]; then
    setfacl -x u:rmorgan /srv/hr 2>/dev/null || true
    rm -rf "$RV"
    install -d -o root -g hr -m 2770 "$RV"
    echo "Q4 reviews (fictional)" > "$REVIEW"
    echo "Q3 reviews (fictional)" > "$RV/2026-q3-reviews.txt"
    chown hlopez:hr "$RV"/*.txt; chmod 660 "$RV"/*.txt
    gpasswd -d rmorgan hr >/dev/null 2>&1 || true
  fi
  if [ ! -f "$SAL" ] || [ "$RESET" = 1 ]; then
    echo "Salary bands 2026 (fictional)" > "$SAL"; chown hlopez:hr "$SAL"; chmod 660 "$SAL"; setfacl -b "$SAL"
  fi
}
do_check() {
  in_group rmorgan hr && fail "rmorgan was added to hr - use an ACL instead" || pass "rmorgan is not in hr"
  can rmorgan cat "$REVIEW" && pass "ALLOWED as rmorgan: read an existing review" || fail "rmorgan cannot read $REVIEW"
  cannot rmorgan sh -c "test -w '$REVIEW'" && pass "DENIED as rmorgan: modify a review" || fail "rmorgan can modify reviews (read-only required)"
  local t="$RV/.lab-check-$$.txt"
  as_user hlopez sh -c "umask 007; echo new-review > '$t'"
  can rmorgan cat "$t" && pass "ALLOWED as rmorgan: read a NEW review (default ACL)" || fail "rmorgan cannot read newly created reviews (default ACL missing)"
  can hlopez sh -c "test -w '$REVIEW'" && pass "ALLOWED as hlopez (HR): still edits reviews" || fail "HR lost write access to reviews"
  rm -f "$t"
  cannot rmorgan ls /srv/hr && pass "DENIED as rmorgan: list /srv/hr" || fail "rmorgan can list /srv/hr (give traverse --x only)"
  cannot rmorgan cat "$SAL" && pass "DENIED as rmorgan: read other HR files" || fail "rmorgan can read $SAL"
  cannot dpatel cat "$REVIEW" && pass "DENIED as dpatel: read a review" || fail "dpatel can read reviews"
}
do_solve() {
  setfacl -m u:rmorgan:--x /srv/hr
  setfacl -R -m u:rmorgan:rX "$RV"
  setfacl -d -m u:rmorgan:rX "$RV"
}
