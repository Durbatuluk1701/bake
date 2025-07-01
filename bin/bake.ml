open Printf

let debug_print msg =
  match Sys.getenv_opt "DEBUG" with
  | Some _ -> print_endline msg
  | None -> ()

let stub_suffixes = ["_Stubs.cml"; "_Axioms.cml"]

let is_stub_file file_path =
  List.exists (fun suf -> Filename.check_suffix file_path suf) stub_suffixes

let should_subst file_path stubs_dir =
  let base = Filename.basename file_path in
  if is_stub_file file_path then (
    debug_print (sprintf "File '%s' ends with a stub suffix, checking for substitution." file_path);
    match stubs_dir with
    | None -> failwith (sprintf "Stub directory '%s' is required for substitution." (Option.value ~default:"<none>" stubs_dir))
    | Some dir ->
      let stub_path = Filename.concat dir base in
      if not (Sys.file_exists stub_path) then failwith (sprintf "Stub file '%s' does not exist." stub_path);
      Some stub_path
  ) else None


let validate_file file_path =
  if not (Sys.file_exists file_path) then invalid_arg (sprintf "File '%s' does not exist." file_path);
  try let _ = open_in file_path in file_path with _ -> invalid_arg (sprintf "File '%s' is not readable." file_path)


let string_starts_with ~prefix s =
  let plen = String.length prefix in
  String.length s >= plen && String.sub s 0 plen = prefix

let string_ends_with ~suffix s =
  let slen = String.length suffix in
  let len = String.length s in
  len >= slen && String.sub s (len - slen) slen = suffix

let dot_to_slash s =
  let buf = Bytes.of_string s in
  for i = 0 to Bytes.length buf - 1 do
    if Bytes.get buf i = '.' then Bytes.set buf i '/'
  done;
  Bytes.to_string buf

let post_proc_module ~dir ~module_ ?stubs_dir ~in_stubs () =
  let root_pattern = "@" in
  let stub_pattern = "$" in
  debug_print (sprintf "Processing module '%s' with dir='%s', stubs_dir='%s', in_stubs=%b" module_ dir (Option.value ~default:"<none>" stubs_dir) in_stubs);
  if string_starts_with ~prefix:root_pattern module_ then
    (dot_to_slash (String.sub module_ 1 (String.length module_ - 1)) ^ ".cml", false)
  else if string_starts_with ~prefix:stub_pattern module_ then
    match stubs_dir with
    | None -> failwith "Stub directory is required for $-modules."
    | Some sdir ->
      (Filename.concat sdir (dot_to_slash (String.sub module_ 1 (String.length module_ - 1))) ^ ".cml", true)
  else
    (Filename.concat dir (dot_to_slash module_) ^ ".cml", false)

let get_direct_deps ~file_path ?parent_dir ?stubs_dir ~in_stubs () =
  debug_print (sprintf "Getting direct deps for %s, with parent_dir=%s, stubs_dir=%s and in_stubs=%b" file_path (Option.value ~default:"<none>" parent_dir) (Option.value ~default:"<none>" stubs_dir) in_stubs);
  let ic = open_in file_path in
  let dir = if in_stubs then Option.value parent_dir ~default:(Filename.dirname file_path) else Filename.dirname file_path in
  let first_line =
    try input_line ic |> String.trim with End_of_file -> ""
  in
  close_in ic;
  let pre_line = "(* deps: " in
  let post_line = " *)" in
  if string_starts_with ~prefix:pre_line first_line && string_ends_with ~suffix:post_line first_line then
    let module_snip = String.sub first_line (String.length pre_line) (String.length first_line - String.length pre_line - String.length post_line) |> String.trim in
    let modules = String.split_on_char ' ' module_snip |> List.filter (fun s -> s <> "") in
    List.map (fun mod_ -> post_proc_module ~dir ~module_:mod_ ?stubs_dir ~in_stubs ()) modules
  else []

