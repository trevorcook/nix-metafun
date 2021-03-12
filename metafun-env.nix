let
  mkShowArgs = var: args: ''
    ${var}="${var}:"
    for arg in ${args}; do
      ${var}="${"$" + var}{$arg}"
      done
    '';
  showAt = ''
    ${mkShowArgs "args" ''"$@"''}
    echo $args'';

myfun-def = {
  desc = "Function to showcase metafunction programming.";
  opts = {
    n = { hook = ''echo "Running hook for option -n (no argument)"'';
          desc = "A short option that takes no argument."; };
    a = { hook = _ : ''echo "Running hook for option a (argument is $1)"'';
          desc = "A short option that takes an argument.";
        };
    longopt-c = _ :''echo "longopt-c running (argument is $1)"'';
    };
  hook = ''
    echo "In myfun hook. Current positional parameters: "
    ${showAt}
    '';
  args = [ { name = "experiment"; type = ["mayo" "cheese"]; }
           { name = "code"; hook = "echo code1 codeb"; }];
  commands = {
          connect = {
            opts = { j = { hook = "echo running option j hook";
                           desc = "An option for the connect command"; }; };
            desc="Connects A to B";
            hook = ''echo "$1 -> $2"'';
            args = ["from" "to"];
            };
          rawcommand = ''
            echo "In rawcommand, current parameters:"
            ${showAt}

          '';
          };
        };
in

{envth,callPackage,lib,figlet}: with envth;
let metafun = callPackage ./metafun.nix {}; in
mkEnvironment {
  name = "metafun-env";
  definition = ./metafun-env.nix;
  passthru = { inherit metafun lib myfun-def;
               myfun = metafun.mkCommand "myfun" myfun-def; };
  shellHook = ''
    complete -F _myfun-completion myfun2
    '';
  paths = [figlet];
  envlib = with metafun; {
    #myfun = myfun-def; #envth now uses metafun for envlib
    myfun2 = mkCommand "myfun2" myfun-def;
    _myfun-completion = mkCommandCompletion "_myfun-completion" myfun-def;

    banner = ''
      echo "/* #####################################################"
      echo "$@" | figlet
      echo "$@"
      echo "*/ #####################################################"
      '';
  };
}
