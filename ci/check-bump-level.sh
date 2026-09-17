#!/usr/bin/env bash
# A release that changes the shipped SCHEMA or METADATA must be at least a minor.
#
# Two sources, one rule. `migrations/` is the schema; `metadata/` is the seed data and
# configuration MetadataSync pushes into a customer's database. Both alter what a consumer
# gets when they upgrade, so neither belongs in a patch.
#
# One implementation, called from every place this is gated, so the rule cannot drift
# between them. It asserts a property of the RELEASE, not of a contributing PR: changesets
# aggregate, so a single minor in the release window already makes the release a minor, and
# a small follow-up migration arriving with a patch changeset is not a mistake.
#
# Expects to run in a checkout with tags fetched, at the commit whose version should be
# judged — i.e. somewhere the version is already RESOLVED (a Version Packages PR, or a
# release PR), not on a branch where changesets are still pending.
#
# BUMP_LEVEL_EXEMPT=true skips the check, for the cases that genuinely are not features:
# a re-captured baseline, a comment fix in a migration.
set -euo pipefail

if [ "${BUMP_LEVEL_EXEMPT:-false}" = "true" ]; then
  echo "Exempt via label — skipping the bump-level check"
  exit 0
fi

# --- metadata: tell a real edit apart from bookkeeping -------------------------------------
#
# Every MetadataSync record carries a `sync` block that `mj sync push` rewrites on every run:
#
#     "sync": { "lastModified": "2026-09-07T14:18:30.894Z", "checksum": "6c752d9c..." }
#
# A raw `git diff --name-only metadata/` therefore fires on commits that changed nothing a
# consumer can observe — bizapps-common 388db6a ("refresh .entities.json checksums after geo
# pin push") is exactly that: fourteen changed lines, all of them `sync`. A check that demands
# a minor for those is a check people learn to route around with the exempt label, which costs
# us the times it is right.
#
# So compare STRUCTURE with `sync` dropped at every depth, not text. Parsing also means a
# reserialization — key order, indentation, a trailing newline — is not a change either.
# `sync` is the only key dropped: `fields` and `primaryKey` are both substantive, and a new
# `primaryKey` is a new record.
normalize_metadata_json() {
  jq -S 'def strip:
           if   type == "object" then with_entries(select(.key != "sync")) | map_values(strip)
           elif type == "array"  then map(strip)
           else . end;
         strip'
}

# Echoes the metadata files that changed substantively between two refs, one per line, and
# explains each decision on stderr so a CI log says WHY a file counted rather than just that it
# did. Three outcomes per file:
#
#   added / deleted   a normal, substantive change — a metadata record appearing or disappearing
#                     is exactly what this rule exists to catch. Reported as such, not as an error.
#   unreadable        genuinely could not be parsed. Counted as changed, loudly, naming the ref
#                     and the reason: guessing "unchanged" on a file you failed to read is worse
#                     than asking a human.
#   compared          both sides parsed; counted only if they differ once every `sync` block is
#                     stripped, so a rewritten checksum or a reserialized file is not a change.
substantive_metadata_changes() {
  local base="$1" head="$2" file base_json head_json changed=""
  local in_base in_head

  # `while read`, not `for $(...)`: a metadata path containing a space would otherwise be split
  # into fragments and silently mis-handled.
  while IFS= read -r file; do
    [ -n "$file" ] || continue

    in_base=false; in_head=false
    git cat-file -e "$base:$file" 2>/dev/null && in_base=true
    git cat-file -e "$head:$file" 2>/dev/null && in_head=true

    if [ "$in_base" = false ] && [ "$in_head" = true ]; then
      echo "  ADDED    $file — a new metadata file is a substantive change" >&2
      changed="${changed}${file}"$'\n'; continue
    fi
    if [ "$in_base" = true ] && [ "$in_head" = false ]; then
      echo "  DELETED  $file — a removed metadata file is a substantive change" >&2
      changed="${changed}${file}"$'\n'; continue
    fi
    if [ "$in_base" = false ] && [ "$in_head" = false ]; then
      echo "  MISSING  $file — git reported it as changed but it exists at neither ref; counting it" >&2
      changed="${changed}${file}"$'\n'; continue
    fi

    case "$file" in
      *.json) ;;
      *) echo "  NOT JSON $file — cannot strip sync bookkeeping from a non-JSON file; counting it" >&2
         changed="${changed}${file}"$'\n'; continue ;;
    esac

    if ! base_json=$(git show "$base:$file" 2>/dev/null | normalize_metadata_json 2>&1); then
      echo "  UNREADABLE $file at $base — not valid JSON, so a cosmetic-vs-real comparison is" >&2
      echo "             impossible; counting it as changed. jq said: ${base_json%%$'\n'*}" >&2
      changed="${changed}${file}"$'\n'; continue
    fi
    if ! head_json=$(git show "$head:$file" 2>/dev/null | normalize_metadata_json 2>&1); then
      echo "  UNREADABLE $file at $head — not valid JSON, so a cosmetic-vs-real comparison is" >&2
      echo "             impossible; counting it as changed. jq said: ${head_json%%$'\n'*}" >&2
      changed="${changed}${file}"$'\n'; continue
    fi

    if [ "$base_json" != "$head_json" ]; then
      changed="${changed}${file}"$'\n'
    fi
  done <<EOF
