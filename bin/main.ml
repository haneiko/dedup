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
  match Option.bind (opendir path) readdir with
  | None -> []
  | Some content ->
      let file_list = prepend_path path content in
      let folders, files = List.partition is_directory file_list in
      let subs = List.map list_files folders in
      List.fold_left List.append files subs

let () =
  let files = list_files "." in
  let prepend_hash a = Digest.to_hex (Digest.file a) ^ " " ^ a in
  let files_with_hash = List.map prepend_hash files in
  ignore (List.map print_endline files_with_hash)
