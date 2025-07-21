Requires input main file
  $ ../bin/bake.exe
  Main CakeML file is required.
  Usage: bake <main> [--mode print|merge|build] [--out <file>] [--stubs <dir>] [--cc-flags <flags>] [--c-libraries <lib1,lib2,...>]
    --mode {print|merge|build}Mode of operation: print, merge, build
    --out Output file name for the monolithic CakeML file
    --stubs Optional folder containing substitute (stub) files
    --cc-flags Additional flags to pass to CC (overrides BAKE_CC_FLAGS env var)
    --c-libraries Comma-separated list of C libraries to link using pkg-config
    -help  Display this list of options
    --help  Display this list of options
  [1]

Cannot use C files without stubs
  $ ../bin/bake.exe --mode print ./test_infra/test_file_ffi.cml
  Fatal error: exception Failure("Stub directory is required for #-modules.")
  [2]
