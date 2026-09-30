# This file :: {opts} -> metafun
# metafun :: command-name -> command-spec -> symlinkJoin-derivation

{lib,getopt,writeTextFile,symlinkJoin}: with builtins; with lib;
command-name: command-spec:
let
  out.metafun = symlinkJoin {
      name = "metafun-${command-name}";
      paths = [
        out.command
        out.completion
      ];
  };
  out.command = writeTextFile {
    name = command-name;
    destination = "/bin/${command-name}";
    text = command.command command-name command-spec;
    executable = true;
  };
  out.help = writeTextFile {
    name = "${command-name}__help__";
    text = help.command command-name command-spec;
    executable = true;
  };
  out.completion = writeTextFile {
    name = "${command-name}";
    destination = "/share/bash-completion/completions/${command-name}";
    text = completion.command command-name command-spec;
    executable = true;
  };

  # mkMetafun = name: cmd: 
  #   let help = mkHelpFile name cmd;
  #   in symlinkJoin {
  #     name = "metafun-${name}";
  #     paths = [
  #       (mkCommandFile name cmd help)
  #       # help
  #       (mkCompletionFile name cmd)
  #     ];
  # };
  # mkCommandFile = name: cmd: help-cmd: writeTextFile {
  #   inherit name;
  #   destination = "/bin/${name}";
  #   text = mkCommand name cmd help-cmd;
  #   executable = true;
  # };
  # mkHelpFile = name: cmd: writeTextFile {
  #   name = "${name}__help__";
  #   # destination = "/${name}__help__";
  #   text = mkHelp name cmd;
  #   executable = true;
  # };
  # mkCompletionFile = name: cmd: writeTextFile {
  #   name = "${name}";
  #   destination = "/share/bash-completion/completions/${name}";
  #   text = mkCommandCompletion name cmd;
  #   executable = true;
  # };

/* #####################################################
           _     ____                                          _
 _ __ ___ | | __/ ___|___  _ __ ___  _ __ ___   __ _ _ __   __| |
| '_ ` _ \| |/ / |   / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |
| | | | | |   <| |__| (_) | | | | | | | | | | | (_| | | | | (_| |
|_| |_| |_|_|\_\\____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|

mkCommand
*/ #####################################################
  command.command = name: cmd:  ''
    declare GETOPT="${getopt}/bin/getopt";
    declare HELP_CMD="${out.help}"
    ${command.subcommand [name] cmd}'';

  # command.subcommand path cmd  generate the (sub)comand represented by "path", given the 
  #   input attributeset, cmd, and associated helpfile.
  command.subcommand = path: cmd_: 
    let
      cmd = ingress.command path cmd_ ;
      mkCommandCase = cmd_name: cmd:
        let cmdpath = super + " ... " + cmd_name; in
        ''
        ${cmd_name} )
        ${command.subcommand (path++[cmd_name]) cmd}
        ;;
        '';
    in if cmd.verbatim then cmd_ else ''
    ${cmd.preOptHook}
    # Begin option parsing for ${concatStringsSep " " path}
    ${command.options cmd.opts}
    # Done option Parsing
    if ${command.argument-test cmd.args}
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
          echo "See: ${concatStrings (take 1 path)} --help"
          ;;
        esac
        ''}
    else
      echo "Argument parse fail."
      echo "See: ${concatStringsSep " " path} --help."
    fi
    '';


  command.options = opts:
    let
      setvars = concatMap (s: if s.set == null then [] else [s.set]) ( attrValues opts );
      preOptHook = if setvars == [] then "" else
        ''declare ${concatStringsSep " " setvars}'';
      mkOptCase = _: opt: ''
          ${hyphenate opt.name})
            ${concatNonEmptySep "\n" [ opt.hook
                                      (if isNull opt.arg then "" else "shift")
                                      (if opt.exit then safeexit else "")
                                      ]}
            ;;'';
      mkGetOpt = opts_ :
        let #getopt-exe = getopt + "/bin/getopt";
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

  command.argument-test = args:
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


