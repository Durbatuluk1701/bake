open Printf

let debug_print str =
  Logs.debug (fun m -> m "%s" str)

(**
 * Writes the basis file content of the 'embedded_basis_ffi.c' file to a temporary file
 * and returns the path to that file.
 * The temporary file is automatically cleaned up on process exit.
 *)
let get_basis_file () : string =
  let temp_path = Filename.temp_file "embedded_basis_ffi" ".c" in
  (* Register a cleanup function to delete the file on normal exit. *)
  at_exit (fun () -> try Sys.remove temp_path with _ -> ());
  let out_channel = open_out temp_path in
  try
    output_string out_channel Basis_c_data.content;
    close_out out_channel;
    temp_path
  with e ->
    close_out_noerr out_channel;
    (* Clean up immediately on error *)
    (try Sys.remove temp_path with _ -> ());
    raise e

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
  if not (Sys.file_exists file_path) 
  then Error (sprintf "File '%s' does not exist." file_path)
  else Ok file_path

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
  let c_pattern = "#" in
  debug_print (sprintf "Processing module '%s' with dir='%s', stubs_dir='%s', in_stubs=%b" module_ dir (Option.value ~default:"<none>" stubs_dir) in_stubs);
  if string_starts_with ~prefix:root_pattern module_ then
    (dot_to_slash (String.sub module_ 1 (String.length module_ - 1)) ^ ".cml", false, false)
  else if string_starts_with ~prefix:stub_pattern module_ then
    match stubs_dir with
    | None -> failwith "Stub directory is required for $-modules."
    | Some sdir ->
      (Filename.concat sdir (dot_to_slash (String.sub module_ 1 (String.length module_ - 1))) ^ ".cml", true, false)
  else if string_starts_with ~prefix:c_pattern module_ then
    (* C dependency *)
    (* C dependencies are always presumed to come from the stubs directory *)
    match stubs_dir with
    | None -> failwith "Stub directory is required for #-modules."
    | Some sdir ->
      (* Remove the leading '#' and replace '.' with '/' *)
      (* The module name is expected to be in the form "#ModuleName" *)
      (Filename.concat sdir (dot_to_slash (String.sub module_ 1 (String.length module_ - 1))) ^ ".c", false, true)
    (* (Filename.concat dir (String.sub module_ 1 (String.length module_ - 1) ^ ".c"), false, true) *)
  else
    (Filename.concat dir (dot_to_slash module_) ^ ".cml", false, false)

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
  let c_deps = ref [] in
  let c_deps_set = Hashtbl.create 8 in
  let next_parent_dir = Option.value parent_dir ~default:(Filename.dirname file_path) in
  let add_c_dep cdep =
    if not (Hashtbl.mem c_deps_set cdep) then (
      Hashtbl.add c_deps_set cdep ();
      c_deps := !c_deps @ [cdep]
    )
  in
  List.iter (fun (dep, next_in_stubs, is_c_dep) ->
    if is_c_dep then (
      add_c_dep dep
    ) else if not (List.mem dep seen) && not (List.mem dep !full_deps) then (
      debug_print (sprintf "\tDep: %s was not yet seen" dep);
      let new_deps, new_c_deps = get_trans_deps ~file_path:dep ~seen:(dep :: !full_deps @ seen) ?stubs_dir ~parent_dir:next_parent_dir ~in_stubs:next_in_stubs () in
      full_deps := !full_deps @ new_deps;
      List.iter add_c_dep new_c_deps
    )
  ) deps_with_flags;
  (!full_deps @ [actual_file], !c_deps)

let print_mode out_opt (deps, c_deps) =
  match out_opt with
  | Some out ->
    let oc = open_out out in
    List.iter (fun dep -> output_string oc (dep ^ "\n")) deps;
    List.iter (fun cdep -> output_string oc (cdep ^ "\n")) c_deps;
    close_out oc
  | None ->
    List.iter print_endline deps;
    List.iter print_endline c_deps

let merge_mode out_opt (deps, c_deps) =
  match out_opt with
  | None -> failwith "Output file name (--out <file>) is required in 'merge' and 'build' modes."
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
    (out, c_deps)

