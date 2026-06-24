# PowerPC Target Attribute Feature Strings

This list contains all possible feature strings that can be used with the `target` attribute on PowerPC, compiled from:
1. GCC documentation (https://gcc.gnu.org/onlinedocs/gcc/PowerPC-Attributes.html)
2. Clang's Options.td (m_ppc_Features_Group)

## Feature List 
// -mFEATURE supported by clang (some are AIX only):
 aix-shared-lib-tls-model-opt    // 0   1   0   clang AIX64-only
 aix-small-local-dynamic-tls     // 0   1   0   clang AIX64-only
 aix-small-local-exec-tls        // 0   1   0   clang AIX64-only
 altivec                         // 1   1   1
 cmpb                            // 1   1   1
 crbits                          // 1   1   0
 crypto                          // 1   1   1
 direct-move                     // 1   1   1
 float128                        // 1   1   1
 fprnd                           // 1   1   1
 htm                             // 1   1   1
 invariant-function-descriptors  // 1   1   0
 isel                            // 1   1   1
 longcall                        // 1   1   1
 mfcrf                           // 1   1   1
 mfocrf                          // 1   1   0   GCC uses mfcrf
 mma                             // 1*  1*  1*  require -mcpu=power10
 paired-vector-memops            // 1*  1*  0   require -mcpu=power10
 pcrel                           // 1*  1*  1*  require -mcpu=power10
 popcntd                         // 1   1   1
 power8-vector                   // 1   1   1
 power9-vector                   // 1   1   1
 power10-vector                  // 1   1   0
 prefixed                        // 1*  1*  1*  require -mcpu=power10
 privileged                      // 1   1** 1   AIX needs -mcpu=power8
 rop-protect                     // 1   1** 1   AIX needs -mcpu=power8
 secure-plt                      // 1   1   1
 vsx                             // 1   1   1

// -mFEATURE supported by GCC only (not clang)
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

## Notes

- Negative forms (e.g., `no-altivec`, `no-vsx`) are not included in this list as they are derived by prefixing `no-` to the feature name
- `cpu=` and `tune=` are not feature strings but separate attribute forms
- Some features may have aliases (e.g., `mfcrf` is an alias for `mfocrf`)
- Not all features may be valid for all PowerPC targets or in all contexts
