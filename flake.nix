{
  inputs = {
    nixpkgs.url = "github:serokell/nixpkgs";
    beamer-theme-serokell.url = "github:serokell/beamer-theme-serokell";
    beamer-theme-serokell.flake = false;
    nix-pandoc.url = "github:serokell/nix-pandoc";
    nix-pandoc.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, nix-pandoc, beamer-theme-serokell }: {
    defaultPackage = builtins.mapAttrs (_: pkgs:
      (pkgs.extend nix-pandoc.overlay).callPackage ./talk.nix {
        inherit beamer-theme-serokell;
      }) nixpkgs.legacyPackages;
  };
}
