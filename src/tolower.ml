(*
 * Module to reduce all files in the base directory to lowercase
 * and other Linux-only boringness
 *)
 
open Util;;

(*
 * Bare-bones interface
 *)
exception Good_exit;;
let askfor func mess =
	print_string mess;
	try 
	  while true do
			print_string "[Y]es or [N]o\n";
	  	let x = read_line () in
  		match String.uppercase x with
	  	| "Y" ->
				func ();
				raise Good_exit;
			| "N" ->
				raise Good_exit;
			| _ ->
				()
		done
	with Good_exit -> ()
;;


(*
 * Turn all files to lowercase, recursively.
 *)
let rec find_and_lower cur_dir () =
  let dh = Unix.opendir cur_dir in
  let dirlist = ref [] in
  try
    while true do
      let element = Unix.readdir dh in
      let implicit = element.[0] = '.' in
      let element = cur_dir ^ "/" ^ element in
      let stats = Unix.lstat element in
      let is_a_symlink = stats.Unix.st_kind = Unix.S_LNK in
      if not implicit && not is_a_symlink then begin
        Unix.rename element "TMP_THIS_IS_A_VERY_TMP_NAME";
        Unix.rename "TMP_THIS_IS_A_VERY_TMP_NAME" (String.lowercase element);
        if stats.Unix.st_kind = Unix.S_DIR then begin
          dirlist := (String.lowercase element) :: !dirlist;
        end
      end
    done
  with _ -> Unix.closedir dh;
  List.iter (fun x -> find_and_lower x ()) !dirlist;
;;

(*
 * Generate linux.ini from baldur.ini using /unix/style/paths rather than
 * W:\indows\style\paths 
 *)

let get_wine_cfg () =
	(* first, figure out what c:\ (etc) means in Unix style *)
	let home = Sys.getenv "HOME" in
	let winepath = home ^ "/.wine/dosdevices" in
	let winelst = Sys.readdir winepath in
	let allpaths = Hashtbl.create 21 in
	Array.iter (fun this ->
		let thisdest = Unix.readlink (winepath ^ "/" ^ this) in
		let relative = Str.regexp "..?/" in
		let thisdest = if Str.string_match relative thisdest 0 then (winepath ^ "/" ^ thisdest) else thisdest in
		Hashtbl.add allpaths (String.uppercase this) thisdest;
	) winelst ;
	(* Read all directory list in baldur.ini and create linux.ini from it *)
	let baldurini = open_in "baldur.ini" in
	let linuxini = open_out "linux.ini" in
	let cdregex = Str.regexp "[ \t]*[HC]D.:=" in
	try
		while true do
			let line = input_line baldurini in
			if Str.string_match cdregex line 0 then begin
				let split = Str.split (Str.regexp "[=;]") line in
				List.iter (fun this ->
					let path = Str.string_before this 2 in
					let path = Hashtbl.find allpaths (String.uppercase path) in
					let otherpart = Str.string_after this 2 in
					let newpath = path ^ otherpart in
					let newpath = Str.global_replace (Str.regexp "\\\\") "/" newpath in
					Printf.fprintf linuxini "CD1:=%s\n%!" newpath;
				) (List.tl split)
			end;
		done
	with End_of_file -> ();
	close_out linuxini;
	close_in baldurini;
;;

(*
 * Ask the user which functions to run
 *)
askfor (find_and_lower ".") "Do you want to lowercase everything?
(run if you extracted some mods since the last time you ran this utility)\n"
;;

askfor get_wine_cfg "Do you want to generate linux.ini from baldur.ini?
(needed once per installation)\n"
;;

