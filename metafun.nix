# This file :: {opts} -> metafun
{lib,getopt,writeTextFile,symlinkJoin,writeShellApplication}: 
with builtins; with lib;
# Metafun as a package is a functor, with 
#    - `metafun name spec` resulting in basic scripts
#    - `metafun.withPackages name spec packages` resulting in writeShellApplication based scripts
#       with both the check phase and additional bash options disable.
#    - `metafun.application attrset spec` resulting in writeShellApplication based scripts. See
#       the trivial builders section of the nixpkgs manual for attribute details.
#    - other options, e.g. `metafun.text.help name spec` resulting in the text string of the help file. 

# Some convenience functions.
let
  nArgs = args: if isNull args then 0 else length args;
  hyphenate = name: if stringLength name > 1 then "--${name}" else "-${name}";
  reference-commands = import ./metafun-ref.nix ;
  # concatenate nonEmpty strings from the given list
  concatNonEmptySep = sep: xs: concatStringsSep sep (concatMap (s: if s=="" then [] else [s]) xs);
  pnt = v: seq (debug.traceVal (generators.toPretty {} )v) v;
  # for interpolation convenience sake.
  st = "METAFUN_COMPLETION";
  stV = "$" + st;
in

# The metafun __functor attribure.
rec {
  # Top level utilities.
  # metafun :: command-name -> command-spec -> symlinkJoin-derivation
  __functor = _:  file.metafun;
  # metafun.application :: writeShellApplicationAtributes -> command-spec -> symlinkJoin-derivation
  application = file.metafunApplication;
  # metafun.withPackages :: command-name -> command-spec -> packages -> symlinkJoin-derivation
  withPackages = name: spec: packages: file.metafunApplication {inherit name; runtimeInputs = packages; checkPhase = ""; bashOptions=[];} spec;

  # Utilities that result in /nix/store files.
  file = {
    metafunApplication = attrs: command-spec: symlinkJoin {
      name = "metafun-${attrs.name}";
      paths = [
        (file.commandApplication attrs command-spec)
        (file.completion attrs.name command-spec)
      ];
    };
    metafun = command-name: command-spec: symlinkJoin {
      name = "metafun-${command-name}";
      paths = [
        (file.command command-name command-spec)
        (file.completion command-name command-spec)
      ];
    };
    command = command-name: command-spec: writeTextFile {
      name = command-name;
      destination = "/bin/${command-name}";
      text = text.command.command command-name command-spec;
      executable = true;
    };
    commandApplication = {name,runtimeInputs,excludeShellChecks?[],...}@attrs: command-spec: 
      let overrides = {
            text = text.command.command name command-spec;
            # excludeShellChecks = ["SC2317"] ++ excludeShellChecks; 
            };
      in writeShellApplication (attrs // overrides); 
    help = command-name: command-spec: writeTextFile {
      name = "${command-name}__help__";
      text = text.help.command command-name command-spec;
      executable = true;
    };
    # The completion script to source
    completion = command-name: command-spec: writeTextFile {
      name = "${command-name}";
      destination = "/share/bash-completion/completions/${command-name}";
      text = text.completion.script (file.completion-command command-name command-spec) command-name;
      executable = true;
    };
    # The command that gets created
    completion-command = command-name: command-spec: writeTextFile {
      name = "${command-name}";
      text = text.completion.command command-name command-spec;
      executable = true;
    };

  };

  # Utilities that result in text strings (which go into the store files).
  text = {
    # The command.
    command = {
      # Alias text.command.command as text.command
      __functor = _: text.command.command;
      # Top level command script contents.
      command = name: cmd:  ''
        declare GETOPT="${getopt}/bin/getopt";
        declare HELP_CMD="${file.help name cmd}"
        ${text.command.subcommand [name] cmd}'';
      #  subcommand path cmd:  generate the (sub)command represented by "path", given the 
      #   input attribute set, cmd
      subcommand = path: cmd_: 
        let
          cmd = ingress.command path cmd_ ;
          mkCommandCase = cmd_name: cmd:
            ''
            ${cmd_name} )
            ${text.command.subcommand (path++[cmd_name]) cmd}
            ;;
            '';
        in if cmd.verbatim then cmd_ else ''
        ${cmd.preOptHook}
        # Begin option parsing for ${concatStringsSep " " path}
        ${text.command.options cmd.opts}
        # Done option Parsing
        if ${text.command.argument-test cmd.args}
          then
          ${cmd.hook}
          ${if cmd.commands == {} then ''
            '' else ''
            shift ${toString (nArgs cmd.args)}
            declare parsed_command="$1"; shift
            case "$parsed_command" in
              ${concatStrings (mapAttrsToList mkCommandCase cmd.commands)}
              * )
              echo "Command unrecognized: ${concatStringsSep " " path}"
              echo "Ensure full subcommand is specified when appropriate."
              echo "See: ${concatStringsSep " " (path)} --help"
              ;;
            esac
            ''}
        else
          echo "Argument parse fail."
          echo "See: ${concatStringsSep " " path} --help."
        fi
        '';
      # Option parsing section of the (sub command) based on specified opts.
      options = opts:
        let
          setvars = concatMap (s: if s.set == null then [] else [s.set]) ( attrValues opts );
          preOptHook = if setvars == [] then "" else
            ''declare ${concatStringsSep " " setvars}'';
          mkOptCase = _: opt: ''
              ${hyphenate opt.name})
                ${concatNonEmptySep "\n" [ opt.hook
                                          (if isNull opt.arg then "" else "shift")
                                          (if opt.exit then "exit" else "")
                                          ]}
                ;;'';
          mkGetOpt = opts_ :
            let 
                opts = { long = []; short = [];} //
                        groupBy (getAttr "length") ( attrValues opts_ );
                # The '+' below stops parsing at first non-option
                shortopt = ''-o +${if shorts=="" then "''" else shorts }'';
                shorts = concatStrings (map mkOpt opts.short);
                longopt = optionalString (opts.long != []) ''--long ${longs}'';
                longs = concatStringsSep "," (map mkOpt opts.long);
                mkOpt = opt: opt.name + optionalString (opt.arg != null) ":";
            in ''$GETOPT  ${shortopt} ${longopt} -- "$@"'';

        in if opts == [] then "" else ''
          eval set -- "$(${mkGetOpt opts})"
          ${preOptHook}
          while true; do
            declare parsed_option=$1; shift
            case "$parsed_option" in
            ${concatStringsSep "\n" (mapAttrsToList mkOptCase opts)}
            --)
                break
                ;;
            esac
          done
          '';
      # Argument parsing section of the (sub command) based on specified opts.
      argument-test = args:
        let
          andArgTest = i: arg: ''
            && ${argTest i arg} '';
          argTest = i: arg:
            let
              param = "$" + (toString i);
              isChoice = choice: "[[ ${param} == ${choice} ]]";
            in
            if arg.type == "choice" then
              "{ ${concatStringsSep " || " (map isChoice arg.choice )}
              }"
            else
              "true";
          argLenTest = "(( $# >= ${toString (length args)} ))";
        in if isNull args then "true" else ''
          { ${argLenTest} ${concatStrings (imap1 andArgTest args)}
          }
        '';
    };
    # Make the text for the help file that the command uses.
    help = {
      # lias text.help.command as text.help
      __functor = _: text.help.command;
      command = name: cmd_:
        let
          cmd = ingress.command [name] cmd_ ;
          mkCommandCase = path: ''
            "${concatStringsSep "," path}")
            shift
            cat <<'EOF'
            ${text.help.output ([name]++path) (getSubCmd path) }
            EOF
            exit
            ;;
            ''
              ;
          getSubCmd =  path: ingress.command ([name]++path) (attrByPath (mkSubCmdPath path) {} cmd) ;
          mkSubCmdPath = path: if path == [] then []
            else ["commands"] ++ (intersperse "command" path);
          # reduce the command specification, cmd, to just a tree of subcommands.
          reduceToCommands = cmd_or_hook: let
            exchange-emptys = mapAttrs (_: v: if v == {} then null else v );
            f = acc: n: v: 
              if n == "commands" then
              exchange-emptys  (mapAttrs (n2: v2: reduceToCommands v2) v) 
              else
                acc;
            in if isAttrs cmd_or_hook then
              foldlAttrs f {} cmd_or_hook
              else null;
          # List all the paths to all subcommands
          all-paths = set: (concatMap subsequence (leaf-paths set));
          # List all the leafs of a nested attribute set
          leaf-paths = set: (collect isList (mapAttrsRecursive (p: _: p) set));
          # get all subsequences of a path: [a b c] -> [[a] [a b] [a b c]]
          subsequence = ls: 
            let 
                subs =  subsequence (drop 1 ls);
                prepend = ms: [(elemAt ls 0)] ++ ms;
            in if ls == [] then [] else map prepend ([[]] ++ subs);

        in ''
          declare csp=$(IFS=,; echo "$*")
          case "$csp" in
            ${mkCommandCase []}
            ${concatStrings (map mkCommandCase (all-paths (reduceToCommands cmd)))}
            * )
            echo "Command unrecognized."
            echo "See: ${name} --help"
            ;;
          esac
          '';

      # Format the help output for a command (subcommand)
      output = path: cmd:
        let 
          mkSection = text: if text == "" then "" else text + "\n";
        in ''
          ${concatStrings (map mkSection [(text.help.head path cmd)
                                          (text.help.usage path cmd)
                                          (text.help.opts cmd.opts)
                                          (text.help.args cmd.args)
                                          (text.help.subcommands cmd)
                                          # (text.help.foot path) 
                                          ])}'';
      head = path: cmd: (concatStringsSep " " path) + ": " + cmd.desc + "\n";
      usage = path : cmd:
        let
        cmdStr = concatStringsSep " ... " path;
        optStr = if cmd.opts == {} then "" else " [opts]";
        argStr = 
          let
            bkt = arg: " <${arg.name}>";
          in if isNull cmd.args then ""
            else concatStrings (map bkt cmd.args);
        commandStr = if cmd.commands == {} then ""
          else " {${concatStringsSep "|" (attrNames cmd.commands)}}";
        in
          ''usage: ${cmdStr}${optStr}${argStr}${commandStr}
          '';

      # Format the options section
      opts = opts: if opts == {} then "" else
        let mkOpt = name: opt: "  ${hyphenate opt.name} : ${opt.desc}"; in ''
          opts:
          ${concatStringsSep "\n" (mapAttrsToList mkOpt opts)}
          '';
      args = args: if args == null then "" else
        let mkArg = i: arg: if isString arg then
          "  ${arg} : '" 
            else
          "  ${toString i}) ${arg.name} : ${arg.desc}"; 
        in ''
          args:
          ${concatStringsSep "\n" (imap1 mkArg args)}
          '';
      # Format the subcommand section
      subcommands = cmd:
        let
          commandAttrAbout = name: {desc?"", ...}:
          "  ${name} : ${desc}";
          commandAbout = name: arg:
            if isAttrs arg then
              commandAttrAbout name arg
            else "  ${name} :";
        in if cmd.commands == {} then "" else ''
        commands:
        ${""}  ${concatStringsSep "\n  " (mapAttrsToList commandAbout cmd.commands)}'';
      foot = name: "";
      call-help = path: ''
        ''${HELP_CMD} ${concatStringsSep " " (drop 1 path)}
        exit'';
    };

    # Make the command completion text
    completion = {
      __functor = text.completion.script;
      # This is final script that should be sourced to initialize command completion.
      # The command must be wrapped in a function to work properly.
      script = completion-file: command-name: let fname = "_${command-name}-completion_"; in ''
        ${fname}(){
          source ${completion-file} "$@"
        }
        complete -F ${fname} ${command-name}
        '';
      # The body of a completion script, i.e. the contents of a file.
      command = name: cmd: ''
        # COMP_WORDS holds command line arguments (for bash functions, not commands)
        # Delete all arguments past the one under the cursor and assign them to positional
        # parameters
        for i in $( seq $(( COMP_CWORD + 1 )) ''${#COMP_WORDS[@]} ); do
          unset COMP_WORDS[$i]
        done
        unset COMP_WORDS[0]
        set -- "''${COMP_WORDS[@]}"
        ${text.completion.subcommand [name] cmd}
        '';
      # The main completion body.
      subcommand = path: cmd_:
        let 
          cmd = ingress.command path cmd_;
          command-case = name: subcommand: ''
              ${name} )
                shift
                ${text.completion.subcommand [name] subcommand}
                ;;
              '';
        in ''
          COMPREPLY=( )
          ${text.completion.opt cmd.opts}
          ${text.completion.args cmd.args}
          #''${completion.subcommand cmd.commands}
          # completion.subcommand = commands:
          ######################################################
          # Complete subcommand
          if [[ ${stV} == cmd ]]; then
            if [[ $# == 1 ]]; then
              ${text.completion.compreply.choice (attrNames cmd.commands) "-- $1"}
            else
              case "$1" in
              ${concatStrings (mapAttrsToList command-case cmd.commands)}
              * )
                ${st}=exit
              ;;
              esac
            fi
          fi
        '';
      opt = opts:
        let
          # test.isopt = str: ''[[ -n "''${${str}#-}"]]'';
          opt-args = map (opt: hyphenate opt.name) (attrValues opts);
          opt-case = opt: ''
            ${hyphenate opt.name})
              COMPREPLY=( )
              ${if opt.arg != null then ''
              shift
              [[ $1 == "=" ]] && shift
              if [[ $# == 1 ]]; then
                #COMPREPLY+=( _ ${hyphenate opt.name}_arg{$1} )
                ${text.completion.arg opt.arg "$1"}
                shift
              else
                shift
              fi
              '' else ''
              shift
              ''}
              ;;
              '';
        in ''
          #############################################
          # Check all options supplied
          declare ${st}="opts"
          while [[ ${stV} == opts ]]; do
            if [[ $# == 0 ]] ; then
              ${st}=args
            else
              ${text.completion.compreply.choice opt-args "-- $1"}
              declare nreply=''${#COMPREPLY[@]}
              declare opt="$1"
              if [[ -z "$1" ]]; then
                ${st}=args
              elif [[ $nreply == 0 ]]; then #No completion
                ${st}=args
              elif [[ $nreply == 1 ]]; then #Is option
                case "$1" in
                ${ concatStrings (map opt-case (attrValues opts) ) }
                *)
                  ${st}=exit
                  ;;
                esac
              else
                ${st}=args
              fi
            fi
          done
          '';

      args = args:
        let
          arg-case = i: arg:
            let param= "$" + (toString i); in ''
            ${toString i} )
              ${text.completion.arg arg param }
            ;;
          '';
        in if nArgs args == 0 then
          ''${st}=cmd
          ''
        else ''
        ############################################
        ## parse args. If latest param is arg, complete
        ## and exit. Else, shift out arguments and
        ## complete subcommand.
        if [[ ${stV} == args ]]; then
          ${st}=exit
          case "$#" in
          ${ concatStrings (imap1 arg-case args ) }
          *)
            shift ${toString (nArgs args)}
            ${st}=cmd
            ;;
          esac
        fi
        '';
      # complete an argument.
      arg = arg@{type,...}: inStr:
        let
          input = "-- " + inStr;
          inherit (arg.completion) hint;
        in
          if arg?completion.hook then text.completion.compreply.hook arg.completion.hook input
          else if arg?completion.compgen-opts then
            text.completion.compreply.compgen-opts arg.completion.compgen-opts input
          else if type == "choice" then text.completion.compreply.choice arg.choice input
          else if type == "file" then text.completion.compreply.file "${hint} _" input
          else if type == "dir" then text.completion.compreply.dir "${hint} _" input
          else text.completion.compreply.compgen-opts ''-W "_ ${hint}"'' input;

      # Formatted calls to the compgen utility.
      compreply = {
        choice = choices:
          text.completion.compreply.compgen-opts ''-W "${concatStringsSep " " choices}"'';
        hook = hook:
          text.completion.compreply.compgen-opts ''-W "$( ${hook} )"'';
        file = hint:
          text.completion.compreply.compgen-opts ''-f -W "${hint}"'';
        dir = hint:
          text.completion.compreply.compgen-opts ''-d -W "${hint}"'';
        compgen-opts = opts: arg:
          ''COMPREPLY+=( $(compgen ${opts} ${arg}) )'';
      };

    };
  };

  # Utilities that sanatize and normalize the inputs, i.e. the command-spec.
  ingress = {
      command = path: cmd_:
        let
          addDefaults = {
            opts?{}, args?null, hook?":",commands?{}, desc?"",
            preOptHook?"", verbatim?false} :
            let opts_ = (ingress.help-options path) // opts;
            in {
              inherit hook commands desc preOptHook verbatim;
              opts = ingress.opts opts_;
              args = ingress.args args;
            };
          out = if isAttrs cmd_ then addDefaults cmd_
                  else addDefaults { hook = cmd_; verbatim=true; };
        in out;

      help-options = path:
        let
          opt = {
            desc = "Show this help text.";
            hook = text.help.call-help path ;
          };
          out = {
            help = opt;
            h = opt;
          };
        in out;

      opts = mapAttrs ingress.opt;
      opt = name:
          let
            go = { desc?"", arg?null, hook?"", set?null, exit?false, ... }:
              let out = {
              inherit desc set name exit;
              arg = if isFunction hook && isNull arg then
                      ingress.arg "arg"
                    else ingress.arg arg;
              hook = ''${ concatNonEmptySep "\n" [
                        (if isNull set then ""
                        else if isNull out.arg then
                          ''declare ${set}=true''
                        else ''declare ${set}="$1"'')
                        (if isFunction hook then hook {} else hook)]}'';
              length = if stringLength name > 1 then "long" else "short";
              }; in out;
          in opt: if isAttrs opt then go opt
                  else go { hook = opt; };
      args = args_ : if isNull args_ then args_ else map ingress.arg args_;
      arg =
          let
            go = arg@{ name?"arg", desc ? name
                  , type ? "_"
                  , choice ? null
                  , completion ? { }
                  , check?null }: let out = {
              inherit name desc check;
              type = if any (n: n == type) ["file" "dir"]  then type
                      else if isList choice then "choice"
                      else "_";
              completion = { hint = if out.type == "_" then
                              "<arg:${out.name}>"
                              else "<arg:${out.type}>";
                            }
                        // completion;
              }; in out // (if out.type == "choice" then {inherit choice;} else {});
          in arg_: if isString arg_ then
                go { name = arg_; type = arg_; }
              else if isList arg_ then
                go {
                  name = "choice";
                  desc = "one of: ${concatStringsSep ", " arg_}.";
                  choice = arg_;
                }
              else if isBool arg_ && arg_ then
                go { name = "arg";
                      type = "arg"; }
              else if isAttrs arg_ then
                go arg_
              else null;
  };
}