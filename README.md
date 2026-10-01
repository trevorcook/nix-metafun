# Metafun

Metafun generates shell commands from Nix specifications. It features:

- Option parsing and argument checking.
- Tab completion script generation with completion for arguments, options, and subcommands.
- Arbitrarily nested subcommands.

## Project Architecture

This project contains:

- `flake.nix`: The nix flake that defines the `metafun` and `metafun-reference` derivations.
- `metafun.nix`: The `metafun` definition. 
- `metafun-reference.nix`: A reference `metafun` specification that defines options, commands, and arguments in various forms that `metafun` accepts.

## Example

To get started try out the example function `metafun-reference` by in a flake shell:

> nix shell --no-write-lock-file github:trevorcook/nix-metafun#metafun-reference

- Try the command `metafun-reference --help` to view the available options.
- Set up command completions with:

> eval "$(metafun-reference --setup-completion)"

Reference `metafun-reference.nix` in this directory to see how the function behavior--options, arguments, and commands--are specified through a nix attribute set.

## Use metafun in your project

Include `metafun` as an input to a nix flake projects. Use the `metafun` attribute to "compile" nix expressions to bash scripts. Use of metafun is of the form:

```nix

metafun name command_spec 

```

where `name` is the command name string and `command_spec` is an attribute set following the form of the one found in `metafun-reference.nix`

The output of a call to `metafun my-command my-command.nix` is the result of a `symlinkJoin`, with the structure

```
$out
├── bin
│   └── my-command -> /nix/store/...
└── share
    └── bash-completion
        └── completions
            └── metafun-reference -> /nix/store/...

