# Metafun

Metafun generates shell commands from specifications encoded in Nix attribute sets. It features:

- Option parsing and argument checking.
- Tab completion script generation with completion for arguments, options, and subcommands.
- Arbitrarily nested subcommands.

## Project Architecture

This project contains:

- `flake.nix`: The nix flake that defines the `metafun` and `metafun-reference` derivations.
- `metafun.nix`: The `metafun` definition. 
- `metafun-reference.nix`: A reference `metafun` specification that defines options, commands, and arguments in various forms that `metafun` accepts.

## Reference Function

To get started try out the example function `metafun-reference` in a flake shell:

> nix shell --no-write-lock-file github:trevorcook/nix-metafun#metafun-reference

- Try the command `metafun-reference --help` to view the available options.
- Although tools like homemanager should correctly initialize tab completions, `nix shell` (apparently) doesn't. The completion setup script location can be viewed with `metafun-reference --completion-path` and sourced with the following.

> source "$(metafun-reference --completion-path)"

Reference `metafun-reference.nix` in this directory to see how the function behavior--options, arguments, and commands--are specified through a nix attribute set.

## Example: metafun in home-manager flake

Include `metafun` as an input to a nix flake project. For example a `home-manager` flake might include the following:

**flake.nix**
```nix
{
  description = "Homemanager Config.";
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    metafun.url = "github:trevorcook/nix-metafun";
  };

  outputs = inputs: let 
      system = "x86_64-linux"; 
      # extend the package set with the contents of metafun flake, i.e. {metafun,metafun-reference}.
      pkgs = (import inputs.nixpkgs {inherit system;}).extend (_: _: inputs.metafun.packages."${system}");
      in {
    homeConfigurations = {
      myProfile = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix     
                  ];
      };
    };
  };
}
```

with the `metafun` utility used to define new packages.

**`home.nix`**
```nix
{lib, pkgs, ...}:
{
  home = {
    packages = with pkgs; [
      (metafun "my-command" (import ./my-command.nix))
      ];
    username = "user";
    homeDirectory = "/home/user";
    stateVersion = "26.11";
  };
}

```

As demonstrated above, `metafun` "compiles" nix expressions to (bash script) programs. Use of metafun is of the form:

```nix

metafun name command_spec 

```

where `name` is the command name string and `command_spec` is an attribute set following the forms found in `metafun-reference.nix`

The output of a call to `metafun my-command my-command.nix` is the result of a `symlinkJoin`, with the structure

```
$out
├── bin
│   └── my-command -> /nix/store/...
└── share
    └── bash-completion
        └── completions
            └── my-command -> /nix/store/...


