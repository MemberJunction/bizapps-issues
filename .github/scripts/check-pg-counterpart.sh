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
# Three one-sided spellings are in use and all three are accepted: `.pg-only.sql` (MJ's, 36
# files), `.pgonly.sql` (one file here) and, for completeness, anything else already shipped.
# They are not reconciled, because renaming a released migration is the very thing the
# immutability check forbids — Flyway checksums the file, so every database that already ran it
# would fail validation. The convention binds what we ADD, not what shipped.
#
# Only newly-added T-SQL migrations are held to the pairing rule, so one-sided files of any
# spelling are simply never examined.
#
# A PostgreSQL BASELINE covers what came before it. An app whose PostgreSQL support started late
# ships one `migrations-pg/B<stamp>__<name>.pg.sql` carrying the whole history up to <stamp>
# instead of one counterpart per T-SQL file — and on a fresh PostgreSQL install Skyway applies the
# baseline and skips every migration at or below its version. So a T-SQL migration whose stamp is
# at or below the newest PostgreSQL baseline's is covered by that baseline and needs no file of its
# own. One added after the baseline still needs its own counterpart.
#
# Two levels, set by PG_COUNTERPART_LEVEL:
#   warning  at the door (PRs into next): annotate the PR, never fail it. Authors may add the
#            converted file in a later PR before the release.
#   error    at the gate (the release PR into main, base = last v* tag): the default. A release
#            must not ship a migration MJ Central cannot run.
set -euo pipefail

LEVEL="${PG_COUNTERPART_LEVEL:-error}"

BASE="${1:?usage: check-pg-counterpart.sh <base-ref> <head-ref>}"
HEAD_REF="${2:?usage: check-pg-counterpart.sh <base-ref> <head-ref>}"

ADDED=$(git diff --name-only --diff-filter=A "$BASE" "$HEAD_REF" -- 'migrations/*.sql' || true)
if [ -z "$ADDED" ]; then
  echo "No T-SQL migration added since $BASE — nothing to pair"
  exit 0
fi

# Newest PostgreSQL baseline's stamp (digits after the B), or empty when there is none.
PG_BASELINE=$( (ls migrations-pg/B*.pg.sql 2>/dev/null || true) | sed -n 's#^migrations-pg/B\([0-9][0-9]*\)__.*#\1#p' | sort | tail -1)

MISSING=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  stem=$(basename "$f" .sql)
  stamp=$(echo "$stem" | sed -n 's#^[VB]\([0-9][0-9]*\)__.*#\1#p')
  if [ -e "migrations-pg/${stem}.pg.sql" ]; then
    echo "  ok       $f  ->  migrations-pg/${stem}.pg.sql"
  elif [ -n "$PG_BASELINE" ] && [ -n "$stamp" ] && [ "${#stamp}" -eq "${#PG_BASELINE}" ] && [[ ! "$stamp" > "$PG_BASELINE" ]]; then
    echo "  ok       $f  ->  covered by PostgreSQL baseline B${PG_BASELINE}"
  else
    echo "  MISSING  $f  ->  migrations-pg/${stem}.pg.sql"
    MISSING="${MISSING}migrations-pg/${stem}.pg.sql"$'\n'
  fi
done <<< "$ADDED"

if [ -n "$MISSING" ]; then
  if [ "$LEVEL" = "warning" ]; then
    echo "::warning::A new T-SQL migration has no PostgreSQL counterpart yet. This does not block the PR, but the release will be blocked (rr: pg counterparts) until it exists. Add the converted file(s):"
    printf '%s' "$MISSING" | sed 's/^/  /'
    exit 0
  fi
  echo "::error::A new T-SQL migration has no PostgreSQL counterpart. MJ Central runs on Postgres and installs this app, so a release carrying this migration would ship something it cannot run. Add the converted file(s):"
  printf '%s' "$MISSING" | sed 's/^/  /'
  exit 1
fi
echo "Every new migration has its Postgres counterpart"
