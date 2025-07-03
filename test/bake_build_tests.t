====================================================
Building Tests
====================================================
Build no out fails
  $ ../bin/bake.exe --mode build ./test_infra/test_file_no_stubs.cml
  Fatal error: exception Failure("Output file name (--out <file>) is required in 'merge' and 'build' modes.")
  [2]

Build out + no stubs works as expected
  $ ../bin/bake.exe --mode build --out ./built.cml ./test_infra/test_file_no_stubs.cml 2>&1 | sed 's/.*ld: warning: \/tmp\/.\+\.o:/<redacted>/' | sed 's/.*NOTE: This behaviour is deprecated.*/<redacted>/'
  <redacted> missing .note.GNU-stack section implies executable stack
  <redacted>
  Binary created: ./built
  $ ./built
  cmd_fn
  etc_fnbasis_stuff
  nat_fn
  rec_fn

Build out with an FFI file
  $ ../bin/bake.exe --mode build --out ./built.cml ./test_infra/test_file_ffi.cml 2>&1 | sed 's/.*ld: warning: \/tmp\/.\+\.o:/<redacted>/' | sed 's/.*NOTE: This behaviour is deprecated.*/<redacted>/'
  <redacted> missing .note.GNU-stack section implies executable stack
  <redacted>
  Binary created: ./built
  $ ./built
  test_function from the ffi
  arg: test1
  Back in Cakeml, we got:
  Dangerous way to return values 
