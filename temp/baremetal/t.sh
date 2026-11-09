#!/bin/bash
set -e

BUILD=/home/wyehia/Source/build.upstream.new
CLANG=$BUILD/bin/clang

# Component 2: real_main (freestanding, instrumented) is the program we want to profile
cat <<EOT >real_main.c
#include <profile/instr_prof_interface.h>
#include <stdint.h>

extern char *allocate(uint64_t Size);

static volatile int x = 10;
static volatile int ar;
static uint64_t ProfSize = 0;
static char *Memory;

__attribute__((no_profile_instrument_function))
static int dump_profile(void) {
#ifdef __LLVM_INSTR_PROFILE_GENERATE
  ProfSize = __llvm_profile_get_size_for_buffer();

  Memory = allocate(ProfSize);
  if (!Memory)
    return -1; // buffer too small

  if (__llvm_profile_write_buffer(Memory) != 0)
    return -2; // serialization failed
#endif
  return 0;
}

__attribute__((visibility("default")))
int real_main(void) {
  // __llvm_profile_reset_counters(); // optional: discard startup counts
  for(int i = 0; i < x; ++i)
     ar += i;
  return dump_profile();
}

#ifdef __LLVM_INSTR_PROFILE_GENERATE
__attribute__((visibility("default")))
char *get_buffer(uint64_t *Size) {
  *Size = ProfSize;
  return Memory;
}
#endif
EOT

# Component 1: driver (NOT profiled).
cat <<EOT >main.c
#include <stdint.h>
#include <stdio.h>

extern int real_main(void);
extern char *get_buffer(uint64_t*);
int main() {
  int rc = real_main();
#ifdef WRITE_PROFILE_TO_DISK
  uint64_t size = 0;
  char *prof_buf = get_buffer(&size);

  FILE *F = fopen("default.profraw", "wb");
  if (!F) {
    perror("fopen default.profraw");
    return 1;
  }
  if (fwrite(prof_buf, 1, size, F) != size) {
    perror("fwrite default.profraw");
    fclose(F);
    return 1;
  }
  if (fclose(F) != 0) {
    perror("fclose default.profraw");
    return 1;
  }
#endif
  return rc;
}
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

#set -x
# (3) helper.c: compiled WITHOUT instrumentation (counters in memcpy/memset
# would change while the profile is being written).
$CLANG $COMMON -fPIC -c helper.c -o helper.o

# (2) real_main.c: instrumented with -fprofile-generate.
$CLANG $COMMON -fPIC -fprofile-generate -fprofile-update=single \
  -c real_main.c -o real_main.o

# Link (2) and (3) into ONE shared library, together with the baremetal
# profile runtime (libclang_rt.profile.a, found via the resource dir).
$BUILD/bin/ld.lld \
  -z relro \
  --hash-style=gnu \
  --eh-frame-hdr \
  -m elf64lppc \
  -shared \
  -o libreal_main.so \
  real_main.o helper.o $BUILD/lib/clang/24/lib/powerpc64le-unknown-linux-gnu/libclang_rt.profile.a

# (1) main.c: not profiled, calls real_main from libreal_main.so.
$CLANG -DWRITE_PROFILE_TO_DISK main.c -o main -L. -lreal_main -Wl,-rpath,'$ORIGIN'

set +x

rm -f default.profraw
./main; echo "exit code: $?"

# Sanity check: the raw profile must be readable by llvm-profdata.
BIN=$(dirname $CLANG)
$BIN/llvm-profdata merge default.profraw -o default.profdata
$BIN/llvm-profdata show --all-functions --counts default.profdata

$CLANG $COMMON -fPIC -fprofile-use=default.profdata -c real_main.c -o real_main.profuse.o
$CLANG $COMMON -shared -fuse-ld=lld real_main.profuse.o helper.o -o libreal_main.so
$CLANG main.c -o main -L. -lreal_main -Wl,-rpath,'$ORIGIN'
./main; echo "exit code: $?"

# Verify the profile was actually applied: no stale/missing-profile warnings
# (-Werror), and real_main must carry !prof metadata (entry count + branch weights).
$CLANG $COMMON -fPIC -fprofile-use=default.profdata \
  -Werror=profile-instr-out-of-date -Werror=profile-instr-missing \
  -S -emit-llvm real_main.c -o real_main.profuse.ll
grep -q 'function_entry_count' real_main.profuse.ll
grep -q 'branch_weights' real_main.profuse.ll
echo "profile-use check: OK"

