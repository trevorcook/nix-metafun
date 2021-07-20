{lib, debug?false}: with builtins; with lib;
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
      mkCommandCase = super: cmd: hook:
        let cmdpath = super + " ... " + cmd; in
        ''
        ${cmd} )
        shift
        ${mkCommand cmdpath hook}
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
        ''unset ${concatStringsSep " " setvars}'';
      mkOptCase = opt:
        let hyph = ''-${optionalString (opt.length == "long") "-"}'';
        in ''
          ${hyphenate opt.name})
            ${opt.hook}
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
            mkOpt = opt: opt.name + optionalString opt.argument ":";
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
  shift
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
        if isList arg.type then
          "{ ${concatStringsSep " || " (map isChoice arg.type )}
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
help.help
*/ #####################################################

  help.help = name: arg@{ commands ? {}, desc?"", opts?[], ... } : ''
    cat <<'EOF'
    ${name + ": " + desc}

    ${help.usage name arg}
    opts:
    ${help.opts opts}
    ${if commands == {} then "" else ''

    commands:
    ${concatStringsSep "\n" (mapAttrsToList commandAbout commands)}
    ''}
    See '${name} --help' for specific subcommand.
    EOF
    # Try to return in case is a function, else exit
    return &> /dev/null
    exit
    '';
  help.opts = opts:
   let
     mkOpt = opt: "  ${hyphenate opt.name} : ${opt.desc}";
   in concatStringsSep "\n" (map mkOpt opts);

  commandAttrAbout = name: {desc?"", ...}:
  "  ${name} : ${desc}";
  commandAbout = name: arg:
    if isAttrs arg then
      commandAttrAbout name arg
    else "  ${name} :";
  help.usage = name : { commands?{}, args?[], opts?{}, ... }:
    ''usage: ${name} [opts] ${mkArgsString args}${mkCommandsString commands}
    '';

  mkArgsString = args:
    let
      bkt = arg: ''<${arg.name}> '';
    in if isNull args then " "
       else concatStrings (map bkt args);
  mkCommandsString = commands: if commands == {} then ""
    else ''{${concatStringsSep "|" (attrNames commands)}}'';




/* #####################################################
           _     ____                      _      _
 _ __ ___ | | __/ ___|___  _ __ ___  _ __ | | ___| |_ ___
| '_ ` _ \| |/ / |   / _ \| '_ ` _ \| '_ \| |/ _ \ __/ _ \
| | | | | |   <| |__| (_) | | | | | | |_) | |  __/ ||  __/
|_| |_| |_|_|\_\\____\___/|_| |_| |_| .__/|_|\___|\__\___|
                                    |_|
mkComplete

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
          ${if opt.argument then ''
          shift
          [[ $1 == "=" ]] && shift
          if [[ $# == 1 ]]; then
            COMPREPLY+=( _ ${hyphenate opt.name}_arg{$1} )
            # DoCompletion
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
      arg-case = i: {type,name,hook?"",...}:
        let param= "-- $" + (toString i); in ''
        ${toString i} )
          ${ if isList type then compreply.choice type param
             else if type == "file" then compreply.file "<arg:${name}> _file_" param
             else if type == "dir" then compreply.dir "<arg:${name}> _dir_" param
             else if type == "hook" then compreply.hook hook param
             else compreply.compgen-opts ''-W "<arg:${name}> _"'' param }
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

  safeexit = ''{ return &> /dev/null || exit ; }'';

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

  makeHelpOptions = name: attrs:
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


  # Sanatize inputs for the mkCommand et. al. functions.
  ingress.command = name: cmd_ :
    let
      defaults = {
        opts?{}, args?null, hook?":",commands?{}, desc?"", preOptHook?""
        } :
        let opts_ = (makeHelpOptions name out) // opts;
        in {
          inherit hook commands desc preOptHook;
          opts = ingress.opts opts_;
          args = ingress.args args;
        };
      out = if isString cmd_ then defaults { hook = cmd_; }
             else defaults cmd_;
    in out;

  ingress.opts = mapAttrsToList ingress.opt;
  ingress.opt = name:
      let
        go = { desc?"", argument?false, hook?":",set?null
          }: let out = {
          inherit desc set name;
          argument = isFunction hook || argument || isFunction set;
          hook = ''${doSet out.argument set}
                   ${if isFunction hook then "shift\n" + (hook {}) else hook}
                   '';
          length = if stringLength name > 1 then "long" else "short";
          }; in out;
        doHook = hook: { inherit hook; };
        doSet = argument: var: if isFunction var then
            ''declare ${var {}}="$1"''
          else if argument && isString var then
            ''declare ${var}="$1"''
          else if isString var then
            ''declare ${var}=true''
          else "";
      in arg: go (if isAttrs arg then arg
                  else doHook arg);
  ingress.args = args_ : if isNull args_ then args_ else map ingress.arg args_;
  ingress.arg =
      let
        isSpecialArgType = type: any (n: n == type) ["file" "dir" "hook"];
        go = {name, desc?name, type?null, hook?null}: {
          inherit name desc hook;
          type = if isList type || isSpecialArgType type then type
                 else if !(isNull hook) then "hook"
                 else "other";
          };
      in arg_: go ( if isString arg_ then
            { name = arg_; type = arg_; desc = arg_; }
          else if isList arg_ then
            { name = "choice"; type = arg_; desc = ""; }
          else arg_ );



in { inherit mkCommand mkCommandCompletion; }
