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
  mkCommand-withComplete = name: cmd_: ''
    if [[ $1 != _complete ]]; then
      ${mkCommand name cmd_ }
    else
      ${mkCommandCompletion name cmd_}
    fi
    '';

  mkCommand = name: cmd_:
    let
      cmd = preprocCommand cmd_;
      helpopts = makeHelpOptions name cmd;
    in ''
    ${if !debug then "" else
        mkShowArgs "args" ''"$@"'' + ''
        echo "mkAttrCommand: ${name} $args"
        ''
      }
    #''${cmd.preOptHook}
    ${mkOptionHandler name false (helpopts // cmd.opts)}
    if ${mkArgumentsTest cmd.args}
      then
      ${cmd.hook}
      ${if cmd.commands == {} then ''
        '' else ''
        shift ${toString (nArgs cmd.args)}
        case "$1" in
          ${concatStrings (mapAttrsToList (mkCommandCase name) cmd.commands)}
          * )
          echo "Command unrecognized."
          echo "${mkUsage name cmd}"
          echo "See: ${name} --help"
          ;;
        esac
        ''}
    else
      echo "Argument parse fail."
      echo "${mkUsage name cmd}"
      echo "See: ${name} --help."
    fi
    '';


  mkOptionHandler = name: nofail: opts_:
    let
      opts = ingress.opts opts_;
      setvars = concatMap (s: if s.set == null then [] else [s.set]) opts;
      preOptHook = if setvars == [] then "" else
        ''unset ${concatStringsSep " " setvars}'';
    in if opts == [] then "" else ''
  eval set -- "$(${mkGetOpt nofail opts})"
  ${if !debug then "" else
      mkShowArgs "args" ''"$@"'' + ''
      echo "postOpt parse: ${name} $args"
      ''
  }
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
  mkGetOpt = nofail: opts_ :
    let opts = { long = []; short = [];} //
                groupBy (getAttr "length") opts_;
        # The '+' below stops parsing at first non-option
        shortopt = ''-o +${if shorts=="" then "''" else shorts }'';
        shorts = concatStrings (map mkOpt opts.short);
        longopt = optionalString (opts.long != []) ''--long ${longs}'';
        longs = concatStringsSep "," (map mkOpt opts.long);
        mkOpt = opt: opt.name + optionalString opt.argument ":";
        silent = if nofail then "-q" else "";
    in ''getopt ${silent} ${shortopt} ${longopt} -- "$@"'';
  mkOptCase = opt:
    let hyph = ''-${optionalString (opt.length == "long") "-"}'';
    in ''
      ${hyph+opt.name})
        ${opt.hook}
      ;;
      '';

  mkArgumentsTest = args_:
    let
      args = preprocArgs args_ ;
      argLenTest = "(( $# >= ${toString (length args)} ))";
    in if isNull args then "true" else ''
      { ${argLenTest} ${concatStrings (imap1 andArgTest args)}
      }
    '';
  mkCommandCase = super: cmd: hook:
    let cmdpath = super + " ... " + cmd; in
    ''
    ${cmd} )
    shift
    ${mkCommand cmdpath hook}
    ;;
    '';


/* #####################################################
           _    _   _      _
 _ __ ___ | | _| | | | ___| |_ __
| '_ ` _ \| |/ / |_| |/ _ \ | '_ \
| | | | | |   <|  _  |  __/ | |_) |
|_| |_| |_|_|\_\_| |_|\___|_| .__/
                            |_|
mkHelp
*/ #####################################################

  mkHelp = name: arg@{ commands ? {}, desc?"", opts?{}, ... } : ''
    cat <<'EOF'
    ${name + ": " + desc}

    ${mkUsage name arg}
    opts:
    ${mkOptsHelp opts}
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
  mkOptsHelp = opts_:
   let
     opts = ingress.opts opts_;
     hyph = opt: ''-${optionalString (opt.length == "long") "-"}'';
     mk = opt: "  ${(hyph opt) + opt.name} : ${opt.desc}";
   in concatStringsSep "\n" (map mk opts);

  commandAttrAbout = name: {desc?"", ...}:
  "  ${name} : ${desc}";
  commandAbout = name: arg:
    if isAttrs arg then
      commandAttrAbout name arg
    else "  ${name} :";
  mkUsage = name : { commands?{}, args?[], opts?{}, ... }:
    ''usage: ${name} [opts] ${mkArgsString args}${mkCommandsString commands}
    '';





