
{ pkgs ? import <nixpkgs> {} }:

let
  test-pkg = import ./test-pkg/default.nix { inherit pkgs; };
in
{
  inherit test-pkg ;
}
