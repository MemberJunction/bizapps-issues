#!/usr/bin/env bash
# A PR that adds a migration must carry a minor-or-major changeset.
#
# Its own script rather than inline YAML for one reason: --self-test. The inline version shipped
# a regex that only matched SINGLE-quoted changesets, and 39 of this repo's 69 changesets are
# double-quoted — including both that were pending on `next` when it was written. It would have
# told those authors "your changeset only requests a patch", which is false, and sent them
# hunting in the wrong file. A check whose failure message can lie needs a test.
#
# Usage:  check-migration-changeset.sh <base-ref> <head-ref>
#         check-migration-changeset.sh --self-test
#
# BUMP_LEVEL_EXEMPT=true reports and passes, for the cases that genuinely are not features:
# a comment fix inside a migration, or a second migration in a window a minor already covers.
set -euo pipefail

# `changeset add` writes the package line as either quote style, and has over this repo's
# history written both. Tolerate unquoted too, plus trailing whitespace and CRLF.
BUMP_LINE_RE="^[[:space:]]*['\"]?[^'\":[:space:]]+['\"]?[[:space:]]*:[[:space:]]*(minor|major)[[:space:]]*$"

has_sufficient_bump() {
  grep -qE "$BUMP_LINE_RE" "$1"
}

self_test() {
  local dir rc=0
  dir=$(mktemp -d)
  trap 'rm -rf "$dir"' RETURN

  _case() { # name, expect(pass|fail), body
    printf '%s' "$3" > "$dir/c.md"
    if has_sufficient_bump "$dir/c.md"; then got=pass; else got=fail; fi
    if [ "$got" = "$2" ]; then
      printf '  ok    %-34s (%s)\n' "$1" "$got"
    else
      printf '  FAIL  %-34s expected %s, got %s\n' "$1" "$2" "$got"; rc=1
    fi
  }

  _case "single-quoted minor"   pass "---
'@mj-biz-apps/common-entities': minor
---
text"
  _case "double-quoted minor"   pass '---
"@mj-biz-apps/common-entities": minor
---
text'
  _case "double-quoted major"   pass '---
"@mj-biz-apps/common-entities": major
---
text'
  _case "unquoted minor"        pass "---
@mj-biz-apps/common-entities: minor
---
text"
  _case "trailing whitespace"   pass "---
'@mj-biz-apps/common-entities': minor   
---
text"
  _case "CRLF line ending"      pass "$(printf -- '---\r\n"@mj-biz-apps/common-entities": minor\r\n---\r\ntext')"
  _case "patch only"            fail '---
"@mj-biz-apps/common-entities": patch
---
text'
  _case "word minor in the body" fail '---
"@mj-biz-apps/common-entities": patch
---
This is a minor cleanup.'
  _case "no frontmatter"        fail 'just prose about a major change'

  [ "$rc" -eq 0 ] && echo "self-test passed" || echo "::error::check-migration-changeset self-test FAILED"
  return "$rc"
}

if [ "${1:-}" = "--self-test" ]; then
  self_test
  exit $?
fi

BASE="${1:?usage: check-migration-changeset.sh <base-ref> <head-ref>}"
HEAD_REF="${2:?usage: check-migration-changeset.sh <base-ref> <head-ref>}"

MIGRATIONS=$(git diff --name-only "$BASE" "$HEAD_REF" | grep -E '^migrations/.*\.sql$' || true)
if [ -z "$MIGRATIONS" ]; then
  echo "No migration changes — any bump level is fine"
  exit 0
fi

if [ "${BUMP_LEVEL_EXEMPT:-false}" = "true" ]; then
  echo "::warning::Exempt via the bump-level-exempt label. Migrations changed:"
  echo "$MIGRATIONS" | sed 's/^/  /'
  exit 0
fi

CHANGESETS=$(git diff --name-only "$BASE" "$HEAD_REF" | grep -E '^\.changeset/.*\.md$' | grep -v 'README.md' || true)
if [ -z "$CHANGESETS" ]; then
  echo "::error::This PR adds migrations but no changeset. A schema change is a feature: run 'pnpm exec changeset' and pick minor. If the migration genuinely is not a feature — a re-captured baseline, a comment fix — label the PR 'bump-level-exempt'. Migrations changed:"
  echo "$MIGRATIONS" | sed 's/^/  /'
  exit 1
fi

for f in $CHANGESETS; do
  if [ -f "$f" ] && has_sufficient_bump "$f"; then
    echo "Found a minor/major changeset: $f"
    exit 0
  fi
done

echo "::error::This PR adds migrations, and its changeset(s) only request a patch. A consumer upgrading on a patch would not expect the schema to change — raise one to minor. If the migration genuinely is not a feature, label the PR 'bump-level-exempt'. Changesets in this PR:"
echo "$CHANGESETS" | sed 's/^/  /'
exit 1
