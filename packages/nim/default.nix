{ nim-unwrapped-2_2 }:
# Nixpkgs bootstraps from c_code, then `koch boot` recompiles patched .nim
# sources. Keep a reproducible first-fix-only compiler as a negative control.
assert nim-unwrapped-2_2.version == "2.2.4";
let
  referentFix = nim-unwrapped-2_2.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./prepare-concrete-referent-hooks.patch ];
  });
in
referentFix.overrideAttrs (old: {
  patches = old.patches ++ [ ./consume-owning-constructor-fields.patch ];
  passthru = (old.passthru or { }) // {
    ownershipFix = {
      ownerCommit = "5267deca91eb58a7aac3ebcae056688e292b180b";
      patch = ./prepare-concrete-referent-hooks.patch;
      constructorOwnerCommit = "74f379ac90c38c199686e63f5d48535e4c3ceddf";
      constructorPatch = ./consume-owning-constructor-fields.patch;
      beforeConstructorFix = referentFix;
    };
  };
})
