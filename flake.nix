{
  inputs = {
    nixpkgs.url = "github:serokell/nixpkgs";
    beamer-theme-serokell = {
      url = "github:serokell/beamer-theme-serokell";
      flake = false;
    };
    nix-pandoc = {
      url = "github:serokell/nix-pandoc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, nix-pandoc, beamer-theme-serokell }: {
    packages = builtins.mapAttrs (_: pkgs: {
      talk = (pkgs.extend nix-pandoc.overlay).callPackage ./talk.nix {
        inherit beamer-theme-serokell;
      };
    }) nixpkgs.legacyPackages;

    defaultPackage =
      builtins.mapAttrs (_: packages: packages.talk) self.packages;

    devShell = builtins.mapAttrs (system: pkgs:
      pkgs.mkShell {
        inputsFrom = [ self.defaultPackage.${system} ];
        buildInputs = [ pkgs.proselint ];
      }) nixpkgs.legacyPackages;
  };
}
