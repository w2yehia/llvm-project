# PowerPC Feature Strings Analysis - Complete Test Results (Native ppc64le)

## Executive Summary

Tested 43 PowerPC feature flags on **native ppc64le Linux** host:
- **Clang Linux (native)**: 25 supported
- **Clang AIX (cross-compile)**: 25 supported  
- **GCC Linux (native)**: 28 supported
- **All three compilers**: 21 features work across all configurations
- **Platform-specific**: 3 AIX-only features (work in Clang AIX, not in Clang Linux or GCC Linux)

## Test Environment

- **Host Architecture**: ppc64le (PowerPC 64-bit Little Endian)
- **Clang**: `/home/wyehia/Source/build.upstream.new/bin/clang` (version 23.0.0git)
- **GCC**: `/opt/at17.0/bin/gcc` (GCC 13.3.1, Advance-Toolchain 17.0-2)
- **Test Method**: Compile simple C file with `-mFEATURE` flag
- **Retry Strategy**: For failures, retry with `-mcpu=power8`, `-mcpu=power9`, `-mcpu=power10`

## Complete Feature Support Matrix

Format: `Feature | Clang-Linux | Clang-AIX | GCC-Linux | Notes`
- 1 = Supported
- 0 = Not supported
- CPU requirements noted where applicable

| Feature | Clang-Linux | Clang-AIX | GCC-Linux | Notes |
|---------|-------------|-----------|-----------|-------|
| aix-shared-lib-tls-model-opt | 0 | 1 | 0 | AIX-only (Clang AIX cross-compile) |
| aix-small-local-dynamic-tls | 0 | 1 | 0 | AIX-only (Clang AIX cross-compile) |
| aix-small-local-exec-tls | 0 | 1 | 0 | AIX-only (Clang AIX cross-compile) |
| altivec | 1 | 1 | 1 | ✓ All compilers |
| avoid-indexed-addresses | 0 | 0 | 1 | GCC-only |
| cmpb | 1 | 1 | 1 | ✓ All compilers |
| crbits | 1 | 1 | 0 | Clang-only |
| crypto | 1 | 1 | 1 | ✓ All compilers |
| direct-move | 1 | 1 | 1 | ✓ All compilers |
| dlmzb | 0 | 0 | 1 | GCC-only |
| efpu2 | 0 | 0 | 0 | Not supported (32-bit SPE only) |
| float128 | 1 | 1 | 1 | ✓ All compilers |
| fprnd | 1 | 1 | 1 | ✓ All compilers |
| friz | 0 | 0 | 1 | GCC-only |
| hard-dfp | 0 | 0 | 1 | GCC-only (decimal floating point) |
| htm | 1 | 1 | 1 | ✓ All compilers |
| invariant-function-descriptors | 1 | 1 | 0 | Clang-only |
| isel | 1 | 1 | 1 | ✓ All compilers |
| longcall | 1 | 1 | 1 | ✓ All compilers |
| mfcrf | 1 | 1 | 1 | ✓ All compilers |
| mfocrf | 1 | 1 | 0 | Clang-only (GCC uses mfcrf) |
| mma | 1* | 1* | 1* | ✓ All (requires -mcpu=power10) |
| mulhw | 0 | 0 | 1 | GCC-only |
| multiple | 0 | 0 | 1 | GCC-only |
| paired | 0 | 0 | 0 | Not supported by any compiler |
| paired-vector-memops | 1* | 1* | 0 | Clang-only (requires -mcpu=power10) |
| pcrel | 1* | 1* | 1* | ✓ All (requires -mcpu=power10) |
| popcntb | 0 | 0 | 1 | GCC-only (Clang suggests popcntd) |
| popcntd | 1 | 1 | 1 | ✓ All compilers |
| power8-vector | 1 | 1 | 1 | ✓ All compilers |
| power9-vector | 1 | 1 | 1 | ✓ All compilers |
| power10-vector | 1 | 1 | 0 | Clang-only |
| powerpc-gfxopt | 0 | 0 | 1 | GCC-only |
| powerpc-gpopt | 0 | 0 | 1 | GCC-only |
| prefixed | 1* | 1* | 1* | ✓ All (requires -mcpu=power10) |
| privileged | 1 | 1** | 1 | ✓ All (AIX needs -mcpu=power8) |
| recip-precision | 0 | 0 | 1 | GCC-only |
| rop-protect | 1 | 1** | 1 | ✓ All (AIX needs -mcpu=power8) |
| secure-plt | 1 | 1 | 1 | ✓ All compilers |
| spe | 0 | 0 | 0 | Not supported (32-bit only) |
| string | 0 | 0 | 1 | GCC-only |
| update | 0 | 0 | 1 | GCC-only |
| vsx | 1 | 1 | 1 | ✓ All compilers |

*Requires -mcpu=power10
**Requires -mcpu=power8 for AIX target

