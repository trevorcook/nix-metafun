{lib}: with builtins; with lib;
let
  debug = false;
  # NOTE:
  # - Longopts will not tab correctly if argument is given with "=".
  #   This is from a mismatch in COMP_CWORD before and after getopt.
  #   Resultingly (( COMP_CWORD-=2 )) takes one too many off.

/* #####################################################
           _     ____                                          _
 _ __ ___ | | __/ ___|___  _ __ ___  _ __ ___   __ _ _ __   __| |
| '_ ` _ \| |/ / |   / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |
| | | | | |   <| |__| (_) | | | | | | | | | | | (_| | | | | (_| |
|_| |_| |_|_|\_\\____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|

mkCommand
*/ #####################################################
  mkCommand = name: x:
    if isAttrs x then
      mkAttrCommand name x
    else x;
  mkAttrCommand = name: arg@{ opts?{}, args?[], hook?"", commands?{}
                            , desc?""}: ''
    ${if !debug then "" else
        mkShowArgs "args" ''"$@"'' + ''
        echo "mkAttrCommand: ${name} $args"
        ''
    }
    ${mkOptionHandler opts}
    if [[ $1 == help ]]; then
      ${mkHelp name arg}
    elif ${mkArgumentsTest args} ; then
      ${hook}
      ${if commands == {} then ''
        '' else ''
        shift ${toString (nArgs args)}
        case "$1" in
          ${concatStrings (mapAttrsToList (mkCommandCase name) commands)}
          * )
          echo "${mkUsage name arg}"
          ;;
        esac
        ''}
    else
      echo "${mkUsage name arg}"
    fi
    '';

  mkOptionHandler = opts_:
    let
      opts = mapAttrsToList preprocOpt opts_;
    in if opts == [] then "" else ''
  eval set -- "$(${mkGetOpt opts})"
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
  mkGetOpt = opts_ :
    let opts = { long = []; short = [];} //
                groupBy (getAttr "length") opts_;
        # The '+' below stops parsing at first non-option
        shortopt = ''-o +${if shorts=="" then "''" else shorts }'';
        shorts = concatStrings (map mkOpt opts.short);
        longopt = optionalString (opts.long != []) ''--long ${longs}'';
        longs = concatStringsSep "," (map mkOpt opts.long);
        mkOpt = opt: opt.name + optionalString opt.argument ":";
    in ''getopt ${shortopt} ${longopt} -- "$@"'';
  mkOptCase = opt:
    let hyph = ''-${optionalString (opt.length == "long") "-"}'';
    in ''
      ${hyph+opt.name})
        ${opt.hook}
      ;;
      '';

  mkArgumentsTest = args:
    if isList args then
      ''(( $# >= ${toString (length args)} ))''
    else
      "true" ;
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
    eval set -- "''${COMP_WORDS[@]}"
    shift
    ${mkCommandCompletion_ name def}
    '';

  mkCommandCompletion_ = name: def:
    if isAttrs def then
      mkAttrCommandCompletion name def
    else mkAttrCommandCompletion name { hook = def; };
  mkAttrCommandCompletion = name:
    arg@{ opts?{}, args?[], hook?"", commands?{}, desc?""}: ''
    ${mkClearOptions opts}
    if (( $COMP_CWORD > 0 )); then
      if (( $COMP_CWORD <= ${toString (nArgs args)} )); then
        ${mkCompleteArgs args}
      else
        shift ${toString (nArgs args)}
        (( COMP_CWORD-=${toString (nArgs args)} ))
        ${mkCompleteCommands commands}
      fi
    else
      COMPREPLY=( )
      ${mkAddCOMPREPLY_info "NegCWORD" ""}

    fi
    '';
  mkClearOptions  = opts_:
    let opts = mapAttrs mkNoOpt opts_;
        mkHook = v: if isFunction v then
            {}:"  (( COMP_CWORD-=2 ))"
          else
            "  (( COMP_CWORD-=1 ))";
        mkNoOpt = k: v: if isAttrs v then
            v // { hook = mkHook v.hook; }
          else
            mkHook v;
    in mkOptionHandler opts;
  mkCompleteArgs = args_ :
    let args = if isNull args_ then [] else args_;
    in ''
    case "$COMP_CWORD" in
    ${concatStrings (imap1 mkCompleteArgCase args )}
    *)
        ;;
    esac
    '';
  mkCompleteArgCase = i: arg:
    let
      repArgOpt = opt: ''
        COMPREPLY=( $(compgen ${opt} -W "_arg_ <${arg}>" "${ "$" + toString i}") )
          '';
      repArg = repArgOpt "";
      repDir = repArgOpt "-d";
      repFile = repArgOpt "-f";
    in ''
      ${toString i} )
        ${ if arg == "file" then repFile
             else if arg == "dir" then repDir
             else repArg }
        ${mkAddCOMPREPLY_info "ARG_CASE" arg}
        ;;
      '';

  mkCompleteCommands = commands:
    let cmds = attrNamesString commands;
    in ''
      if [[ $COMP_CWORD == 1 ]]; then
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
      (( COMP_CWORD-=1 ))
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
  mkArgsString = args:
    let bkt = str: ''<${str}> '';
        bktK = k: v: bkt k;
    in if isList args then concatStrings (map bkt args)
      else if isAttrs args then concatStrings (mapAttrsToList bktK args)
      else "";
  mkCommandsString = commands: if commands == {} then ""
    else ''{${concatStringsSep "|" (attrNames commands)}}'';
  attrNamesString = attrs: concatStringsSep " " (attrNames attrs);

  mkAddCOMPREPLY_info = desc: comps: if !debug then "" else ''
    ${mkShowArgs "args" ''"$@"''}
    ${mkShowArgs "compgen" ''''$(compgen -W "${comps}" "$1")''}
    COMPREPLY_INFO=( $args $compgen CWORD:$COMP_CWORD ${desc} )
    COMPREPLY+=( "''${COMPREPLY_INFO[@]}" )
    '';

  mkShowArgs = var: args: ''
    ${var}=${var}
    for arg in ${args}; do
      ${var}="${"$" + var}:$arg"
      done
    '';
  nArgs = args: if isNull args then 0
                  else if isAttrs args then length (attrNames args)
                  else length args;

  # args is expected to be a list that can be converted to argtype
  # argtype = {name, desc, type}
  preprocArgs  = map preprocArg;
  preprocArg =  arg:
    let specialArgType = str: any (n: n == arg) ["file" "dir"]; in
    if isString arg then
      if specialArgType then
        { name = arg; type = arg; desc = arg; }
        else { name = arg; type = "other"; desc = arg; }
      else if isAttrs arg then
        ({name,desc?name,type}: {inherit name desc type;}) arg
      else { name = "unknown"; type = "other"; desc = "unknown"; };

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





in { inherit mkCommand mkCommandCompletion; }
