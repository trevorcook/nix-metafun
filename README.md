# Metafun

Metafun generates shell commands from Nix specifications. It features:

- Option parsing and argument checking
- Arbitrarily nested subcommands
- Tab completion script generation

## Structure of metafun specifications

A metafun specification is either nix text containing lines of Bash or an attribute set with the following attributes.

- desc: Description of the command, used in help.
- opts: Command options, long and short.
- args: Non optional arguments.
- hook: Command body.
- commands: Further subcommand metafun specifications.

The metafun library exports two main nix functions:

- `mkCommand`: Generates shell commands based on a specification
- `mkCommandCompletion`: Generates a bash completion commands based on a specfication.

## Example

A reference specification can be found in `metafun.reference` that contains a comprehensive set of all valid forms of specification. `metafun-env.nix` shows how shell functions can be created. Launch `nix-shell` for a shell session containing the generated functions.
