{
  lib,
  nimPackages,
  fetchFromGitHub,
  SDL2,
  faststreams,
  asynctools,
  stew,
  json-rpc,
  chronicles,
  json-serialization,
  serialization,
  zevv-with,
  chronos,
  nimcrypto,
  stint,
  zlib,
  unicodedb,
  regex,
  httputils,
  websock,
  bearssl,
  results,
  unittest2,
}:

nimPackages.buildNimPackage rec {
  pname = "langserver";
  version = "1.12.0";
  src = fetchFromGitHub {
    owner = "nim-lang";
    repo = "langserver";
    rev = "be5fb8ee33b33dc6ca13ed71a42f9f488e2b3b9a";
    hash = "sha256-yf3oiKwsJoQxRPhbEBMJN+TR7j58t6ggjq51DJ3ypGQ=";
  };

  propagatedBuildInputs = [
    faststreams
    asynctools
    stew
    json-rpc
    chronicles
    json-serialization
    serialization
    zevv-with
    chronos
    nimcrypto
    stint
    zlib
    unicodedb
    regex
    httputils
    websock
    bearssl
    results
    unittest2
  ];

  doCheck = false;

  meta = with lib; {
    mainProgram = "nimlangserver";
  };
}
