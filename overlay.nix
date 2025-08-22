_finalNixpkgs: prevNixpkgs: let
  nim2OrDefault = if prevNixpkgs ? nim2 then prevNixpkgs.nim2 else prevNixpkgs.nim;
  nimPkgs2 =
    if prevNixpkgs ? nimPackages then prevNixpkgs.nimPackages.override { nim = nim2OrDefault; }
    else if prevNixpkgs ? nim2Packages then prevNixpkgs.nim2Packages
    else {
      buildNimPackage = prevNixpkgs.buildNimPackage;
      nim = nim2OrDefault;
      nimble = prevNixpkgs.nimble or null;
    };
  faststreams = prevNixpkgs.callPackage ./packages/faststreams/default.nix {};
  asynctools = prevNixpkgs.callPackage ./packages/asynctools/default.nix {};
  stew = prevNixpkgs.callPackage ./packages/stew/default.nix {};
  results = prevNixpkgs.callPackage ./packages/results/default.nix {};
  json-rpc = prevNixpkgs.callPackage ./packages/json-rpc/default.nix {};
  chronicles = prevNixpkgs.callPackage ./packages/chronicles/default.nix {};
  unittest2 = prevNixpkgs.callPackage ./packages/unittest2/default.nix {};
  json-serialization = prevNixpkgs.callPackage ./packages/json-serialization/default.nix {};
  serialization = prevNixpkgs.callPackage ./packages/serialization/default.nix {};
  httputils = prevNixpkgs.callPackage ./packages/httputils/default.nix {};
  zevv-with = prevNixpkgs.callPackage ./packages/zevv-with/default.nix {};
  websock = prevNixpkgs.callPackage ./packages/websock/default.nix {};
  bearssl = prevNixpkgs.callPackage ./packages/bearssl/default.nix {};
  nimcrypto = prevNixpkgs.callPackage ./packages/nimcrypto/default.nix {};
  stint = prevNixpkgs.callPackage ./packages/stint/default.nix {};
  zlib = prevNixpkgs.callPackage ./packages/zlib/default.nix {};
  unicodedb = prevNixpkgs.callPackage ./packages/unicodedb/default.nix {};
  regex = prevNixpkgs.callPackage ./packages/regex/default.nix {};
  chronos = prevNixpkgs.callPackage ./packages/chronos/default.nix {};
  langserver = prevNixpkgs.callPackage ./packages/langserver/default.nix {
    inherit zevv-with serialization json-serialization chronicles faststreams asynctools stew json-rpc chronos nimcrypto stint zlib unicodedb regex httputils websock bearssl results unittest2;
    nimPackages = nimPkgs2;
  };
  
in {
  metacraft-labs = rec {
    inherit langserver;
    inherit faststreams;
    inherit asynctools;
    inherit stew;
    inherit results;
    inherit json-rpc;
    inherit chronicles;
    inherit unittest2;
    inherit json-serialization;
    inherit serialization;
    inherit httputils;
    inherit zevv-with;
    inherit chronos;
    inherit websock;
    inherit bearssl;
    inherit nimcrypto;
    inherit stint;
    inherit zlib;
    inherit unicodedb;
    inherit regex;
    default = langserver;
  };
}
