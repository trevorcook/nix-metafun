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
  desc = "Function to showcase metafunction programming.";
  hook = ''
    echo "In metafun-ref.hook.
    Hooks of super commands are always run for each subcommand.
    Current positional parameters: "
    ${showInputs}
    echo
    '';
  commands.optionalSubcommands =
    let
      make-case = name: _: ''
        ${name})
          echo "found ${name}"
          echo "letting optionalSubcommands.hook run until completion."
          ;;
        '';
    in rec {
    desc = ''This command shows how to implement optional subcommands. Note, the automated help output (esp "usage") does not cover this scenario.
           '';
    hook = ''
      echo Running \"optionalSubcommands\"
      echo Checking for subcommand.
      case $1 in
      ${concatStrings (mapAttrsToList make-case commands)}
      *)
        echo "no subcommand given"
        echo "will do my business and call return/exit"
        ${showInputs}
        ${safeexit}
        ;;
      esac
      '';
    commands.sub-1 = ''
      echo "Running sub-1"
      ${showInputs}
      '';
    commands.sub-2 = ''
      echo "Running sub-2"
      ${showInputs}
      '';
  };
  commands.optsOnly = {
    desc = "This command showcases several types of options.";
    opts = {
      a=''echo "processing opt -a (string definition)" '';
      bee = _ : ''echo "processing opt --bee $1 (functional definition)"'';
      c = { desc = "Option as attribute set. Uses \"set\" to set var_c to input.";
            argument = true;
            hook="echo in var_c hook";
            set = "var_c";
      };
      d = { desc = "Option as attribute set. Uses \"set\" to set var_d true.";
            argument = false;
            hook="echo in var_d hook";
            set = "var_d";
      };
      e = { desc = "Option as attribute set. Uses \"set\" to set var_e true. (default to argument=false)";
            set = "var_e";
      };
    };
    hook = ''
      echo "Running metafun-ref.optsOnly"
      declare -p var_a var_bee var_c var_d var_e
      '';
  };
  commands.argsOnly = {
    desc = "This command has no options but several arguments, each with a different method of tab completion.";
    args  = [ "desc"
              "file"
              "dir"
              { name = "choice_type"; type = ["option_a" "option_b"];}
              { name = "hook_type"; hook = "echo $argsOnly_values"; }];
    hook = "echo running noOptsNoArgs";
  };
  commands.a-hook = ''
    echo "This command was made by supplying a string instead of a \"command\" attribute set".
    echo "The raw script will be executed with the remaining command line parameters."
    ${showInputs}
    '';
}
