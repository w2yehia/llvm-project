# GCC Feature Testing Plan for PPC target/target_clones

## Objective

Determine the exact list of features that GCC accepts for:
1. `__attribute__((target("feature")))` on PPC
2. `__attribute__((target_clones("feature")))` on PPC  
3. `__builtin_cpu_supports("feature")` on PPC

## Test Environment Requirements

- GCC compiler for PowerPC (preferably on AIX)
- Access to compile and test on PPC/AIX system
- GCC version: Latest stable (or version matching target deployment)

## Test Cases

### Test 1: __builtin_cpu_supports() Features

**Purpose**: Verify runtime feature detection capabilities

**Test Code**:
```c
// test_builtin_cpu_supports.c
#include <stdio.h>

int main() {
    // Test each feature from PPCTargetParser.def
    const char* features[] = {
        "4xxmac", "altivec", "arch_2_05", "arch_2_06", "arch_2_07", 
        "arch_3_00", "arch_3_1", "archpmu", "booke", "cellbe",
        "darn", "dfp", "dscr", "ebb", "efpdouble", "efpsingle",
        "fpu", "htm", "htm-nosc", "htm-no-suspend", "ic_snoop",
        "ieee128", "isel", "mma", "mmu", "notb", "pa6t",
        "power4", "power5", "power5+", "power6x", "ppc32", "ppc601",
        "ppc64", "ppcle", "scv", "smt", "spe", "tar", "true_le",
        "ucache", "vcrypto", "vsx",
        NULL
    };
    
    for (int i = 0; features[i] != NULL; i++) {
        if (__builtin_cpu_supports(features[i])) {
            printf("SUPPORTED: %s\n", features[i]);
        } else {
            printf("NOT_SUPPORTED: %s\n", features[i]);
        }
    }
    return 0;
}
```

**Compile**: `gcc -o test_builtin test_builtin_cpu_supports.c`

**Expected**: Should compile successfully. Features that don't compile indicate invalid feature names.

---

### Test 2: target Attribute Features

**Purpose**: Determine which features are accepted by the `target` attribute

**Test Code Template**:
```c
// test_target_attribute.c
// Test each feature individually

__attribute__((target("altivec")))
void test_altivec() {}

__attribute__((target("vsx")))
void test_vsx() {}

__attribute__((target("power8-vector")))
void test_power8_vector() {}

__attribute__((target("power9-vector")))
void test_power9_vector() {}

__attribute__((target("power10-vector")))
void test_power10_vector() {}

__attribute__((target("crypto")))
void test_crypto() {}

__attribute__((target("htm")))
void test_htm() {}

__attribute__((target("mma")))
void test_mma() {}

__attribute__((target("arch_2_06")))
void test_arch_2_06() {}

__attribute__((target("arch_2_07")))
void test_arch_2_07() {}

__attribute__((target("arch_3_00")))
void test_arch_3_00() {}

__attribute__((target("arch_3_1")))
void test_arch_3_1() {}

// Test negations
__attribute__((target("no-altivec")))
void test_no_altivec() {}

__attribute__((target("no-vsx")))
void test_no_vsx() {}

// Test features from __builtin_cpu_supports that might not work
__attribute__((target("dfp")))
void test_dfp() {}

__attribute__((target("darn")))
void test_darn() {}

__attribute__((target("isel")))
void test_isel() {}

__attribute__((target("smt")))
void test_smt() {}

// Test invalid/unknown features
__attribute__((target("invalid_feature_xyz")))
void test_invalid() {}

__attribute__((target("crbits")))
void test_crbits() {}

int main() { return 0; }
```

**Compile**: `gcc -c test_target_attribute.c 2>&1 | tee target_results.txt`

**Analysis**: 
- Features that compile successfully are VALID for target attribute
- Features that produce errors are INVALID
- Note the exact error messages

---

### Test 3: target_clones Attribute Features

**Purpose**: Verify target_clones accepts same features as target

**Test Code**:
```c
// test_target_clones.c

__attribute__((target_clones("default", "altivec")))
void test_altivec_clone() {}

__attribute__((target_clones("default", "vsx")))
void test_vsx_clone() {}

__attribute__((target_clones("default", "power8-vector")))
void test_power8_vector_clone() {}

__attribute__((target_clones("default", "power9-vector")))
void test_power9_vector_clone() {}

__attribute__((target_clones("default", "power10-vector")))
void test_power10_vector_clone() {}

__attribute__((target_clones("default", "crypto")))
void test_crypto_clone() {}

__attribute__((target_clones("default", "htm")))
void test_htm_clone() {}

__attribute__((target_clones("default", "mma")))
void test_mma_clone() {}

// Test negations
__attribute__((target_clones("default", "no-altivec")))
void test_no_altivec_clone() {}

__attribute__((target_clones("default", "no-vsx")))
void test_no_vsx_clone() {}

// Test multiple features
__attribute__((target_clones("default", "altivec", "vsx", "power8-vector")))
void test_multiple_features() {}

// Test conflicts
__attribute__((target_clones("default", "altivec", "no-altivec")))
void test_conflict() {}

// Test CPU specifications
__attribute__((target_clones("default", "cpu=pwr8", "cpu=pwr9", "cpu=pwr10")))
void test_cpu_specs() {}

// Test mixing CPU and features
__attribute__((target_clones("default", "cpu=pwr10", "altivec")))
void test_mixed() {}

// Test arch features
__attribute__((target_clones("default", "arch_2_06")))
void test_arch_2_06_clone() {}

__attribute__((target_clones("default", "arch_2_07")))
void test_arch_2_07_clone() {}

__attribute__((target_clones("default", "arch_3_00")))
void test_arch_3_00_clone() {}

__attribute__((target_clones("default", "arch_3_1")))
void test_arch_3_1_clone() {}

// Test features from __builtin_cpu_supports
__attribute__((target_clones("default", "dfp")))
void test_dfp_clone() {}

__attribute__((target_clones("default", "darn")))
void test_darn_clone() {}

__attribute__((target_clones("default", "isel")))
void test_isel_clone() {}

// Test invalid
__attribute__((target_clones("default", "invalid_feature_xyz")))
void test_invalid_clone() {}

__attribute__((target_clones("default", "crbits")))
void test_crbits_clone() {}

int main() { return 0; }
```