/* #####################################################
           _     ____                      _      _
 _ __ ___ | | __/ ___|___  _ __ ___  _ __ | | ___| |_ ___
| '_ ` _ \| |/ / |   / _ \| '_ ` _ \| '_ \| |/ _ \ __/ _ \
| | | | | |   <| |__| (_) | | | | | | |_) | |  __/ ||  __/
|_| |_| |_|_|\_\\____\___/|_| |_| |_| .__/|_|\___|\__\___|
                                    |_|
mkComplete

*/ #####################################################
  mkCommandCompletion = handler.completion.command-COMP_WORDS;

  # Replace input arguments with COMP_WORDS vector and call the handler.
  handler.completion.command-COMP_WORDS  = name: cmd: ''
    for i in $( seq $(( COMP_CWORD + 1 )) ''${#COMP_WORDS[@]} ); do
      unset COMP_WORDS[$i]
    done
    unset COMP_WORDS[0]
    set -- "''${COMP_WORDS[@]}"
    ${handler.completion.command name cmd}
    '';

  #METAFUN Completion Variable
  st = "METAFUN_COMPLETION";
  stV = "$" + st;

  handler.completion.command = name: cmd_:
    let cmd = ingress.command cmd_;
    in ''
      COMPREPLY=( )
      ${handler.completion.opt cmd}
      ${handler.completion.args cmd}
      ${handler.completion.subcommand cmd}
      '';
  handler.completion.opt = cmd@{opts,...}:
    let
      test.isopt = str: ''[[ -n "''${${str}#-}"]]'';
      mkOptArg = opt:
        let hyph = ''-${optionalString (opt.length == "long") "-"}'';
        in hyph + opt.name;
      opt-args = map mkOptArg opts;
      opt-case = opt: ''
        ${mkOptArg opt})
          COMPREPLY=( )
          ${if opt.argument then ''
          shift
          [[ $1 == "=" ]] && shift
          if [[ $# == 1 ]]; then
            COMPREPLY+=( _ ${mkOptArg opt}_arg{$1} )
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

  handler.completion.args = cmd:
    let
      nArgs = if isNull cmd.args then 0 else length cmd.args;
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
    in if nArgs == 0 then
      ''${st}=cmd
      ''
    else ''
    ############################################
    ## parse args. If params are args, complete
    ## and exit. Else, shift out arguments and
    ## complete subcommand.
    if [[ ${stV} == args ]]; then
      ${st}=exit
      case "$#" in
      ${ concatStrings (imap1 arg-case cmd.args ) }
      *)
        shift ${toString nArgs}
        ${st}=cmd
        ;;
      esac
    fi
    '';
    handler.completion.subcommand = cmd:
    let command-case = name: subcommand: ''
    ${name} )
      shift
      ${handler.completion.command name subcommand}
      ;;
    '';
    in ''
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


  /* mkAttrCommandCompletion = name:
    arg@{ opts?{}, args?[], hook?"", commands?{}, desc?""}: ''
    ${mkClearOptions name opts}
    if (( $# <= ${toString (nArgs args)} )); then
      ${mkCompleteArgs args}
    else
      shift ${toString (nArgs args)}
      # (( COMP_CWORD-=${toString (nArgs args)} ))
      ${mkCompleteCommands commands}
    fi
    ''; */
  /* mkClearOptions  = name: opts_:
    let opts = mapAttrs mkNoOpt opts_;
        mkHook = v: if isFunction v then
            {}:": #  (( COMP_CWORD-=2 ))"
          else
            " : # (( COMP_CWORD-=1 ))";
        mkNoOpt = k: v: if isAttrs v then
            v // { hook = mkHook v.hook; }
          else
            mkHook v;
    in mkOptionHandler name true opts; */
  /* mkCompleteArgs = args_ :
    let args = preprocArgs args_;
    in ''
    case "$#" in
    ${concatStrings (imap1 mkCompleteArgCase args )}
    *)
        ;;
    esac
    ''; */
  /* mkCompleteArgCase = i: {type,name,hook?"",...}:
    let
      repChoice = ''
        COMPREPLY=( $(compgen -W "${concatStringsSep " " type}" "${ "$" + toString i}") )
          '';
      repArgOpt = opt: ''
        COMPREPLY=( $(compgen ${opt} -W "_arg_ <${name}>" "${ "$" + toString i}") )
          '';
      repArgHook = ''
        COMPREPLY=( $(compgen -W "$( ${hook} )" "${ "$" + toString i}") )
                    '';

      repArg = repArgOpt "";
      repDir = repArgOpt "-d";
      repFile = repArgOpt "-f";
    in ''
      ${toString i} )
        ${ if isList type then repChoice
           else if type == "file" then repFile
           else if type == "dir" then repDir
           else if type == "hook" then repArgHook
           else repArg }
        ${mkAddCOMPREPLY_info "ARG_CASE" name}
        ;;
      ''; */

  /* mkCompleteCommands = commands:
    let cmds = attrNamesString commands;
    in ''
      if [[ $# == 1 ]]; then
        COMPREPLY=( $(compgen -W "${cmds}" "$1") )
        ${mkAddCOMPREPLY_info "AT_CMD" cmds}
      else
        case "$1" in
        ${concatStrings (mapAttrsToList mkCompleteCommandCase commands)}
        * )
          COMPREPLY=( )
          ${mkAddCOMPREPLY_info "NO_CMD_CASE" cmds}
        ;;
        esac
      fi
    ''; */
  /* mkCompleteCommandCase = name: val: ''
    ${name} )
      shift
      ${mkCommandCompletion_ name val}
      ;;
    ''; */


/* #####################################################
       _   _ _
 _   _| |_(_) |
| | | | __| | |
| |_| | |_| | |
 \__,_|\__|_|_|

util
*/ #####################################################
  mkArgsString = args_:
    let
      args = preprocArgs args_;
      bkt = arg: ''<${arg.name}> '';
    in if isNull args then " "
       else concatStrings (map bkt args);
  mkCommandsString = commands: if commands == {} then ""
    else ''{${concatStringsSep "|" (attrNames commands)}}'';
  attrNamesString = attrs: concatStringsSep " " (attrNames attrs);

  mkAddCOMPREPLY_info = desc: comps: if !debug then "" else ''
    ${mkShowArgs "args" ''"$@"''}
    ${mkShowArgs "compwords" ''"''${COMP_WORDS[@]}"''}
    ${mkShowArgs "compgen" ''''$(compgen -W "${comps}" "$1")''}
    COMPREPLY_INFO=( $args $compgen $compwords CWORD:$COMP_CWORD ${desc} n:$# )
    COMPREPLY+=( "''${COMPREPLY_INFO[@]}" )
    '';

  mkShowArgs = var: args: ''
    ${var}="${var}:"
    for arg in ${args}; do
      ${var}="${"$" + var}{$arg}"
      done
    '';
  nArgs = args: if isNull args then 0
                  else if isAttrs args then length (attrNames args)
                  else length args;

  /* preprocCommand = arg:
    let
      toCmd = {
        opts?{}, args?null, hook?"",commands?{}, desc?""
        preOptHook?""
      } : {
        inherit opts args hook commands desc
          preOptHook;
      };
    in
    if isString arg then toCmd { hook = arg; }
    else toCmd arg; */

  makeHelpOptions = name: attrs:
    let
      opt = {
        desc = "Show this help text.";
        hook = mkHelp name (recursiveUpdate {opts = out;} attrs);
      };
      out = {
        help = opt;
        h = opt;
      };
    in out;


  # args is expected to be a list that can be converted to argtype
  # argtype = {name, desc, type}
  /* preprocArgs  = args: if isNull args then args else map preprocArg args;
  preprocArg =
    let
      isSpecialArgType = type: any (n: n == type) ["file" "dir" "hook"];
      setType = {name, desc?name, type?null, hook?null}: {
        inherit name desc hook;
        type = if isList type || isSpecialArgType type then type
               else if !(isNull hook) then "hook"
               else "other";
        };
      mkAttrs = arg :
        if isString arg then
          { name = arg; type = arg; desc = arg; }
        else if isList arg then
          { name = "choice"; type = arg; desc = ""; }
        else arg;
      in arg: setType ( mkAttrs arg ); */
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


  # Sanatize inputs for the mkCommand et. al. functions.
  ingress.command = cmd_ :
    let
      defaults = {
        opts?{}, args?null, hook?":",commands?{}, desc?"" preOptHook?""
        } : {
          inherit hook commands desc preOptHook;
          opts = ingress.opts opts;
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



in { inherit mkCommand mkCommand-withComplete mkCommandCompletion; }
