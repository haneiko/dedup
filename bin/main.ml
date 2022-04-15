let opendir path =
  try Some (Unix.opendir path)
  with Unix.Unix_error (err, _, arg) ->
    Printf.printf "%s: %s\n" (Unix.error_message err) arg;
    None

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
  Some (_readdir [])

let prepend_path p files = List.map (fun a -> p ^ Filename.dir_sep ^ a) files
let is_directory p = try Sys.is_directory p with Sys_error _ -> false

let rec list_files path =
  let ( let* ) o f = match o with None -> [] | Some x -> f x in
  let* dir = opendir path in
  let* content = readdir dir in
  let file_list = prepend_path path content in
  let folders, files = List.partition is_directory file_list in
  let subs = List.map list_files folders in
  List.fold_left List.append files subs

let find_dups files =
  let hash_file a = Digest.to_hex (Digest.file a) in
  let hashes = List.map hash_file files in
  let tb = Hashtbl.create (List.length files) in
  let fold k _ l =
    match Hashtbl.find_all tb k with
    | [] | [ _ ] | "" :: _ -> l
    | dups ->
        (* to avoid repeated keys: *)
        Hashtbl.add tb k "";
        dups :: l
  in
  List.iter2 (fun f h -> Hashtbl.add tb h f) files hashes;
  Hashtbl.fold fold tb []

let make_tmp_file text =
  try
    let file_name = Filename.temp_file "dedup_" "_files_to_remove" in
    let file = Unix.openfile file_name [ Unix.O_CREAT; Unix.O_WRONLY ] 600 in
    (try ignore (Unix.write_substring file text 0 (String.length text))
     with Unix.Unix_error (err, _, arg) ->
       Printf.printf "%s: %s\n" (Unix.error_message err) arg);
    Unix.close file;
    Some file_name
  with Unix.Unix_error (err, _, arg) ->
    Printf.printf "%s: %s\n" (Unix.error_message err) arg;
    None

let join sep list =
  List.fold_left (fun a b -> if a <> "" then a ^ sep ^ b else b) "" list

let () =
  match Sys.getenv_opt "EDITOR" with
  | None -> print_endline "environment variable \"EDITOR\" not set"
  | Some editor -> (
      let files = list_files "." in
      let dups = find_dups files in
      let str =
        "# Uncomment the files you want to remove\n"
        ^ "# then save and quit the editor:\n\n"
        ^ join "\n\n"
            (List.map
               (fun l -> List.map (fun a -> "#" ^ a) l |> join "\n")
               dups)
      in
      match make_tmp_file str with
      | None -> ()
      | Some file_name -> (
          match Unix.system (editor ^ " " ^ file_name) with
          | Unix.WSIGNALED v -> Printf.printf "signaled %d\n" v
          | Unix.WSTOPPED v -> Printf.printf "stopped %d\n" v
          | Unix.WEXITED 0 -> ()
          | Unix.WEXITED v -> Printf.printf "exited %d\n" v))
