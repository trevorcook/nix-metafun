{
  description = "nix-metafun is a utility for creating bash scripts based on attribte sets that declare options, arguments, subcommands, and hooks.";
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
  };
  outputs = inputs: rec {
    packages = builtins.mapAttrs (system: pkgs: rec {
      metafun = pkgs.callPackage ./metafun.nix {};
      metafun-reference = metafun "metafun-reference" (import ./metafun-reference.nix); 
      default = metafun-reference;
    }) inputs.nixpkgs.legacyPackages;
    devShells = builtins.mapAttrs (system: pkgs: {
      metafun-reference = pkgs.mkShell {
        packages = [packages."${system}".metafun-reference];
        shellHook = ''echo $metafun_reference'';
        metafun_reference = packages."${system}".metafun-reference;
      };
    } ) inputs.nixpkgs.legacyPackages;

  };
}
