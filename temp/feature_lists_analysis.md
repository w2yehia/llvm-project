# Feature Lists Analysis for PPC target_clones

## Key Finding: Different Lists for Different Purposes

On x86, Clang has **separate** feature lists for:
1. `isValidFeatureName()` - Used for `target` and `target_clones` attributes
2. `validateCpuSupports()` - Used for `__builtin_cpu_supports()` builtin

**Current PPC implementation incorrectly uses `validateCpuSupports()` for `isValidFeatureName()`**

## 1. PPC AIX __builtin_cpu_supports Features

From `llvm/include/llvm/TargetParser/PPCTargetParser.def` (PPC_AIX_FEATURE):

```
altivec, arch_2_05, arch_2_06, arch_2_07, arch_3_00, arch_3_1
darn, dfp, dscr, ebb, fpu, htm, isel, mma, mmu
power4, power5, power5+, ppc32, ppc64, smt, tar, true_le, ucache, vsx
```

**Not supported on AIX** (BUILTIN_PPC_FALSE):
- 4xxmac, booke, cellbe, efpsingle, efpdouble, pa6t, ppc601, ppcle, spe

## 2. PPC Linux __builtin_cpu_supports Features

From `llvm/include/llvm/TargetParser/PPCTargetParser.def` (PPC_LNX_FEATURE):

All AIX features PLUS:
```
4xxmac, archpmu, booke, cellbe, efpdouble, efpsingle, htm-nosc, htm-no-suspend
ic_snoop, ieee128, notb, pa6t, power6x, ppc601, ppcle, scv, spe, vcrypto
```

## 3. Current Clang PPC isValidFeatureName() Implementation

Location: `clang/lib/Basic/Targets/PPC.cpp:830-835`

```cpp
bool PPCTargetInfo::isValidFeatureName(StringRef Name) const {
  // For now, we will support any string accepted by __builtin_cpu_supports
  return validateCpuSupports(Name);
}
```

**This delegates to validateCpuSupports(), which uses PPCTargetParser.def**

## 4. X86 Comparison: isValidFeatureName()

Location: `clang/lib/Basic/Targets/X86.cpp:1076+`

Explicit hardcoded list (partial):
```cpp
bool X86TargetInfo::isValidFeatureName(StringRef Name) const {
  return llvm::StringSwitch<bool>(Name)
      .Case("adx", true)
      .Case("aes", true)
      .Case("amx-avx512", true)
      .Case("amx-bf16", true)
      // ... many more ...
      .Case("avx", true)
      .Case("avx2", true)
      .Case("avx512f", true)
      // ... etc ...
      .Default(false);
}
```

## 5. X86 Comparison: validateCpuSupports()

Location: `clang/lib/Basic/Targets/X86.cpp:1327+`

Uses X86TargetParser.def:
```cpp
bool X86TargetInfo::validateCpuSupports(StringRef FeatureStr) const {
  return llvm::StringSwitch<bool>(FeatureStr)
#define X86_FEATURE_COMPAT(ENUM, STR, PRIORITY, ABI_VALUE) .Case(STR, true)
#define X86_MICROARCH_LEVEL(ENUM, STR, PRIORITY, ABI_VALUE) .Case(STR, true)
#include "llvm/TargetParser/X86TargetParser.def"
      .Default(false);
}
```

## Key Observations

### X86 Pattern
- **isValidFeatureName()**: Explicit hardcoded list for target/target_clones attributes
- **validateCpuSupports()**: Uses X86TargetParser.def for __builtin_cpu_supports
- **These are DIFFERENT lists!**

### Current PPC Implementation
- **isValidFeatureName()**: Delegates to validateCpuSupports() ❌
- **validateCpuSupports()**: Uses PPCTargetParser.def ✅

### Problem
The current PPC implementation assumes that features valid for `__builtin_cpu_supports()` are the same as features valid for `target`/`target_clones` attributes. **This may not be correct!**

## Questions to Answer

1. **What features does GCC accept for `target` attribute on PPC?**
   - Need to test or find GCC documentation

2. **What features does GCC accept for `target_clones` attribute on PPC?**
   - According to user: "exactly the list accepted by the 'target' attribute"

3. **Are these the same as __builtin_cpu_supports features?**
   - On x86: NO (different lists)
   - On PPC: Unknown, need to verify

## Next Steps

1. Test GCC to determine what features it accepts for:
   - `__attribute__((target("feature")))`
   - `__attribute__((target_clones("feature")))`
   - `__builtin_cpu_supports("feature")`

2. Compare with current Clang implementation

3. Update `isValidFeatureName()` if needed with correct list

## Prototype Implementation Issue

The current prototype at commit `bc27b39f20b9` has:

```cpp
bool PPCTargetInfo::isValidFeatureName(StringRef Name) const {
  // List of valid PPC features for target_clones on AIX
  return llvm::StringSwitch<bool>(Name)
      .Case("altivec", true)
      .Case("crbits", true)
      .Case("vsx", true)
      .Case("power8-vector", true)
      .Case("crypto", true)
      .Case("htm", true)
      .Case("power9-vector", true)
      .Case("power10-vector", true)
      // Add more features as needed
      .Default(false);
}
```

**This is a hardcoded list, but we need to verify it matches GCC's accepted features!**

Note: "crbits" is in the list but NOT in PPCTargetParser.def for __builtin_cpu_supports!
