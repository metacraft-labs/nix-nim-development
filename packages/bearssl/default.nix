{ fetchFromGitHub, fetchgit, lib, stdenv, runCommand }:

let
  src = fetchgit {
    url = "https://github.com/status-im/nim-bearssl";
    rev = "667b40440a53a58e9f922e29e20818720c62d9ac";
    hash = "sha256-mlSUqAbDEk72AjZX4Wbhh/oJ64wxUfc/he2fe15ylSg=";
    fetchSubmodules = true;
  };
in src