let rec get_trans_deps ~file_path ~seen ?stubs_dir ?parent_dir ~in_stubs () =
  let subst = should_subst file_path stubs_dir in
  let actual_file = match subst with Some s -> s | None -> file_path in
  let in_stubs = in_stubs || Option.is_some subst in
  let deps_with_flags = get_direct_deps ~file_path:actual_file ?parent_dir ?stubs_dir ~in_stubs () in
  let full_deps = ref [] in
  let next_parent_dir = Option.value parent_dir ~default:(Filename.dirname file_path) in
  List.iter (fun (dep, next_in_stubs) ->
    if not (List.mem dep seen) && not (List.mem dep !full_deps) then (
      debug_print (sprintf "\tDep: %s was not yet seen" dep);
      let new_deps = get_trans_deps ~file_path:dep ~seen:(dep :: !full_deps @ seen) ?stubs_dir ~parent_dir:next_parent_dir ~in_stubs:next_in_stubs () in
      full_deps := !full_deps @ new_deps
    )
  ) deps_with_flags;
  !full_deps @ [actual_file]

let print_mode out_opt deps =
  match out_opt with
  | Some out ->
    let oc = open_out out in
    List.iter (fun dep -> output_string oc (dep ^ "\n")) deps;
    close_out oc
  | None ->
    List.iter print_endline deps

let merge_mode out_opt deps =
  match out_opt with
  | None -> failwith "Output file name (--out <file>) is required in 'merge' mode."
  | Some out ->
    let oc = open_out out in
    List.iter (fun dep ->
      let ic = open_in dep in
      try
        while true do
          output_string oc (input_line ic ^ "\n")
        done
      with End_of_file -> close_in ic; output_string oc "\n\n"
    ) deps;
    close_out oc;
    out

let build_mode out_opt deps =
  let cc = "gcc" in
  let basis_dir = Filename.dirname (Sys.executable_name) in
  let basis_file = Filename.concat basis_dir "basis_ffi.c" in
  let cc_flags = "-O2 -lm" in
  let out_file = merge_mode out_opt deps in
  let asm_file = Filename.chop_suffix out_file ".cml" ^ ".S" in
  let binary_file = Filename.chop_suffix out_file ".cml" in
  let cake_cmd = sprintf "cake < %s > %s" out_file asm_file in
  let gcc_cmd = sprintf "%s %s %s %s -o %s" cc basis_file asm_file cc_flags binary_file in
  let run_or_fail cmd err =
    match Sys.command cmd with
    | 0 -> ()
    | _ -> failwith err
  in
  run_or_fail cake_cmd ("Error during CakeML compilation: " ^ cake_cmd);
  run_or_fail gcc_cmd ("Error during GCC compilation: " ^ gcc_cmd);
  Printf.printf "Binary created: %s\n" binary_file

let () =
  let main_file = ref "" in
  let mode = ref "print" in
  let out = ref None in
  let stubs = ref None in
  let speclist = [
    ("--mode", Arg.Symbol (["print"; "merge"; "build"], (fun m -> mode := m)), "Mode of operation: print, merge, build");
    ("--out", Arg.String (fun s -> out := Some s), "Output file name for the monolithic CakeML file");
    ("--stubs", Arg.String (fun s -> stubs := Some s), "Optional folder containing substitute (stub) files");
  ] in
  let anon_fun fname = main_file := fname in
  Arg.parse speclist anon_fun "Usage: bake <main> [--mode print|merge|build] [--out <file>] [--stubs <dir>]";
  main_file := validate_file !main_file;
  if !main_file = "" then (eprintf "Main CakeML file is required.\n"; exit 1);
  let stubs_dir = match !stubs with Some s -> Some s | None -> Sys.getenv_opt "CAKEML_STUBS" in
  let deps = get_trans_deps ~file_path:!main_file ~seen:[] ?stubs_dir ~in_stubs:false () in
  match !mode with
  | "print" -> print_mode !out deps
  | "merge" -> ignore (merge_mode !out deps)
  | "build" -> build_mode !out deps
  | _ -> failwith ("Unknown mode: " ^ !mode)
