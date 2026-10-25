#!/usr/bin/env bash
# Actual compiler and native reference lifetimes; no mocks. Compile errors and
# a failed explicit-transfer control are inconclusive, never reproductions.
set -u
source_dir=$(cd -- "$(dirname -- "$0")" && pwd)
evidence=$(mktemp -d "${NIM_CONSTRUCTOR_EVIDENCE_ROOT:-/tmp}/nim-constructor-resource.XXXXXXXX")
printf 'Evidence: %s\n' "$evidence"
compiler=${NIM:-nim}
"$compiler" --version > "$evidence/compiler.txt" 2>&1 || exit 2
cat "$evidence/compiler.txt"
failed=0
for memory in arc orc; do
  for mode in subject control; do
    output="$evidence/$memory-$mode"
    "$compiler" c --hints:off --colors:off --mm:"$memory" \
      --nimcache:"$output-cache" --out:"$output" \
      "$source_dir/$mode.nim" > "$output.compile.log" 2>&1 || {
        cat "$output.compile.log"; exit 2;
      }
    "$output" > "$output.run.log" 2>&1
    rc=$?
    if [[ "$mode" == control ]]; then
      if [[ "$rc" != 0 ]]; then cat "$output.run.log"; exit 2; fi
    elif [[ "$rc" != 0 ]] && grep -Fq '`finalized == [1, 1]`' "$output.run.log" &&
        grep -q AssertionDefect "$output.run.log"; then
      failed=$((failed+1))
    elif [[ "$rc" != 0 ]]; then
      cat "$output.run.log"; exit 2
    fi
    printf '%s %s rc=%s\n' "$memory" "$mode" "$rc"
  done
done
if [[ "$failed" == 2 ]]; then exit 1; fi
if [[ "$failed" == 0 ]]; then exit 0; fi
exit 2
