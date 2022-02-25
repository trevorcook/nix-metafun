{lib}: with builtins; with lib;
let

/* #####################################################
           _     ____                                          _
 _ __ ___ | | __/ ___|___  _ __ ___  _ __ ___   __ _ _ __   __| |
| '_ ` _ \| |/ / |   / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |
| | | | | |   <| |__| (_) | | | | | | | | | | | (_| | | | | (_| |
|_| |_| |_|_|\_\\____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|

mkCommand
*/ #####################################################
  mkCommand = command.command;

  command.command = name: cmd_:
    let
      cmd = ingress.command name cmd_ ;
      mkCommandCase = super: cmd_name: cmd:
        let cmdpath = super + " ... " + cmd_name; in
        ''
        ${cmd_name} )
        shift
        ${command.command cmdpath cmd}
        ;;
        '';
    in ''
    ${cmd.preOptHook}
    ${command.option name cmd.opts}
    if ${command.argument-test cmd.args}
      then
      ${cmd.hook}
      ${if cmd.commands == {} then ''
        '' else ''
        shift ${toString (nArgs cmd.args)}
        case "$1" in
          ${concatStrings (mapAttrsToList (mkCommandCase name) cmd.commands)}
          * )
          echo "Command unrecognized."
          echo "${help.usage name cmd}"
          echo "See: ${name} --help"
          ;;
        esac
        ''}
    else
      echo "Argument parse fail."
      echo "${help.usage name cmd}"
      echo "See: ${name} --help."
    fi
    '';


  command.option = name: opts:
    let
      setvars = concatMap (s: if s.set == null then [] else [s.set]) opts;
      preOptHook = if setvars == [] then "" else
        ''declare ${concatStringsSep " " setvars}'';
      mkOptCase = opt: ''
          ${hyphenate opt.name})
            shift
            ${opt.hook}
            ${if isNull opt.arg then "" else "shift"}
          ;;
          '';
      mkGetOpt = opts_ :
        let opts = { long = []; short = [];} //
                    groupBy (getAttr "length") opts_;
            # The '+' below stops parsing at first non-option
            shortopt = ''-o +${if shorts=="" then "''" else shorts }'';
            shorts = concatStrings (map mkOpt opts.short);
            longopt = optionalString (opts.long != []) ''--long ${longs}'';
            longs = concatStringsSep "," (map mkOpt opts.long);
            mkOpt = opt: opt.name + optionalString (opt.arg != null) ":";
        in ''getopt  ${shortopt} ${longopt} -- "$@"'';

    in if opts == [] then "" else ''
  eval set -- "$(${mkGetOpt opts})"
  ${preOptHook}
  while true; do
    case "$1" in
    ${concatStrings (map mkOptCase opts)}
    --)
        shift
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

  help.help = name: cmd: ''
    cat <<'EOF'
    ${concatStrings [
      (help.head name cmd)
      (help.usage name cmd)
      (help.opts cmd.opts)
      (help.commands cmd)
      (help.foot name)
      ]}
    EOF
    ${safeexit}
    '';
  help.head = name: cmd: name + ": " + cmd.desc + "\n\n";
  help.usage = name : cmd:
   let
    opts = if cmd.opts == {} then "" else " [opts]";
    args = mkArgsString cmd.args;
    commands = mkCommandsString cmd.commands;
  in
    ''usage: ${name}${opts}${args}${commands}

    '';
  mkArgsString = args:
    let
      bkt = arg: " <${arg.name}>";
    in if isNull args then ""
       else concatStrings (map bkt args);
  mkCommandsString = commands: if commands == {} then ""
    else " {${concatStringsSep "|" (attrNames commands)}}";

  help.opts = opts: if opts == [] then "" else
    let mkOpt = opt: "  ${hyphenate opt.name} : ${opt.desc}"; in ''
      opts:
      ${concatStringsSep "\n" (map mkOpt opts)}

      '';

  help.commands = cmd:
    let
      commandAttrAbout = name: {desc?"", ...}:
      "  ${name} : ${desc}";
      commandAbout = name: arg:
        if isAttrs arg then
          commandAttrAbout name arg
        else "  ${name} :";
    in if cmd.commands == {} then "" else ''
    commands:
    ${concatStringsSep "\n" (mapAttrsToList commandAbout cmd.commands)}

    '';
  help.foot = name: "";