**Compile**: `gcc -c test_target_clones.c 2>&1 | tee target_clones_results.txt`

**Analysis**:
- Compare results with target attribute test
- Verify user's claim: "exactly the list accepted by the 'target' attribute"

---

### Test 4: Case Sensitivity

**Test Code**:
```c
// test_case_sensitivity.c

__attribute__((target("altivec")))
void test_lowercase() {}

__attribute__((target("ALTIVEC")))
void test_uppercase() {}

__attribute__((target("AltiVec")))
void test_mixedcase() {}

__attribute__((target_clones("default", "altivec")))
void test_clone_lowercase() {}

__attribute__((target_clones("default", "ALTIVEC")))
void test_clone_uppercase() {}

int main() { return 0; }
```

**Expected**: Only lowercase should work (confirmed in IMPLEMENTATION_PLAN.md)

---

### Test 5: Feature Combinations

**Test Code**:
```c
// test_combinations.c

// Single string with multiple features (should FAIL per IMPLEMENTATION_PLAN.md)
__attribute__((target("altivec+vsx")))
void test_combined_plus() {}

__attribute__((target("altivec,vsx")))
void test_combined_comma() {}

__attribute__((target_clones("default", "altivec+vsx")))
void test_clone_combined() {}

// Separate parameters (should SUCCEED)
__attribute__((target_clones("default", "altivec", "vsx")))
void test_clone_separate() {}

int main() { return 0; }
```

**Expected**: Combined features in single string should fail

---

## Test Execution Steps

1. **Compile each test file individually**:
   ```bash
   gcc -c test_builtin_cpu_supports.c -o test1.o 2>&1 | tee test1_errors.txt
   gcc -c test_target_attribute.c -o test2.o 2>&1 | tee test2_errors.txt
   gcc -c test_target_clones.c -o test3.o 2>&1 | tee test3_errors.txt
   gcc -c test_case_sensitivity.c -o test4.o 2>&1 | tee test4_errors.txt
   gcc -c test_combinations.c -o test5.o 2>&1 | tee test5_errors.txt
   ```

2. **Analyze error messages**:
   - Look for patterns like: `__attribute__((__target__('feature'))) is invalid`
   - Identify which features are accepted vs rejected

3. **Run the __builtin_cpu_supports test** (if it compiles):
   ```bash
   gcc test_builtin_cpu_supports.c -o test_builtin
   ./test_builtin > builtin_results.txt
   ```

4. **Check generated symbols** for target_clones:
   ```bash
   nm test3.o | grep -E '\.(default|altivec|vsx|power|no_)'
   ```
   This shows the mangled function names

---

## Expected Results Format

Create a summary table:

| Feature | target attr | target_clones | __builtin_cpu_supports | Notes |
|---------|-------------|---------------|------------------------|-------|
| altivec | ✅ | ✅ | ✅ | |
| vsx | ✅ | ✅ | ✅ | |
| power8-vector | ? | ? | ? | |
| arch_2_06 | ? | ? | ✅ | |
| crbits | ? | ? | ❌ | Not in PPCTargetParser.def |
| invalid_xyz | ❌ | ❌ | ❌ | |

---

## Questions to Answer

1. **Are target and target_clones feature lists identical?**
   - User claims: YES
   - Verify with testing

2. **Do target/target_clones accept all __builtin_cpu_supports features?**
   - x86 pattern: NO (different lists)
   - PPC: Unknown, need to test

3. **Which features are in target/target_clones but NOT in __builtin_cpu_supports?**
   - Example: "crbits" in prototype but not in PPCTargetParser.def
   - Example: "power8-vector" vs "arch_2_07"

4. **What is the relationship between feature names?**
   - "power8-vector" vs "arch_2_07"
   - "power9-vector" vs "arch_3_00"
   - "power10-vector" vs "arch_3_1"

---

## Deliverables

After testing, provide:

1. **Complete list of valid features for target attribute**
2. **Complete list of valid features for target_clones attribute**
3. **Complete list of valid features for __builtin_cpu_supports**
4. **Comparison table showing differences**
5. **Recommended implementation for isValidFeatureName()**

---

## Alternative: GCC Source Code Analysis

If testing is not immediately available, examine GCC source code:

1. **Location**: `gcc/config/rs6000/rs6000.cc` (or similar)
2. **Look for**: 
   - `rs6000_valid_target_attribute_p()` function
   - Feature validation logic
   - Feature name tables

3. **GCC Documentation**:
   - https://gcc.gnu.org/onlinedocs/gcc/PowerPC-Function-Attributes.html
   - https://gcc.gnu.org/onlinedocs/gcc/PowerPC-Built-in-Functions.html

---

## Notes

- The prototype implementation has "crbits" which is NOT in PPCTargetParser.def
- Need to verify if "crbits" is a valid GCC feature name
- Need to understand feature name aliases (e.g., "power8-vector" vs other names)
- Priority ordering may depend on feature relationships
