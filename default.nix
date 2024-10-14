
{ pkgs ? import <nixpkgs> {} }:

let
  myPackage = import ./my-package/default.nix { inherit pkgs; };
  anotherPackage = import ./another-package/default.nix { inherit pkgs; };
in
{
  inherit myPackage anotherPackage;
}
