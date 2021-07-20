{envth,callPackage,lib,figlet}: with envth;
mkEnvironment rec {
  name = "metafun-env";
  definition = ./metafun-env.nix;

  passthru = rec {
     inherit lib;
     metafun = callPackage ./metafun.nix {debug=false;};
     metafun-ref =
       metafun.mkCommand "metafun-ref" metafun-ref-def ;
     metafun-ref-completion =
       metafun.mkCommandCompletion "_metafun-ref-completion" metafun-ref-def ;
     metafun-ref-def = import ./metafun-ref.nix;
   };
  argsOnly_values = "option_a option_b";
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
  envlib = with metafun; {
    #myfun = myfun-def; #envth now uses metafun for envlib
    /* myfun = mkCommand "myfun" myfun-def;
    _myfun-completion = mkCommandCompletion "_myfun-completion" myfun-def; */

    banner = ''
      echo "/* #####################################################"
      echo "$@" | figlet
      echo "$@"
      echo "*/ #####################################################"
      '';
  };
}
