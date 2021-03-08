{lib}: with builtins; with lib;
let
  debug = false;
  # NOTE:

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
    let cmd = preprocCommand cmd_; in  ''
    ${if !debug then "" else
        mkShowArgs "args" ''"$@"'' + ''
        echo "mkAttrCommand: ${name} $args"
        ''
      }
    ${mkOptionHandler false cmd.opts}
    if [[ $1 == help ]]; then
      ${mkHelp name cmd}
    elif ${mkArgumentsTest cmd.args}
      then
      ${cmd.hook}
      ${if cmd.commands == {} then ''
        '' else ''
        shift ${toString (nArgs cmd.args)}
        case "$1" in
          ${concatStrings (mapAttrsToList (mkCommandCase name) cmd.commands)}
          * )
          echo "${mkUsage name cmd}"
          ;;
        esac
        ''}
    else
      echo "Argument parse fail"
      echo "${mkUsage name cmd}"
    fi
    '';

  mkOptionHandler = nofail: opts_:
    let
      opts = mapAttrsToList preprocOpt opts_;
    in if opts == [] then "" else ''
  eval set -- "$(${mkGetOpt nofail opts})"
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

  mkArgumentsTest_ = args:
    if isList args then
      ''(( $# >= ${toString (length args)} ))''
    else
      "true" ;
  mkArgumentsTest = args_:
    let
      args = preprocArgs args_ ;
      argLenTest = "(( $# >= ${toString (length args)} ))";
    in if isNull args then "true" else ''
      { ${argLenTest} && \
        ${concatStringsSep "&& \\\n" (imap1 argTest args)}
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

    commands:
    ${concatStrings (mapAttrsToList commandAbout commands)}
    EOF
    '';
  mkOptsHelp = opts_:
   let
     opts = mapAttrsToList preprocOpt opts_;
     hyph = opt: ''-${optionalString (opt.length == "long") "-"}'';
     mk = opt: "  ${(hyph opt) + opt.name} : ${opt.desc}";
   in concatStringsSep "\n" (map mk opts);

  commandAttrAbout = name: {desc?"", ...}:
  "  ${name} : ${desc}\n";
  commandAbout = name: arg:
    if isAttrs arg then
      commandAttrAbout name arg
    else "  ${name} :\n";
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
  mkCommandCompletion = name: def: ''
    for i in $( seq $(( COMP_CWORD + 1 )) ''${#COMP_WORDS[@]} ); do
      unset COMP_WORDS[$i]
    done
    unset COMP_WORDS[0]
    set -- "''${COMP_WORDS[@]}"
    ${mkCommandCompletion_ name def}
    '';

  mkCommandCompletion_ = name: def:
    if isAttrs def then
      mkAttrCommandCompletion name def
    else mkAttrCommandCompletion name { hook = def; };
  mkAttrCommandCompletion = name:
    arg@{ opts?{}, args?[], hook?"", commands?{}, desc?""}: ''
    ${mkClearOptions opts}
    if (( $# <= ${toString (nArgs args)} )); then
      ${mkCompleteArgs args}
    else
      shift ${toString (nArgs args)}
      # (( COMP_CWORD-=${toString (nArgs args)} ))
      ${mkCompleteCommands commands}
    fi
    '';
  mkClearOptions  = opts_:
    let opts = mapAttrs mkNoOpt opts_;
        mkHook = v: if isFunction v then
            {}:": #  (( COMP_CWORD-=2 ))"
          else
            " : # (( COMP_CWORD-=1 ))";
        mkNoOpt = k: v: if isAttrs v then
            v // { hook = mkHook v.hook; }
          else
            mkHook v;
    in mkOptionHandler true opts;
  mkCompleteArgs = args_ :
    let args = preprocArgs args_;
    in ''
    case "$#" in
    ${concatStrings (imap1 mkCompleteArgCase args )}
    *)
        ;;
    esac
    '';
  mkCompleteArgCase = i: {type,name,...}:
    let
      repChoice = ''
        COMPREPLY=( $(compgen -W "${concatStringsSep " " type}" "${ "$" + toString i}") )
          '';
      repArgOpt = opt: ''
        COMPREPLY=( $(compgen ${opt} -W "_arg_ <${name}>" "${ "$" + toString i}") )
          '';
      repArg = repArgOpt "";
      repDir = repArgOpt "-d";
      repFile = repArgOpt "-f";
    in ''
      ${toString i} )
        ${ if isList type then repChoice
           else if type == "file" then repFile
           else if type == "dir" then repDir
           else repArg }
        ${mkAddCOMPREPLY_info "ARG_CASE" name}
        ;;
      '';

  mkCompleteCommands = commands:
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
    '';
  mkCompleteCommandCase = name: val: ''
    ${name} )
      shift
      ${mkCommandCompletion_ name val}
      ;;
    '';


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

  preprocCommand = arg:
    let cmd1 = {opts?{}, args?null, hook?"",commands?{}, desc?""} :
          { inherit opts args hook commands desc; }; in
    if isString arg then cmd1 { hook = arg; }
    else cmd1 arg;
  # args is expected to be a list that can be converted to argtype
  # argtype = {name, desc, type}
  preprocArgs  = args: if isNull args then args else map preprocArg args;
  preprocArg =
    let
      isSpecialArgType = type: any (n: n == type) ["file" "dir"];
      setType = {name, desc?name, type}: {
        inherit name desc;
        type = if isList type || isSpecialArgType type then type
               else "other";
        };
      mkAttrs = arg :
        if isString arg then
          { name = arg; type = arg; desc = arg; }
        else if isList arg then
          { name = "choice"; type = arg; desc = ""; }
        else arg;
      in arg: setType ( mkAttrs arg );
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


  # opts is expected to be an attribute set of opttype, or a list of opts
  # opttype = {}
  preprocOpts = opts: if isAttrs opts then
      mapAttrsToList preprocOpt opts
    else if isList opts then
      concatMap preprocOpts opts
    else [];
  preprocOpt = k: v:
    let
      hook_ = if isAttrs v && hasAttr "hook" v then v.hook else v;
      desc = if isAttrs v && hasAttr "desc" v then v.desc else "";
    in
  rec {
    inherit desc;
    name = k;
    length = if stringLength k > 1 then "long" else "short";
    argument = isFunction hook_;
    hook = if argument then
        ''shift
        '' + (hook_ {})
      else
        hook_;
    };





in { inherit mkCommand mkCommand-withComplete mkCommandCompletion; }
