build:
	@dune build @fmt --auto-promote .

run:
	@dune exec dedup

deps:
	@opam install ./*.opam --deps-only
