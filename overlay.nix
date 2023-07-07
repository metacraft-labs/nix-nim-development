_finalNixpkgs: prevNixpkgs: let
  langserver = prevNixpkgs.callPackage ./packages/langserver/default.nix { inherit zevv-with; inherit serialization; inherit json-serialization; inherit chronicles; inherit faststreams; inherit asynctools; inherit stew; inherit json-rpc; };
  faststreams = prevNixpkgs.callPackage ./packages/faststreams/default.nix {};
  asynctools = prevNixpkgs.callPackage ./packages/asynctools/default.nix {};
  stew = prevNixpkgs.callPackage ./packages/stew/default.nix {};
  json-rpc = prevNixpkgs.callPackage ./packages/json-rpc/default.nix {};
  chronicles = prevNixpkgs.callPackage ./packages/chronicles/default.nix {};
  json-serialization = prevNixpkgs.callPackage ./packages/json-serialization/default.nix {};
  serialization = prevNixpkgs.callPackage ./packages/serialization/default.nix {};
  zevv-with = prevNixpkgs.callPackage ./packages/zevv-with/default.nix {};
  
in {
  metacraft-labs = rec {
    inherit langserver;
    inherit faststreams;
    inherit asynctools;
    inherit stew;
    inherit json-rpc;
    inherit chronicles;
    inherit json-serialization;
    inherit serialization;
    inherit zevv-with;
    default = langserver;
  };
}
