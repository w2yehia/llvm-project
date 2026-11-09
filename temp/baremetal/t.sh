#!/bin/bash

cat <<EOF >main.c
#include <profile/instr_prof_interface.h>
#include <stdint.h>

__attribute__((no_profile))
static int dump_profile(void) {
  char *Memory = allocate(__llvm_profile_get_size_for_buffer());
  if (!Memory)
    return -1; // buffer too small

  if (__llvm_profile_write_buffer(Memory) != 0)
    return -2; // serialization failed

  return 0;
}

int main(void) {
  // __llvm_profile_reset_counters(); // optional: discard startup counts
  for(int i = 0; i < x; ++i)
     ar += i;
  return dump_profile();
}
EOF
cat <<EOF >helper.c
static char ProfBuf[16 * 1024] __attribute__((aligned(8)));
extern char *allocate(uint64_t Size) {
  if (Size > sizeof(ProfBuf)) {
    return 0;
  return &ProfBuf;
}
EOF

