{ pkgs }:
with pkgs;
mkShell {
  packages = [
    figlet
    metacraft-labs.langserver
  ];

  shellHook = ''
    figlet -w"''${COLUMNS:-80}" "langserver"
  '';
}