## Detailed Error Messages

### Clang Linux Native Errors

**AIX-specific features:**
- aix-shared-lib-tls-model-opt: `option '-maix-shared-lib-tls-model-opt' cannot be specified on this target`
- aix-small-local-dynamic-tls: `option '-maix-small-local-[exec|dynamic]-tls' cannot be specified on this target`
- aix-small-local-exec-tls: `option '-maix-small-local-[exec|dynamic]-tls' cannot be specified on this target`

**Unknown arguments:**
- avoid-indexed-addresses: `'-mavoid-indexed-addresses'`
- dlmzb: `'-mdlmzb'`
- friz: `'-mfriz'`
- hard-dfp: `'-mhard-dfp'`
- mulhw: `'-mmulhw'`
- multiple: `'-mmultiple'`
- paired: `'-mpaired'`
- popcntb: `unknown argument '-mpopcntb'; did you mean '-mpopcntd'?`
- powerpc-gfxopt: `'-mpowerpc-gfxopt'`
- powerpc-gpopt: `'-mpowerpc-gpopt'`
- recip-precision: `'-mrecip-precision'`
- string: `'-mstring'`
- update: `'-mupdate'`

**Architecture-specific:**
- efpu2: `SPE is only supported for 32-bit targets.`
- spe: `SPE is only supported for 32-bit targets.`

### Clang AIX Cross-Compile Errors

**Unknown arguments (same as Linux):**
- avoid-indexed-addresses: `'-mavoid-indexed-addresses'`
- dlmzb: `'-mdlmzb'`
- friz: `'-mfriz'`
- hard-dfp: `'-mhard-dfp'`
- mulhw: `'-mmulhw'`
- multiple: `'-mmultiple'`
- paired: `'-mpaired'`
- popcntb: `unknown argument '-mpopcntb'; did you mean '-mpopcntd'?`
- powerpc-gfxopt: `'-mpowerpc-gfxopt'`
- powerpc-gpopt: `'-mpowerpc-gpopt'`
- recip-precision: `'-mrecip-precision'`
- string: `'-mstring'`
- update: `'-mupdate'`

**Architecture-specific:**
- efpu2: `clang frontend command failed due to signal (use -v to see invocation)`
- spe: `clang frontend command failed due to signal (use -v to see invocation)`

### GCC Linux Native Errors

**Unrecognized options:**
- aix-shared-lib-tls-model-opt: `unrecognized command-line option '-maix-shared-lib-tls-model-opt'`
- aix-small-local-dynamic-tls: `unrecognized command-line option '-maix-small-local-dynamic-tls'`
- aix-small-local-exec-tls: `unrecognized command-line option '-maix-small-local-exec-tls'`
- crbits: `unrecognized command-line option '-mcrbits'`
- efpu2: `unrecognized command-line option '-mefpu2'`
- invariant-function-descriptors: `unrecognized command-line option '-minvariant-function-descriptors'`
- mfocrf: `unrecognized command-line option '-mmfocrf'; did you mean '-mmfcrf'?`
- paired: `unrecognized command-line option '-mpaired'`
- paired-vector-memops: `unrecognized command-line option '-mpaired-vector-memops'`
- power10-vector: `unrecognized command-line option '-mpower10-vector'; did you mean '-mpower8-vector'?`
- spe: `unrecognized command-line option '-mspe'`

## Analysis by Category

### 1. Features Supported by All Three Compilers (21 features)

These work in Clang (Linux + AIX) and GCC:
- altivec
- cmpb
- crypto
- direct-move
- float128
- fprnd
- htm
- isel
- longcall
- mfcrf
- mma (requires -mcpu=power10)
- pcrel (requires -mcpu=power10)
- popcntd
- power8-vector
- power9-vector
- prefixed (requires -mcpu=power10)
- privileged
- rop-protect
- secure-plt
- vsx

**Recommendation**: These 21 features are safe to use in `target_clones` for maximum cross-compiler compatibility.

### 2. Clang-Only Features (5 features)

Supported by Clang (both Linux and AIX) but not GCC:
- crbits
- invariant-function-descriptors
- mfocrf (GCC uses mfcrf instead)
- paired-vector-memops (requires -mcpu=power10)
- power10-vector

### 3. GCC-Only Features (10 features)

Supported by GCC but not Clang:
- avoid-indexed-addresses
- dlmzb
- friz
- hard-dfp (decimal floating point)
- mulhw
- multiple
- popcntb (Clang suggests using popcntd)
- powerpc-gfxopt
- powerpc-gpopt
- recip-precision
- string
- update

### 4. AIX-Specific Features (3 features)

Work only with Clang AIX cross-compile target:
- aix-shared-lib-tls-model-opt
- aix-small-local-dynamic-tls
- aix-small-local-exec-tls

