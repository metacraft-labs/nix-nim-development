#!/usr/bin/env bash
# Independent native lifetime oracle: actual Valgrind, resources and compilers.
# Requires a supported Linux environment; absence of Valgrind is a hard error.
set -euo pipefail
sources=$(cd -- "$(dirname -- "$0")" && pwd)
: "${WRAPPED_NIM:?}" "${FIRST_FIX_NIM:?}" "${OWNERSHIP_OUTPUT:?}"
command -v valgrind >/dev/null
mkdir -p "$OWNERSHIP_OUTPUT"
output=$OWNERSHIP_OUTPUT
check_case() {
  local label=$1 compiler=$2 backend=$3 memory=$4 inference=$5 source=$6 expected=$7
  "$compiler" "$backend" --mm:"$memory" --sinkInference:"$inference" -d:useMalloc --hints:off \
    --nimcache:"$output/$label-cache" --out:"$output/$label" "$source" \
    > "$output/$label.compile.log" 2>&1 || { cat "$output/$label.compile.log"; exit 2; }
  local rc=0
  valgrind --error-exitcode=99 --leak-check=full --errors-for-leak-kinds=all \
    "$output/$label" > "$output/$label.run.log" 2> "$output/$label.valgrind.log" || rc=$?
  [[ $rc == "$expected" ]] || { cat "$output/$label.valgrind.log" "$output/$label.run.log"; exit 1; }
  if [[ $expected == 0 ]]; then
    grep -q 'ERROR SUMMARY: 0 errors from 0 contexts' "$output/$label.valgrind.log"
    grep -q 'All heap blocks were freed -- no leaks are possible' "$output/$label.valgrind.log"
  else
    # The old compiler must trigger actual memory errors, not just an assertion.
    grep -Eq 'Invalid (read|write|free)' "$output/$label.valgrind.log"
  fi
  echo "PASS $label expected=$expected" >> "$output/matrix.log"
}
for memory in arc orc; do
  check_case "first-fix-$memory-subject" "$FIRST_FIX_NIM" c "$memory" off "$sources/constructor-resource/subject.nim" 99
  check_case "first-fix-$memory-control" "$FIRST_FIX_NIM" c "$memory" off "$sources/constructor-resource/control.nim" 0
  for backend in c cpp; do
    for fixture in subject control; do
      check_case "$backend-$memory-$fixture" "$WRAPPED_NIM" "$backend" "$memory" off "$sources/constructor-resource/$fixture.nim" 0
    done
    for inference in off on; do
      check_case "$backend-$memory-semantics-$inference" "$WRAPPED_NIM" "$backend" "$memory" "$inference" "$sources/phantom-hooks/tconstructorsemantics.nim" 0
    done
  done
done
cat "$output/matrix.log"
