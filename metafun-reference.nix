{
  # Top level has only a description, `desc`, and `commands` (no opts, args, hook).
  desc = "A Reference Specification for metafun.";
  hook = ''echo Running main command hook with remaining command line parameters: $@'';
  opts = {
    completion-path = {
        desc = ''Print the path to the completion script to for easy sourcing:
         > source "$(metafun-reference --completion-path)"'';
        exit = true;
        hook = ''
          realpath $(dirname $(which metafun-reference))/../share/bash-completion/completions/metafun-reference
        '';
    };
    copy-spec = {
        desc = ''Copies the specification used to generate this command to the current directory.'';
        exit = true;
        hook = ''
          cp ${./metafun-reference.nix} metafun-reference-copy.nix
          chmod 644 metafun-reference-copy.nix
        '';
    };
  };  
  commands = {
    options = {
      desc = "A subcommand demonstrating the ways to define option types.";
      opts = {  # opts a and b use attribute sets to define variable setting behavior
                a = { desc = "set var_a=true using set option.";
                  hook = ''echo option \"a\" set var_a="$var_a"'';
                  set = "var_a"; };
                b = { desc = "set var_b to an argument";
                  hook = ''echo option \"b\" set var_b="$var_b"'';
                  set = "var_b";
                  arg = true; };
              # a-hook and b-hook mimic the behavior of a and b only using "hooks".
              a-hook = { desc = "set var_a using a hook";
                  hook = ''
                    declare var_a=1
                    echo option \"a\" set var_a="$var_a";
                    '';
                  arg = false; };
                b-hook = { desc = "set var_b to an argument using a hook";
                  hook = ''
                        declare var_b=$1
                        echo option \"b\" set var_b="$var_b";
                        '';
                  arg = true; };
                # String and function mimic a and b, but do not generate help.
                string = "declare var_a=2";
                function = _:"declare var_b=$1";
                # Abandon command execution after processing an option with the exit attribute set.
                exit = { 
                  desc = "Demonstrates early exit.";
                  hook = ''echo exiting now'';
                  exit = true; }; 
    
                };
      hook = ''
        echo in \"options\" subcommand hook with remaining command line parameters: $@
        declare -p var_a var_b
        '';
      };
    arguments= rec {
      desc = ''A subcommand demonstrating the ways to define arguments.'';
      hook = ''
        echo Running \"arguments\" subcommand hook with remaining command line parameters: $@
        '';
      args = [ { name = "choice"; desc = "Predefined choice of fruit."; choice = ["apple" "banana"]; }
           "file" # Alternatively, use type = "file" as in the case of directory, below.
           { name = "directory"; desc = "A directory."; type = "dir"; }
           { name = "hook"; desc = "Arbitrary code."; completion.hook = "echo $@"; }
           { name = "compgen-arg"; desc = "Arbitrary compgen argument. An environment variable in this case."; completion.compgen-opts = "-A variable"; }
             "arbitrary" # Simple string that is not "file" or "dir" 
           { name = "arbitrary"; desc = "Arbitrary argument."; }
             ];
    };
  };

}
