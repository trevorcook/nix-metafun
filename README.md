# Metafun

Metafun generates shell commands from Nix specifications. It features:

- Option parsing and argument checking.
- Tab completion script generation with completion for arguments, options, and subcommands.
- Arbitrarily nested subcommands.

## Project Architecture

This project contains:

- `metafun.nix`: The `metafun` definition set that exports two main functions:
  - `mkCommand`: Generates shell commands based on a specification
  - `mkCommandCompletion`: Generates a bash completion command based on a specfication.
- `metafun-ref.nix`: The `metafun` definition of a command that prints
   reference information for `metafun` specifications.
- `metafun-example.nix`: An example `metafun` specification that shows some of the various ways to define arguments and options.
- `metafun-env.nix`: A definition for an interactive `nix-shell` environment.

## Example

An example of `metafun` use is contained in `metafun-env.nix`. Clone this repository and launch `nix-shell` to load the definitions contained in `metafun-env.nix`, notably the shell function `metafun-example`, whose definitin is contained in `metafun-example.nix`

## Metafun Specifications

The `metafun` functions, `mkCommand` and `mkCommandCompletion`, translate nix expressions into shell commands. They accept specific expressions, referred to here as "specifications", and discussed below.

### Commands

The top level specification expected by `mkCommand` (`mkCommandCompletion`) are attribute sets with the following elements.

- `desc`: Help description of current command.
- `opts`: A set of option specifications.
- `preOptHook`: Shell code to be run prior to option and argument parsing.
- `args`: A list of required arguments (or null).
- `hook`: Shell code to be run after option and argument parsing.
- `commands`: A set of additional command specifications to be run as sub-commands.

The default command attribute set is something like the following:

```nix
{
  desc="";
  preOptHook="";
  opts={h,help};
  args=null;
  hook=":";
  commands={};
}
```

`mkCommand`, will also accept strings, in which case the resulting command (subcommand) is passed verbatim. For completions, nothing will be generated.

### Options

Command line options for a resulting command can be specified with an attribute set with the following elements:

- `desc`: A helpful description used in help.
- `arg`: An argument specification or `null`.
- `set`: The name of a variable that should be set, or `null`. If the option accepts an argument, the variable will be assigned to the argument. If no argument, then it will be set to "`true`". If `set` is specified and the command is not called with the option, then the named variable will be unset.
- `hook`: Shell code to be run when the option has been encountered. The option argument, if applicable, is positional parameter `$1`. Hook is run after `set`.

The default attribute set is something like the following:
```nix
{
  desc="";
  arg = null;
  set = null;
  hook = ":";
}
```

Additionally, the following short forms for options are accepted.

- A string option, `optStr`, is taken to be the option hook:
      {
        hook = `optStr`.
      }
- A function, `f`, that takes (and ignores) a single argument and returns a string is translated to the attribute set:
     {
        arg = "arg";
        hook = f {};
     }
- Additionally, setting the `hook` attribute to a function will set `arg="arg"` as in the example above.


### Arguments
Lists of arguments can be supplied to a command and individual arguments can be supplied to options. The most general form of an `arg` is an attribute set with the following elements:

- `name`: The name of the argument, used for help and usage.
- `desc`: A helpful description used in help.
- `type`: The type of argument: file, directory, choice, or "\_" (for any other supplied type). `Type` is used for argument completion.
- `choice`: Choices of specific enumerated arguments. Used for completion and argument test.
- `completion`: A set of additional completion opts. Elements:
    - `hint`: A hint that will be provided on empty completions.
    - `hook`: A hook that will be run to generate compgen words.
- `check`: A test that should be run during argument parsing (unimplemented).

The default attribute set is something like:

```nix
{
  name="arg" #or the option name (if opt argument).
  desc=name;
  type="_";
  choice = null; #or not present
  completion = { hint = "<arg:${type}"; };
  check=null; #or not present
 }
```

Additionally, the following short forms for arguments are accepted.

- A supplied string (`argStr`) is translated to the attribute set:
      {
        name = argStr;
        type = argStr;
      }
  Note that `argStr`not equal to `file` or `dir` will result in the undefined type "\_"
- A supplied list (`argList`) is translated to the attribte set:
  {
    name = "choice";
    type = "choice";
    desc = "one of: <enumerated argList>";
    choice = argList;
  }
