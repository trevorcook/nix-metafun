{envth,callPackage,lib,figlet}: with envth;
mkEnvironment rec {
  name = "metafun-env";
  definition = ./metafun-env.nix;

  passthru = rec {
    inherit lib;
    metafun = callPackage ./metafun.nix {};
    # The function nix definition
    metafun-ref-def = import ./metafun-ref.nix { inherit lib; };
    # The text of the shell script
    metafun-ref =
      metafun.mkCommand "metafun-ref" metafun-ref-def ;
    # The text of the completion script
    metafun-ref-completion =
      metafun.mkCommandCompletion "_metafun-ref-completion" metafun-ref-def ;
  };
  #This enviornment variable is used in metafun-ref.argsOnly.
  argsOnly_values = "option-x option-y";
  # Define the function and completion on shell entry
  shellHook = ''
    metafun-ref(){
      ${passthru.metafun-ref}
    }
    _metafun-ref-completion(){
      ${passthru.metafun-ref-completion}
    }
    complete -F _metafun-ref-completion metafun-ref
    '';

  paths = [figlet];
  envlib = {
    # A "banner" shell function
    banner = ''
      echo "/* #####################################################"
      echo "$@" | figlet
      echo "$@"
      echo "*/ #####################################################"
      '';
  };
}
