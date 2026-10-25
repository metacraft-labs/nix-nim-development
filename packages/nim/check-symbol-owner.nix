{
  runCommand,
  stdenv,
  bash,
  coreutils,
  gnugrep,
  gnused,
  nim,
  nim-unwrapped,
  baseline,
}:
let
  beforeAccessor = baseline.override {
    nim-unwrapped-2_2 = nim-unwrapped.symbolOwner.beforeAccessor;
  };
in
runCommand "nim-symbol-owner-check"
  {
    nativeBuildInputs = [
      stdenv.cc
      bash
      coreutils
      gnugrep
      gnused
    ];
  }
  ''
    export HOME="$TMPDIR"
    export WRAPPED_NIM=${nim}/bin/nim UNWRAPPED_NIM=${nim-unwrapped}/bin/nim
    export BASELINE_NIM=${beforeAccessor}/bin/nim
    export NIM_LIBRARY=${nim-unwrapped}/nim/lib SYMBOL_OWNER_OUTPUT="$out"
    bash ${../../tests}/check_symbol_owner.sh
    cat > "$out/provenance.txt" <<ANCHORS
    owner=${nim-unwrapped.symbolOwner.ownerCommit}
    source=${nim-unwrapped.src}
    wrapper=${nim}
    unwrapped=${nim-unwrapped}
    baseline=${beforeAccessor}
    ANCHORS
    sha256sum ${nim-unwrapped.symbolOwner.patch} ${nim-unwrapped}/nim/lib/core/macros.nim \
      ${nim-unwrapped}/nim/bin/nim ${nim}/bin/*-nim \
      ${nim-unwrapped.symbolOwner.beforeAccessor}/nim/lib/core/macros.nim \
      ${nim-unwrapped.symbolOwner.beforeAccessor}/nim/bin/nim \
      ${beforeAccessor}/bin/*-nim >> "$out/provenance.txt"
  ''
