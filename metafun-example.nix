{lib}: with lib;
let
  # This will create a little script that shows {}-enclosed arguments.
  mkShowArgs = var: args: ''
    declare ${var}="${var}:"
    for arg in ${args}; do
      ${var}="${"$" + var}{$arg}"
      done
    '';
  #Exit a script or function.
  safeexit = ''{ return &> /dev/null || exit ; }'';
  showInputs = ''
    ${mkShowArgs "args" ''"$@"''}
    echo $args'';
in {
  # Top level has only a description, `desc`, and `commands` (no opts, args, hook).
  desc = "A metafun definition with sub-commands showing example uses.";
  hook = ''
    echo Running main command hook with remaining opts: $@'';
    
  commands.sub1  = {
    desc = "Subcommand 1";
    hook = ''
      echo "Since subcommands have been defined a complete path through the subcommand tree must be taken."
      echo "e.g. \"metafun-example sub1\" or \"metafun-example sub2 a\""
      '';
  };
  commands.sub2 = rec {
    desc = ''Subcommand 2'';
    hook = ''
      echo Running \"sub2\" hook with remaining opts: $@
      '';
    commands.def-string = ''
      echo Running \"sub2 def-string\" with remaining opts: $@. It was defined with a string, and no help is generated.
      '';
    commands.def-hook.hook = ''
      echo "Running sub2 b hook" with remaining opts: $@. 
      '';
    };
  opts = {
    hook =''echo "running `hook` option"'';
    hook_fcn = _ : ''
      echo "running `hook_fcn` option with input $1" '';
    a = { desc = "Short option sets variable 'var_a' to true";
          set = "var_c";
        };
  };
}
