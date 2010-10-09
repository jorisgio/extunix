(**
  New toplevel statement (structure item): HAVE <uident> <structure_items> END
  if (Config.have "<uident>") is true then enclosed structure items are left as is,
  otherwise:
    if -gen-all was specified then external structure items are rewritten to raise exception when called,
    otherwise they are dropped altogether
*)

module Have(Syntax : Camlp4.Sig.Camlp4Syntax) =
struct
  open Camlp4.PreCast 

  include Syntax

  let all = ref false
  let verbose = ref false

  let rec make_dummy_f body = function
  | <:ctyp@loc< $Ast.TyLab (_,s,t)$ -> $tl$ >> -> <:expr@loc< fun ~ $s$:(_:$t$) -> $make_dummy_f body tl$ >>
  | <:ctyp@loc< $t$ -> $tl$ >> -> <:expr@loc< fun (_:$t$) -> $make_dummy_f body tl$ >>
  | <:ctyp< $t$ >> -> let loc = Loc.ghost in <:expr@loc< ($body$ : $t$) >>

  let invalid_external = function
  | <:str_item@_loc< external $i$ : $t$ = $sl$ >> ->
      <:str_item< value $lid:i$ = $make_dummy_f <:expr< raise (Not_available $str:i$) >> t$; >>
  | e -> e

  let invalid_external e = (Ast.map_str_item invalid_external)#str_item e

  let show name s = if !verbose then Printf.eprintf "%-20s %s\n%!" name s

  EXTEND Gram
    GLOBAL: str_item;
    str_item:
      [ [ "HAVE"; name=UIDENT; si=str_items; "END" ->
          match Config.have name, !all with
          | Some true, _ -> show name "ok"; si
          | Some false, true -> show name "rewrite"; invalid_external <:str_item< $si$ >>
          | Some false, false -> show name "drop"; <:str_item<>>
          | None, _ -> failwith ("Unregistered feature : " ^ name)
      ] ]
    ;
  END

  ;;

  Camlp4.Options.add "-gen-all" (Arg.Set all) " generate values from all HAVE sections";;
  Camlp4.Options.add "-gen-verbose" (Arg.Set verbose) " verbose mode";;

end

module Id = struct
let version = "0"
let name = "Have"
end

module M = Camlp4.Register.OCamlSyntaxExtension(Id)(Have)

