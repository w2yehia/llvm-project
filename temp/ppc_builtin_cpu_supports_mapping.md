# PowerPC Target Attribute to __builtin_cpu_supports() Mapping

This document maps the 28 Clang-supported PowerPC target attribute feature strings to their corresponding `__builtin_cpu_supports()` runtime check strings.

## Mapping Table

| Target Attribute Feature | __builtin_cpu_supports() String | ISA Level | Notes |
|--------------------------|----------------------------------|-----------|-------|
| **Direct Matches (9 features)** |
| altivec | "altivec" | - | Direct match |
| htm | "htm" | - | Direct match |
| isel | "isel" | - | Direct match |
| mma | "mma" | POWER10 | Direct match |
| vsx | "vsx" | - | Direct match |
| dfp (hard-dfp equivalent) | "dfp" | - | Decimal floating point |
| darn (crypto related) | "darn" | POWER9 | Random number generation |
| tar | "tar" | POWER8 | Target address register |
| vcrypto (crypto) | "vcrypto" | - | Vector crypto |
| **ISA Level Mappings (7 features)** |
| cmpb | "arch_2_05" | POWER6 | Compare bytes (ISA 2.05) |
| fprnd | "arch_2_05" | POWER6 | FP round (ISA 2.05) |
| popcntd | "arch_2_06" | POWER7 | Population count (ISA 2.06) |
| crypto | "arch_2_07" | POWER8 | Crypto extensions (ISA 2.07) |
| direct-move | "arch_2_07" | POWER8 | VSR<->GPR moves (ISA 2.07) |
| power8-vector | "arch_2_07" | POWER8 | POWER8 vector (ISA 2.07) |
| power9-vector | "arch_3_00" | POWER9 | POWER9 vector (ISA 3.0) |
| **POWER10 Features (5 features)** |
| mma | "mma" | POWER10 | Matrix-multiply assist |
| paired-vector-memops | "arch_3_1" | POWER10 | Paired vector ops (ISA 3.1) |
| pcrel | "arch_3_1" | POWER10 | PC-relative (ISA 3.1) |
| power10-vector | "arch_3_1" | POWER10 | POWER10 vector (ISA 3.1) |
| prefixed | "arch_3_1" | POWER10 | Prefixed instructions (ISA 3.1) |
| **No Direct Runtime Check (7 features)** |
| aix-shared-lib-tls-model-opt | N/A | - | AIX compile-time only |
| aix-small-local-dynamic-tls | N/A | - | AIX compile-time only |
| aix-small-local-exec-tls | N/A | - | AIX compile-time only |
| crbits | N/A | - | Optimization hint, no runtime check |
| float128 | "ieee128" | - | IEEE 128-bit float (use "ieee128") |
| invariant-function-descriptors | N/A | - | AIX ABI feature, no runtime check |
| longcall | N/A | - | Code generation option, no runtime check |
| mfcrf | N/A | - | Basic instruction, always available |
| mfocrf | N/A | - | Alias for mfcrf, always available |
| privileged | N/A | - | Privileged mode, no runtime check |
| rop-protect | N/A | - | Security feature, no runtime check |
| secure-plt | N/A | - | Linking option, no runtime check |

## Available __builtin_cpu_supports() Strings

### Linux (from PPC_LNX_FEATURE)
```
4xxmac, altivec, arch_2_05, arch_2_06, arch_2_07, arch_3_00, arch_3_1,
archpmu, booke, cellbe, darn, dfp, dscr, ebb, efpdouble, efpsingle,
fpu, htm, htm-nosc, htm-no-suspend, ic_snoop, ieee128, isel, mma, mmu,
notb, pa6t, power4, power5, power5+, power6x, ppc32, ppc601, ppc64,
ppcle, scv, smt, spe, tar, true_le, ucache, vcrypto, vsx
```