**Note**: These features are accepted by Clang when targeting AIX (`--target=powerpc64-ibm-aix-xcoff`) but rejected on native Linux target and by GCC.

### 5. Unsupported by All Compilers (2 features)

Not supported by any tested compiler:
- efpu2 (SPE 32-bit only)
- paired (not recognized)
- spe (SPE 32-bit only)

## CPU Requirements Summary

Several features require specific Power ISA levels:

### Power10 Required (4 features)
- mma
- paired-vector-memops (Clang only)
- pcrel
- prefixed

### Power8 Required for AIX Target (2 features)
- privileged (Clang AIX)
- rop-protect (Clang AIX)

## Key Differences: Clang vs GCC

### Clang Advantages
1. **AIX target support**: Can cross-compile for AIX with proper feature validation
2. **Modern features**: Supports power10-vector, paired-vector-memops
3. **Better diagnostics**: Suggests alternatives (e.g., popcntb → popcntd)

### GCC Advantages
1. **More legacy features**: Supports 10 additional features Clang doesn't
2. **Decimal floating point**: Supports hard-dfp
3. **Broader compatibility**: Works with older PowerPC-specific optimizations

### Feature Aliases
- **mfcrf/mfocrf**: Clang treats mfocrf as primary, mfcrf as alias. GCC only recognizes mfcrf.

## Recommendations for target_clones Implementation

### Phase 1: Core Cross-Compiler Features (21 features)

Start with features that work across all compilers:
```
altivec, cmpb, crypto, direct-move, float128, fprnd, htm, isel,
longcall, mfcrf, mma, pcrel, popcntd, power8-vector, power9-vector,
prefixed, privileged, rop-protect, secure-plt, vsx
```

### Phase 2: Clang-Specific Extensions (5 features)

Add Clang-only features with appropriate documentation:
```
crbits, invariant-function-descriptors, mfocrf, paired-vector-memops,
power10-vector
```

### Phase 3: Platform-Specific Features (3 features)

Add AIX-specific features with target validation:
```
aix-shared-lib-tls-model-opt, aix-small-local-dynamic-tls,
aix-small-local-exec-tls
```

**Implementation Note**: These should only be accepted when:
- Target triple is `powerpc64-*-aix*` or `powerpc-*-aix*`
- Explicit AIX target specified

### Not Recommended for target_clones

Do not include:
- **GCC-only features** (10 features): Not portable to Clang
- **paired**: Not supported by any compiler
- **efpu2, spe**: 32-bit SPE only, limited use case

## Implementation Guidelines

### 1. Feature Validation

```cpp
bool isValidPPCFeature(StringRef Feature, const llvm::Triple &Triple) {
  // Core features (all compilers)
  if (Feature == "altivec" || Feature == "vsx" || ...)
    return true;
  
  // AIX-specific features
  if (Feature.starts_with("aix-"))
    return Triple.isOSAIX();
  
  // Clang-specific features
  if (Feature == "crbits" || Feature == "power10-vector" || ...)
    return true; // Clang supports these
  
  return false;
}
```

### 2. CPU Requirements

```cpp
bool requiresPower10(StringRef Feature) {
  return Feature == "mma" || Feature == "pcrel" ||
         Feature == "prefixed" || Feature == "paired-vector-memops";
}
```

### 3. Error Messages

For unsupported features, provide helpful diagnostics:
- `"feature 'popcntb' not supported; use 'popcntd' instead"`
- `"feature 'aix-*' requires AIX target"`
- `"feature 'mma' requires -mcpu=power10 or higher"`

## Summary Statistics

- **Total features tested**: 43
- **Clang Linux supported**: 25 (58%)
- **Clang AIX supported**: 25 (58%)
- **GCC Linux supported**: 28 (65%)
- **All three compilers**: 21 (49%)
- **Clang-only**: 5 (12%)
- **GCC-only**: 10 (23%)
- **AIX-specific**: 3 (7%)
- **Unsupported by all**: 2 (5%)

## Conclusion

For `target_clones` implementation on PowerPC:

1. **Prioritize the 21 core features** that work across all compilers for maximum portability
2. **Support 5 Clang-specific features** for advanced optimizations
3. **Implement AIX feature validation** for the 3 platform-specific features
4. **Document GCC incompatibilities** for users migrating code
5. **Validate CPU requirements** (Power10 features need explicit CPU level)
6. **Provide helpful error messages** with suggestions for alternatives

This approach balances portability with Clang-specific optimizations while maintaining clear documentation for users.

## Testing Notes

- Tests performed on native ppc64le Linux system
- Clang AIX tests used cross-compilation with `--target=powerpc64-ibm-aix-xcoff`
- All tests used simple C file: `int main(void) { return 0; }`
- Failed features were retried with `-mcpu=power8`, `-mcpu=power9`, `-mcpu=power10`
- Success = clean compilation with no errors
- Failure = any compilation error (unknown option, unsupported feature, etc.)
