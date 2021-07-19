let
  mkShowArgs = var: args: ''
    declare ${var}="${var}:"
    for arg in ${args}; do
      ${var}="${"$" + var}{$arg}"
      done
    '';
  showInputs = ''
    ${mkShowArgs "args" ''"$@"''}
    echo $args'';
  opts-def = {
    n.desc = "A short option that takes no argument.";
    n.hook = ''echo "Running hook for option -n (no argument)"'';
    a.hook = _ : ''echo "Running hook for option a (argument is $1)"'';
    a.desc = "A short option that takes an argument.";
    longopt-c = _ :''echo "longopt-c running (argument is $1 $2 $3)"'';
  };
in {
  desc = "Function to showcase metafunction programming.";
  opts = opts-def;
  args = [{name="x";type=["arg1-a" "arg1-b"];}];
  hook = ''
    echo "In myfun hook. Current positional parameters: "
    ${showInputs}
    '';
  /* args = [ { name = "experiment"; type = ["mayo" "cheese"]; }
           { name = "code"; hook = "echo code1 codeb"; }]; */
  commands.noOptsNoArgs = {
    desc = "This command has no options or arguments.";
    hook = "echo running noOptsNoArgs";
  };
  commands.optsOnly = {
    desc = "This command takes showcases several types of options.";
    opts = {
      a=''echo "processing opt -a (string definition)" '';
      bee = _ : ''echo "processing opt --bee $1 (function definition)"'';
      c = { desc = "c's help description";
            argument = true;
            hook="echo $var_c";
            set = "var_c";
      };
      d = { desc = "d's help description";
            argument = false;
            hook="echo $var_d";
            set = "var_d";
      };
      e = { desc = "e's help description";
            set = "var_e";
      };
    };
    hook = "declare -p var_a var_bee var_c var_d var_e";
  };
  commands.argsOnly = {
    desc = "This command has no options but several arguments, each with a different method of tab completion.";
    args  = [ "text_type"
              "file"
              "dir"
              { name = "type_type"; type = ["option_a" "option_b"];}
              { name = "hook_type"; hook = "echo $argsOnly_values"; }];
    hook = "echo running noOptsNoArgs";
  };
  commands.getOpts = {
    hook = "echo x";
  };
}
