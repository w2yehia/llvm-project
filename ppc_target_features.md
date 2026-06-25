# PowerPC Target Attribute Feature Strings

This list contains all possible feature strings that can be used with the `target` attribute on PowerPC, compiled from:
1. GCC documentation (https://gcc.gnu.org/onlinedocs/gcc/PowerPC-Attributes.html)
2. Clang's Options.td (m_ppc_Features_Group)

## Feature List 
```c
// -mFEATURE supported by clang (some are AIX only). These are also accepted 
// by clang on __attribute__((target("FEATURE"))). See test_target_attribute_all.sh for verification.
//
// Format: 
// feature_name       // clang-linux clang-aix gcc-linux // __builtin_cpu_supports mapping and notes
 altivec                         // 1   1   1   // __builtin_cpu_supports("altivec")
 htm                             // 1   1   1   // __builtin_cpu_supports("htm")
 isel                            // 1   1   1   // __builtin_cpu_supports("isel")
 mma                             // 1*  1*  1*  // __builtin_cpu_supports("mma") [POWER10]
 vsx                             // 1   1   1   // __builtin_cpu_supports("vsx")
 cmpb                            // 1   1   1   // __builtin_cpu_supports("arch_2_05") [POWER6]
 crypto                          // 1   1   1   // __builtin_cpu_supports("arch_2_07") [POWER8]
 direct-move                     // 1   1   1   // __builtin_cpu_supports("arch_2_07") [POWER8]
 float128                        // 1   1   1   // __builtin_cpu_supports("arch_3_00") [POWER9] (UNCERTAIN - needs verification)
 fprnd                           // 1   1   1   // __builtin_cpu_supports("arch_2_05") [POWER6]
 paired-vector-memops            // 1*  1*  0   // __builtin_cpu_supports("arch_3_1") [POWER10]
 pcrel                           // 1*  1*  1*  // __builtin_cpu_supports("arch_3_1") [POWER10]
 popcntd                         // 1   1   1   // __builtin_cpu_supports("arch_2_06") [POWER7]
 power8-vector                   // 1   1   1   // __builtin_cpu_supports("arch_2_07") [POWER8]
 power9-vector                   // 1   1   1   // __builtin_cpu_supports("arch_3_00") [POWER9]
 power10-vector                  // 1   1   0   // __builtin_cpu_supports("arch_3_1") [POWER10]
 prefixed                        // 1*  1*  1*  // __builtin_cpu_supports("arch_3_1") [POWER10]
 aix-shared-lib-tls-model-opt    // 0   1   0   // clang AIX64-only // No runtime check (compile-time only)
 aix-small-local-dynamic-tls     // 0   1   0   // clang AIX64-only // No runtime check (compile-time only)
 aix-small-local-exec-tls        // 0   1   0   // clang AIX64-only // No runtime check (compile-time only)
 crbits                          // 1   1   0   // No runtime check (optimization hint)
 invariant-function-descriptors  // 1   1   0   // No runtime check (AIX ABI feature)
 longcall                        // 1   1   1   // No runtime check (code gen option)
 mfcrf                           // 1   1   1   // Always available (basic instruction, no check needed)
 mfocrf                          // 1   1   0   // GCC uses mfcrf // Always available (basic instruction, no check needed)
 privileged                      // 1   1** 1   // AIX needs -mcpu=power8 // No runtime check available
 rop-protect                     // 1   1** 1   // AIX needs -mcpu=power8 // No runtime check available
 secure-plt                      // 1   1   1   // No runtime check (linking option)

// Additional __builtin_cpu_supports strings available but not directly mapped:
// darn, tar, dscr, ebb (these have direct support but no corresponding target attribute)

// -mFEATURE supported by GCC only (not clang); for now ignore on target/target_clones on AIX
 avoid-indexed-addresses
 dlmzb
 friz
 hard-dfp
 mulhw
 multiple
 popcntb
 powerpc-gfxopt
 powerpc-gpopt
 recip-precision
 string
 update

// -mFEATURE not supported by any
 efpu2   // Not supported (32-bit SPE only)
 spe     // Not supported (32-bit only)
 paired  // Not supported by any compiler
```

## Notes

- Negative forms (e.g., `no-altivec`, `no-vsx`) are not included in this list as they are derived by prefixing `no-` to the feature name
- `cpu=` and `tune=` are not feature strings but separate attribute forms
- Some features may have aliases (e.g., `mfcrf` is an alias for `mfocrf`)
- Not all features may be valid for all PowerPC targets or in all contexts

