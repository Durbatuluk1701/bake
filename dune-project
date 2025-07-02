(lang dune 3.19)

(name bake)

(version 1.0.0)

(generate_opam_files true)

(source
 (github Durbatuluk1701/bake))

(authors "Will Thomas <30wthomas@ku.edu>")

(maintainers "Will Thomas <30wthomas@ku.edu>")

(license Unlicense)

(documentation https://github.com/Durbatuluk1701/bake)

(package
 (name bake)
 (synopsis "Bake - The CakeML Build Tool")
 (description
  "Bake is a build tool for CakeML projects, designed to facilitate the compilation and management of CakeML codebases. In particular, it intends to address the lack of module support in CakeML by allowing dependencies to be specified in comments and then resolved to a monolithic CakeML file that is compiled. It supports various modes of operation including printing dependencies, merging files, and building executables.")
 (depends ocaml)
 (tags
  ("cakeml" "build")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
