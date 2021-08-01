{envth,callPackage,lib,figlet}: with envth;
mkEnvironment rec {
  name = "metafun-env";
  definition = ./metafun-env.nix;

  passthru = rec {
    inherit lib;
    metafun = callPackage ./metafun.nix {};
    # The function nix definition
    metafun-ex-def = import ./metafun-example.nix { inherit lib metafun; };
    # The text of the shell script
    metafun-example =
      metafun.mkCommand "metafun-example" metafun-ex-def ;
    # The text of the completion script
    metafun-example-completion =
      metafun.mkCommandCompletion "_metafun-example-completion" metafun-ex-def ;
  };
  #This enviornment variable is used in metafun-ref.argsOnly.
  argsOnly_values = "option-x option-y";
  # Define the function and completion on shell entry
  shellHook = ''
    metafun-example(){
      ${passthru.metafun-example}
    }
    _metafun-example-completion(){
      ${passthru.metafun-example-completion}
    }
    complete -F _metafun-example-completion metafun-example
    '';

  paths = [figlet];
  envlib = {
    print-reference = ''
      metafun-example reference command
      metafun-example reference opt
      metafun-example reference arg
      '';
    # A "banner" shell function
    banner = ''
      echo "/* #####################################################"
      echo "$@" | figlet
      echo "$@"
      echo "*/ #####################################################"
      '';
  };
}