$(git diff --name-only "$base" "$head" -- metadata/ || true)
EOF

  printf '%s' "$changed"
}

LAST_TAG=$(git tag --list 'v*' --sort=-v:refname | head -1)
if [ -z "$LAST_TAG" ]; then
  echo "No v* tag yet — nothing to compare against"
  exit 0
fi

MIGRATIONS=$(git --no-pager diff --name-only "$LAST_TAG" HEAD -- migrations/ || true)
METADATA=$(substantive_metadata_changes "$LAST_TAG" HEAD)

RAW_METADATA=$(git --no-pager diff --name-only "$LAST_TAG" HEAD -- metadata/ || true)
if [ -n "$RAW_METADATA" ] && [ -z "$METADATA" ]; then
  echo "metadata/ changed since $LAST_TAG, but nothing substantive — sync bookkeeping or reserialization only, not counted:"
  echo "$RAW_METADATA" | sed 's/^/  /'
fi

if [ -z "$MIGRATIONS" ] && [ -z "$METADATA" ]; then
  echo "No schema or metadata changes since $LAST_TAG — any bump level is fine"
  exit 0
fi

CHANGED=""
[ -n "$MIGRATIONS" ] && CHANGED="migrations/"
[ -n "$METADATA" ] && CHANGED="${CHANGED:+$CHANGED and }metadata/"

VERSION=$(jq -r .version packages/Entities/package.json)
PREV=${LAST_TAG#v}

if [ "$VERSION" = "$PREV" ]; then
  echo "::error::$CHANGED changed since $LAST_TAG but the version is still $VERSION. Nothing has been versioned yet — merge the Version Packages PR on next first."
  printf '%s\n%s\n' "$MIGRATIONS" "$METADATA" | grep -v '^$' | sed 's/^/  /'
  exit 1
fi

IFS='.' read -r PMAJ PMIN _ <<< "$PREV"
IFS='.' read -r NMAJ NMIN _ <<< "$VERSION"
if [ "$NMAJ" -gt "$PMAJ" ] || { [ "$NMAJ" -eq "$PMAJ" ] && [ "$NMIN" -gt "$PMIN" ]; }; then
  echo "$PREV -> $VERSION is a minor or major bump, and $CHANGED changed — ok"
  exit 0
fi

echo "::error::This release bumps $PREV -> $VERSION, a patch, but $CHANGED changed since $LAST_TAG. A consumer upgrading on a patch would not expect the schema or the seeded metadata to change. Raise one changeset on next to minor, then MERGE the Version Packages PR it regenerates — the fix only takes effect once that merge puts the new version on next; or label this PR 'bump-level-exempt' if the change genuinely is not a feature. Changed:"
printf '%s\n%s\n' "$MIGRATIONS" "$METADATA" | grep -v '^$' | sed 's/^/  /'
exit 1
