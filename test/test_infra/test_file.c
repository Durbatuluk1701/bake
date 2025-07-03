#include <stdio.h>
#include <string.h>

void ffitest_function(unsigned char *c, long clen, unsigned char *a, long alen) {
  printf("test_function from the ffi\n");
  printf("arg: %.*s\n", (int)clen, c);
  // Flush stdio
  fflush(stdout);

  const char *msg = "Dangerous way to return values \n\0";
  size_t msg_len = strlen(msg);
  if (alen >= msg_len) {
    memcpy(a, msg, msg_len);
  } else {
    // alen too small, and this is our test!? just throw an error I guess
    a[0] = 1; // Indicate an error
  }
}