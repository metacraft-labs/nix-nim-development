#!/usr/bin/env bash
# Real compilers and native resources only. Every compilation and execution is
# retained; known broken compilers are tested separately from corrected ones.
set -euo pipefail
sources=$(cd -- "$(dirname -- "$0")" && pwd)
: "${WRAPPED_NIM:?}" "${UNWRAPPED_NIM:?}" "${STOCK_NIM:?}" "${FIRST_FIX_NIM:?}" "${OWNERSHIP_OUTPUT:?}"
mkdir -p "$OWNERSHIP_OUTPUT"
output=$(cd -- "$OWNERSHIP_OUTPUT" && pwd)
mkdir -p "$output/evidence"
export NIM_DESTRUCTOR_EVIDENCE_ROOT="$output/evidence"
export NIM_CONSTRUCTOR_EVIDENCE_ROOT="$output/evidence"
run_harness() {
  local compiler=$1 fixture=$2 expected=$3 label=$4 rc=0
  NIM="$compiler" NIM_DESTRUCTOR_EVIDENCE_DIR="$output/evidence/$label" \
    NIM_CONSTRUCTOR_EVIDENCE_DIR="$output/evidence/$label" \
    bash "$sources/$fixture/reproduce.sh" > "$output/$label.log" 2>&1 || rc=$?
  cat "$output/$label.log"
  [[ $rc == "$expected" ]] || { echo "$label: expected $expected, got $rc" >&2; exit 1; }
}
run_harness "$STOCK_NIM" phantom-hooks 1 stock-phantom
run_harness "$FIRST_FIX_NIM" phantom-hooks 0 first-fix-phantom
run_harness "$FIRST_FIX_NIM" constructor-resource 1 first-fix-constructor
for variant in unwrapped wrapped; do
  compiler=$UNWRAPPED_NIM
  [[ $variant != wrapped ]] || compiler=$WRAPPED_NIM
  "$compiler" --version > "$output/$variant-version.txt"
  grep -F 'Version 2.2.4' "$output/$variant-version.txt"
  run_harness "$compiler" phantom-hooks 0 "$variant-phantom"
  run_harness "$compiler" constructor-resource 0 "$variant-constructor"
done
# Isolate each compiler/configuration in its own cache, including deliberate
# mutations. A stale artifact cannot stand in for a differently configured case.
run_case() {
  local label=$1 compiler=$2 backend=$3 memory=$4 inference=$5 source=$6
  shift 6
  "$compiler" "$backend" --mm:"$memory" --sinkInference:"$inference" --hints:off \
    --nimcache:"$output/$label-cache" --out:"$output/$label" "$@" "$source" \
    > "$output/$label.compile.log" 2>&1 || { cat "$output/$label.compile.log"; exit 2; }
}
execute_case() {
  local label=$1
  "$output/$label" > "$output/$label.run.log" 2>&1 || { cat "$output/$label.run.log"; exit 1; }
  printf 'PASS %s\n' "$label" >> "$output/matrix.log"
}
for backend in c cpp; do
  for memory in arc orc; do
    for mode in two single nonGeneric; do
      flags=()
      [[ $mode != single ]] || flags+=(-d:singleType)
      [[ $mode != nonGeneric ]] || flags+=(-d:nonGeneric)
      label="constructor-$backend-$memory-$mode"
      run_case "$label" "$WRAPPED_NIM" "$backend" "$memory" off "$sources/phantom-hooks/tconstructortemporary.nim" "${flags[@]}"
      execute_case "$label"
      # First-fix-only must still refuse every original constructor variant.
      label="first-fix-$label"
      run_case "$label" "$FIRST_FIX_NIM" "$backend" "$memory" off "$sources/phantom-hooks/tconstructortemporary.nim" "${flags[@]}"
      if "$output/$label" > "$output/$label.run.log" 2>&1; then
        echo "$label unexpectedly passed" >&2; exit 1
      fi
      grep -Fq '`finalized == [1, 1]`' "$output/$label.run.log"
      grep -q AssertionDefect "$output/$label.run.log"
      printf 'REFUSED %s\n' "$label" >> "$output/matrix.log"
    done
    for inference in off on; do
      for fixture in tconstructorownership tconstructorsemantics; do
        label="$fixture-$backend-$memory-$inference"
        run_case "$label" "$WRAPPED_NIM" "$backend" "$memory" "$inference" "$sources/phantom-hooks/$fixture.nim"
        execute_case "$label"
      done
    done
    for mode in distinct alias reverse alias-reverse; do
      flags=()
      [[ $mode != *alias* ]] || flags+=(-d:phantomAlias)
      [[ $mode != *reverse* ]] || flags+=(-d:reverseOrder)
      label="phantom-$backend-$memory-$mode"
      run_case "$label" "$WRAPPED_NIM" "$backend" "$memory" off "$sources/phantom-hooks/tphantomtypehooks.nim" "${flags[@]}"
      execute_case "$label"
    done
  done
  label="phantom-$backend-atomicArc"
  run_case "$label" "$WRAPPED_NIM" "$backend" atomicArc off "$sources/phantom-hooks/tphantomtypehooks.nim"
  execute_case "$label"
done
# Deliberately dispatch string/int hooks backwards in a copied fixture. The
# same owning program must compile, then refuse the wrong nominal marker.
cp -R "$sources/phantom-hooks" "$output/wrong-hook-source"
chmod -R u+w "$output/wrong-hook-source"
sed -i 's/when T is string:/when T is int:/g' "$output/wrong-hook-source/phantomhooks/owner.nim"
run_case wrong-hook "$WRAPPED_NIM" c arc off "$output/wrong-hook-source/tphantomtypehooks.nim"
if "$output/wrong-hook" > "$output/wrong-hook.run.log" 2>&1; then
  echo 'Wrong nominal hook was accepted' >&2; exit 1
fi
# The int value is destroyed first; the inverted predicate sends it through
# the string branch. Require that precise failed assertion, not any failure.
grep -Fq '`value.marker == "string"`' "$output/wrong-hook.run.log"
grep -q AssertionDefect "$output/wrong-hook.run.log"
printf 'REFUSED wrong-hook\n' >> "$output/matrix.log"
