# GCC target_clones Attribute Test Results (PPC Linux)

## Test Environment
- GCC Version: 13.3.1 20240529 (Advance-Toolchain 17.0-2)
- Platform: PowerPC Linux
- Test File: test_gcc_target_clones.c
- Compilation: `-mcpu=power10` (required for mma feature)

## Results Summary

### ✅ ALL target_clones Tests PASSED

**Key Finding**: All features that work with `target` attribute also work with `target_clones` attribute.

This confirms the user's statement: *"the list of features accepted by gcc on target_clones is exactly the list accepted by the 'target' attribute"*

### Valid Features for target_clones

| Feature | Status | Mangled Name | Notes |
|---------|--------|--------------|-------|
| altivec | ✅ VALID | `.altivec` | |
| vsx | ✅ VALID | `.vsx` | |
| power8-vector | ✅ VALID | `.power8_vector` | Hyphen → underscore |
| power9-vector | ✅ VALID | `.power9_vector` | Hyphen → underscore |
| crypto | ✅ VALID | `.crypto` | |
| htm | ✅ VALID | `.htm` | |
| isel | ✅ VALID | `.isel` | |
| mma | ✅ VALID | `.mma` | Requires `-mcpu=power10` |
| no-altivec | ✅ VALID | `.no_altivec` | Warning: disables vsx |
| no-vsx | ✅ VALID | `.no_vsx` | |

### Name Mangling Pattern

GCC uses the following mangling pattern for target_clones:
- Base: `function_name.feature`
- Hyphens converted to underscores: `power8-vector` → `.power8_vector`
- Negations: `no-altivec` → `.no_altivec`
- Default: `.default`

**Examples from nm output**:
```
test_altivec_clone.altivec
test_altivec_clone.default
test_power8_vector_clone.power8_vector
test_no_altivec_clone.no_altivec
test_mma_clone.mma
```

### Multiple Features Test

```c
__attribute__((target_clones("default", "altivec", "vsx", "power8-vector")))
void test_multiple_features() {}
```

**Result**: ✅ SUCCESS - Generates 4 separate versions:
- `test_multiple_features.default`
- `test_multiple_features.altivec`
- `test_multiple_features.vsx`
- `test_multiple_features.power8_vector`

### Conflict Test

```c
__attribute__((target_clones("default", "altivec", "no-altivec")))
void test_conflict() {}
```

**Result**: ✅ SUCCESS - Generates 3 separate versions:
- `test_conflict.default`
- `test_conflict.altivec`
- `test_conflict.no_altivec`

**Warning**: `-mno-altivec' disables vsx` (as expected)

### CPU Specifications Test

```c
__attribute__((target_clones("default", "cpu=power8", "cpu=power9", "cpu=power10")))
void test_cpu_specs() {}
```

**Result**: ✅ SUCCESS - CPU specifications work alongside feature strings

### Mixed CPU and Features Test

```c
__attribute__((target_clones("default", "cpu=power10", "altivec")))
void test_mixed() {}
```

**Result**: ✅ SUCCESS - Can mix CPU specifications with feature strings:
- `test_mixed.default`
- `test_mixed.altivec`
- (CPU versions have different mangling - not shown in grep output)

## Comparison: target vs target_clones

| Aspect | target attribute | target_clones attribute |
|--------|------------------|-------------------------|
| Valid features | altivec, vsx, power8-vector, power9-vector, crypto, htm, isel, mma | **IDENTICAL** |
| Invalid features | arch_*, dfp, darn, smt, vcrypto, crbits, power10-vector | **IDENTICAL** |
| Negations | ✅ Supported | ✅ Supported |
| Multiple features | N/A (single function) | ✅ Creates multiple versions |
| CPU specs | ✅ Supported | ✅ Supported |
| Mixing CPU + features | N/A | ✅ Supported |

## Key Observations

1. **Feature Lists are Identical**: target and target_clones accept exactly the same features
2. **Name Mangling**: Hyphens in feature names become underscores in mangled names
3. **Negations Work**: `no-feature` syntax is fully supported
4. **Conflicts Allowed**: Can specify both `altivec` and `no-altivec` (generates separate versions)
5. **mma Requires power10**: The mma feature needs `-mcpu=power10` to compile
6. **CPU + Features Mix**: Can combine CPU specifications with feature strings

## Implications for Clang Implementation

### Current Prototype Issues

1. ❌ **crbits** - Should be REMOVED (GCC rejects it)
2. ❌ **power10-vector** - Should be REMOVED (GCC rejects it)
3. ✅ **Missing isel** - Should be ADDED (GCC accepts it)

### Correct isValidFeatureName() Implementation

```cpp
bool PPCTargetInfo::isValidFeatureName(StringRef Name) const {
  // List of valid PPC features for target/target_clones
  // Based on GCC 13.3.1 testing on PPC Linux
  return llvm::StringSwitch<bool>(Name)
      .Case("altivec", true)
      .Case("vsx", true)
      .Case("power8-vector", true)
      .Case("power9-vector", true)
      .Case("crypto", true)
      .Case("htm", true)
      .Case("isel", true)
      .Case("mma", true)  // Note: requires power10 CPU
      .Default(false);
}
```

### Name Mangling Implementation

The current prototype correctly handles hyphen → underscore conversion:
```cpp
std::string MangledFeature = Feature.str();
std::replace(MangledFeature.begin(), MangledFeature.end(), '-', '_');
```

This matches GCC behavior: `power8-vector` → `.power8_vector`

## Conclusion

✅ **User's claim confirmed**: The feature list for target_clones is exactly the same as for target attribute on PPC Linux.

✅ **Implementation validated**: The prototype's approach is correct, but needs these adjustments:
- Remove: crbits, power10-vector
- Add: isel
- Keep: altivec, vsx, power8-vector, power9-vector, crypto, htm, mma
