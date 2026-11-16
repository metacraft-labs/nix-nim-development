#!/usr/bin/env bash
# Derive the deliberately wrong nominal-hook fixture: a copy of phantom-hooks
# whose owner module dispatches string/int hooks backwards. The package check
# builds it as its own derivation, so the mutant is compiled from a fixed store
# path (see tests/check_ownership.sh); standalone runs create it in the output.
set -euo pipefail
source=${1:?usage: make_wrong_hook_fixture.sh PHANTOM_HOOKS_DIR DESTINATION}
destination=${2:?usage: make_wrong_hook_fixture.sh PHANTOM_HOOKS_DIR DESTINATION}
owner="$destination/phantomhooks/owner.nim"
cp -R "$source" "$destination"
chmod -R u+w "$destination"
# Refuse a no-op mutation: if the fixture no longer spells this predicate, the
# "wrong hook" case would silently compile the correct program.
grep -Fq 'when T is string:' "$owner"
sed -i 's/when T is string:/when T is int:/g' "$owner"
if grep -Fq 'when T is string:' "$owner"; then
  echo "wrong-hook mutation left a string predicate in $owner" >&2
  exit 1
fi
