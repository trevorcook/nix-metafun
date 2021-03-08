let
  /* envth-src = builtins.fetchGit {
      url = https://github.com/trevorcook/envth.git ;
      rev = "08642524aca53789fd944d8c3d4856d232b3c0f8"; };
  envth-overlay = self: super: { envth = import envth-src self super; };
  nixpkgs = import <nixpkgs> { overlays = [ envth-overlay ]; }; */
  nixpkgs = import <nixpkgs> {};
in
  {definition ? ./metafun-env.nix}: nixpkgs.callPackage definition {}
