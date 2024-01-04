{ lib, nimPackages, fetchFromGitHub, SDL2, faststreams, asynctools, stew, json-rpc, chronicles, json-serialization, serialization, zevv-with }:

nimPackages.buildNimPackage rec {
  pname = "langserver";
  version = "1.6.10";
  src = fetchFromGitHub {
    owner = "nim-lang";
    repo = "langserver";
    rev = "29b519f412371d6358773fd1bda507dc9f79a1e8";
    hash = "sha256-u+1R6nh2pCr0vyC2N+ItiHa8Qf0tKt4m781ZjclQZ98=";
  };

  propagatedBuildInputs = [ faststreams asynctools stew json-rpc chronicles json-serialization serialization zevv-with ];

  doCheck = true;

  meta = with lib; {
    mainProgram = "nimlangserver";
  };
}
