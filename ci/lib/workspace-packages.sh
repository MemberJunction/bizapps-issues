#!/usr/bin/env bash
#
# Which packages does this repo publish? Shared by the three publish validators
# (validate-npm-packages.sh, validate-package-files.sh, validate-package-repository.sh) so they
# can never disagree on the answer.
#
# The list is DERIVED, never named. An earlier version filtered on a hardcoded scope
# (`@mj-biz-apps/common-*`, carried over from bizapps-common); in this repo that matched nothing,
# so all three gates checked zero packages and passed. Deriving from the workspace means a copied
# script checks whatever packages the repo it lands in actually has.
#
# Source of truth: the `workspaces` globs in the root package.json -- the same list the OpenApp
# install engine and publish.yml's jq steps read (pnpm-workspace.yaml mirrors it; see the note
# there). Private packages are excluded by each caller, because changesets never publishes them
# (@changesets/cli: `packages.filter(pkg => !pkg.packageJson.private)`).
#
# Source it from the repo root; it defines functions and runs nothing.

# Prints one package.json path per workspace package, in glob order. Fails (returns 1, with a
# GitHub error annotation) when there is no workspaces list or it matches nothing: a gate over an
# empty list would report all-clear having checked nothing.
workspace_package_jsons() {
  local globs glob dir found=0
  if ! globs=$(jq -r '(.workspaces // []) | if type == "object" then .packages // [] else . end | .[]' package.json 2>/dev/null) \
     || [ -z "$globs" ]; then
    echo "::error::No \"workspaces\" list in the root package.json -- cannot tell which packages this repo publishes" >&2
    return 1
  fi
  # A `!pattern` entry removes matching directories from the list (npm/pnpm workspace semantics),
  # so collect those first and test every candidate against them.
  local negations="" neg excluded
  while IFS= read -r glob; do
    case "$glob" in '!'*) negations="$negations${glob#!}"$'\n' ;; esac
  done <<< "$globs"
  while IFS= read -r glob; do
    case "$glob" in '!'*) continue ;; esac
    for dir in $glob; do                     # unquoted on purpose: the shell expands the glob
      [ -f "$dir/package.json" ] || continue
      excluded=0
      while IFS= read -r neg; do
        [ -n "$neg" ] || continue
        case "$dir" in $neg) excluded=1 ;; esac   # unquoted: glob match, not string compare
      done <<< "$negations"
      [ "$excluded" -eq 1 ] && continue
      echo "$dir/package.json"
      found=$((found + 1))
    done
  done <<< "$globs"
  if [ "$found" -eq 0 ]; then
    echo "::error::The root package.json workspaces globs match no package.json -- nothing to validate" >&2
    return 1
  fi
}
