#!/bin/bash
# Fixture tests for check-pg-counterpart.sh.
#
# Pins the PostgreSQL-baseline rule: a T-SQL migration at or below the newest
# migrations-pg/B<stamp>__*.pg.sql is covered by it, one after it still needs its own .pg.sql,
# and a repo with no baseline behaves exactly as before.
#
# Usage: ./.github/scripts/__tests__/check-pg-counterpart.test.sh
# Exit 0 = all cases pass.

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/check-pg-counterpart.sh"
PASS=0
FAIL=0

# Builds a repo whose base commit has nothing, then adds the T-SQL files in $1 and the
# migrations-pg files in $2 (space-separated names) in one commit. Echoes the directory.
make_repo() {
  local tsql="$1" pg="$2"
  local dir; dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" config user.email t@t.local
  git -C "$dir" config user.name test
  git -C "$dir" commit -q --allow-empty -m base
  git -C "$dir" tag base
  mkdir -p "$dir/migrations" "$dir/migrations-pg"
  for f in $tsql; do echo "-- t" > "$dir/migrations/$f"; done
  for f in $pg; do echo "-- p" > "$dir/migrations-pg/$f"; done
  git -C "$dir" add -A
  git -C "$dir" commit -q -m head
  echo "$dir"
}

# check <name> <expected exit> <tsql files> <pg files>
check() {
  local name="$1" want="$2"
  local dir; dir=$(make_repo "$3" "$4")
  if [ -z "$dir" ] || [ ! -d "$dir/.git" ]; then
    echo "FAIL  $name: fixture repo not created"; FAIL=$((FAIL + 1)); return
  fi
  local out got
  out=$(cd "$dir" && PG_COUNTERPART_LEVEL=error "$SCRIPT" base HEAD 2>&1); got=$?
  if [ "$got" -eq "$want" ]; then
    echo "pass  $name"; PASS=$((PASS + 1))
  else
    echo "FAIL  $name: exit $got, wanted $want"; echo "$out" | sed 's/^/        /'; FAIL=$((FAIL + 1))
  fi
  rm -rf "$dir"
}

check "no baseline, counterpart present" 0 \
  "V202601010000__v1__A.sql" "V202601010000__v1__A.pg.sql"
check "no baseline, counterpart missing" 1 \
  "V202601010000__v1__A.sql" ""
check "migration below the baseline is covered" 0 \
  "V202601010000__v1__A.sql" "B202602010000__v1__Baseline.pg.sql"
check "migration at the baseline's stamp is covered" 0 \
  "V202602010000__v1__A.sql" "B202602010000__v1__Baseline.pg.sql"
check "migration after the baseline still needs its own" 1 \
  "V202603010000__v1__A.sql" "B202602010000__v1__Baseline.pg.sql"
check "the newest of several baselines decides" 0 \
  "V202603010000__v1__A.sql" "B202602010000__v1__Old.pg.sql B202604010000__v2__New.pg.sql"
check "mixed: covered one passes, later one without a counterpart fails" 1 \
  "V202601010000__v1__A.sql V202603010000__v1__B.sql" "B202602010000__v1__Baseline.pg.sql"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