/* #####################################################
           _    _   _      _
 _ __ ___ | | _| | | | ___| |_ __
| '_ ` _ \| |/ / |_| |/ _ \ | '_ \
| | | | | |   <|  _  |  __/ | |_) |
|_| |_| |_|_|\_\_| |_|\___|_| .__/
                            |_|
mkHelp: The help part of the command.
*/ #####################################################

  # Format the whole help file for the command.
  help.command = name: cmd_:
    let
      cmd = ingress.command [name] cmd_ ;
      mkCommandCase = path: ''
        "${concatStringsSep "," path}")
        shift
        # ''${help.help (mkSubName path) (getSubCmd (mkSubName path) path) }
        ${help.help ([name]++path) (getSubCmd path) }
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
      # subsequence = let f = l: ls: [[l]] ++ (if ls == [] then [] else map (ms: [l]++ms) (f (elemAt ls 0) (drop 1 ls))); in f

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
  help.help = path: cmd:
    let 
      mkSection = text: if text == "" then "" else text + "\n";
    in ''
      cat <<'EOF'
      ${concatStrings (map mkSection [(help.head path cmd)
                                      (help.usage path cmd)
                                      (help.opts cmd.opts)
                                      (help.subcommands cmd)
                                      (help.foot path) ])}EOF
      ${safeexit}
      '';
  help.head = path: cmd: (concatStringsSep " " path) + ": " + cmd.desc + "\n";
  help.usage = path : cmd:
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
  help.opts = opts: if opts == {} then "" else
    let mkOpt = name: opt: "  ${hyphenate opt.name} : ${opt.desc}"; in ''
      opts:
      ${concatStringsSep "\n" (mapAttrsToList mkOpt opts)}
      '';
  # Format the subcommand section
  help.subcommands = cmd:
    let
      commandAttrAbout = name: {desc?"", ...}:
      "  ${name} : ${desc}";
      commandAbout = name: arg:
        if isAttrs arg then
          commandAttrAbout name arg
        else "  ${name} :";
    in if cmd.commands == {} then "" else ''
    commands:
    ${""}  ${concatStringsSep "\n  " (mapAttrsToList commandAbout cmd.commands)}
    '';
  help.foot = name: "";
  help.call-help = path: ''
    ''${HELP_CMD} ${concatStringsSep " " (drop 1 path)}
    ${safeexit}'';


