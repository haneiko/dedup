let opendir path =
  try Ok (Unix.opendir path)
  with Unix.Unix_error (err, _, arg) ->
    Error (Printf.sprintf "%s: %s\n" (Unix.error_message err) arg)

let readdir dir_handle =
  let rec _readdir list =
    try
      match Unix.readdir dir_handle with
      | "." | ".." -> _readdir list
      | entry -> _readdir (entry :: list)
    with
    | End_of_file ->
        Unix.closedir dir_handle;
        list
    | exn ->
        Unix.closedir dir_handle;
        raise exn
  in
  Ok (_readdir [])

let prepend_path p files = List.map (fun a -> p ^ Filename.dir_sep ^ a) files
let is_directory p = try Sys.is_directory p with Sys_error _ -> false

let list_files path =
  let rec _list_files folders files =
    let path = List.hd folders in
    let flip f a b = f b a in
    let open Result in
    bind (opendir path) readdir
    |> map (prepend_path path)
    |> map (List.partition is_directory)
    |> flip bind (fun (sub_folders, sub_files) ->
           let s = List.tl folders @ sub_folders in
           let f = files @ sub_files in
           if List.length s = 0 then Ok f else _list_files s f)
  in
  match _list_files [ path ] [] with
  | Ok [] -> Error (Printf.sprintf "0 files found in directory \"%s\"\n" path)
  | other -> other

let find_dups files =
  let hash_file a = Digest.to_hex (Digest.file a) in
  let hashes = List.map (fun a -> (a, hash_file a)) files in
  let tb = Hashtbl.create (List.length files) in
  let fold k _ l =
    match Hashtbl.find_all tb k with
    | [] | [ _ ] | "" :: _ -> l
    | dups ->
        (* to avoid repeated keys: *)
        Hashtbl.add tb k "";
        dups :: l
  in
  List.iter (fun (f, h) -> Hashtbl.add tb h f) hashes;
  match Hashtbl.fold fold tb [] with
  | [] -> Error "0 duplicates found in directory"
  | list -> Ok list

let make_tmp_file text =
  try
    let file_name = Filename.temp_file "dedup_" "_files_to_remove" in
    let file = Unix.openfile file_name [ Unix.O_CREAT; Unix.O_WRONLY ] 600 in
    (try ignore (Unix.write_substring file text 0 (String.length text))
     with Unix.Unix_error (err, _, arg) ->
       Printf.printf "%s: %s\n" (Unix.error_message err) arg);
    Unix.close file;
    Ok file_name
  with Unix.Unix_error (err, _, arg) ->
    Error (Printf.sprintf "%s: %s\n" (Unix.error_message err) arg)

let read_tmp_file file_name =
  try
    let file = Unix.openfile file_name [ Unix.O_RDONLY ] 0 in
    let rec read str =
      let size = 1024 in
      let bytes = Bytes.make size '\n' in
      let len = Unix.read file bytes 0 size in
      if len = 0 then str ^ Bytes.sub_string bytes 0 len
      else read (str ^ Bytes.sub_string bytes 0 len)
    in
    try
      let text = read "" in
      Unix.close file;
      Ok text
    with Unix.Unix_error (err, _, arg) ->
      Unix.close file;
      Error (Printf.sprintf "%s: %s\n" (Unix.error_message err) arg)
  with Unix.Unix_error (err, _, arg) ->
    Error (Printf.sprintf "%s: %s\n" (Unix.error_message err) arg)

let join sep list =
  List.fold_left (fun a b -> if a <> "" then a ^ sep ^ b else b) "" list

let call_editor editor file_name =
  match Unix.system (editor ^ " " ^ file_name) with
  | Unix.WSIGNALED v ->
      Error (Printf.sprintf "problem with editor, signaled %d\n" v)
  | Unix.WSTOPPED v ->
      Error (Printf.sprintf "problem with editor, stopped %d\n" v)
  | Unix.WEXITED 0 -> Ok ()
  | Unix.WEXITED v ->
      Error (Printf.sprintf "problem with editor, exited %d\n" v)

let parse_list str =
  String.split_on_char '\n' str
  |> List.map String.trim
  |> List.filter (fun b -> b <> "" && not (String.starts_with ~prefix:"#" b))

let check_editor_var =
  match Sys.getenv_opt "EDITOR" with
  | None | Some "" -> Error "environment variable \"EDITOR\" not set"
  | Some editor -> Ok editor

let remove_last_dir_sep path =
  if String.ends_with ~suffix:Filename.dir_sep path then
    String.sub path 0 (String.length path - String.length Filename.dir_sep)
  else path

let () =
  let ( let* ) o f = match o with Error e -> print_endline e | Ok x -> f x in
  let usage_msg =
    "dedup [-i] [-f] <dir>\n\n\
    \ dedup will recursively search <dir> for duplicated files (with same md5 \
     hash).\n\
    \ With the -i option will open \"EDITOR\" with the list of duplicates found.\n\
    \ Without -i will only output the list.\n\
    \ Duplicates will be grouped together, different files will be separated\n\
    \ by an empty line.\n\
    \ In the editor: all files will be commented out, uncommenting will mark\n\
    \ the file for removal.\n\
    \ Saving then quiting the editor will remove the selected files,\n\
    \ but will only remove if the option -f was provided in the command line.\n"
  in
  let remove = ref false in
  let interactive = ref false in
  let dir = ref "" in
  let anon_fun path = dir := path in
  let speclist =
    [
      ("-i", Arg.Set interactive, "Select files with \"EDITOR\"");
      ("-f", Arg.Set remove, "Remove selected files");
    ]
  in
  Arg.parse speclist anon_fun usage_msg;
  if !dir = "" then (
    Arg.usage speclist usage_msg;
    exit 1);
  let* files = list_files (remove_last_dir_sep !dir) in
  let* dups = find_dups files in
  if not !interactive then
    List.iter
      (fun a ->
        List.iter (fun b -> print_endline b) a;
        print_newline ())
      dups
  else
    let str =
      "# Uncomment the files you want to remove\n"
      ^ "# then save and quit the editor:\n\n"
      ^ join "\n\n"
          (List.map (fun l -> List.map (fun a -> "#" ^ a) l |> join "\n") dups)
    in
    let* file_name = make_tmp_file str in
    let* editor = check_editor_var in
    let* _ = call_editor editor file_name in
    let* text = read_tmp_file file_name in
    let to_remove = parse_list text in
    List.iter
      (fun a ->
        if !remove then (
          Unix.unlink a;
          Printf.printf "removed %s\n" a)
        else Printf.printf "remove? %s\n" a)
      to_remove
