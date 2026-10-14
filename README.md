# The `metafun` Project

Metafun generates shell commands from specifications encoded in Nix attribute sets. It features:

- Automatic creation of --help option that shows options, arguments, and subcommands.
- Tab completion script generation with completion for arguments, options, and subcommands.
- Option parsing and argument checking.
- Arbitrarily nested subcommands.

## Project Architecture

This project contains:

- `flake.nix`: The `nix` flake that defines the `metafun` and `metafun-reference` derivations.
- `metafun.nix`: The `metafun` definition. 
- `metafun-reference.nix`: A reference `metafun` specification that defines options, commands, and arguments in various forms that `metafun` accepts.

## Quick Start: Reference Function

A good way to get started with `metafun` is to compare a sample definition with its resuting output. For this purpose, this project provides the `metafun-reference` command built from the `metafun-reference.nix` specification. To get started, try running the command in a flake development shell:

> nix develop --no-write-lock-file github:trevorcook/nix-metafun#metafun-reference


On success, `nix` will drop the user into a subshell with the `metafun-reference` command added to `PATH`.

- Try the command `metafun-reference --help` to view the available options.
- Reference `metafun-reference.nix` in this directory to see how the function behavior--options, arguments, and commands--are specified through a `nix` attribute set. Alternatively, use `metafun-reference --copy-spec` to copy `metafun-reference.nix` to the current directory.
- Although `nix develop` and tools like `homemanager` correctly initialize tab completions, `nix shell` doesn't. To use the tab-completions using `nix shell`, use: 

  > nix shell --no-write-lock-file github:trevorcook/nix-metafun#metafun-reference
  
  to load the command in a tempory environment. Then source the completion script with:

  > source "$(metafun-reference --completion-path)"



## The `metafun` Functor

This repository provides the `metafun` utility for the `nix` language. It is used in a way similar to `nix` trivial builders such as `writeScript`. Use is of the form:

```nix
metafun name command-spec 
```

where `name` is the command name string and `command-spec` is an attribute set following the forms found in `metafun-reference.nix`. For beginners to `nix`, please note that it often makes sense to keep the command specification in a dedicated file, in which case calling convention might be something like,

```nix
metafun name (import ./command-spec.nix) 
```

The output of a call to `metafun "my-command" my-command-spec` is the result of a `symlinkJoin`, with the structure

```
$out
├── bin
│   └── my-command -> /nix/store/...
└── share
    └── bash-completion
        └── completions
            └── my-command -> /nix/store/...
```

Not seen in this output is a dedicated command for the help output. Direct calls to this command can be found within the command script. Previous versions of `metafun` kept the help output inline within the command, but were later moved to a separate script to aid readability.   

### `metafun` Attribues

`metafun` is defined as a `nix` functor so that it allows default calls, as shown above, while exposing additional attributes for the sake of versitility:

- `metafun.withPackages`
- `metafun.application`
- `metafun.file`
- `metafun.text`

The first two attributes are for building `metafun` type derivations that depend on runtime resources. The first, `metafun.withPackages` accepts calls of the form:

```nix
metafun.withPackages name command-spec packages
```

where `name` and `command-spec` are the same type of arguments as in the base case, and `packages` is a list of derivations that will be added to the runtime path of the resulting script. The second attribute, `metafun.application`, accepts calls of the form:

```nix
metafun.application attrs command-spec
```

where `attrs` is an attribute set that requires, at minimum, the attribute `name`, and `command-spec` is (again) the same as the base case. 

Both `metafun.withPackages` and `metafun.application`, are implemented with the `nix` trivial builder `writeShellApplication`. `metafun.application` passes its input `attrs` directly to `writeShellApplication`. It accepts all the same arguments except `text`, which is generated based on `command-spec`. (See [nixpkgs-manual: writeShellApplication](https://nixos.org/manual/nixpkgs/stable/#trivial-builder-writeShellApplication) for details). `metafun.withPackages` is written in terms of `metafun.application`, but with some options disabled to make the resulting script less strict (`checkPhase = "";`,  `bashOptions=[];`).

The next two attributes contain the definitions for the various parts of the above commands. The `metafun.file` is an attribute set that contains definitions for how the various files--command, help, completions--get written to `/nix/store` (i.e. `symlinkJoin`, `writeTextFile`, `writeShellApplication`). The `metafun.text` option is an attribute set that defines the text content of those files. Finally, a fifth attribute also exists, `metafun.ingress`, which is used to normalize `command-spec`s.


## Example: metafun in home-manager flake

To see how `metafun` might be included in a project, here is an example where a simple script is added to a `home-manager` configuration. The flake defines the `metafun` input and adds it's packages to nixpkgs via extending by an anonymous overlay. 

**flake.nix**
```nix
{
  description = "Homemanager Config.";
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    metafun.url = "github:trevorcook/nix-metafun";
    metafun.inputs.nixpkgs.follows = "nixpkgs";
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

The home module uses the `metafun` utility (thanks to the above overlay, now a part of pkgs) to define the `my-command` package.

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

The actual command specification, is just a simple nix attribute set. 

**`my-command.nix`**
```nix
{
  desc = ''A simple "hello world" style metafun example.'';
  hook = ''echo hello world'';
}
```

With all the files put in place, (added to git) and attributes adjusted as needed, a call to home manager

```
home-manager switch --flake .#myProfile
```

should then put `my-command` on the user `PATH`.
