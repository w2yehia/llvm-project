# Implementation Plan: Extending target_clones on AIX to Support Feature Strings

## Project Overview

Extend the `target_clones` attribute on AIX/PowerPC to accept feature strings (e.g., "altivec", "no-altivec") in addition to the currently supported CPU specifications.

**Initial Goal**: Support specifying a single feature or its negation: "altivec" and "no-altivec"

**Final Goal**: Support multiple features like `target_clones("default", "altivec", "vsx")`

**Base Commit**: 495c518b96cb (implements target_clones CPU-only support on AIX)

---

## Table of Contents

1. [Current Implementation Analysis](#current-implementation-analysis)
2. [Requirements](#requirements)
3. [Detailed Code Modifications](#detailed-code-modifications)
4. [Implementation Strategy](#implementation-strategy)
5. [Success Criteria](#success-criteria)
6. [References](#references)

---

## Current Implementation Analysis

### Key Files and Their Roles

| File | Purpose | Current State |
|------|---------|---------------|
| `clang/lib/Sema/SemaPPC.cpp` | Validates target_clones parameters | Rejects feature strings |
| `clang/lib/AST/ASTContext.cpp` | Builds feature maps for functions | Only handles CPU specs |
| `clang/lib/CodeGen/CodeGenFunction.cpp` | Generates resolver functions | Only handles CPU-based selection |
| `clang/lib/CodeGen/Targets/PPC.cpp` | Name mangling for function versions | Only handles CPU mangling |
| `clang/lib/Basic/Targets/PPC.cpp` | Target-specific parsing and priority | Only handles CPU priority |
| `clang/lib/Basic/Targets/PPC.h` | PPCTargetInfo class definition | Missing `isValidFeatureName()` |
| `clang/include/clang/Basic/AttrDocs.td` | Documentation | States CPU-only support |

### Current Behavior

The implementation in `SemaPPC.cpp::checkTargetClonesAttr()` (lines 605-673):

```cpp
bool SemaPPC::checkTargetClonesAttr(...) {
  // Validates parameters
  // Accepts: "cpu=pwr10", "cpu=pwr8", "default"
  // Rejects: Feature strings with error:
  //   "it's a feature string, but not supported yet"
  
  if (LHS.starts_with("cpu=")) {
    // Validate CPU name
  } else if (LHS == "default") {
    HasDefault = true;
  } else {
    // Line ~653: Explicitly rejects feature strings
    return Diag(CurLoc, diag::warn_unsupported_target_attribute)
           << Unsupported << None << LHS << TargetClones;
  }
}
```

### Comparison with x86

x86 implementation (`SemaX86.cpp::checkTargetClonesAttr()`, lines 1056-1115) accepts both:

```cpp
if (LHS.starts_with("arch=")) {
  // Validate architecture
} else if (LHS == "default") {
  HasDefault = true;
} else if (!getASTContext().getTargetInfo().isValidFeatureName(LHS) ||
           getASTContext().getTargetInfo().getFMVPriority(LHS) == 0) {
  // Reject invalid features
  return Diag(...);
}
```

**Key Difference**: x86 uses `isValidFeatureName()` and `getFMVPriority()` to validate features.

---

## Requirements

### Functional Requirements

#### FR1: Feature String Parsing

- **FR1.1**: Accept feature strings in target_clones attribute (e.g., "altivec", "vsx")
- **FR1.2**: Accept negated features with "no-" prefix (e.g., "no-altivec", "no-vsx")
- **FR1.3**: Maintain backward compatibility with existing "cpu=XXX" syntax
  - **FR1.3.1**: All existing code using `target_clones("cpu=pwr10", "cpu=pwr8", "default")` must continue to work
  - **FR1.3.2**: The `cpu=` prefix must remain the way to specify CPU targets
  - **FR1.3.3**: Feature strings and CPU specifications can be mixed: `target_clones("cpu=pwr10", "altivec", "default")`
  - **FR1.3.4**: Each parameter creates a SEPARATE function version (they do NOT combine):
    - `"cpu=pwr10"` → version with `target-cpu=pwr10` in LLVM IR
    - `"altivec"` → version with default CPU + `target-features="+altivec"` in LLVM IR
    - `"default"` → version with default target-cpu and target-features
    - Example: `target_clones("cpu=pwr10", "altivec", "default")` creates 3 separate versions
  - **FR1.3.5**: No changes to existing name mangling for CPU-only specifications
  - **FR1.3.6**: Existing error messages and diagnostics for CPU specifications must remain unchanged
- **FR1.4**: Continue to require "default" option in all target_clones declarations

#### FR2: Feature Validation

- **FR2.1**: Validate that feature names are recognized PPC features
- **FR2.2**: Reject invalid or unsupported feature names with appropriate diagnostics
- **FR2.3**: Ensure features are appropriate for AIX platform
- **FR2.4**: Handle feature dependencies (e.g., some features require others)

#### FR3: Initial Implementation Scope

- **FR3.1**: Support "altivec" feature string
- **FR3.2**: Support "no-altivec" negation
- **FR3.3**: Allow mixing with existing cpu= syntax

#### FR4: Code Generation

- **FR4.1**: Generate appropriate function versions for each feature combination
- **FR4.2**: Generate resolver function to select correct version at runtime
- **FR4.3**: Use IFUNC mechanism (already supported on AIX)
- **FR4.4**: Update `ASTContext::getFunctionFeatureMap()` to handle feature strings from target_clones

### Non-Functional Requirements

#### NFR1: Compatibility
- Must not break existing code using cpu= syntax
- Must maintain ABI compatibility
- Must work with existing AIX IFUNC support

#### NFR2: Error Handling
- Clear, actionable error messages for invalid features
- Consistent with x86/ARM error message patterns
- Helpful suggestions when features are misspelled

#### NFR3: Documentation
- Update AttrDocs.td to reflect new capability
- Add examples showing feature string usage
- Document supported features for AIX/PPC

### Available PPC Features

From `PPC.h`, known feature flags:
- `altivec` (HasAltivec)
- `vsx` (HasVSX)
- `mma` (HasMMA)
- `htm` (HasHTM)
- `p8vector` (HasP8Vector)
- `p8crypto` (HasP8Crypto)
- `p9vector` (HasP9Vector)
- `p10vector` (HasP10Vector)
- `spe` (HasSPE)
- there could be more; TODO revisit later.

---

## Detailed Code Modifications

### 1. clang/lib/Basic/Targets/PPC.h

**Location**: Class definition
**Priority**: HIGH (Required first)

**Add Method Declaration:**
```cpp
class LLVM_LIBRARY_VISIBILITY PPCTargetInfo : public TargetInfo {
  // ... existing members ...
  
  // ADD THIS METHOD:
  bool isValidFeatureName(StringRef Name) const override;
  
  // ... rest of class ...
};
```

**Why**: Foundation for feature validation throughout the codebase.

---

### 2. clang/lib/Basic/Targets/PPC.cpp

**Location**: After existing methods
**Priority**: HIGH (Required first)

**Add Method Implementation:**
```cpp
bool PPCTargetInfo::isValidFeatureName(StringRef Name) const {
  // List of valid PPC features for target_clones
  return llvm::StringSwitch<bool>(Name)
      .Case("altivec", true)
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

**Why**: Validates that a feature name is recognized and supported for target_clones on PPC/AIX.

---

### 3. clang/lib/Sema/SemaPPC.cpp

**Location**: Line ~653 in `checkTargetClonesAttr()`
**Priority**: HIGH (Core validation)

**Current Code:**
```cpp
} else {
  // it's a feature string, but not supported yet.
  return Diag(CurLoc, diag::warn_unsupported_target_attribute)
         << Unsupported << None << LHS << TargetClones;
}
```

**Replace With:**
```cpp
} else {
  // Handle feature strings
  StringRef FeatureName = LHS;
  bool IsNegated = false;
  
  // Check for negation prefix
  if (FeatureName.starts_with("no-")) {
    IsNegated = true;
    FeatureName = FeatureName.drop_front(3);
  }
  
  // Validate feature name
  if (!TargetInfo.isValidFeatureName(FeatureName)) {
    return Diag(CurLoc, diag::warn_unsupported_target_attribute)
           << Unknown << None << LHS << TargetClones;
  }
  
  // TODO: Check if feature is appropriate for AIX
  // TODO: Handle feature dependencies
}
```

**Why**: This is the semantic validation that currently rejects feature strings. Needs to accept and validate them instead.

---

### 4. clang/lib/AST/ASTContext.cpp

**Location**: Line ~15254 in `getFunctionFeatureMap()`
**Priority**: HIGH (Feature map building)

**Current Code:**
```cpp
} else if (Target->getTriple().isOSAIX()) {
  std::vector<std::string> Features;
  StringRef VersionStr = TC->getFeatureStr(GD.getMultiVersionIndex());
  if (VersionStr.starts_with("cpu="))
    TargetCPU = VersionStr.drop_front(sizeof("cpu=") - 1);
  else
    assert(VersionStr == "default");  // <-- REMOVE THIS
  Target->initFeatureMap(FeatureMap, getDiagnostics(), TargetCPU, Features);
```

**Replace With:**
```cpp
} else if (Target->getTriple().isOSAIX()) {
  std::vector<std::string> Features;
  StringRef VersionStr = TC->getFeatureStr(GD.getMultiVersionIndex());
  if (VersionStr.starts_with("cpu="))
    TargetCPU = VersionStr.drop_front(sizeof("cpu=") - 1);
  else if (VersionStr != "default") {
    // Handle feature strings
    ParsedTargetAttr ParsedAttr = Target->parseTargetAttr(VersionStr);
    Features = ParsedAttr.Features;
  }
  Target->initFeatureMap(FeatureMap, getDiagnostics(), TargetCPU, Features);
```

**Why**: This function builds the feature map for each function version. Currently it only handles CPU specifications, needs to handle feature strings.

---

### 5. clang/lib/CodeGen/CodeGenFunction.cpp

**Location**: Line ~1850 in resolver generation
**Priority**: HIGH (Runtime selection)

**Current Code:**
```cpp
assert(RO.Features.size() == 1 &&
       "for now one feature requirement per version");

assert(RO.Features[0].starts_with("cpu="));  // <-- REMOVE THIS
StringRef CPU = RO.Features[0].split("=").second.trim();
StringRef Feature = llvm::StringSwitch<StringRef>(CPU)
                        .Case("pwr7", "arch_2_06")
                        .Case("pwr8", "arch_2_07")
                        .Case("pwr9", "arch_3_00")
                        .Case("pwr10", "arch_3_1")
                        .Case("pwr11", "arch_3_1")
                        .Default("error");

llvm::Value *Condition = EmitPPCBuiltinCpu(Feature);
```

**Replace With:**
```cpp
assert(RO.Features.size() == 1 &&
       "for now one feature requirement per version");

StringRef FeatureStr = RO.Features[0];
StringRef Feature;

if (FeatureStr.starts_with("cpu=")) {
  StringRef CPU = FeatureStr.split("=").second.trim();
  Feature = llvm::StringSwitch<StringRef>(CPU)
                .Case("pwr7", "arch_2_06")
                .Case("pwr8", "arch_2_07")
                .Case("pwr9", "arch_3_00")
                .Case("pwr10", "arch_3_1")
                .Case("pwr11", "arch_3_1")
                .Default("error");
} else {
  // Direct feature string (e.g., "altivec")
  Feature = FeatureStr;
}

llvm::Value *Condition = EmitPPCBuiltinCpu(Feature);
```

**Why**: This generates the resolver function that selects the correct version at runtime. Needs to handle both CPU and feature-based selection.

---

### 6. clang/lib/CodeGen/Targets/PPC.cpp

**Location**: Line ~160 in `appendAttributeMangling()`
**Priority**: HIGH (Name mangling)

**Current Code:**
```cpp
void AIXABIInfo::appendAttributeMangling(StringRef AttrStr,
                                         raw_ostream &Out) const {
  if (AttrStr == "default") {
    Out << ".default";
    return;
  }

  const TargetInfo &TI = CGT.getTarget();
  ParsedTargetAttr Info = TI.parseTargetAttr(AttrStr);

  if (!Info.CPU.empty()) {
    assert(Info.Features.empty() && "cannot have both a CPU and a feature");
    Out << ".cpu_" << Info.CPU;
    return;
  }

  assert(0 && "specifying target features on an FMV is unsupported on AIX");  // <-- REMOVE THIS
}
```

**Replace With:**
```cpp
void AIXABIInfo::appendAttributeMangling(StringRef AttrStr,
                                         raw_ostream &Out) const {
  if (AttrStr == "default") {
    Out << ".default";
    return;
  }

  const TargetInfo &TI = CGT.getTarget();
  ParsedTargetAttr Info = TI.parseTargetAttr(AttrStr);

  if (!Info.CPU.empty()) {
    assert(Info.Features.empty() && "cannot have both a CPU and a feature");
    Out << ".cpu_" << Info.CPU;
    return;
  }

  // Handle feature strings
  if (!Info.Features.empty()) {
    assert(Info.Features.size() == 1 && "one feature per version for now");
    StringRef Feature = Info.Features[0];
    // Remove leading '+' or '-' from feature
    if (Feature.starts_with("+") || Feature.starts_with("-"))
      Feature = Feature.drop_front(1);
    Out << "." << Feature;
    return;
  }

  llvm_unreachable("Invalid target_clones parameter");
}
```

**Why**: This function generates the mangled name suffix for each function version. Currently only handles CPU, needs to handle features.

---

### 7. clang/lib/Basic/Targets/PPC.cpp

**Location**: Line ~729 in `getFMVPriority()`
**Priority**: MEDIUM (Proper ordering)

**Current Code:**
```cpp
llvm::APInt PPCTargetInfo::getFMVPriority(ArrayRef<StringRef> Features) const {
  if (Features.empty())
    return llvm::APInt(32, 0);
  assert(Features.size() == 1 && "one feature/cpu per clone on PowerPC");
  ParsedTargetAttr ParsedAttr = parseTargetAttr(Features[0]);
  if (!ParsedAttr.CPU.empty()) {
    int Priority = llvm::StringSwitch<int>(ParsedAttr.CPU)
                       .Case("pwr7", 1)
                       .Case("pwr8", 2)
                       .Case("pwr9", 3)
                       .Case("pwr10", 4)
                       .Case("pwr11", 5)
                       .Default(0);
    return llvm::APInt(32, Priority);
  }
  assert(false && "unimplemented");  // <-- REMOVE THIS
  return llvm::APInt(32, 0);
}
```

**Replace With:**
```cpp
llvm::APInt PPCTargetInfo::getFMVPriority(ArrayRef<StringRef> Features) const {
  if (Features.empty())
    return llvm::APInt(32, 0);
  assert(Features.size() == 1 && "one feature/cpu per clone on PowerPC");
  ParsedTargetAttr ParsedAttr = parseTargetAttr(Features[0]);
  if (!ParsedAttr.CPU.empty()) {
    int Priority = llvm::StringSwitch<int>(ParsedAttr.CPU)
                       .Case("pwr7", 1)
                       .Case("pwr8", 2)
                       .Case("pwr9", 3)
                       .Case("pwr10", 4)
                       .Case("pwr11", 5)
                       .Default(0);
    return llvm::APInt(32, Priority);
  }
  
  // Handle feature strings
  if (!ParsedAttr.Features.empty()) {
    // For now, assign lower priority to features than CPUs
    // This ensures CPU-based versions are preferred over feature-only versions
    // TODO: Implement proper feature priority ordering
    return llvm::APInt(32, 10); // Base priority for features
  }
  
  return llvm::APInt(32, 0);
}
```

**Why**: This determines the priority/ordering of function versions for the resolver. Features need their own priority scheme.

---

### 8. clang/include/clang/Basic/AttrDocs.td

**Location**: Line ~3410
**Priority**: LOW (Documentation)

**Current Documentation:**
```
For PowerPC targets, ``target_clones`` is supported on AIX only. Only CPU
(specified as ``cpu=CPU``) and ``default`` options are allowed.
```

**Replace With:**
```
For PowerPC targets, ``target_clones`` is supported on AIX only. Options can be:

- CPU specifications: ``cpu=CPU`` (e.g., ``cpu=pwr10``)
- Feature strings: feature names like ``altivec``, ``vsx``
- Negated features: ``no-<feature>`` (e.g., ``no-altivec``)
- The required ``default`` option

Example:

  .. code-block:: c++

    __attribute__((target_clones("cpu=pwr10", "altivec", "default")))
    void foo() {}
```

**Why**: Documentation needs to reflect the new capability.

---

## Implementation Strategy

### Phase 1: Infrastructure (Initial Goal)
**Goal**: Support "altivec" and "no-altivec"

1. **Step 1.1**: Implement `isValidFeatureName()` in PPC.h/PPC.cpp
   - Add method declaration to PPC.h
   - Implement validation logic in PPC.cpp
   - Initially support only "altivec"

2. **Step 1.2**: Modify SemaPPC.cpp to accept feature strings
   - Remove rejection of feature strings
   - Add validation using `isValidFeatureName()`
   - Handle "no-" prefix for negation

3. **Step 1.3**: Update ASTContext.cpp
   - Remove `assert(VersionStr == "default")`
   - Add feature string parsing
   - Build feature map correctly

4. **Step 1.4**: Update CodeGenFunction.cpp
   - Remove `assert(RO.Features[0].starts_with("cpu="))`
   - Add feature string handling in resolver
   - Test runtime selection

5. **Step 1.5**: Update Targets/PPC.cpp
   - Remove `assert(0 && "specifying target features...")`
   - Implement feature string mangling
   - Test name generation

6. **Step 1.6**: Basic testing
   - Create test cases for "altivec"
   - Create test cases for "no-altivec"
   - Verify backward compatibility

### Phase 2: Priority and Ordering
**Goal**: Proper feature priority implementation

1. **Step 2.1**: Implement feature priority in `getFMVPriority()`
   - Remove `assert(false && "unimplemented")`
   - Design priority scheme for features
   - Implement priority logic

2. **Step 2.2**: Test priority ordering
   - Verify resolver selects correct version
   - Test mixed CPU and feature specifications

### Phase 3: Extended Features
**Goal**: Support additional features

1. **Step 3.1**: Add more features to `isValidFeatureName()`
   - vsx, p8vector, p9vector, etc.
   - Document each feature

2. **Step 3.2**: Handle feature dependencies
   - Identify dependencies (e.g., VSX requires Altivec)
   - Add validation logic

3. **Step 3.3**: Comprehensive testing
   - Test all supported features
   - Test feature combinations
   - Test error cases

### Phase 4: Documentation and Polish
**Goal**: Complete documentation and testing

1. **Step 4.1**: Update AttrDocs.td
   - Document all supported features
   - Add comprehensive examples

2. **Step 4.2**: Add test coverage
   - Semantic tests in `clang/test/Sema/PowerPC/attr-target-clones.c`
   - CodeGen tests in `clang/test/CodeGen/PowerPC/attr-target-clones.c`

3. **Step 4.3**: Code review and refinement
   - Address review feedback
   - Optimize implementation
   - Final testing

---

## Success Criteria

### Minimal Success (Initial Goal)
- [ ] Accept "altivec" as a valid target_clones parameter on AIX
- [ ] Accept "no-altivec" as a valid target_clones parameter on AIX
- [ ] Generate correct code for altivec/no-altivec variants
- [ ] Maintain backward compatibility with cpu= syntax
- [ ] Pass basic test cases
- [ ] All 8 critical assertions removed/modified

### Full Success (Final Goal)
- [ ] Support multiple feature strings (altivec, vsx, p8vector, etc.)
- [ ] Proper feature validation and error reporting
- [ ] Feature priority/ordering implementation
- [ ] Comprehensive test coverage
- [ ] Updated documentation
- [ ] No regressions in existing functionality

---

## Open Questions and Design Decisions

### Q1: Feature String Case Sensitivity
**Question**: Should feature strings be case-sensitive?
**Decision**: YES - Feature strings are case-sensitive (confirmed via GCC testing)
**Details**: 
- "altivec" is valid ✅
- "altiVec" is invalid ❌ (GCC rejects with error: `__attribute__((__target__('altiVec'))) is invalid`)
- This matches x86 behavior and ensures consistency
**Status**: ✅ RESOLVED

### Q2: Feature Combinations
**Question**: Can features be combined in a single string (e.g., "altivec+vsx")?
**Decision**: NO - Feature combinations in a single string are NOT supported (confirmed via GCC testing)
**Details**:
- "altivec+vsx" is invalid ❌ (GCC rejects with error: `__attribute__((__target__('altivec+vsx'))) is invalid`)
- Each feature must be specified separately: `target_clones("default", "altivec", "vsx")`
- This simplifies implementation and matches GCC behavior
**Status**: ✅ RESOLVED - Will NOT implement feature combinations in single strings

### Q3: Conflict Handling
**Question**: How to handle conflicts (e.g., "altivec" and "no-altivec" in same declaration)?
**Decision**: ALLOW conflicts - Generate separate versions for each (confirmed via GCC testing)
**Details**:
- `target_clones("default", "altivec", "no-altivec")` is valid ✅
- GCC generates 3 separate versions: foo.default, foo.altivec, foo.no_altivec
- GCC emits warning about dependencies: `'-mno-altivec' disables vsx`
- Each version is independent; resolver selects appropriate one at runtime
- We should follow GCC behavior: allow conflicts, emit warnings for dependency issues
**Status**: ✅ RESOLVED - Allow conflicts, warn about dependencies in Phase 3

### Q4: Feature Priority
**Question**: Should there be a priority order when multiple features are specified?
**Decision**: YES - Priority ordering is required for resolver function (confirmed via GCC testing)
**Details**:
- GCC successfully compiles `target_clones("default", "altivec", "vsx", "power8-vector")` ✅
- Generates 4 separate versions: foo.default, foo.altivec, foo.vsx, foo.power8_vector
- Resolver function selects most specific/capable version at runtime
- Priority scheme needed to determine selection order (e.g., power8-vector > vsx > altivec > default)
- Must implement in `getFMVPriority()` similar to x86 approach
**Status**: ✅ CONFIRMED - Implementation required in Phase 2

### Q5: Unavailable Features
**Question**: What happens if a feature is specified that's not available on the target CPU?
**Decision**: REJECT with error - Invalid features cause compilation failure (confirmed via GCC testing)
**Details**:
- Invalid feature names are rejected with error: `__attribute__((__target__('invalid_feature_xyz'))) is invalid`
- GCC performs validation at compile time
- We must implement similar validation using `isValidFeatureName()` method
- This ensures early detection of typos and invalid feature specifications
**Status**: ✅ RESOLVED - Reject invalid features with clear error messages

### Q6: Feature Dependencies
**Question**: Do features have dependencies that need validation?
**Decision**: NO strict validation required - GCC allows independent feature specifications (confirmed via testing)
**Details**:
- `target_clones("default", "vsx")` compiles successfully without altivec ✅
- No warnings or errors about missing dependencies
- GCC generates foo.default and foo.vsx versions
- At runtime, hardware capabilities determine which version runs (VSX hardware includes altivec)
- We should follow GCC behavior: allow any valid feature, let runtime resolver handle capabilities
- Optional: Could add informational warnings in Phase 3 for educational purposes
**Status**: ✅ RESOLVED - No strict dependency validation needed

---

## References

### Key Code Locations
- **Semantic validation**: `clang/lib/Sema/SemaPPC.cpp:605-673`
- **X86 reference impl**: `clang/lib/Sema/SemaX86.cpp:1056-1115`
- **ARM reference impl**: `clang/lib/Sema/SemaARM.cpp:1678+`
- **RISCV reference impl**: `clang/lib/Sema/SemaRISCV.cpp:1822+`
- **Target info**: `clang/lib/Basic/Targets/PPC.h`, `PPC.cpp`
- **Documentation**: `clang/include/clang/Basic/AttrDocs.td:3410-3415`
- **Diagnostics**: `clang/include/clang/Basic/DiagnosticSemaKinds.td`

### Related Commits
- **Commit 495c518b96cb**: Implements target_clones on AIX with CPU-only support
  - Author: Wael Yehia
  - Date: Tue Mar 17 23:15:15 2026 -0400
  - 16 files changed, 633 insertions(+), 74 deletions(-)

### Files Modified in Base Commit
1. clang/lib/AST/ASTContext.cpp
2. clang/lib/CodeGen/CodeGenModule.cpp
3. clang/lib/CodeGen/CodeGenFunction.cpp
4. clang/lib/CodeGen/Targets/PPC.cpp
5. clang/lib/Basic/Targets/PPC.cpp
6. clang/lib/Basic/Targets/PPC.h
7. clang/lib/Sema/SemaPPC.cpp
8. clang/lib/Sema/SemaDeclAttr.cpp
9. clang/include/clang/Basic/AttrDocs.td
10. clang/include/clang/Sema/SemaPPC.h
11. Test files

### Documentation References
- AttrDocs.td lines 3361-3415: target_clones documentation
- Shows x86, AArch64, and PowerPC/AIX support levels

---

## Summary of Critical Changes

### Assertions to Remove
1. ❌ `assert(VersionStr == "default")` in ASTContext.cpp
2. ❌ `assert(RO.Features[0].starts_with("cpu="))` in CodeGenFunction.cpp
3. ❌ `assert(0 && "specifying target features on an FMV is unsupported on AIX")` in Targets/PPC.cpp
4. ❌ `assert(false && "unimplemented")` in PPC.cpp getFMVPriority()

### New Methods to Add
1. ✅ `bool PPCTargetInfo::isValidFeatureName(StringRef Name) const` in PPC.h/PPC.cpp

### Priority Levels
- **HIGH**: Core functionality (Steps 1.1-1.5) - Required for minimal success
- **MEDIUM**: Proper ordering (Step 2.1-2.2) - Required for full success
- **LOW**: Documentation (Step 4.1) - Required for full success
- **TESTING**: Comprehensive tests (Steps 1.6, 2.2, 3.3, 4.2) - Required throughout

---

## Notes

- All assertions that reject feature strings must be removed or modified
- Feature string handling should follow the pattern established for CPU handling
- Priority scheme for features needs careful design
- Feature dependencies need to be considered in Phase 3
- Name mangling for features should be consistent and unambiguous
- Maintain backward compatibility at all times
- Test incrementally after each phase
