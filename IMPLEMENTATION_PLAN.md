# Implementation Plan: Extending target_clones on AIX to Support Feature Strings

## Project Overview

Extend the `target_clones` attribute on AIX/PowerPC to accept feature strings (e.g., "altivec", "no-altivec") in addition to the currently supported CPU specifications.

**Initial Goal**: Support all 17 PowerPC feature strings with runtime detection

**Final Goal**: Support multiple features like `target_clones("default", "altivec", "vsx", "crypto")`

**Base Commit**: 495c518b96cb (implements target_clones CPU-only support on AIX)

---

## Table of Contents

1. [Current Implementation Analysis](#current-implementation-analysis)
2. [Requirements](#requirements)
3. [Feature-to-Runtime Mapping](#feature-to-runtime-mapping)
4. [Detailed Code Modifications](#detailed-code-modifications)
5. [Implementation Strategy](#implementation-strategy)
6. [Success Criteria](#success-criteria)
7. [References](#references)

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

---

## Requirements

### Functional Requirements

#### FR1: Feature String Parsing

- **FR1.1**: Accept 17 feature strings with runtime detection in target_clones attribute
- **FR1.2**: Accept negated features with "no-" prefix (e.g., "no-altivec", "no-vsx")
- **FR1.3**: Maintain backward compatibility with existing "cpu=XXX" syntax
- **FR1.4**: Continue to require "default" option in all target_clones declarations
- **FR1.5**: Each parameter creates a SEPARATE function version (they do NOT combine)
- **FR1.6**: Reject features without runtime checks in target_clones (but allow in target attribute)

#### FR2: Feature Validation

- **FR2.1**: Validate that feature names are one of the 17 recognized PPC features with runtime detection
- **FR2.2**: Reject features without runtime checks with clear error message
- **FR2.3**: Reject invalid or unsupported feature names with appropriate diagnostics
- **FR2.4**: Ensure features are appropriate for AIX platform
- **FR2.5**: No strict dependency validation (follow GCC behavior)

#### FR3: Runtime Feature Detection

- **FR3.1**: Use `__builtin_cpu_supports()` for runtime feature detection
- **FR3.2**: Map each feature to appropriate __builtin_cpu_supports() call
- **FR3.3**: All supported features must have runtime detection capability
- **FR3.4**: Generate efficient resolver functions

#### FR4: Code Generation

- **FR4.1**: Generate appropriate function versions for each feature
- **FR4.2**: Generate resolver function using __builtin_cpu_supports()
- **FR4.3**: Use IFUNC mechanism (already supported on AIX)
- **FR4.4**: Update `ASTContext::getFunctionFeatureMap()` to handle feature strings

### Non-Functional Requirements

#### NFR1: Compatibility
- Must not break existing code using cpu= syntax
- Must maintain ABI compatibility
- Must work with existing AIX IFUNC support

#### NFR2: Error Handling
- Clear, actionable error messages for invalid features
- Specific error for features without runtime checks
- Consistent with x86/ARM error message patterns
- Helpful suggestions when features are misspelled

#### NFR3: Documentation
- Update AttrDocs.td to reflect new capability
- Add examples showing feature string usage
- Document all 17 supported features for AIX/PPC
- Explain why some features are excluded from target_clones

---

## Feature-to-Runtime Mapping

### Features with Direct __builtin_cpu_supports() Mapping (5 features)

```cpp
altivec              → __builtin_cpu_supports("altivec")
htm                  → __builtin_cpu_supports("htm")
isel                 → __builtin_cpu_supports("isel")
mma                  → __builtin_cpu_supports("mma")
vsx                  → __builtin_cpu_supports("vsx")
```

### Features Mapped to ISA Levels (12 features)

```cpp
// POWER6 (ISA 2.05)
cmpb                 → __builtin_cpu_supports("arch_2_05")
fprnd                → __builtin_cpu_supports("arch_2_05")

// POWER7 (ISA 2.06)
popcntd              → __builtin_cpu_supports("arch_2_06")

// POWER8 (ISA 2.07)
crypto               → __builtin_cpu_supports("arch_2_07")
direct-move          → __builtin_cpu_supports("arch_2_07")
power8-vector        → __builtin_cpu_supports("arch_2_07")

// POWER9 (ISA 3.0)
float128             → __builtin_cpu_supports("arch_3_00")
power9-vector        → __builtin_cpu_supports("arch_3_00")

// POWER10 (ISA 3.1)
paired-vector-memops → __builtin_cpu_supports("arch_3_1")
pcrel                → __builtin_cpu_supports("arch_3_1")
power10-vector       → __builtin_cpu_supports("arch_3_1")
prefixed             → __builtin_cpu_supports("arch_3_1")
```

### Features WITHOUT Runtime Checks (11 features - EXCLUDED from target_clones)

These features are **NOT** supported in target_clones but remain valid for target attribute:

```cpp
// AIX-specific (compile-time only)
aix-shared-lib-tls-model-opt
aix-small-local-dynamic-tls
aix-small-local-exec-tls

// Optimization/ABI features (no runtime check)
crbits
invariant-function-descriptors
longcall
secure-plt

// Basic instructions (always available)
mfcrf
mfocrf

// Security/privilege (no runtime check)
privileged
rop-protect
```

**Rationale for Exclusion:**
- target_clones requires runtime feature detection to select appropriate function version
- These features have no runtime detection mechanism via __builtin_cpu_supports()
- They are compile-time only, optimization hints, or always available
- Allowing them would require resolver to always select that version (no actual selection)
- They remain valid for target attribute where compile-time feature enabling is sufficient

**Error Message:**
When user specifies these in target_clones, emit clear error:
```
error: feature 'FEATURE' cannot be used with target_clones because it has no runtime detection; use target attribute instead
```

---

## Detailed Code Modifications

### 1. clang/lib/Basic/Targets/PPC.h

**Location**: Class definition
**Priority**: HIGH (Required first)

**Add Method Declarations:**
```cpp
class LLVM_LIBRARY_VISIBILITY PPCTargetInfo : public TargetInfo {
  // ... existing members ...
  
  // ADD THESE METHODS:
  bool isValidFeatureName(StringRef Name) const override;
  
  // Check if feature is valid for target_clones (has runtime detection)
  bool isValidClonesFeatureName(StringRef Name) const;
  
  // Get __builtin_cpu_supports() argument for feature
  StringRef getBuiltinCpuSupportsName(StringRef FeatureName) const;
  
  // ... rest of class ...
};
```

---

### 2. clang/lib/Basic/Targets/PPC.cpp

**Location**: After existing methods
**Priority**: HIGH (Required first)

**Add Method Implementations:**
```cpp
bool PPCTargetInfo::isValidFeatureName(StringRef Name) const {
  // All 28 PPC features valid for target attribute
  return llvm::StringSwitch<bool>(Name)
      // Features with runtime detection (valid for target_clones)
      .Case("altivec", true)
      .Case("htm", true)
      .Case("isel", true)
      .Case("mma", true)
      .Case("vsx", true)
      .Case("cmpb", true)
      .Case("crypto", true)
      .Case("direct-move", true)
      .Case("float128", true)
      .Case("fprnd", true)
      .Case("paired-vector-memops", true)
      .Case("pcrel", true)
      .Case("popcntd", true)
      .Case("power8-vector", true)
      .Case("power9-vector", true)
      .Case("power10-vector", true)
      .Case("prefixed", true)
      // Features without runtime checks (NOT valid for target_clones)
      .Case("aix-shared-lib-tls-model-opt", true)
      .Case("aix-small-local-dynamic-tls", true)
      .Case("aix-small-local-exec-tls", true)
      .Case("crbits", true)
      .Case("invariant-function-descriptors", true)
      .Case("longcall", true)
      .Case("mfcrf", true)
      .Case("mfocrf", true)
      .Case("privileged", true)
      .Case("rop-protect", true)
      .Case("secure-plt", true)
      .Default(false);
}

bool PPCTargetInfo::isValidClonesFeatureName(StringRef Name) const {
  // Only 17 features with runtime detection are valid for target_clones
  return llvm::StringSwitch<bool>(Name)
      // Direct mappings (5 features)
      .Case("altivec", true)
      .Case("htm", true)
      .Case("isel", true)
      .Case("mma", true)
      .Case("vsx", true)
      // ISA level mappings (12 features)
      .Case("cmpb", true)
      .Case("crypto", true)
      .Case("direct-move", true)
      .Case("float128", true)
      .Case("fprnd", true)
      .Case("paired-vector-memops", true)
      .Case("pcrel", true)
      .Case("popcntd", true)
      .Case("power8-vector", true)
      .Case("power9-vector", true)
      .Case("power10-vector", true)
      .Case("prefixed", true)
      .Default(false);
}

StringRef PPCTargetInfo::getBuiltinCpuSupportsName(StringRef FeatureName) const {
  // Map feature names to __builtin_cpu_supports() strings
  // Only returns non-empty for features with runtime detection
  return llvm::StringSwitch<StringRef>(FeatureName)
      // Direct mappings (5 features)
      .Case("altivec", "altivec")
      .Case("htm", "htm")
      .Case("isel", "isel")
      .Case("mma", "mma")
      .Case("vsx", "vsx")
      // ISA level mappings (12 features)
      .Case("cmpb", "arch_2_05")
      .Case("fprnd", "arch_2_05")
      .Case("popcntd", "arch_2_06")
      .Case("crypto", "arch_2_07")
      .Case("direct-move", "arch_2_07")
      .Case("power8-vector", "arch_2_07")
      .Case("float128", "arch_3_00")
      .Case("power9-vector", "arch_3_00")
      .Case("paired-vector-memops", "arch_3_1")
      .Case("pcrel", "arch_3_1")
      .Case("power10-vector", "arch_3_1")
      .Case("prefixed", "arch_3_1")
      // Features without runtime checks return empty string
      .Default("");
}
```

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
  
  // First check if it's a valid feature name at all
  if (!TargetInfo.isValidFeatureName(FeatureName)) {
    return Diag(CurLoc, diag::warn_unsupported_target_attribute)
           << Unknown << None << LHS << TargetClones;
  }
  
  // Check if feature is valid for target_clones (has runtime detection)
  if (!TargetInfo.isValidClonesFeatureName(FeatureName)) {
    // Feature is valid for target attribute but not target_clones
    return Diag(CurLoc, diag::err_ppc_feature_no_runtime_detection)
           << FeatureName << TargetClones;
  }
}
```

**Note**: Need to add new diagnostic in DiagnosticSemaKinds.td:
```cpp
def err_ppc_feature_no_runtime_detection : Error<
  "feature '%0' cannot be used with 'target_clones' because it has no "
  "runtime detection; use 'target' attribute instead">;
```

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
StringRef BuiltinCpuSupportsArg;

if (FeatureStr.starts_with("cpu=")) {
  // CPU specification - map to ISA level
  StringRef CPU = FeatureStr.split("=").second.trim();
  BuiltinCpuSupportsArg = llvm::StringSwitch<StringRef>(CPU)
                              .Case("pwr7", "arch_2_06")
                              .Case("pwr8", "arch_2_07")
                              .Case("pwr9", "arch_3_00")
                              .Case("pwr10", "arch_3_1")
                              .Case("pwr11", "arch_3_1")
                              .Default("error");
} else {
  // Feature string - get __builtin_cpu_supports() argument
  const PPCTargetInfo &TI = static_cast<const PPCTargetInfo&>(getTarget());
  BuiltinCpuSupportsArg = TI.getBuiltinCpuSupportsName(FeatureStr);
  
  // All features in target_clones must have runtime detection
  assert(!BuiltinCpuSupportsArg.empty() && 
         "feature without runtime detection should have been rejected in Sema");
}

llvm::Value *Condition = EmitPPCBuiltinCpu(BuiltinCpuSupportsArg);
```

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
    // Replace hyphens with underscores for valid symbol names
    std::string MangledFeature = Feature.str();
    std::replace(MangledFeature.begin(), MangledFeature.end(), '-', '_');
    Out << "." << MangledFeature;
    return;
  }

  llvm_unreachable("Invalid target_clones parameter");
}
```

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
  
  // CPU specifications have highest priority
  if (!ParsedAttr.CPU.empty()) {
    int Priority = llvm::StringSwitch<int>(ParsedAttr.CPU)
                       .Case("pwr7", 100)
                       .Case("pwr8", 200)
                       .Case("pwr9", 300)
                       .Case("pwr10", 400)
                       .Case("pwr11", 500)
                       .Default(0);
    return llvm::APInt(32, Priority);
  }
  
  // Feature strings have lower priority, ordered by ISA level
  if (!ParsedAttr.Features.empty()) {
    StringRef Feature = ParsedAttr.Features[0];
    // Remove leading '+' or '-'
    if (Feature.starts_with("+") || Feature.starts_with("-"))
      Feature = Feature.drop_front(1);
    
    int Priority = llvm::StringSwitch<int>(Feature)
        // POWER10 features (ISA 3.1) - highest feature priority
        .Case("mma", 90)
        .Case("paired-vector-memops", 89)
        .Case("pcrel", 88)
        .Case("power10-vector", 87)
        .Case("prefixed", 86)
        // POWER9 features (ISA 3.0)
        .Case("float128", 80)
        .Case("power9-vector", 79)
        // POWER8 features (ISA 2.07)
        .Case("crypto", 70)
        .Case("direct-move", 69)
        .Case("power8-vector", 68)
        .Case("htm", 67)
        // POWER7 features (ISA 2.06)
        .Case("popcntd", 60)
        .Case("vsx", 59)
        .Case("isel", 58)
        // POWER6 features (ISA 2.05)
        .Case("cmpb", 50)
        .Case("fprnd", 49)
        // Base features
        .Case("altivec", 40)
        .Default(0);
    
    return llvm::APInt(32, Priority);
  }
  
  return llvm::APInt(32, 0);
}
```

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

- CPU specifications: ``cpu=CPU`` (e.g., ``cpu=pwr10``, ``cpu=pwr8``)
- Feature strings: 17 supported features with runtime detection:
  
  - Vector features: ``altivec``, ``vsx``, ``power8-vector``, ``power9-vector``, ``power10-vector``
  - POWER8 features: ``crypto``, ``direct-move``, ``htm``
  - POWER9 features: ``float128``
  - POWER10 features: ``mma``, ``paired-vector-memops``, ``pcrel``, ``prefixed``
  - ISA features: ``cmpb``, ``fprnd``, ``popcntd``, ``isel``

- Negated features: ``no-<feature>`` (e.g., ``no-altivec``, ``no-vsx``)
- The required ``default`` option

Runtime feature detection uses ``__builtin_cpu_supports()`` for all supported features.

**Note**: Some features valid for the ``target`` attribute (e.g., ``aix-shared-lib-tls-model-opt``,
``crbits``, ``longcall``, ``secure-plt``, ``mfcrf``, ``mfocrf``, ``privileged``, ``rop-protect``)
are not supported in ``target_clones`` because they have no runtime detection mechanism.
Use the ``target`` attribute for these features.

Example:

  .. code-block:: c++

    __attribute__((target_clones("cpu=pwr10", "crypto", "altivec", "default")))
    void foo() {}
    
    // Generates 4 versions:
    // - foo.cpu_pwr10 (for POWER10 CPUs)
    // - foo.crypto (for CPUs with crypto/ISA 2.07 support)
    // - foo.altivec (for CPUs with AltiVec)
    // - foo.default (baseline version)
    
    // Features without runtime detection must use target attribute:
    __attribute__((target("longcall")))
    void bar() {}  // OK
    
    __attribute__((target_clones("longcall", "default")))
    void baz() {}  // ERROR: longcall has no runtime detection
```

---

### 9. clang/include/clang/Basic/DiagnosticSemaKinds.td

**Location**: Near other PPC diagnostics
**Priority**: HIGH (Required for error messages)

**Add New Diagnostic:**
```cpp
def err_ppc_feature_no_runtime_detection : Error<
  "feature '%0' cannot be used with 'target_clones' because it has no "
  "runtime detection; use 'target' attribute instead">;
```

---

## Implementation Strategy

### Phase 1: Infrastructure
**Goal**: Support 17 features with runtime detection

1. **Step 1.1**: Implement validation methods in PPC.h/PPC.cpp
   - Add `isValidFeatureName()` for all 28 features
   - Add `isValidClonesFeatureName()` for 17 features with runtime detection
   - Add `getBuiltinCpuSupportsName()` helper method

2. **Step 1.2**: Add new diagnostic
   - Add `err_ppc_feature_no_runtime_detection` to DiagnosticSemaKinds.td

3. **Step 1.3**: Modify SemaPPC.cpp to accept feature strings
   - Remove rejection of feature strings
   - Add validation using `isValidClonesFeatureName()`
   - Handle "no-" prefix for negation
   - Emit clear error for features without runtime detection

4. **Step 1.4**: Update ASTContext.cpp
   - Remove `assert(VersionStr == "default")`
   - Add feature string parsing
   - Build feature map correctly

5. **Step 1.5**: Update CodeGenFunction.cpp
   - Remove `assert(RO.Features[0].starts_with("cpu="))`
   - Add feature string handling in resolver
   - Use `getBuiltinCpuSupportsName()` for mapping
   - Add assertion that all features have runtime detection

6. **Step 1.6**: Update Targets/PPC.cpp
   - Remove `assert(0 && "specifying target features...")`
   - Implement feature string mangling
   - Handle hyphenated feature names

7. **Step 1.7**: Basic testing
   - Test features with direct mapping (altivec, vsx, htm, isel, mma)
   - Test features with ISA mapping (crypto, power8-vector, etc.)
   - Test negated features
   - Test that features without runtime detection are rejected
   - Verify backward compatibility with cpu= syntax

### Phase 2: Priority and Ordering
**Goal**: Proper feature priority implementation

1. **Step 2.1**: Implement feature priority in `getFMVPriority()`
   - Remove `assert(false && "unimplemented")`
   - Implement ISA-level based priority scheme
   - Ensure CPU specs have higher priority than features

2. **Step 2.2**: Test priority ordering
   - Verify resolver selects correct version
   - Test mixed CPU and feature specifications
   - Test multiple features with different ISA levels

### Phase 3: Comprehensive Testing
**Goal**: Ensure robustness

1. **Step 3.1**: Test all 17 features individually
   - Verify each feature compiles and generates correct resolver
   - Test negated forms

2. **Step 3.2**: Test error cases
   - Verify features without runtime detection are rejected
   - Test invalid feature names
   - Test typos and suggestions

3. **Step 3.3**: Test feature combinations
   - Multiple features in same target_clones
   - Mixed CPU and feature specifications

### Phase 4: Documentation and Final Testing
**Goal**: Complete documentation and testing

1. **Step 4.1**: Update AttrDocs.td
   - Document all 17 supported features
   - Add comprehensive examples
   - Explain exclusion of features without runtime detection

2. **Step 4.2**: Add test coverage
   - Semantic tests in `clang/test/Sema/PowerPC/attr-target-clones.c`
   - CodeGen tests in `clang/test/CodeGen/PowerPC/attr-target-clones.c`
   - Test resolver generation
   - Test name mangling
   - Test error messages

3. **Step 4.3**: Code review and refinement
   - Address review feedback
   - Optimize implementation
   - Final testing

---

## Success Criteria

### Minimal Success
- [ ] Accept all 17 feature strings with runtime detection as valid target_clones parameters on AIX
- [ ] Reject 11 features without runtime detection with clear error message
- [ ] Accept negated forms (no-feature) for all 17 features
- [ ] Generate correct code for feature variants
- [ ] Maintain backward compatibility with cpu= syntax
- [ ] Pass basic test cases for each feature category
- [ ] All 4 critical assertions removed/modified
- [ ] New diagnostic added and working

### Full Success
- [ ] Proper feature validation and error reporting
- [ ] Feature priority/ordering implementation based on ISA levels
- [ ] Correct __builtin_cpu_supports() mapping for all 17 features
- [ ] Clear error messages for features without runtime detection
- [ ] Comprehensive test coverage (all 17 features + error cases)
- [ ] Updated documentation with all features listed and exclusions explained
- [ ] No regressions in existing functionality

---

## Open Questions and Design Decisions

### Q1: Features Without Runtime Checks
**Question**: How to handle features that have no __builtin_cpu_supports() mapping?
**Decision**: REJECT in target_clones, ALLOW in target attribute
**Details**:
- 11 features have no runtime check (AIX-specific, optimization hints, always-available)
- Reject them in target_clones with clear error message
- Error explains they should use target attribute instead
- This ensures target_clones only contains features with actual runtime selection
- Maintains consistency: all target_clones features must have runtime detection
**Status**: ✅ RESOLVED - Reject with helpful error message

### Q2: Feature Priority Scheme
**Question**: How to order features when multiple are specified?
**Decision**: ISA-level based priority (POWER10 > POWER9 > POWER8 > POWER7 > POWER6 > base)
**Details**:
- CPU specifications: 100-500 (pwr7=100, pwr8=200, pwr9=300, pwr10=400, pwr11=500)
- POWER10 features: 86-90
- POWER9 features: 79-80
- POWER8 features: 67-70
- POWER7 features: 58-60
- POWER6 features: 49-50
- Base features: 40
- This ensures most capable version is selected first
**Status**: ✅ RESOLVED - Implemented in getFMVPriority()

### Q3: Hyphenated Feature Names
**Question**: How to handle features with hyphens in mangled names?
**Decision**: Replace hyphens with underscores in mangled names
**Details**:
- Features like "direct-move", "power8-vector" contain hyphens
- Hyphens are not valid in C symbol names
- Replace with underscores: "direct_move", "power8_vector"
- This matches common C naming conventions
**Status**: ✅ RESOLVED - Implemented in appendAttributeMangling()

---

## References

### Key Code Locations
- **Semantic validation**: `clang/lib/Sema/SemaPPC.cpp:605-673`
- **Feature mapping**: `ppc_target_features.md` (28 features documented, 17 for target_clones)
- **Runtime detection**: `ppc_builtin_cpu_supports_mapping_aix.md`
- **Target info**: `clang/lib/Basic/Targets/PPC.h`, `PPC.cpp`
- **Documentation**: `clang/include/clang/Basic/AttrDocs.td:3410-3415`
- **Diagnostics**: `clang/include/clang/Basic/DiagnosticSemaKinds.td`

### Related Commits
- **Commit 495c518b96cb**: Implements target_clones on AIX with CPU-only support

---

## Summary of Critical Changes

### Assertions to Remove
1. ❌ `assert(VersionStr == "default")` in ASTContext.cpp
2. ❌ `assert(RO.Features[0].starts_with("cpu="))` in CodeGenFunction.cpp
3. ❌ `assert(0 && "specifying target features on an FMV is unsupported on AIX")` in Targets/PPC.cpp
4. ❌ `assert(false && "unimplemented")` in PPC.cpp getFMVPriority()

### New Methods to Add
1. ✅ `bool PPCTargetInfo::isValidFeatureName(StringRef Name) const` - validates all 28 features
2. ✅ `bool PPCTargetInfo::isValidClonesFeatureName(StringRef Name) const` - validates 17 features for target_clones
3. ✅ `StringRef PPCTargetInfo::getBuiltinCpuSupportsName(StringRef FeatureName) const` - maps to __builtin_cpu_supports()

### New Diagnostics to Add
1. ✅ `err_ppc_feature_no_runtime_detection` - error for features without runtime detection

### Feature Categories
- **17 features** with __builtin_cpu_supports() runtime checks (supported in target_clones)
  - 5 with direct mapping: altivec, htm, isel, mma, vsx
  - 12 with ISA level mapping: cmpb, fprnd, popcntd, crypto, direct-move, power8-vector, float128, power9-vector, paired-vector-memops, pcrel, power10-vector, prefixed
- **11 features** without runtime checks (rejected in target_clones, allowed in target attribute)
- **All 28 features** supported in target attribute

---

## Notes

- Use __builtin_cpu_supports() for runtime detection (not direct hwcap access like GCC)
- Map features to appropriate ISA levels or direct feature checks
- Reject features without runtime checks in target_clones with clear error message
- Priority scheme based on ISA levels ensures correct version selection
- Hyphenated feature names converted to underscores in mangled symbols
- Maintain backward compatibility with cpu= syntax at all times
- Test incrementally after each phase
- Ensure error messages guide users to use target attribute for features without runtime detection