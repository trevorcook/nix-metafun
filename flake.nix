{
  description = "nix-metafun is a utility for creating bash scripts based on nix expressions.";
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
  };
  outputs = inputs: {
    packages = builtins.mapAttrs (system: pkgs: rec {
      metafun = pkgs.callPackage ./metafun.nix {};
      metafun-reference = metafun "metafun-reference" (import ./metafun-reference.nix); 
      default = metafun-reference;
    }) inputs.nixpkgs.legacyPackages;

  };
}
