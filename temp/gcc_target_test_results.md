# GCC Target Attribute Test Results (PPC Linux)

## Test Environment
- GCC Version: 13.3.1 20240529 (Advance-Toolchain 17.0-2)
- Platform: PowerPC Linux
- Test File: test_gcc_target_attr.c

## Results Summary

### ✅ VALID Features (Accepted by GCC target attribute)

| Feature | Status | Notes |
|---------|--------|-------|
| altivec | ✅ VALID | |
| vsx | ✅ VALID | |
| power8-vector | ✅ VALID | |
| power9-vector | ✅ VALID | |
| crypto | ✅ VALID | |
| htm | ✅ VALID | |
| isel | ✅ VALID | |
| no-altivec | ✅ VALID | Warning: '-mno-altivec' disables vsx |
| no-vsx | ✅ VALID | |

### ❌ INVALID Features (Rejected by GCC target attribute)

| Feature | Error Message |
|---------|---------------|
| power10-vector | `__attribute__((__target__('power10-vector'))) is invalid` |
| arch_2_06 | `__attribute__((__target__('arch_2_06'))) is invalid` |
| arch_2_07 | `__attribute__((__target__('arch_2_07'))) is invalid` |
| arch_3_00 | `__attribute__((__target__('arch_3_00'))) is invalid` |
| arch_3_1 | `__attribute__((__target__('arch_3_1'))) is invalid` |
| dfp | `__attribute__((__target__('dfp'))) is invalid` |
| darn | `__attribute__((__target__('darn'))) is invalid` |
| smt | `__attribute__((__target__('smt'))) is invalid` |
| vcrypto | `__attribute__((__target__('vcrypto'))) is invalid` |
| crbits | `__attribute__((__target__('crbits'))) is invalid` |
| invalid_feature_xyz | `__attribute__((__target__('invalid_feature_xyz'))) is invalid` |

### ⚠️ SPECIAL CASE

| Feature | Error Message | Notes |
|---------|---------------|-------|
| mma | `'-mmma' requires '-mcpu=power10'` | Might be valid with appropriate CPU setting |

## Key Findings

### 1. arch_* Features NOT Valid for target Attribute
The `arch_2_06`, `arch_2_07`, `arch_3_00`, `arch_3_1` features are:
- ✅ VALID for `__builtin_cpu_supports()` (in PPCTargetParser.def)
- ❌ INVALID for `target` attribute

**This confirms the x86 pattern: Different feature lists for different purposes!**

### 2. __builtin_cpu_supports Features NOT Valid for target
Many features valid for `__builtin_cpu_supports()` are INVALID for `target` attribute:
- dfp, darn, smt, vcrypto (all in PPCTargetParser.def)

### 3. crbits is INVALID
The prototype implementation includes "crbits" but GCC rejects it:
- ❌ NOT in PPCTargetParser.def
- ❌ NOT accepted by GCC target attribute
- **Should be REMOVED from isValidFeatureName()**

### 4. power10-vector is INVALID
Despite being in the prototype, GCC rejects it for target attribute.

### 5. vcrypto vs crypto
- `crypto` ✅ VALID
- `vcrypto` ❌ INVALID
The prototype should use "crypto", not "vcrypto"

## Comparison with Prototype Implementation

### Prototype's isValidFeatureName() List:
```cpp
.Case("altivec", true)      // ✅ CORRECT
.Case("crbits", true)       // ❌ WRONG - GCC rejects this
.Case("vsx", true)          // ✅ CORRECT
.Case("power8-vector", true) // ✅ CORRECT
.Case("crypto", true)       // ✅ CORRECT
.Case("htm", true)          // ✅ CORRECT
.Case("power9-vector", true) // ✅ CORRECT
.Case("power10-vector", true) // ❌ WRONG - GCC rejects this
```

### Missing from Prototype:
- `isel` ✅ (GCC accepts it)

### Should be Removed from Prototype:
- `crbits` ❌ (GCC rejects it)
- `power10-vector` ❌ (GCC rejects it)

## Recommended isValidFeatureName() Implementation

```cpp
bool PPCTargetInfo::isValidFeatureName(StringRef Name) const {
  // List of valid PPC features for target/target_clones on Linux
  // Based on GCC 13.3.1 testing
  return llvm::StringSwitch<bool>(Name)
      .Case("altivec", true)
      .Case("vsx", true)
      .Case("power8-vector", true)
      .Case("power9-vector", true)
      .Case("crypto", true)
      .Case("htm", true)
      .Case("isel", true)
      // Note: mma might need special handling (requires power10 CPU)
      // Note: power10-vector is NOT accepted by GCC target attribute
      // Note: arch_* features are for __builtin_cpu_supports only
      .Default(false);
}
```

## Next Steps

1. ✅ Test target_clones attribute with same features
2. ✅ Verify mma behavior with different CPU settings
3. ✅ Update prototype implementation to match GCC behavior
4. ✅ Remove invalid features (crbits, power10-vector)
5. ✅ Add missing feature (isel)
