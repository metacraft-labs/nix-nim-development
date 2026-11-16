#!/usr/bin/env bash
# Exercise actual packaged compilers and libraries, including falsifiers.
# No compiler/VM/runtime is mocked. The mutant changes only an isolated library.
set -euo pipefail
: "${WRAPPED_NIM:?}" "${UNWRAPPED_NIM:?}" "${BASELINE_NIM:?}"
: "${NIM_LIBRARY:?}" "${SYMBOL_OWNER_OUTPUT:?}"
root=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$SYMBOL_OWNER_OUTPUT"
out=$(cd "$SYMBOL_OWNER_OUTPUT" && pwd)
for compiler in "$WRAPPED_NIM" "$UNWRAPPED_NIM" "$BASELINE_NIM"; do
  test -x "$compiler"
done
compile() {
  local compiler=$1 backend=$2 name=$3 source=$4
  shift 4
  "$compiler" "$backend" --hints:off --warningAsError:Deprecated:on \
    --nimcache:"$out/cache-$name" --out:"$out/$name" "$@" "$source" \
    > "$out/$name.log" 2>&1
}
refuse() {
  local diagnostic=$1
  shift
  local name=$3
  if compile "$@"; then
    echo "Unexpected compilation success: $name" >&2
    return 1
  fi
  grep -F "$diagnostic" "$out/$name.log"
}
# Preserve the positive fixture byte-for-byte from the owner repository.
# Compiling executes its typed-macro assertions on both backends.
for backend in c js; do
  for variant in wrapped unwrapped; do
    if [[ $variant == wrapped ]]; then compiler=$WRAPPED_NIM; else compiler=$UNWRAPPED_NIM; fi
    compile "$compiler" "$backend" "$variant-$backend-owner" "$root/symbol-owner/tgetowner.nim"
    refuse 'node is not a symbol' "$compiler" "$backend" "$variant-$backend-invalid" "$root/symbol-owner/tgetownerinvalid.nim"
    refuse 'owner is deprecated' "$compiler" "$backend" "$variant-$backend-deprecated" "$root/symbol-owner/tgetownerdeprecated.nim"
  done
  refuse "undeclared identifier: 'getOwner'" "$BASELINE_NIM" "$backend" "baseline-$backend" "$root/symbol-owner/tgetowner.nim"
done
# A wrong implementation that returns its input has the right signature but
# fails the unchanged real typed ownership assertions. Copy the entire library
# so --lib selects the mutant without touching the Nix store or original API.
cp -R "$NIM_LIBRARY" "$out/mutant-lib"
chmod -R u+w "$out/mutant-lib"
sed -i 's/proc getOwner\*(sym: NimNode): NimNode {.magic: "SymOwner", noSideEffect, since: (2, 2, 4).}/proc getOwner*(sym: NimNode): NimNode {.noSideEffect, since: (2, 2, 4).} = sym/' "$out/mutant-lib/core/macros.nim"
grep -F 'proc getOwner*(sym: NimNode): NimNode {.noSideEffect, since: (2, 2, 4).} = sym' "$out/mutant-lib/core/macros.nim"
for backend in c js; do
  refuse 'getOwner(own).strVal == "nested"' "$UNWRAPPED_NIM" "$backend" "mutant-$backend" "$root/symbol-owner/tgetowner.nim" --lib:"$out/mutant-lib"
  grep -F 'AssertionDefect' "$out/mutant-$backend.log"
done
printf 'supported-owner: 4 positive, 8 compatibility refusals, 2 absent-API refusals, 2 semantic mutant refusals\n' > "$out/result.txt"