let build_mode out_opt (deps, c_deps) ~extra_cc_flags : (unit, string) result = 
  let cc = "cc" in
  let basis_file = get_basis_file () in
  let cc_flags = ref "" in
  let add_flag flag_ref flag =
    match flag with
    | None -> ()
    | Some flag ->
      flag_ref := !flag_ref ^ " " ^ String.trim flag
  in
  add_flag cc_flags (Some "-lm"); (* Default library flag *)
  add_flag cc_flags (Some "-O2"); (* Default optimization level *)
  let env_cc_flags = Sys.getenv_opt "BAKE_CC_FLAGS" in
  (* Compose CLI flags first, then env flags, then default *)
  add_flag cc_flags extra_cc_flags;
  add_flag cc_flags env_cc_flags;
  (* CakeML Flags *)
  let cake_flags = ref "" in
  (* If we are on an arm architecture, add a 
    --target=arm8 flag to CakeML *)
  (match Config.arch with
  | "arm64" -> add_flag cake_flags (Some "--target=arm8")
  | "x86_64" -> add_flag cake_flags (Some "--target=x64")
  | _ -> ());
  let out_file, c_deps = merge_mode out_opt (deps, c_deps) in
  (match Filename.chop_suffix_opt ~suffix:".cml" out_file with
  | None -> Error "Output file must have a .cml suffix."
  | Some out_basename -> 
    (let asm_file = out_basename ^ ".S" in
    let binary_file = out_basename in
    let cake_cmd = sprintf "cake %s < %s > %s" !cake_flags out_file asm_file in
    let cc_cmd = sprintf "%s %s %s %s %s -o %s" cc basis_file (String.concat " " c_deps) asm_file !cc_flags binary_file in
    let run_or_fail cmd err =
      match Sys.command cmd with
      | 0 -> ()
      | _ -> failwith err
    in
    run_or_fail cake_cmd ("Error during CakeML compilation: " ^ cake_cmd);
    run_or_fail cc_cmd ("Error during CC compilation: " ^ cc_cmd);
    Printf.printf "Binary created: %s\n" binary_file;
    Ok ()))

let () =
  (* Initialize logging *)
  Logs.set_reporter (Logs_fmt.reporter ());
  (match Sys.getenv_opt "DEBUG" with
   | Some _ -> Logs.set_level (Some Logs.Debug)
   | None -> Logs.set_level (Some Logs.Error));

  let main_file = ref None in
  (* Default to build *)
  let mode = ref "build" in
  (* Default output to current directory *)
  let out = ref None in
  let stubs = ref None in
  let cc_flags = ref None in
  let speclist = [
    ("--mode", Arg.Symbol (["print"; "merge"; "build"], (fun m -> mode := m)), "Mode of operation: print, merge, build");
    ("--out", Arg.String (fun s -> out := Some s), "Output file name for the monolithic CakeML file");
    ("--stubs", Arg.String (fun s -> stubs := Some s), "Optional folder containing substitute (stub) files");
    ("--cc-flags", Arg.String (fun s -> cc_flags := Some s), "Additional flags to pass to CC (overrides BAKE_CC_FLAGS env var)");
  ] in
  let usage_str = "Usage: bake <main> [--mode print|merge|build] [--out <file>] [--stubs <dir>] [--cc-flags <flags>]" in
  let print_usage () = Arg.usage speclist usage_str in
  (* Anonymous function to handle the main file argument *)
  (* This is required for processing, so it must be provided *)
  (* If not provided, print usage and exit *)
  let anon_fun fname = 
    (* Set the main file, which is required for processing *)
    match validate_file fname with
    | Error msg -> (* Print usage *)
      eprintf "Error: %s\n" msg;
      print_usage ();
      eprintf "Main CakeML file is required.\n";
      exit 1
    | Ok fname -> main_file := Some fname 
  in
  Arg.parse speclist anon_fun usage_str;
  let stubs_dir = match !stubs with Some s -> Some s | None -> Sys.getenv_opt "CAKEML_STUBS" in
  match !main_file with
  | None ->
    eprintf "Main CakeML file is required.\n";
    print_usage ();
    exit 1
  | Some main_file -> 
    let deps, c_deps = get_trans_deps ~file_path:main_file ~seen:[] ?stubs_dir ~in_stubs:false () in
    match !mode with
    | "print" -> print_mode !out (deps, c_deps)
    | "merge" -> ignore (merge_mode !out (deps, c_deps))
    | "build" -> 
      (match build_mode !out (deps, c_deps) ~extra_cc_flags:!cc_flags with
      | Ok () -> ()
      | Error err ->
        eprintf "Build failed: %s\n" err;
        print_endline "";
        print_usage ();
        exit 1)
    | _ -> failwith ("Unknown mode: " ^ !mode)
