{ lib, nimPackages, fetchFromGitHub, SDL2, faststreams, asynctools, stew, json-rpc, chronicles, json-serialization, serialization, zevv-with, chronos, nimcrypto, stint, zlib, unicodedb, regex, httputils, websock, bearssl, results, unittest2 }:

nimPackages.buildNimPackage rec {
  pname = "langserver";
  version = "1.12.0+rev-7bfb16a";
  src = fetchFromGitHub {
    owner = "nim-lang";
    repo = "langserver";
    rev = "7bfb16a40296071dd4915a4712307ccc8fce8c69";
    hash = "sha256-Sny9H6hQDIj0IbfzZBXzmObSHVJjQatTzZd/eF0HSSg=";
  };

  propagatedBuildInputs = [ faststreams asynctools stew json-rpc chronicles json-serialization serialization zevv-with chronos nimcrypto stint zlib unicodedb regex httputils websock bearssl results unittest2 ];

  doCheck = false;

  meta = with lib; {
    mainProgram = "nimlangserver";
  };
}
