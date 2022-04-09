build:
	@dune build @fmt --auto-promote .

run:
	@dune exec dedup

clean:
	@dune clean

deps:
	@opam install ./*.opam --deps-only
