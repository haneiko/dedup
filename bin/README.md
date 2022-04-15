## Usage:
```
dedup [-f] <dir>

  dedup will recursively search <dir> for duplicated files (with same md5 hash),
  then will open "EDITOR" with the list of duplicates found.
  In the editor: duplicates will be grouped together, different files will
  be separeted by an empty line.
  All files will be commented out, uncommenting will mark the file for
  deletion.
  Will only delete if the option -f is provided in the cmd line.

  -f Remove selected files
  -help  Display this list of options
  --help  Display this list of options
```
## Examples
```
$ ./_build/default/bin/main.exe .
remove? ./_build/install/default/lib/dedup/opam
remove? ./_build/default/dedup.opam
$ ./_build/default/bin/main.exe -f .
removed ./_build/install/default/lib/dedup/opam
removed ./_build/default/dedup.opam
```
## Build
```
$ opam install ./dedup.opam --deps-only
$ dune build
```
