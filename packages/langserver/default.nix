{ lib, nimPackages, fetchFromGitHub, SDL2, faststreams, asynctools, stew, json-rpc, chronicles, json-serialization, serialization, zevv-with }:

nimPackages.buildNimPackage rec {
  pname = "langserver";
  version = "1.6.10";
  src = fetchFromGitHub {
    owner = "nim-lang";
    repo = "langserver";
    rev = "772547ea6954582aeefd89cdaab0c1554ee81f92";
    hash = "sha256-aOwqndBtIPZPODATt/RMk7mPcSwihjBJj4JytDeKv0E=";
  };

  propagatedBuildInputs = [ faststreams asynctools stew json-rpc chronicles json-serialization serialization zevv-with ];

  doCheck = true;

  meta = with lib; {
    mainProgram = "nimlangserver";
  };
}
