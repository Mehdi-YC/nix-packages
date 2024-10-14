
{ pkgs ? import <nixpkgs> {} }:
pkgs.stdenv.mkDerivation {
  pname = "test-pkg";
  version = "1.0";
  src = null;  # Use an actual source for your package

  buildPhase = ''
    echo "Building my package!"
  '';

  installPhase = ''
    mkdir -p $out/bin
    echo "Hello, World!" > $out/bin/test-pkg
    chmod +x $out/bin/test-pkg
  '';
}
