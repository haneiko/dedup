## Usage:
```
dedup [-i] [-f] <dir>

 dedup will recursively search <dir> for duplicated files (with same md5 hash).
 With the -i option will open "EDITOR" with the list of duplicates found.
 Without -i will only output the list.
 Duplicates will be grouped together, different files will be separated
 by an empty line.
 In the editor: all files will be commented out, uncommenting will mark
 the file for removal.
 Saving then quiting the editor will remove the selected files,
 but will only remove if the option -f was provided in the command line.

  -i Select files with "EDITOR"
  -f Remove selected files
  -help  Display this list of options
  --help  Display this list of options
```
## Examples
List duplicates:
```
$ dedup .
./_build/install/default/lib/dedup/opam
./_build/default/dedup.opam
```
Interactive use (-i) lets you select files with the editor:
```
$ dedup -i .
remove? ./_build/install/default/lib/dedup/opam
```
But will only remove with the -f option:
```
$ dedup -i -f .
removed ./_build/install/default/lib/dedup/opam
```
## Build
```
$ opam install ./dedup.opam --deps-only
$ dune build
```
