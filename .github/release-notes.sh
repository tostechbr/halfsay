#!/bin/sh
# Release notes: the commit subjects since the previous tag, grouped by type (feat: → Features, fix: → Fixes, ...).
# Usage: .github/release-notes.sh v0.2.0 > notes.md
set -eu
tag=$1
previous=$(git describe --tags --abbrev=0 "$tag^" 2>/dev/null || true)
range=${previous:+$previous..}$tag

section() {  # a heading, then the commit types it gathers
  heading=$1
  shift
  types=$(echo "$*" | tr ' ' '|')
  lines=$(git log --no-merges --reverse --format=%s "$range" |
    sed -nE "s/^($types)(\([^)]*\))?!?: (.*)/\3/p" |
    awk '{ print "- " toupper(substr($0, 1, 1)) substr($0, 2) }')
  if [ -n "$lines" ]; then
    printf '## %s\n\n%s\n\n' "$heading" "$lines"
  fi
}

section Features feat
section Fixes fix
section Docs docs
section Other refactor perf test build ci chore
if [ -n "$previous" ]; then
  printf '**Full changelog**: https://github.com/%s/compare/%s...%s\n' "${GITHUB_REPOSITORY:-tostechbr/partway}" "$previous" "$tag"
fi