### AIX (from PPC_AIX_FEATURE)
```
4xxmac, altivec, arch_2_05, arch_2_06, arch_2_07, arch_3_00, arch_3_1,
booke, cellbe, darn, dfp, dscr, ebb, efpsingle, efpdouble, fpu, htm,
isel, mma, mmu, pa6t, power4, power5, power5+, power6x, ppc32, ppc601,
ppc64, ppcle, smt, spe, tar, true_le, ucache, vsx
```

## Recommended Mapping Strategy

### 1. Features with Direct __builtin_cpu_supports() Match (9 features)
Use the corresponding string directly:
```c
// Example for altivec
if (__builtin_cpu_supports("altivec")) {
    return altivec_version();
}
```

### 2. Features Mapped to ISA Levels (7 features)
Use the ISA level check:
```c
// Example for power8-vector
if (__builtin_cpu_supports("arch_2_07")) {
    return power8_vector_version();
}
```

### 3. POWER10 Features (5 features)
Use either specific feature or ISA 3.1:
```c
// Example for mma (has direct support)
if (__builtin_cpu_supports("mma")) {
    return mma_version();
}

// Example for pcrel (use ISA level)
if (__builtin_cpu_supports("arch_3_1")) {
    return pcrel_version();
}
```

### 4. Features Without Runtime Check (7 features)
These require alternative strategies:

**AIX-specific features (3):**
- Compile-time only, no runtime check needed
- Should be resolved at compile time based on target

**Optimization/ABI features (4):**
- `crbits`, `invariant-function-descriptors`, `longcall`, `secure-plt`
- These are compile-time optimizations, not runtime-detectable
- Should not be used in target_clones (or always available)

**Basic instructions (2):**
- `mfcrf`, `mfocrf`
- Always available on supported platforms
- Can assume present if base ISA level is met

**Security/privilege features (2):**
- `privileged`, `rop-protect`
- Not runtime-detectable via __builtin_cpu_supports
- May need alternative detection or compile-time only

## Special Cases

### float128
- Target attribute: `float128`
- Runtime check: `__builtin_cpu_supports("ieee128")`
- Note: Different naming between attribute and runtime check

### crypto
- Target attribute: `crypto`
- Runtime check: `__builtin_cpu_supports("vcrypto")` OR `__builtin_cpu_supports("arch_2_07")`
- Note: Can use either vector crypto or ISA level

### mfcrf vs mfocrf
- Both are aliases in Clang
- No runtime check needed (basic instructions)
- Always available on 64-bit PowerPC

## Implementation Notes for target_clones

1. **Priority Order**: Features should be checked in order of specificity:
   - Specific feature checks (mma, altivec, etc.)
   - ISA level checks (arch_3_1, arch_3_00, etc.)
   - Base/default version

2. **Combining Features**: When multiple features are specified:
   ```c
   if (__builtin_cpu_supports("mma") && __builtin_cpu_supports("vsx")) {
       return mma_vsx_version();
   }
   ```

3. **Fallback Strategy**: Always provide a base version with no requirements

4. **AIX vs Linux**: Some features have different availability:
   - Check target platform in resolver
   - Use appropriate __builtin_cpu_supports strings

## Uncertain Mappings (Need Review)

The following features need further investigation:

1. **crbits**: Condition register bit optimization
   - No direct __builtin_cpu_supports equivalent
   - May need ISA level check or always-available assumption

2. **invariant-function-descriptors**: AIX ABI feature
   - Compile-time only, no runtime equivalent
   - Should be resolved at compile time

3. **privileged**: Privileged mode instructions
   - No __builtin_cpu_supports equivalent
   - May need alternative detection method

4. **rop-protect**: ROP protection
   - Security feature, no runtime check
   - Likely compile-time only

5. **secure-plt**: PLT security
   - Linking option, no runtime equivalent
   - Compile-time only

## Summary

- **16 features** have clear __builtin_cpu_supports() mappings
- **5 features** can use ISA level checks as proxy
- **7 features** have no runtime check (compile-time only or always available)

For target_clones implementation, focus on the 21 features with runtime checks, and handle the remaining 7 as compile-time decisions or always-available features.
