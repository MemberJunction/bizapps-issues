#!/usr/bin/env bash
#
# MJ Central runs on PostgreSQL and installs BizApps. App migrations are authored in T-SQL and
# run through the same Skyway engine MJ uses, which needs a converted Postgres file per
# migration. Without one, a release carrying a new migration ships something MJ Central cannot
# run — and nothing else in this pipeline notices.
#
# Naming follows MJ's own convention, which is the authority here:
#   migrations/V<stamp>__<name>.sql          T-SQL
#   migrations-pg/V<stamp>__<name>.pg.sql    its Postgres counterpart   (227 in MJ)
#   migrations-pg/V<stamp>__<name>.pg-only.sql   Postgres-only, no T-SQL side   (36 in MJ)
#
# Only NEW migrations are held to this. One existing file here spells it `.pgonly.sql`, which
# is not MJ's convention — and it stays that way: renaming a released migration is the very
# thing the immutability check forbids, because Flyway checksums the file and every database
# that already ran it would fail validation. The convention binds what we add, not what shipped.
set -euo pipefail

BASE="${1:?usage: check-pg-counterpart.sh <base-ref> <head-ref>}"
HEAD_REF="${2:?usage: check-pg-counterpart.sh <base-ref> <head-ref>}"

ADDED=$(git diff --name-only --diff-filter=A "$BASE" "$HEAD_REF" -- 'migrations/*.sql' || true)
if [ -z "$ADDED" ]; then
  echo "No new T-SQL migration in this PR — nothing to pair"
  exit 0
fi

MISSING=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  stem=$(basename "$f" .sql)
  if [ -e "migrations-pg/${stem}.pg.sql" ]; then
    echo "  ok       $f  ->  migrations-pg/${stem}.pg.sql"
  else
    echo "  MISSING  $f  ->  migrations-pg/${stem}.pg.sql"
    MISSING="${MISSING}migrations-pg/${stem}.pg.sql"$'\n'
  fi
done <<< "$ADDED"

if [ -n "$MISSING" ]; then
  echo "::error::A new T-SQL migration has no PostgreSQL counterpart. MJ Central runs on Postgres and installs this app, so a release carrying this migration would ship something it cannot run. Add the converted file(s):"
  printf '%s' "$MISSING" | sed 's/^/  /'
  exit 1
fi
echo "Every new migration has its Postgres counterpart"
