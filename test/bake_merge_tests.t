====================================================
Merging Tests
====================================================
Merge no out fails
  $ ../bin/bake.exe --mode merge ./test_infra/test_file_no_stubs.cml
  Fatal error: exception Failure("Output file name (--out <file>) is required in 'merge' and 'build' modes.")
  [2]

Merge out + no stubs works as expected
  $ ../bin/bake.exe --mode merge --out ./merged.cml ./test_infra/test_file_no_stubs.cml
  $ cat merged.cml
  fun cmd_fn i =
    "cmd_fn"
  
  
  fun basis_stuff j =
    "basis_stuff"
  
  
  (* deps: BasisStuff *)
  
  fun etc_fn i =
    "etc_fn" ^ basis_stuff ()
  
  
  (* deps: CMD *)
  
  fun nat_fn i =
    "nat_fn"
  
  
  fun rec_fn i =
    "rec_fn"
  
  
  (* deps: CMD Etc Nat rec_tests.Rec *)
  
  fun fact i =
    if i < 1 
    then 1
    else i * fact (i - 1)
  
  val _ =
    let 
      val _ = print (cmd_fn ())
      val _ = print "\n"
      val _ = print (etc_fn ())
      val _ = print "\n"
      val _ = print (nat_fn ())
      val _ = print "\n"
      val _ = print (rec_fn ())
      val _ = print "\n"
    in
      ()
    end
  
  
Merge out + stubs works as expected
  $ ../bin/bake.exe --mode merge --out ./merged.cml --stubs ./test_infra/stubs ./test_infra/test_file.cml
  $ cat merged.cml
  fun cmd_fn i =
    "cmd_fn"
  
  
  fun basis_stuff j =
    "basis_stuff"
  
  
  (* deps: BasisStuff *)
  
  fun etc_fn i =
    "etc_fn" ^ basis_stuff ()
  
  
  (* deps: CMD *)
  
  fun nat_fn i =
    "nat_fn"
  
  
  fun rec_fn i =
    "rec_fn"
  
  
  fun jump_back i = "this is a jump back test"
  
  
  (* deps: CMD *)
  
  
  (* deps: JumpBack $Test_Dep *)
  
  val _ = 
    let 
      val _ = print "\nfjdskf\n"
      val _ = print (cmd_fn "Test")
      val _ = print "\nfjdskf\n"
      val _ = print (jump_back ())
      val _ = print "\nfjdskf\n"
    in
      ()
    end
  
  
  (* deps: CMD Etc Nat rec_tests.Rec Test_Stubs *)
  
  fun fact i =
    if i < 1 
    then 1
    else i * fact (i - 1)
  
  val _ =
    let 
      val _ = print (cmd_fn ())
      val _ = print "\n"
      val _ = print (etc_fn ())
      val _ = print "\n"
      val _ = print (nat_fn ())
      val _ = print "\n"
      val _ = print (rec_fn ())
      val _ = print "\n"
    in
      ()
    end
  
  
 
