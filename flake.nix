{
  description = "My Custom Nix Repository with Multiple Packages";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";  # Choose the right version.

  outputs = { self, nixpkgs }: {
    packages = {
      # Package 1: hello
      hello = nixpkgs.lib.mkDerivation {
        pname = "hello";
        version = "2.10";
        src = nixpkgs.hello.src;
        buildInputs = [ nixpkgs.gcc ];
      };

      # Package 2: cowsay
      cowsay = nixpkgs.lib.mkDerivation {
        pname = "cowsay";
        version = "3.03";
        src = nixpkgs.cowsay.src;
        buildInputs = [ nixpkgs.gcc ];
      };
      
      # Add more packages similarly...
    };

    # Provide a default package or utility.
    defaultPackage.x86_64-linux = self.packages.hello;
  };
}
