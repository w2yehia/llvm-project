#!/bin/bash
set -e
CLANG=/home/wyehia/Source/build.upstream.new/bin/clang

# Component 2: real_main (freestanding, instrumented) is the program we want to profile
cat <<EOT >real_main.c
#include <profile/instr_prof_interface.h>
#include <stdint.h>

extern char *allocate(uint64_t Size);

volatile int x = 10;
volatile int ar;

__attribute__((no_profile_instrument_function))
static int dump_profile(void) {
  char *Memory = allocate(__llvm_profile_get_size_for_buffer());
  if (!Memory)
    return -1; // buffer too small

  if (__llvm_profile_write_buffer(Memory) != 0)
    return -2; // serialization failed

  return 0;
}

__attribute__((visibility("default")))
int real_main(void) {
  // __llvm_profile_reset_counters(); // optional: discard startup counts
  for(int i = 0; i < x; ++i)
     ar += i;
  return dump_profile();
}
EOT

# Component 1: driver (NOT profiled).
cat <<EOT >main.c
extern int real_main(void);

int main() { return real_main(); }
EOT

# Component 3: helper (see below).
cat <<EOT >helper.c
#include <stdint.h>
static char ProfBuf[16 * 1024] __attribute__((aligned(8)));
char *allocate(uint64_t Size) {
  if (Size > sizeof(ProfBuf))
    return 0;
  return ProfBuf;
}

// Minimal libc replacements needed by the profile runtime (no libc is linked).
void *memset(void *Dst, int C, unsigned long N) {
  unsigned char *D = Dst;
  while (N--)
    *D++ = (unsigned char)C;
  return Dst;
}
void *memcpy(void *Dst, const void *Src, unsigned long N) {
  unsigned char *D = Dst;
  const unsigned char *S = Src;
  while (N--)
    *D++ = *S++;
  return Dst;
}
EOT

COMMON="-O2 -ffreestanding -fno-builtin -fno-stack-protector -nostdlib -fvisibility=hidden"

# (3) helper.c: compiled WITHOUT instrumentation (counters in memcpy/memset
# would change while the profile is being written).
$CLANG $COMMON -fPIC -c helper.c -o helper.o

# (2) real_main.c: instrumented with -fprofile-generate.
$CLANG $COMMON -fPIC -fprofile-generate -fprofile-update=single \
  -c real_main.c -o real_main.o

# Link (2) and (3) into ONE shared library, together with the baremetal
# profile runtime (libclang_rt.profile.a, found via the resource dir).
$CLANG $COMMON -shared -fuse-ld=lld \
  real_main.o helper.o -o libreal_main.so \
  $($CLANG --print-file-name=libclang_rt.profile.a)

# (1) main.c: not profiled, calls real_main from libreal_main.so.
$CLANG main.c -o main -L. -lreal_main -Wl,-rpath,'$ORIGIN'

./main; echo "exit code: $?"
