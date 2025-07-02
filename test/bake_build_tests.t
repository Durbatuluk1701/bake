====================================================
Building Tests
====================================================
Build no out fails
  $ ../bin/bake.exe --mode build ./test_infra/test_file_no_stubs.cml
  Fatal error: exception Failure("Output file name (--out <file>) is required in 'merge' and 'build' modes.")
  [2]

Build out + no stubs works as expected
  $ ../bin/bake.exe --mode build --out ./built.cml ./test_infra/test_file_no_stubs.cml 2>&1 | sed 's/\/tmp\/.\+\.o:/<redacted>/'
  /bin/ld: warning: <redacted> missing .note.GNU-stack section implies executable stack
  /bin/ld: NOTE: This behaviour is deprecated and will be removed in a future version of the linker
  Binary created: ./built
  $ ./built
  cmd_fn
  etc_fnbasis_stuff
  nat_fn
  rec_fn
