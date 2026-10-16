# The `metafun` Project

`metafun` is a Nix language utiltiy that generates shell scripts from specifications encoded in Nix attribute sets. It features:

- Automated option parsing and argument checking.
- Automatic creation of `--help` option that shows options, arguments, and subcommands.
- Tab completion script generation with completion for arguments, options, and subcommands.
- Arbitrarily nested subcommands.

## Project Architecture

This project contains:

- `flake.nix`: The Nix flake that defines the `metafun` and `metafun-reference` derivations.
- `metafun.nix`: The `metafun` definition. 
- `metafun-reference.nix`: A reference `metafun` specification that defines options, commands, and arguments in various forms that `metafun` accepts.

## Overview

`metafun` is a utility for the Nix language. It creates bash scripts in a way similar to Nix trivial builders such as [`writeScript`](https://nixos.org/manual/nixpkgs/stable/#trivial-builder-writeScript). Use is of the form:

```nix
metafun name command-spec 
```

where `name` is the command name string and `command-spec` is the command specification. 

The command specification is, generally, an attribute set with the following attributes:
  
  - `desc`: A string used in help output for describing the command.
  - `preOptHook`: A string that becomes part of the script before option and argument parsing.
  - `opts`: An attribute set of option flag names and option specification values. 
  - `args`: A list of argument specifications.
  - `hook`: A string that becomes part of the script after option and argument parsing, i.e. the interesting part of script.
  - `commands`: An attribute set of sub-command names and command specification values to be run after the hook.
  - Any additional attributes are ignored. 
  
Generally, each option specification is an attribute set with the following attributes:

  - `desc`: A string used in help output for describing the option.
  - `hook`: A string that is executed when the option is encountered.
  - `arg`: An argument specification for when the option requires an argument.
  - `set`: A string naming a variable to set, either to the supplied argument, or true if no argument.
  - `exit`: A boolean to signal if the script should exit after processing this option.
  
The argument specification is, again generally, a set with the attributes:
  
  - `name`: A string naming the argurment for help and tab completions (not assigned to a varible.)
  - `type`: A string declaring the type. Supported types, "file" nad "dir" are used in tab completion.
  - `choice`: A list of strings which will be supplied for tab completion.
  - `completion.hook`: A string which will be executed to help generate tab completions.
  - `completion.compgen-opt`: A string that will be passed directly to compgen in the generation of tab completions.
  
The attribute sets given above are the most general cases for their respective specifications. Not every argument needs to be specified. There are also short cuts. For insance a command specification can simply be a string, which is the same as supplying a set with only `hook` specified. In some cases, attributes clash, as in the case of argument `choice` and `completion.hook`. However these should hopefully be common sense. Refer to [`metafun-reference.nix`](metafun-reference.nix) for examples.

## Quick Start: Reference Function

A good way to get started with `metafun` is to compare a sample definition with its resuting output. For this purpose, this project provides the `metafun-reference` command built from the `metafun-reference.nix` specification. To get started, try running the command in a flake development shell:

> nix develop --no-write-lock-file github:trevorcook/nix-metafun#metafun-reference


On success, `nix` will drop the user into a subshell with the `metafun-reference` command added to `PATH`.

- Try the command `metafun-reference --help` to view the available options. Subcommands each have their own `--help` option.
- Reference `metafun-reference.nix` in this directory to see how the function behavior--options, arguments, and commands--are specified through a Nix attribute set. Alternatively, use `metafun-reference --copy-spec` to copy `metafun-reference.nix` to the current directory.
- Although `nix develop` and tools like `homemanager` correctly initialize tab completions, `nix shell` doesn't. To use the tab-completions using `nix shell`, use: 

  > nix shell --no-write-lock-file github:trevorcook/nix-metafun#metafun-reference
  
  to load the command in a tempory environment. Then source the completion script with:

  > source "$(metafun-reference --completion-path)"


## The `metafun` Functor

`metafun` is defined as a Nix functor so that it allows default calls, as shown above, while exposing additional attributes for the sake of versitility:

- `metafun.withPackages`
- `metafun.application`
- `metafun.file`
- `metafun.text`

The first two attributes are for building `metafun` type derivations that depend on runtime resources. The first, `metafun.withPackages` accepts calls of the form:

```nix
metafun.withPackages name packages command-spec
```

where `name` and `command-spec` are the same type of arguments as in the base case, and `packages` is a list of derivations that will be added to the runtime path of the resulting script. The second attribute, `metafun.application`, accepts calls of the form:

```nix
metafun.application attrs command-spec
```

where `attrs` is an attribute set that requires, at minimum, the attribute `name`, and `command-spec` is (again) the same as the base case. 

Both `metafun.withPackages` and `metafun.application`, are implemented with the Nix trivial builder `writeShellApplication`. `metafun.application` passes its input `attrs` directly to `writeShellApplication`. It accepts all the same arguments except `text`, which is generated based on `command-spec`. (See [nixpkgs-manual: writeShellApplication](https://nixos.org/manual/nixpkgs/stable/#trivial-builder-writeShellApplication) for details). `metafun.withPackages` is written in terms of `metafun.application`, but with some options disabled to make the resulting script less strict (`checkPhase = "";`,  `bashOptions=[];`).

The next two attributes contain the definitions for the various parts of the above commands. The `metafun.file` is an attribute set that contains definitions for how the various files--command, help, completions--get written to `/nix/store` (i.e. `symlinkJoin`, `writeTextFile`, `writeShellApplication`). The `metafun.text` option is an attribute set that defines the text content of those files. Finally, a fifth attribute also exists, `metafun.ingress`, which is used to normalize `command-spec`s.

## Outputs

The output of a call to `metafun "my-command" my-command-spec` (similarly, `metafun.withPackages` or `metafun.application`) is the result of a `symlinkJoin`, with the structure

```
$out
├── bin
│   └── my-command -> /nix/store/...
└── share
    └── bash-completion
        └── completions
            └── my-command -> /nix/store/...
```

Not seen in this output is a dedicated command for the help output. Direct calls to this command can be found within the command script.

## Limitiations and Infelicities

`metafun` creates commands with the invokation pattern:

> command [opts_0] <arg_0_1> .. <arg_0_i> subcommand_n [opts_n] <arg_m_1> .. <arg_m_j>

At every (sub)command, any number of that (sub)command's options may be supplied, but each declared argument is required. Furthermore, if *any* subcommands are specified then one must be invoked. This restricts the types of commands that it creates. For instance a command that processes one or more files, `process-files <file1> [<files>]`, is not specifically supported. The general workaround for unsupported patterns is to put the required logic in the specification's `hook`s. The workaround for this particular situation could be to declare one file argument and check within the hook for any additional files:

```nix
{
 args = ["file"];
 hook = ''
  file1="$1"
  if [[ $# > 1]] ; then
    ...
  fi
  '';
}
```

This workaround would only work for the last subcommands, and it would be up to the implementer to describe the extra optional arguments because they will not be indicated by the help otherwise. Some scheme might be developed for handling this specific scenario within `metafun` itself, but it is currently unclear what that would look like. 

Another unsupported command pattern is when commands behave differently depending on the number of arguments supplied. The `metafun` approach would be to supply different subcommands for the specific patterns of arguments supported. For example, the script resulting from the following expression accepts 0, 1, or 2 arguments, which would be called with `do-thing`, `do-thing on-one <arg1>`, and `do-thing on-two <arg1> <arg2>`. 

```nix
metafun "do-thing" {
  desc = "Does a thing with numbers. Note, invoking without arguments does the default thing.";
  hook = ''
    declare -f the_thing
    the_thing(){
      echo $(( $1 + $2 ))
    }
    if [[ $# == 0 ]]; then
      the_thing 1000
      exit
    fi
    '';
  commands = {
    on-one = "the_thing $1 99";
    on-two = "the_thing $1 $2";
  };
}

```

Making a subcommand for the different patterns requires more typing at the command line from the end user than otherwise. The extra typing is mitigated by tab completion, however, and the declaration of subcommands can help to clearly signal to the user the various command behaviors. In `do-thing`'s definition, the use of `exit` within the main `hook` is used to avoid the need for a `on-none` subcommand while simultaneously avoiding `metafun`'s instance that *some* `subcommand` must be invoked if *any* are specified. Tricks like this can be added for the sake of a user's convenience and is up to the implementer's discretion. Note that `do-thing` also illustrates how internal funcitons can be utilized, though `preOptHook` may often be a better place to put such definitions.

The previous issues with `metafun` arise as a result of its design. To contrast, the next issue arises from a lack of design. It's that the various forms of the various specifications (commands, options, and arguments) are not well defined. To mitigate this,  `metafun-reference.nix` is supplied. Also, the logic of accepted inputs is localized to `metafun.ingress`, which should help improvements on this front. 

Finally, the resulting scripts output by `metafun` are quite ugly. Previously, the help output was taken from the main script and put into a separate command that is referenced within the main script. Although this aided readability immensly, there are still improvements that might be made. For example, subcommands are implemented in terms of `case` statements but there is no indentation. One reason for this (besides ease of implementation) was to ensure that all `hooks` are formatted with the script as written (a concern with the possible presence of heredoc strings and `EOF`). 

The reason readability is important is mainly for the sake of development. Rebuilding a script by a `nix build` invocation or within a `nix develop` shell adds some friction to the development process. The friction is multiplied by the many repeated calls for testing small changes and correcting syntax errors in a user's `hook`s. To mitigate this, a developer can copy a compiled script to their local directory with a command similar to the following:

> cp .result/bin/script-name . && chmod +w script-name

They can then make and test edits to the `hook` portions of the script with less friction, and then copy validated code back to their `hook`s. When new functionality that `metafun` provides is needed, the subcommand (options ect.) can be specified in nix and then the rebuild/copy locally/development process is repeated.

Another reason readibility is important is the possibility of being read by someone other than the developer (I'm told.). Any `metafun` script included in a package set will be much easier to access than tracing back to its specification. This may be the differnce between simply calling `less $(which script-name)` and working with nix tools to find the definition somewhere in its closure (if that's even possible). Its also possible to develop standalone scripts for non-nix systems by simply copying the output from the nix store and scrubbing the script for nixisms (i.e. references to /nix/store).

In any case, to make the scripts more readable, a possible middle ground might be to provide typical nesting for the `metafun` generated script parts while ensuring left justification of any user supplied hooks. The nesting should help orient the reader on the subcommand nesting level, while letting them focus on the actual business logic of the left justified code.

## Example: metafun in home-manager flake

To see how `metafun` might be included in a project, here is an example where a simple script is added to a `home-manager` configuration. The flake defines the `metafun` input and adds it's outputs to the nixpkgs via extension with the defined `with_metafun` overlay. 

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
      pkgs_for_sys = import inputs.nixpkgs {inherit system;};
      with_metafun = _: _: inputs.metafun.packages."${system}";
      in {
    homeConfigurations = {
      myProfile = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = pkgs_for_sys.extend with_metafun;
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
      (metafun.withPackages "my-command" [figlet lolcat] (import ./my-command.nix))
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
  hook = ''figlet hello world | lolcat'';
}
```

With all the files put in place, (added to git) and attributes adjusted as needed, a call to home manager

```
home-manager switch --flake .#myProfile
```

should then put `my-command` on the user `PATH`.

```sh
> my-command
 _          _ _                            _     _ 
| |__   ___| | | ___   __      _____  _ __| | __| |
| '_ \ / _ \ | |/ _ \  \ \ /\ / / _ \| '__| |/ _` |
| | | |  __/ | | (_) |  \ V  V / (_) | |  | | (_| |
|_| |_|\___|_|_|\___/    \_/\_/ \___/|_|  |_|\__,_|
                                                   
```

