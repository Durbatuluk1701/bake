====================================================
Printing Tests
====================================================
Print works as expected
  $ ../bin/bake.exe --mode print ./test_infra/test_file_no_stubs.cml
  ./test_infra/CMD.cml
  ./test_infra/BasisStuff.cml
  ./test_infra/Etc.cml
  ./test_infra/Nat.cml
  ./test_infra/rec_tests/Rec.cml
  ./test_infra/test_file_no_stubs.cml

Print with stubs works as expected
  $ ../bin/bake.exe --mode print --stubs ./test_infra/stubs ./test_infra/test_file.cml
  ./test_infra/CMD.cml
  ./test_infra/BasisStuff.cml
  ./test_infra/Etc.cml
  ./test_infra/Nat.cml
  ./test_infra/rec_tests/Rec.cml
  ./test_infra/JumpBack.cml
  ./test_infra/stubs/Test_Dep.cml
  ./test_infra/stubs/Test_Stubs.cml
  ./test_infra/test_file.cml

Print with FFI works
  $ ../bin/bake.exe --mode print ./test_infra/test_file_ffi.cml
  ./test_infra/test_file_ffi.cml
  ./test_infra/test_file.c