/* #####################################################
           _     ____                      _      _
 _ __ ___ | | __/ ___|___  _ __ ___  _ __ | | ___| |_ ___
| '_ ` _ \| |/ / |   / _ \| '_ ` _ \| '_ \| |/ _ \ __/ _ \
| | | | | |   <| |__| (_) | | | | | | |_) | |  __/ ||  __/
|_| |_| |_|_|\_\\____\___/|_| |_| |_| .__/|_|\___|\__\___|
                                    |_|
mkComplete: make the command completion function
*/ #####################################################
  mkCommandCompletion = completion.command-COMP_WORDS;

  # Replace input arguments with COMP_WORDS vector and call the handler.
  completion.command-COMP_WORDS  = name: cmd: ''
    for i in $( seq $(( COMP_CWORD + 1 )) ''${#COMP_WORDS[@]} ); do
      unset COMP_WORDS[$i]
    done
    unset COMP_WORDS[0]
    set -- "''${COMP_WORDS[@]}"
    ${completion.command name cmd}
    '';

  #METAFUN Completion Variable
  st = "METAFUN_COMPLETION";
  stV = "$" + st;

  completion.command = name: cmd_:
    let cmd = ingress.command name cmd_;
    in ''
      COMPREPLY=( )
      ${completion.opt cmd.opts}
      ${completion.args cmd.args}
      ${completion.subcommand cmd.commands}
      '';
  completion.opt = opts:
    let
      test.isopt = str: ''[[ -n "''${${str}#-}"]]'';
      opt-args = map (opt: hyphenate opt.name) opts;
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
            ${ concatStrings (map opt-case opts ) }
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




    completion.subcommand = commands:
    let command-case = name: subcommand: ''
    ${name} )
      shift
      ${completion.command name subcommand}
      ;;
    '';
    in ''
    ######################################################
    # Complete cubcommand
    if [[ ${stV} == cmd ]]; then
      if [[ $# == 1 ]]; then
        ${compreply.choice (attrNames commands) "-- $1"}
      else
        case "$1" in
        ${concatStrings (mapAttrsToList command-case commands)}
        * )
          ${st}=exit
        ;;
        esac
      fi
    fi
  '';


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
  ingress.command = name: cmd_ :
    let
      defaults = {
        opts?{}, args?null, hook?":",commands?{}, desc?"", preOptHook?""
        } :
        let opts_ = (ingress.addHelpOptions name out) // opts;
        in {
          inherit hook commands desc preOptHook;
          opts = ingress.opts opts_;
          args = ingress.args args;
        };
      out = if isString cmd_ then defaults { hook = cmd_; }
             else defaults cmd_;
    in out;

  ingress.addHelpOptions = name: attrs:
    let
      opt = {
        desc = "Show this help text.";
        hook = help.help name (recursiveUpdate {opts = out;} attrs);
      };
      out = {
        help = opt;
        h = opt;
      };
    in out;

  ingress.opts = mapAttrsToList ingress.opt;
  ingress.opt = name:
      let
        go = { desc?"", arg?null, hook?":",set?null }: let out = {
          inherit desc set name;
          arg = if isFunction hook && isNull arg then
                  ingress.arg "arg"
                else ingress.arg arg;
          hook = ''
            ${ if isNull set then ""
               else if isNull out.arg then
                 ''declare ${set}=true''
               else ''declare ${set}="$1"''
            }
            ${if isFunction hook then hook {} else hook}
            '';
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

in { inherit mkCommand mkCommandCompletion reference-commands; }
