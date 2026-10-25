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
  firstFix = baseline.override {
    nim-unwrapped-2_2 = nim-unwrapped.ownershipFix.beforeConstructorFix;
  };
in
runCommand "nim-ownership-check"
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
    export HOME="$TMPDIR" NIM_DESTRUCTOR_EVIDENCE_ROOT="$TMPDIR"
    export NIM_CONSTRUCTOR_EVIDENCE_ROOT="$TMPDIR"
    export CC=${stdenv.cc}/bin/cc CXX=${stdenv.cc}/bin/c++
    export WRAPPED_NIM=${nim}/bin/nim UNWRAPPED_NIM=${nim-unwrapped}/bin/nim
    export STOCK_NIM=${baseline}/bin/nim FIRST_FIX_NIM=${firstFix}/bin/nim
    export OWNERSHIP_OUTPUT="$out"
    bash ${../../tests}/check_ownership.sh
    cat > "$out/provenance.txt" <<ANCHORS
    referent-owner=${nim-unwrapped.ownershipFix.ownerCommit}
    constructor-owner=${nim-unwrapped.ownershipFix.constructorOwnerCommit}
    source=${nim-unwrapped.src}
    unwrapped=${nim-unwrapped}
    wrapper=${nim}
    baseline=${baseline}
    first-fix-only=${firstFix}
    ANCHORS
    sha256sum ${nim-unwrapped.src} ${nim-unwrapped.ownershipFix.patch} \
      ${nim-unwrapped.ownershipFix.constructorPatch} \
      ${nim-unwrapped}/nim/bin/nim ${nim}/bin/*-nim >> "$out/provenance.txt"
  ''
