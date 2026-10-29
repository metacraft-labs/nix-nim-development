# nix-nim-development

A Nix flake offering essential tools for Nim development

## Stock compiler with ownership corrections

`packages.<system>.nim` exports the nixpkgs Nim 2.2.4 wrapper around
`packages.<system>.nim-unwrapped`, rebuilt from the existing stock source.
The default package remains langserver, which also uses this compiler.
The overlay exposes these as `pkgs.metacraft-labs.nim` and
`pkgs.metacraft-labs.nim-unwrapped`; it does not replace global `pkgs.nim`.
Consumers can apply `overlays.default` to a matching nixpkgs input without
upgrading that input. This backport supports the locked Nim 2.2.4 source and
builder API; other compiler versions or alternate Nim package sets are refused.
Pin the provider revision before consuming the overlay.

The first compiler-only patch comes from
[5267deca91eb58a7aac3ebcae056688e292b180b](https://github.com/metacraft-labs/nim/commit/5267deca91eb58a7aac3ebcae056688e292b180b).
It prepares concrete referent hooks when canonical reference hooks are reused.
The backport omits `gcYrc`, which stock 2.2.4 does not declare, matching the
release's existing ARC/ORC/atomicARC selection in `atomicRefOp`. The surrounding
context retains the release's `isTrival` spelling. No tracing changes are used.
The second compiler-only patch comes from
[74f379ac90c38c199686e63f5d48535e4c3ceddf](https://github.com/metacraft-labs/nim/commit/74f379ac90c38c199686e63f5d48535e4c3ceddf).
It consumes the fields of owning custom-destructor constructor temporaries.
Its stock 2.2.4 branch matches exactly; only source line offsets differ.
The source version and nixpkgs lock remain unchanged. Nixpkgs bootstraps from
pregenerated C, then `koch boot` rebuilds the final compiler from patched Nim
sources; changing the wrapper alone would not carry the correction.

Run `nix build .#checks.x86_64-linux.nim-ownership` (or the host system).
This sandboxed check runs the original ten-case hook harness and the four-case
constructor/control harness with both the actual unwrapped binary and wrapper.
Stock Nim must still reproduce the hook failure, while a reproducible compiler
carrying only the first patch must pass that harness and still reproduce the
constructor defect with its explicit-transfer controls passing.

The check also runs 18 C/C++ ARC/ORC/atomicARC hook variants, the 12 C/C++
ARC/ORC two-type/single-type/nongeneric constructor variants, and 16 retained
ownership/default/inherited/evaluation-order/exception variants with sink
inference on and off. The first-fix-only compiler must refuse the same twelve
constructor cases. Marker-only custom callbacks validate every nonempty nominal
tag and report callback multiplicity; four separately identified owned resources
must each finalize exactly once. A deliberately wrong nominal-hook mutation must
compile, then fail its unchanged marker assertion. Compile failures and broken
positive controls fail the gate. Unsupported YRC is not requested on stock 2.2.4.

Its output retains compile/runtime evidence and `provenance.txt` with source,
owner commits, patch hashes and artifact hashes. Use these identities and runtime
checks to establish the capability: the version string remains 2.2.4 and cannot
identify either correction. The check driver is `tests/check_ownership.sh`;
it requires explicit absolute compiler paths and an output directory.

## Supported symbol ownership inspection

The package also backports `std/macros.getOwner` from
[05c9a809bed098833590573c113bce8656e1785d](https://github.com/metacraft-labs/nim/commit/05c9a809bed098833590573c113bce8656e1785d).
It exposes the existing `SymOwner` operation without a deprecated entry point;
the existing `owner` API remains deprecated and its behavior is unchanged.
The library-only backport adapts the availability annotation to `(2, 2, 4)`
and documents availability in this Metacraft-patched stock package. It does
not claim that an upstream Nim 2.2.4 release provides the API. No VM or tracing
changes are included.

Run `nix build .#checks.x86_64-linux.nim-symbol-owner` (or the host system).
The required check compiles the unchanged owning typed-symbol assertions using
both real wrapper and unwrapped compilers, under C and JS with deprecated
warnings treated as errors. It checks module, procedure, field, type, local,
capture, nested overload, generic and ownerless-symbol behavior. Exact
non-symbol and legacy-deprecation refusals remain required. A reproducible
compiler with only the first two backports must refuse the absent API on both
backends. An isolated library mutation returning the input symbol must fail
the unchanged ownership assertion on both backends. Its output retains all
compiler logs plus source, patch, library and binary provenance.

`python3 tests/check_ci_package_inventory.py` evaluates the actual Linux and
Darwin package/check catalogs and rejects missing package checks, including its
real removed-checks negative control. All exported package builds, including
the existing langserver build, remain in `checks` alongside the required gates.

## Reproducible retained check evidence

The compiler behavior checks retain deterministic, exclusive evidence directories
for each invocation, without changing standalone harnesses' random-directory
default. Archive finalization runs only after every behavioral assertion and
negative control has passed. It validates Nim cache timestamps against the actual
retained output files, then archives those mtimes and nonempty cache timestamp
fields at the Nix store epoch (Unix second 1). Empty timestamp fields and every
other source, cache, compiler, command and log byte remain unchanged. The retained
`artifact-retention.txt` receipts describe this archive policy and its census;
canonical timestamps are not wall-clock execution provenance.

`nim-artifact-retention` exercises metadata corruption and containment refusals,
byte preservation, and real C runtime / JS compiler output with the packaged
compiler. Run `python3 tests/check_artifact_reproducibility.py --output /tmp/nim-check-comparison`
to build and force-rebuild all three behavior checks on x86_64-linux, retaining
both logs and requiring Nix's complete output comparison. Use `--system` for a
different local platform or `--check` to select a focused check. A successful
ordinary build alone does not establish byte reproducibility.

On Linux, `tests/check_ownership_memory.sh` additionally requires real Valgrind.
Set `WRAPPED_NIM` to the combined package compiler, `FIRST_FIX_NIM` to its
reproducible first-fix-only control, and `OWNERSHIP_OUTPUT` to a fresh directory.
It requires old subjects to produce actual memory errors, positive controls to
remain clean, and sixteen combined C/C++ report/semantic variants to report zero
errors and no remaining heap blocks. Missing tools fail explicitly.
