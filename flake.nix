{
  description = "nix-metafun is a utility for creating bash scripts based on nix expressions.";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
  };

  outputs = inputs: {
    packages = builtins.mapAttrs (system: pkgs: rec {
      metafun = pkgs.callPackage ./metafun.nix {};
      # metafun-example = metafun.mkMetafun "metafun-example" (import ./metafun-example.nix { lib = pkgs.lib; }); 
      metafun-example = metafun "metafun-example" (import ./metafun-example.nix { lib = pkgs.lib; }); 

      default = metafun-example;
    }) inputs.nixpkgs.legacyPackages;

  };
}
