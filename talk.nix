{ linkFarm, mkDoc, texlive, pandoc, fontconfig
, beamer-theme-serokell, google-fonts }:
let
  texlive-packages = {
    inherit (texlive)
      scheme-small noto mweights cm-super cmbright fontaxes beamer minted
      fvextra catchfile xstring framed;
  };


  texlive-combined = texlive.combine texlive-packages;

in mkDoc {
  name = "nixcon-talk";
  src = ./.;
  font = google-fonts;
  inherit texlive-combined;
  HOME = "/build";
  extraTexInputs = [ beamer-theme-serokell ];
  extraBuildInputs = [ ];

  enableParallelBuilding = true;
}
