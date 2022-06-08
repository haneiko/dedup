(lang dune 3.0)

(name dedup)

(generate_opam_files true)

(source
 (github haneiko/dedup))

(authors "Mateus Haneiko")

(maintainers "Mateus Haneiko")

(license ISC)

(package
 (name dedup)
 (synopsis "dedup searches for duplicated files")
 (description
  "dedup will recursively search <dir> for duplicated files (with same md5 hash)")
 (depends ocaml dune))
