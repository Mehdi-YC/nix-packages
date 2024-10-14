{
  description = "Flake to install htop 3.2.2 built from source as nix3";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";  # Adjust to desired Nixpkgs version.

  outputs = { self, nixpkgs }: 
  let
    system = "x86_64-linux";  # Adjust for your architecture if needed.
  in
  {
    packages.${system}.nix3 = nixpkgs.lib.mkDerivation {
      pname = "htop";
      version = "3.2.2";

      # Fetch htop source code from the official GitHub repository.
      src = nixpkgs.fetchurl {
        url = "https://github.com/htop-dev/htop/archive/refs/tags/3.2.2.tar.gz";
        sha256 = "sha256-gVKXnh0j2CCDE/KqNfSEkhFzChzCBmsFfsZuw+ik/Nk=";
      };

      buildInputs = [ nixpkgs.ncurses nixpkgs.autotools nixpkgs.gcc ];

      # Build phases
      configurePhase = ''
        ./autogen.sh
        ./configure --prefix=$out
      '';
      buildPhase = "make";
      installPhase = "make install";

      meta = with nixpkgs.lib; {
        description = "Htop 3.2.2 built from source (nix3)";
        license = licenses.gpl2Plus;
        platforms = platforms.linux;
      };
    };
  };
}
