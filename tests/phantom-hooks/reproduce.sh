#!/usr/bin/env bash
# No mocks: actual native compilation and execution. No application deps.
set -u
source_dir=$(cd -- "$(dirname -- "$0")" && pwd)
# Nix dev shells may delete their TMPDIR on exit. Keep the printed receipts
# outside that shell-owned parent unless the caller explicitly chooses one.
if [[ -n ${NIM_DESTRUCTOR_EVIDENCE_DIR:-} ]]; then
  # Package checks own an exclusive, deterministic destination. Refuse reuse so
  # a stale compilation can never satisfy a later invocation's assertions.
  evidence=$NIM_DESTRUCTOR_EVIDENCE_DIR
  [[ $evidence == /* ]] && mkdir -- "$evidence" || exit 2
else
  evidence=$(mktemp -d "${NIM_DESTRUCTOR_EVIDENCE_ROOT:-/tmp}/nim-phantom-destructor.XXXXXXXX") || exit 2
fi
printf 'Evidence: %s\n' "$evidence"
compiler=${NIM:-nim}
"$compiler" --version || exit 2
failed=0
for memory in arc orc; do
  for mode in subject procedure alias single plain; do
    flags=()
    case "$mode" in
      procedure) flags+=(-d:procedureBoundary);;
      alias) flags+=(-d:phantomAlias);;
      single) flags+=(-d:singleType);;
      plain) flags+=(-d:plainToken);;
    esac
    output="$evidence/$memory-$mode"
    "$compiler" c --hints:off --colors:off --mm:"$memory" \
      --nimcache:"$output-cache" --out:"$output" "${flags[@]}" \
      "$source_dir/subject.nim" >"$output.compile.log" 2>&1 || {
        cat "$output.compile.log"; exit 2;
      }
    "$output" >"$output.run.log" 2>&1
    rc=$?
    if [[ "$mode" == single || "$mode" == plain ]]; then
      if [[ "$rc" != 0 ]] || ! grep -qx 'finalized=2' "$output.run.log"; then
        cat "$output.run.log"; exit 2
      fi
    elif [[ "$rc" != 0 ]] && grep -qx 'finalized=0' "$output.run.log" &&
        grep -q 'AssertionDefect' "$output.run.log"; then
      failed=$((failed+1))
    elif [[ "$rc" != 0 ]] || ! grep -qx 'finalized=2' "$output.run.log"; then
      cat "$output.run.log"; exit 2
    fi
    printf '%s %s rc=%s %s\n' "$memory" "$mode" "$rc" "$(head -n 1 "$output.run.log")"
  done
done
if [[ "$failed" == 6 ]]; then exit 1; fi
if [[ "$failed" == 0 ]]; then exit 0; fi
exit 2