/* #####################################################
           _     ____                      _      _
 _ __ ___ | | __/ ___|___  _ __ ___  _ __ | | ___| |_ ___
| '_ ` _ \| |/ / |   / _ \| '_ ` _ \| '_ \| |/ _ \ __/ _ \
| | | | | |   <| |__| (_) | | | | | | |_) | |  __/ ||  __/
|_| |_| |_|_|\_\\____\___/|_| |_| |_| .__/|_|\___|\__\___|
                                    |_|
mkComplete: make the command completion function
*/ #####################################################

  #METAFUN Completion Variable
  st = "METAFUN_COMPLETION";
  stV = "$" + st;

  completion.command = name: cmd: ''
  # Replace input arguments with COMP_WORDS vector and call the handler.
    for i in $( seq $(( COMP_CWORD + 1 )) ''${#COMP_WORDS[@]} ); do
      unset COMP_WORDS[$i]
    done
    unset COMP_WORDS[0]
    set -- "''${COMP_WORDS[@]}"
    ${completion.subcommand [name] cmd}
    '';
  completion.subcommand = path: cmd_:
    let 
      cmd = ingress.command path cmd_;
      command-case = name: subcommand: ''
          ${name} )
            shift
            ${completion.subcommand [name] subcommand}
            ;;
          '';
    in ''
      COMPREPLY=( )
      ${completion.opt cmd.opts}
      ${completion.args cmd.args}
      #''${completion.subcommand cmd.commands}
      # completion.subcommand = commands:
      ######################################################
      # Complete subcommand
      if [[ ${stV} == cmd ]]; then
        if [[ $# == 1 ]]; then
          ${compreply.choice (attrNames cmd.commands) "-- $1"}
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
  completion.opt = opts:
    let
      test.isopt = str: ''[[ -n "''${${str}#-}"]]'';
      opt-args = map (opt: hyphenate opt.name) (attrValues opts);
      opt-case = opt: ''
        ${hyphenate opt.name})
          COMPREPLY=( )
          ${if opt.arg != null then ''
          shift
          [[ $1 == "=" ]] && shift
          if [[ $# == 1 ]]; then
            #COMPREPLY+=( _ ${hyphenate opt.name}_arg{$1} )
            ${completion.arg opt.arg "$1"}
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
          ${compreply.choice opt-args "-- $1"}
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

  completion.args = args:
    let
      arg-case = i: arg:
        let param= "$" + (toString i); in ''
        ${toString i} )
          ${completion.arg arg param }
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
  completion.arg = arg@{type,...}: inStr:
    let
      input = "-- " + inStr;
      inherit (arg.completion) hint;
    in
      if arg?completion.hook then compreply.hook arg.completion.hook input
      else if arg?completion.compgen-opts then
        compreply.compgen-opts arg.completion.compgen-opts input
      else if type == "choice" then compreply.choice arg.choice input
      else if type == "file" then compreply.file "${hint} _" input
      else if type == "dir" then compreply.dir "${hint} _" input
      else compreply.compgen-opts ''-W "_ ${hint}"'' input;

    # completion.subcommand = commands:
    #   let 
    #     command-case = name: subcommand: ''
    #       ${name} )
    #         shift
    #         ${completion.subcommand [name] subcommand}
    #         ;;
    #       '';
    #   in ''
    #   ######################################################
    #   # Complete subcommand
    #   if [[ ${stV} == cmd ]]; then
    #     if [[ $# == 1 ]]; then
    #       ${compreply.choice (attrNames commands) "-- $1"}
    #     else
    #       case "$1" in
    #       ${concatStrings (mapAttrsToList command-case commands)}
    #       * )
    #         ${st}=exit
    #       ;;
    #       esac
    #     fi
    #   fi
    # '';

  compreply.choice = choices:
    compreply.compgen-opts ''-W "${concatStringsSep " " choices}"'';
  compreply.hook = hook:
    compreply.compgen-opts ''-W "$( ${hook} )"'';
  compreply.file = hint:
    compreply.compgen-opts ''-f -W "${hint}"'';
  compreply.dir = hint:
    compreply.compgen-opts ''-d -W "${hint}"'';
  compreply.compgen-opts = opts: arg:
    ''COMPREPLY+=( $(compgen ${opts} ${arg}) )'';

/* #####################################################
 _
(_)_ __   __ _ _ __ ___  ___ ___
| | '_ \ / _` | '__/ _ \/ __/ __|
| | | | | (_| | | |  __/\__ \__ \
|_|_| |_|\__, |_|  \___||___/___/
         |___/
ingress: sanatize inputs.
*/ #####################################################
  # ingress.command path cmd: sanatize command attribute set, cmd, of the (sub)command, path.
  ingress.command = path: cmd_:
    let
      addDefaults = {
        opts?{}, args?null, hook?"",commands?{}, desc?"",
        preOptHook?"", verbatim?false} :
        let opts_ = (ingress.help-options path) // opts;
        in {
          inherit hook commands desc preOptHook verbatim;
          opts = ingress.opts opts_;
          args = ingress.args args;
        };
      # out = if isString cmd_ then defaults { hook = cmd_; verbatim=true; }
      #        else defaults cmd_;
      out = if isAttrs cmd_ then addDefaults cmd_
             else addDefaults { hook = cmd_; verbatim=true; };
            #  else defaults cmd_;
    in out;

  ingress.help-options = path:
    let
      opt = {
        desc = "Show this help text.";
        hook = help.call-help path ;
      };
      out = {
        help = opt;
        h = opt;
      };
    in out;

  ingress.opts = mapAttrs ingress.opt;
  ingress.opt = name:
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
  ingress.args = args_ : if isNull args_ then args_ else map ingress.arg args_;
  ingress.arg =
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


/* #####################################################
       _   _ _
 _   _| |_(_) |
| | | | __| | |
| |_| | |_| | |
 \__,_|\__|_|_|

util
*/ #####################################################

  nArgs = args: if isNull args then 0 else length args;
  hyphenate = name: if stringLength name > 1 then "--${name}" else "-${name}";
  safeexit = ''{ return &> /dev/null || exit ; }'';
  reference-commands = import ./metafun-ref.nix ;
  # concatenate nonEmpty strings from the given list
  concatNonEmptySep = sep: xs: concatStringsSep sep (concatMap (s: if s=="" then [] else [s]) xs);
  pnt = v: seq (debug.traceVal (generators.toPretty {} )v) v;

# in { inherit mkCommand mkCommandCompletion reference-commands mkCommandFile mkMetafun mkHelpFile; }
in out.metafun
