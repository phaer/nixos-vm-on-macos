{ pkgs }:
pkgs.mkShell {
  packages = [
    pkgs.vfkit
  ];
}
