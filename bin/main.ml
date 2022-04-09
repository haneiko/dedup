type file = File of string | Dir of string * file list

let rec list_files folder_name =
  let file_list = ref [] in
  try
    let h = Unix.opendir folder_name in
    (try
       while true do
         let entry2 = Unix.readdir h in
         if entry2 <> "." && entry2 <> ".." then
           let entry = folder_name ^ Filename.dir_sep ^ entry2 in
           let stats = Unix.stat entry in
           match stats.st_kind with
           | Unix.S_DIR -> (
               match list_files entry with
               | Some sub_dir -> file_list := sub_dir :: !file_list
               | None -> ())
           | Unix.S_REG -> file_list := File entry :: !file_list
           | _ -> ()
       done
     with End_of_file -> Unix.closedir h);
    Some (Dir (folder_name, !file_list))
  with Unix.Unix_error (err, _, arg) ->
    Printf.printf "%s: %s\n" (Unix.error_message err) arg;
    None

let rec print_files = function
  | File name -> print_endline name
  | Dir (name, file_list) ->
      print_endline name;
      ignore (List.map print_files file_list)

let () =
  let folder_name = "." in
  match list_files folder_name with
  | Some files -> print_files files
  | None -> ()
