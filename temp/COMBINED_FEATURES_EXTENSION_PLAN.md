# Extension Plan: Combined CPU and Single Feature in target_clones

## Project Overview

Extend the current `target_clones` implementation on AIX/PowerPC to support combining a CPU specification with a single feature string within a clone specification, using semicolon (`;`) as the delimiter.

**Current State**: Each clone parameter specifies EITHER a CPU OR a single feature
**Target State**: Each clone parameter can specify zero-or-one CPU AND zero-or-one feature

**Example Syntax**:
```c
__attribute__((target_clones("cpu=pwr10;prefixed", "no-vsx", "default")))
void foo() {}

// Generates 3 versions:
// 1. foo.cpu_pwr10_prefixed - POWER10 CPU with prefixed instructions
// 2. foo.no_vsx - baseline without VSX
// 3. foo.default - default baseline
```

**Base Implementation**: Phase 1 feature strings support (from IMPLEMENTATION_PLAN.md)

---

## Table of Contents

1. [Motivation and Use Cases](#motivation-and-use-cases)
2. [Syntax and Semantics](#syntax-and-semantics)
3. [Requirements](#requirements)
4. [Design Decisions](#design-decisions)
5. [Detailed Code Modifications](#detailed-code-modifications)
6. [Implementation Strategy](#implementation-strategy)
7. [Testing Strategy](#testing-strategy)
8. [Success Criteria](#success-criteria)
9. [Open Questions](#open-questions)

---

## Motivation and Use Cases

### Why Combine CPU and Feature?

1. **Fine-grained Optimization**: Target specific CPU generation with additional feature requirement
   ```c
   // Optimize for POWER10 with MMA enabled
   __attribute__((target_clones("cpu=pwr10;mma", "default")))
   void matrix_multiply() {}
   ```

2. **Feature Override**: Enable or disable specific feature on a CPU baseline
   ```c
   // POWER9 baseline with crypto explicitly enabled
   __attribute__((target_clones("cpu=pwr9;crypto", "default")))
   void secure_hash() {}
   
   // POWER8 without VSX
   __attribute__((target_clones("cpu=pwr8;no-vsx", "default")))
   void no_vector() {}
   ```

3. **Incremental Testing**: Test single feature on specific CPU
   ```c
   // Test POWER10 with and without MMA
   __attribute__((target_clones(
       "cpu=pwr10;mma",
       "cpu=pwr10",
       "default")))
   void experimental_code() {}
   ```

4. **Compatibility Layers**: Provide fallback for missing feature
   ```c
   // Full POWER8 with crypto, or POWER8 without crypto
   __attribute__((target_clones("cpu=pwr8;crypto", "cpu=pwr8;no-crypto", "default")))
   void crypto_optional() {}
   ```

---

## Syntax and Semantics

### Syntax Rules

```
clone_spec ::= (cpu_spec (';' feature_spec)?) | feature_spec
cpu_spec   ::= 'cpu=' cpu_name
feature_spec ::= 'no-'? feature_name
cpu_name   ::= 'pwr7' | 'pwr8' | 'pwr9' | 'pwr10' | 'pwr11'
feature_name ::= <one of 14 valid feature names>
```

**Key Constraints**:
- At most one CPU specification per clone
- At most one feature specification per clone
- If both present, CPU must come first, separated by semicolon
- At least one of CPU or feature must be present (or "default")

### Valid Examples

```c
// CPU only (current support)
__attribute__((target_clones("cpu=pwr10", "default")))

// Feature only (current support)
__attribute__((target_clones("altivec", "default")))

// CPU + single feature (NEW)
__attribute__((target_clones("cpu=pwr10;prefixed", "default")))

// CPU + negated feature (NEW)
__attribute__((target_clones("cpu=pwr8;no-vsx", "default")))

// Mixed specifications (NEW)
__attribute__((target_clones(
    "cpu=pwr10;mma",      // POWER10 with MMA
    "cpu=pwr9",           // POWER9 baseline
    "altivec",            // Just AltiVec
    "default")))          // Baseline
```

### Invalid Examples

```c
// Multiple CPUs (INVALID)
__attribute__((target_clones("cpu=pwr10;cpu=pwr9", "default")))
// Error: only one CPU specification allowed per clone

// Multiple features (INVALID)
__attribute__((target_clones("vsx;crypto", "default")))
// Error: only one feature specification allowed per clone

// Feature before CPU (INVALID)
__attribute__((target_clones("mma;cpu=pwr10", "default")))
// Error: CPU specification must be first

// Feature without runtime detection (INVALID)
__attribute__((target_clones("cpu=pwr10;longcall", "default")))
// Error: feature 'longcall' has no runtime detection

// Empty specification (INVALID)
__attribute__((target_clones("", "default")))
// Error: empty clone specification

// Trailing/leading semicolons (INVALID)
__attribute__((target_clones(";cpu=pwr10", "default")))
__attribute__((target_clones("cpu=pwr10;", "default")))
// Error: invalid syntax
```

### Semantic Rules

1. **At most one CPU**: Each clone specification can contain zero or one CPU specification
2. **At most one feature**: Each clone specification can contain zero or one feature specification
3. **CPU first**: If both CPU and feature present, CPU must come first
4. **Feature validation**: Feature must have runtime detection capability
5. **No empty specs**: Specification must contain CPU, feature, or be "default"

---

## Requirements

### Functional Requirements

#### FR1: Parsing and Validation

- **FR1.1**: Parse semicolon-delimited clone specifications (CPU;feature)
- **FR1.2**: Validate at most one CPU per specification
- **FR1.3**: Validate at most one feature per specification
- **FR1.4**: Validate CPU comes before feature if both present
- **FR1.5**: Validate feature has runtime detection
- **FR1.6**: Reject empty specifications or specifications with only semicolons
- **FR1.7**: Provide clear error messages for all validation failures

#### FR2: Code Generation

- **FR2.1**: Generate function versions with combined CPU and feature requirements
- **FR2.2**: Generate resolver that checks CPU AND feature (if both specified)
- **FR2.3**: Use logical AND for combined CPU+feature checks in resolver
- **FR2.4**: Maintain correct priority ordering with combined specifications

#### FR3: Name Mangling

- **FR3.1**: Mangle combined specifications into valid symbol names
- **FR3.2**: Include both CPU and feature in mangled name
- **FR3.3**: Ensure mangled names are unique and deterministic
- **FR3.4**: Keep mangled names reasonably readable

#### FR4: Feature Map Building

- **FR4.1**: Build feature maps that include CPU-implied features
- **FR4.2**: Apply explicit feature override on top of CPU features
- **FR4.3**: Handle negated features correctly (disable feature)
- **FR4.4**: Maintain feature consistency

### Non-Functional Requirements

#### NFR1: Backward Compatibility
- Must not break existing single-feature or CPU-only specifications
- Must maintain ABI compatibility with existing code
- Must work with existing IFUNC mechanism

#### NFR2: Performance
- Resolver function should be efficient (minimize runtime checks)
- At most two checks per version (CPU + feature)
- Avoid redundant checks in resolver

#### NFR3: Usability
- Clear, actionable error messages
- Intuitive syntax that matches user expectations
- Good documentation with comprehensive examples

---

## Design Decisions

### D1: Semicolon as Delimiter

**Decision**: Use semicolon (`;`) as the delimiter between CPU and feature

**Rationale**:
- Comma (`,`) already used to separate clone specifications
- Semicolon is visually distinct and commonly used for separation
- Not commonly used in feature names (unlike hyphen)
- Easy to parse and doesn't require escaping

**Alternatives Considered**:
- `+` (too similar to feature prefix, confusing)
- `|` (suggests OR logic, but we want AND)
- `:` (could be confused with key-value syntax)

### D2: CPU Must Be First (If Present)

**Decision**: If a CPU is specified, it must appear first in the specification

**Rationale**:
- Matches intuitive reading: "for CPU X, enable feature Y"
- Simplifies parsing (CPU is always at position 0)
- Consistent with "cpu=" prefix making it clearly distinct
- Easier to validate (only check first component for "cpu=")

**Example**:
```c
// Valid
"cpu=pwr10;mma"

// Invalid
"mma;cpu=pwr10"
```

### D3: At Most One Feature

**Decision**: Only one feature allowed per clone specification

**Rationale**:
- Simplifies implementation significantly
- Covers most practical use cases
- Users can create multiple clones for multiple features
- Easier to understand and debug
- Reduces complexity in validation, code generation, and mangling

**Example**:
```c
// Valid - separate clones for each feature
__attribute__((target_clones("cpu=pwr10;mma", "cpu=pwr10;prefixed", "default")))

// Invalid - multiple features in one clone
__attribute__((target_clones("cpu=pwr10;mma;prefixed", "default")))
```

### D4: Resolver Logic - Conjunction (AND)

**Decision**: Both CPU and feature must be present for version to be selected

**Rationale**:
- Matches user expectation: "cpu=pwr10;mma" means "POWER10 AND MMA"
- Consistent with how CPU specifications work (CPU implies ISA level)
- Allows precise targeting of specific hardware configurations

**Implementation**:
```c
// For "cpu=pwr10;mma"
if (__builtin_cpu_supports("arch_3_1") &&    // pwr10
    __builtin_cpu_supports("mma"))
    return foo_cpu_pwr10_mma;
```

### D5: Name Mangling Strategy

**Decision**: Use format `.cpu_<cpu>_<feature>` or `.<feature>` or `.cpu_<cpu>`

**Rationale**:
- Deterministic (same specification always produces same mangled name)
- Readable (can identify version from symbol name)
- Unique (different specifications produce different names)
- Consistent with existing CPU-only and feature-only mangling

**Examples**:
```c
"cpu=pwr10;prefixed"        → .cpu_pwr10_prefixed
"cpu=pwr9;no-vsx"           → .cpu_pwr9_no_vsx
"mma"                       → .mma
"cpu=pwr10"                 → .cpu_pwr10
```

### D6: Priority Calculation

**Decision**: Priority = CPU_priority + feature_priority

**Rationale**:
- CPU provides base priority (100-500)
- Feature adds to priority (40-90)
- More specific versions (CPU+feature) get higher priority than CPU-only
- Ensures most capable version is selected first

**Example**:
```c
"cpu=pwr10;mma"
  = 400 (pwr10) + 90 (mma)
  = 490

"cpu=pwr10"
  = 400 (pwr10)
  = 400

"mma"
  = 90 (mma)
  = 90
```

---

## Detailed Code Modifications

### 1. clang/lib/Sema/SemaPPC.cpp

**Location**: `checkTargetClonesAttr()` function
**Priority**: HIGH (Core parsing and validation)

**Current Code** (after Phase 1):
```cpp
// Handles single feature or CPU
StringRef LHS = Cur.split(',').first.trim();
if (LHS.starts_with("cpu=")) {
  // CPU validation
} else {
  // Single feature validation
}
```

**New Code**:
```cpp
StringRef FullSpec = Cur.split(',').first.trim();

// Check for semicolon (combined specification)
if (FullSpec.contains(';')) {
  // Parse semicolon-delimited specification
  SmallVector<StringRef, 2> Components;
  FullSpec.split(Components, ';', -1, false);
  
  // Must have exactly 2 components
  if (Components.size() != 2) {
    return Diag(CurLoc, diag::err_target_clones_invalid_combined_spec)
           << FullSpec << TargetClones;
  }
  
  StringRef First = Components[0].trim();
  StringRef Second = Components[1].trim();
  
  // Check for empty components
  if (First.empty() || Second.empty()) {
    return Diag(CurLoc, diag::err_target_clones_empty_component)
           << FullSpec << TargetClones;
  }
  
  // First component must be CPU
  if (!First.starts_with("cpu=")) {
    return Diag(CurLoc, diag::err_target_clones_cpu_not_first)
           << FullSpec << TargetClones;
  }
  
  // Validate CPU
  StringRef CPU = First.drop_front(4).trim();
  if (!isValidCPU(CPU)) {
    return Diag(CurLoc, diag::warn_unsupported_target_attribute)
           << Unsupported << None << First << TargetClones;
  }
  
  // Second component must be feature (not another CPU)
  if (Second.starts_with("cpu=")) {
    return Diag(CurLoc, diag::err_target_clones_multiple_cpus)
           << FullSpec << TargetClones;
  }
  
  // Validate feature
  StringRef FeatureName = Second;
  bool IsNegated = false;
  
  if (FeatureName.starts_with("no-")) {
    IsNegated = true;
    FeatureName = FeatureName.drop_front(3);
  }
  
  if (!TargetInfo.isValidFeatureName(FeatureName)) {
    return Diag(CurLoc, diag::warn_unsupported_target_attribute)
           << Unknown << None << Second << TargetClones;
  }
  
  if (!TargetInfo.isValidClonesFeatureName(FeatureName)) {
    return Diag(CurLoc, diag::err_ppc_feature_no_runtime_detection)
           << FeatureName << TargetClones;
  }
} else {
  // Single component (CPU or feature) - existing validation
  if (FullSpec.starts_with("cpu=")) {
    // CPU validation (existing code)
  } else {
    // Feature validation (existing code)
  }
}
```

**New Diagnostics Needed**:
```cpp
def err_target_clones_invalid_combined_spec : Error<
  "invalid combined specification '%0' in 'target_clones' attribute; "
  "expected 'cpu=<cpu>;feature' format">;
def err_target_clones_empty_component : Error<
  "empty component in clone specification '%0'">;
def err_target_clones_multiple_cpus : Error<
  "multiple CPU specifications in clone '%0'; only one CPU allowed per clone">;
def err_target_clones_cpu_not_first : Error<
  "CPU specification must be first in clone '%0'; use 'cpu=<cpu>;feature' format">;
```

---

### 2. clang/lib/AST/ASTContext.cpp

**Location**: `getFunctionFeatureMap()` function
**Priority**: HIGH (Feature map building)

**Current Code** (after Phase 1):
```cpp
} else if (Target->getTriple().isOSAIX()) {
  std::vector<std::string> Features;
  StringRef VersionStr = TC->getFeatureStr(GD.getMultiVersionIndex());
  if (VersionStr.starts_with("cpu="))
    TargetCPU = VersionStr.drop_front(sizeof("cpu=") - 1);
  else if (VersionStr != "default") {
    ParsedTargetAttr ParsedAttr = Target->parseTargetAttr(VersionStr);
    Features = ParsedAttr.Features;
  }
  Target->initFeatureMap(FeatureMap, getDiagnostics(), TargetCPU, Features);
```

**New Code**:
```cpp
} else if (Target->getTriple().isOSAIX()) {
  std::vector<std::string> Features;
  StringRef VersionStr = TC->getFeatureStr(GD.getMultiVersionIndex());
  
  if (VersionStr != "default") {
    // Check for combined specification (CPU;feature)
    if (VersionStr.contains(';')) {
      SmallVector<StringRef, 2> Components;
      VersionStr.split(Components, ';', -1, false);
      
      assert(Components.size() == 2 && "combined spec must have exactly 2 components");
      
      StringRef First = Components[0].trim();
      StringRef Second = Components[1].trim();
      
      // First is CPU
      if (First.starts_with("cpu=")) {
        TargetCPU = First.drop_front(4).trim();
      }
      
      // Second is feature
      ParsedTargetAttr ParsedAttr = Target->parseTargetAttr(Second);
      Features = ParsedAttr.Features;
    } else {
      // Single component (CPU or feature)
      if (VersionStr.starts_with("cpu=")) {
        TargetCPU = VersionStr.drop_front(sizeof("cpu=") - 1);
      } else {
        ParsedTargetAttr ParsedAttr = Target->parseTargetAttr(VersionStr);
        Features = ParsedAttr.Features;
      }
    }
  }
  
  Target->initFeatureMap(FeatureMap, getDiagnostics(), TargetCPU, Features);
```

---

### 3. clang/lib/CodeGen/CodeGenFunction.cpp

**Location**: Resolver generation in `EmitMultiVersionResolver()`
**Priority**: HIGH (Runtime selection logic)

**Current Code** (after Phase 1):
```cpp
assert(RO.Features.size() == 1 &&
       "for now one feature requirement per version");

StringRef FeatureStr = RO.Features[0];
// ... single feature handling
llvm::Value *Condition = EmitPPCBuiltinCpu(BuiltinCpuSupportsArg);
```

**New Code**:
```cpp
assert(RO.Features.size() == 1 && "spec stored as single string");
StringRef FullSpec = RO.Features[0];

llvm::Value *Condition = nullptr;

// Check for combined specification (CPU;feature)
if (FullSpec.contains(';')) {
  SmallVector<StringRef, 2> Components;
  FullSpec.split(Components, ';', -1, false);
  
  assert(Components.size() == 2 && "combined spec must have exactly 2 components");
  
  StringRef CPUSpec = Components[0].trim();
  StringRef FeatureSpec = Components[1].trim();
  
  // Generate check for CPU
  assert(CPUSpec.starts_with("cpu=") && "first component must be CPU");
  StringRef CPU = CPUSpec.drop_front(4).trim();
  StringRef CPUCheck = llvm::StringSwitch<StringRef>(CPU)
                           .Case("pwr7", "arch_2_06")
                           .Case("pwr8", "arch_2_07")
                           .Case("pwr9", "arch_3_00")
                           .Case("pwr10", "arch_3_1")
                           .Case("pwr11", "arch_3_1")
                           .Default("error");
  
  llvm::Value *CPUCondition = EmitPPCBuiltinCpu(CPUCheck);
  
  // Generate check for feature
  const PPCTargetInfo &TI = static_cast<const PPCTargetInfo&>(getTarget());
  StringRef FeatureCheck = TI.getBuiltinCpuSupportsName(FeatureSpec);
  assert(!FeatureCheck.empty() && 
         "feature without runtime detection should have been rejected");
  
  llvm::Value *FeatureCondition = EmitPPCBuiltinCpu(FeatureCheck);
  
  // Combine with AND
  Condition = Builder.CreateAnd(CPUCondition, FeatureCondition);
} else {
  // Single component (CPU or feature)
  StringRef BuiltinCpuSupportsArg;
  
  if (FullSpec.starts_with("cpu=")) {
    StringRef CPU = FullSpec.drop_front(4).trim();
    BuiltinCpuSupportsArg = llvm::StringSwitch<StringRef>(CPU)
                                .Case("pwr7", "arch_2_06")
                                .Case("pwr8", "arch_2_07")
                                .Case("pwr9", "arch_3_00")
                                .Case("pwr10", "arch_3_1")
                                .Case("pwr11", "arch_3_1")
                                .Default("error");
  } else {
    const PPCTargetInfo &TI = static_cast<const PPCTargetInfo&>(getTarget());
    BuiltinCpuSupportsArg = TI.getBuiltinCpuSupportsName(FullSpec);
    assert(!BuiltinCpuSupportsArg.empty() && 
           "feature without runtime detection should have been rejected");
  }
  
  Condition = EmitPPCBuiltinCpu(BuiltinCpuSupportsArg);
}

assert(Condition != nullptr && "must have at least one check");
```

---

### 4. clang/lib/CodeGen/Targets/PPC.cpp

**Location**: `appendAttributeMangling()` function
**Priority**: HIGH (Name mangling)

**Current Code** (after Phase 1):
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

  if (!Info.Features.empty()) {
    assert(Info.Features.size() == 1 && "one feature per version for now");
    // ... single feature mangling
  }
}
```

**New Code**:
```cpp
void AIXABIInfo::appendAttributeMangling(StringRef AttrStr,
                                         raw_ostream &Out) const {
  if (AttrStr == "default") {
    Out << ".default";
    return;
  }

  // Check for combined specification (CPU;feature)
  if (AttrStr.contains(';')) {
    SmallVector<StringRef, 2> Components;
    AttrStr.split(Components, ';', -1, false);
    
    assert(Components.size() == 2 && "combined spec must have exactly 2 components");
    
    StringRef CPUSpec = Components[0].trim();
    StringRef FeatureSpec = Components[1].trim();
    
    // Mangle CPU part
    assert(CPUSpec.starts_with("cpu=") && "first component must be CPU");
    StringRef CPU = CPUSpec.drop_front(4).trim();
    Out << ".cpu_" << CPU;
    
    // Mangle feature part
    const TargetInfo &TI = CGT.getTarget();
    ParsedTargetAttr Info = TI.parseTargetAttr(FeatureSpec);
    
    if (!Info.Features.empty()) {
      StringRef Feature = Info.Features[0];
      // Remove leading '+' or '-'
      if (Feature.starts_with("+") || Feature.starts_with("-"))
        Feature = Feature.drop_front(1);
      
      // Replace hyphens with underscores
      std::string MangledFeature = Feature.str();
      std::replace(MangledFeature.begin(), MangledFeature.end(), '-', '_');
      Out << "_" << MangledFeature;
    }
    
    return;
  }

  // Single component (CPU or feature)
  const TargetInfo &TI = CGT.getTarget();
  ParsedTargetAttr Info = TI.parseTargetAttr(AttrStr);

  if (!Info.CPU.empty()) {
    Out << ".cpu_" << Info.CPU;
    return;
  }

  if (!Info.Features.empty()) {
    assert(Info.Features.size() == 1 && "one feature per version");
    StringRef Feature = Info.Features[0];
    // Remove leading '+' or '-'
    if (Feature.starts_with("+") || Feature.starts_with("-"))
      Feature = Feature.drop_front(1);
    // Replace hyphens with underscores
    std::string MangledFeature = Feature.str();
    std::replace(MangledFeature.begin(), MangledFeature.end(), '-', '_');
    Out << "." << MangledFeature;
    return;
  }

  llvm_unreachable("Invalid target_clones parameter");
}
```

---

### 5. clang/lib/Basic/Targets/PPC.cpp

**Location**: `getFMVPriority()` function
**Priority**: HIGH (Priority calculation)

**Current Code** (after Phase 1):
```cpp
llvm::APInt PPCTargetInfo::getFMVPriority(ArrayRef<StringRef> Features) const {
  if (Features.empty())
    return llvm::APInt(32, 0);
  assert(Features.size() == 1 && "one feature/cpu per clone on PowerPC");
  ParsedTargetAttr ParsedAttr = parseTargetAttr(Features[0]);
  
  // CPU or single feature priority
  // ...
}
```

**New Code**:
```cpp
llvm::APInt PPCTargetInfo::getFMVPriority(ArrayRef<StringRef> Features) const {
  if (Features.empty())
    return llvm::APInt(32, 0);
  
  assert(Features.size() == 1 && "spec stored as single string");
  StringRef FullSpec = Features[0];
  
  int TotalPriority = 0;
  
  // Check for combined specification (CPU;feature)
  if (FullSpec.contains(';')) {
    SmallVector<StringRef, 2> Components;
    FullSpec.split(Components, ';', -1, false);
    
    assert(Components.size() == 2 && "combined spec must have exactly 2 components");
    
    StringRef CPUSpec = Components[0].trim();
    StringRef FeatureSpec = Components[1].trim();
    
    // Add CPU priority
    assert(CPUSpec.starts_with("cpu=") && "first component must be CPU");
    StringRef CPU = CPUSpec.drop_front(4).trim();
    int CPUPriority = llvm::StringSwitch<int>(CPU)
                         .Case("pwr7", 100)
                         .Case("pwr8", 200)
                         .Case("pwr9", 300)
                         .Case("pwr10", 400)
                         .Case("pwr11", 500)
                         .Default(0);
    TotalPriority += CPUPriority;
    
    // Add feature priority
    ParsedTargetAttr ParsedAttr = parseTargetAttr(FeatureSpec);
    if (!ParsedAttr.Features.empty()) {
      StringRef Feature = ParsedAttr.Features[0];
      // Remove leading '+' or '-'
      if (Feature.starts_with("+") || Feature.starts_with("-"))
        Feature = Feature.drop_front(1);
      
      int FeaturePriority = llvm::StringSwitch<int>(Feature)
          // POWER10 features (ISA 3.1)
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
          // Base features
          .Case("altivec", 40)
          .Default(0);
      
      TotalPriority += FeaturePriority;
    }
  } else {
    // Single component (CPU or feature)
    ParsedTargetAttr ParsedAttr = parseTargetAttr(FullSpec);
    
    if (!ParsedAttr.CPU.empty()) {
      // CPU only
      int CPUPriority = llvm::StringSwitch<int>(ParsedAttr.CPU)
                           .Case("pwr7", 100)
                           .Case("pwr8", 200)
                           .Case("pwr9", 300)
                           .Case("pwr10", 400)
                           .Case("pwr11", 500)
                           .Default(0);
      TotalPriority = CPUPriority;
    } else if (!ParsedAttr.Features.empty()) {
      // Feature only
      StringRef Feature = ParsedAttr.Features[0];
      // Remove leading '+' or '-'
      if (Feature.starts_with("+") || Feature.starts_with("-"))
        Feature = Feature.drop_front(1);
      
      int FeaturePriority = llvm::StringSwitch<int>(Feature)
          // POWER10 features (ISA 3.1)
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
          // Base features
          .Case("altivec", 40)
          .Default(0);
      
      TotalPriority = FeaturePriority;
    }
  }
  
  return llvm::APInt(32, TotalPriority);
}
```

---

### 6. clang/include/clang/Basic/AttrDocs.td

**Location**: PowerPC target_clones documentation
**Priority**: MEDIUM (Documentation)

**Add to Documentation**:
```
**Combined Specifications** (NEW):

A CPU specification can be combined with a single feature using semicolon (``;``) as delimiter:

  .. code-block:: c++

    // CPU with specific feature
    __attribute__((target_clones("cpu=pwr10;mma", "default")))
    void optimized_func() {}
    
    // CPU with negated feature
    __attribute__((target_clones("cpu=pwr8;no-vsx", "default")))
    void no_vector() {}
    
    // Mixed specifications
    __attribute__((target_clones(
        "cpu=pwr10;mma",      // POWER10 with MMA
        "cpu=pwr9",           // POWER9 baseline
        "altivec",            // Just AltiVec
        "default")))          // Baseline
    void complex_func() {}

**Syntax Rules**:

- At most one CPU specification per clone
- At most one feature specification per clone
- If both present, format is ``cpu=<cpu>;feature``
- CPU must come first, followed by semicolon, then feature
- Feature must have runtime detection capability

**Priority Calculation**:

When multiple clones match, priority is calculated as:
``Priority = CPU_priority + feature_priority``

Combined specifications (CPU+feature) have higher priority than CPU-only or feature-only.

**Examples**:

  .. code-block:: c++

    // Priority: 400 + 90 = 490
    "cpu=pwr10;mma"
    
    // Priority: 400
    "cpu=pwr10"
    
    // Priority: 90
    "mma"
```

---

## Implementation Strategy

### Phase 1: Parsing and Validation (Week 1)

**Goal**: Parse semicolon-delimited specifications and validate them

1. **Step 1.1**: Update SemaPPC.cpp parsing logic
   - Detect semicolon in specification
   - Split into exactly 2 components
   - Validate component structure

2. **Step 1.2**: Add validation checks
   - Exactly 2 components if semicolon present
   - First component must be CPU
   - Second component must be feature (not CPU)
   - Feature must have runtime detection
   - No empty components

3. **Step 1.3**: Add new diagnostics
   - Invalid combined specification format
   - Empty component errors
   - Multiple CPU errors
   - CPU position errors

4. **Step 1.4**: Basic testing
   - Test valid combined specifications
   - Test all error conditions
   - Test backward compatibility

### Phase 2: Code Generation (Week 1-2)

**Goal**: Generate correct code for combined specifications

1. **Step 2.1**: Update ASTContext.cpp
   - Parse combined specifications
   - Build feature maps with CPU + feature
   - Handle feature overrides correctly

2. **Step 2.2**: Update CodeGenFunction.cpp
   - Generate AND logic for CPU + feature
   - Test resolver generation

3. **Step 2.3**: Test code generation
   - Verify correct resolver logic
   - Test with various combinations
   - Check optimization opportunities

### Phase 3: Name Mangling and Priority (Week 2)

**Goal**: Implement deterministic mangling and priority

1. **Step 3.1**: Update name mangling
   - Implement combined mangling (cpu_<cpu>_<feature>)
   - Test uniqueness and determinism

2. **Step 3.2**: Update priority calculation
   - Implement additive priority
   - Test priority ordering
   - Verify correct version selection

3. **Step 3.3**: Integration testing
   - Test complete flow end-to-end
   - Verify symbol names
   - Check resolver behavior

### Phase 4: Documentation and Testing (Week 2-3)

**Goal**: Complete documentation and comprehensive testing

1. **Step 4.1**: Update documentation
   - Add combined specification examples
   - Document syntax rules
   - Explain priority calculation

2. **Step 4.2**: Comprehensive testing
   - Test all valid combinations
   - Test error cases
   - Test edge cases
   - Performance testing

3. **Step 4.3**: Code review and refinement
   - Address feedback
   - Optimize implementation
   - Final testing

---

## Testing Strategy

### Unit Tests

#### Parsing Tests (`clang/test/Sema/PowerPC/attr-target-clones-combined.c`)

```c
// Valid combined specifications
__attribute__((target_clones("cpu=pwr10;mma", "default")))
void test1() {}

__attribute__((target_clones("cpu=pwr9;no-vsx", "default")))
void test2() {}

// Error: multiple features
__attribute__((target_clones("cpu=pwr10;mma;prefixed", "default")))
void test_err1() {}
// expected-error@-1 {{invalid combined specification}}

// Error: multiple CPUs
__attribute__((target_clones("cpu=pwr10;cpu=pwr9", "default")))
void test_err2() {}
// expected-error@-1 {{multiple CPU specifications}}

// Error: feature before CPU
__attribute__((target_clones("mma;cpu=pwr10", "default")))
void test_err3() {}
// expected-error@-1 {{CPU specification must be first}}

// Error: empty component
__attribute__((target_clones("cpu=pwr10;", "default")))
void test_err4() {}
// expected-error@-1 {{empty component}}

// Error: feature without runtime detection
__attribute__((target_clones("cpu=pwr10;longcall", "default")))
void test_err5() {}
// expected-error@-1 {{feature 'longcall' cannot be used with target_clones}}
```

#### CodeGen Tests (`clang/test/CodeGen/PowerPC/attr-target-clones-combined.c`)

```c
// RUN: %clang_cc1 -triple powerpc64-ibm-aix -emit-llvm %s -o - | FileCheck %s

__attribute__((target_clones("cpu=pwr10;mma", "default")))
void combined_test() {}

// CHECK: define {{.*}} @combined_test.cpu_pwr10_mma()
// CHECK: define {{.*}} @combined_test.default()
// CHECK: define {{.*}} @combined_test.resolver()
// CHECK: call i32 @llvm.ppc.builtin.cpu.supports(ptr @{{.*}}arch_3_1{{.*}})
// CHECK: call i32 @llvm.ppc.builtin.cpu.supports(ptr @{{.*}}mma{{.*}})
// CHECK: and i1
```

### Integration Tests

#### Priority Tests

```c
__attribute__((target_clones(
    "cpu=pwr10;mma",      // Priority: 400+90 = 490
    "cpu=pwr10",          // Priority: 400
    "mma",                // Priority: 90
    "default")))          // Priority: 0
void priority_test() {}

// Verify resolver checks in order: 490, 400, 90, 0
```

#### Name Mangling Tests

```c
// CHECK: @combined_test.cpu_pwr10_mma
// CHECK: @negated.cpu_pwr8_no_vsx
// CHECK: @feature_only.altivec
// CHECK: @cpu_only.cpu_pwr9
```

### Edge Cases

```c
// Empty specification
__attribute__((target_clones("", "default")))  // Error

// Only semicolon
__attribute__((target_clones(";", "default")))  // Error

// Trailing semicolon
__attribute__((target_clones("cpu=pwr10;", "default")))  // Error

// Leading semicolon
__attribute__((target_clones(";cpu=pwr10", "default")))  // Error

// Whitespace handling
__attribute__((target_clones(" cpu=pwr10 ; mma ", "default")))  // OK

// Multiple semicolons
__attribute__((target_clones("cpu=pwr10;;mma", "default")))  // Error

// Feature only with semicolon
__attribute__((target_clones("mma;vsx", "default")))  // Error (multiple features)
```

---

## Success Criteria

### Minimal Success
- [ ] Parse semicolon-delimited specifications correctly
- [ ] Validate exactly 2 components if semicolon present
- [ ] Validate CPU must be first if both present
- [ ] Validate at most one feature per specification
- [ ] Generate correct resolver with AND logic
- [ ] Mangle combined specifications correctly
- [ ] Calculate priority as sum of CPU + feature
- [ ] Pass basic test cases
- [ ] Maintain backward compatibility

### Full Success
- [ ] All validation checks working with clear errors
- [ ] Efficient resolver generation (at most 2 checks)
- [ ] Deterministic name mangling
- [ ] Correct priority ordering in all cases
- [ ] Comprehensive test coverage (50+ test cases)
- [ ] Updated documentation with examples
- [ ] No performance regression
- [ ] No ABI breakage

---

## Open Questions

### Q1: Redundant Feature Checks

**Question**: Should we optimize when CPU implies the feature?

**Example**:
```c
// "cpu=pwr10;prefixed" generates:
if (__builtin_cpu_supports("arch_3_1") &&  // pwr10
    __builtin_cpu_supports("arch_3_1"))    // prefixed (same check!)
```

**Options**:
1. **Keep both checks** (simpler, clearer code)
2. **Deduplicate identical checks** (more efficient)

**Recommendation**: Option 2 - deduplicate identical checks
- Simple to implement (track seen checks)
- Improves performance
- Maintains correctness

**Status**: ⏳ OPEN - Decide during implementation

### Q2: Feature Dependency Validation

**Question**: Should we validate feature dependencies?

**Example**:
```c
// "cpu=pwr7;mma" - MMA requires POWER10
// Should this be an error or warning?
```

**Options**:
1. **No validation** (follow GCC behavior)
2. **Warning only** (inform user)
3. **Error** (strict validation)

**Recommendation**: Option 1 - no validation
- Matches GCC behavior
- Allows experimentation
- Runtime check will fail naturally
- Simpler implementation

**Status**: ✅ RESOLVED - No validation

### Q3: Negated Feature Priority

**Question**: How should negated features affect priority?

**Example**:
```c
"cpu=pwr10;no-vsx"  // Same priority as "cpu=pwr10"?
```

**Options**:
1. **Same priority** (negation doesn't change priority)
2. **Lower priority** (negation reduces capability)

**Recommendation**: Option 1 - same priority
- Simpler to understand
- Negation is about disabling, not capability
- Priority based on what's enabled

**Status**: ✅ RESOLVED - Same priority

---

## Risk Assessment

### High Risk

1. **Backward Compatibility**: Changes to parsing may break existing code
   - **Mitigation**: Extensive testing, maintain single-component path

### Medium Risk

1. **Validation Complexity**: Multiple validation rules may have bugs
   - **Mitigation**: Comprehensive test coverage, clear error messages

2. **Priority Calculation**: Additive priority may not be intuitive
   - **Mitigation**: Document clearly, provide examples

### Low Risk

1. **Documentation**: Users may not understand new syntax
   - **Mitigation**: Clear examples, migration guide

2. **Name Mangling**: Combined names may be long
   - **Mitigation**: Use underscores, keep format simple

---

## Timeline

### Week 1: Parsing and Validation
- Days 1-2: Implement parsing logic
- Days 3-4: Add validation checks
- Day 5: Testing and bug fixes

### Week 2: Code Generation and Mangling
- Days 1-2: Update ASTContext and resolver
- Days 3-4: Update name mangling and priority
- Day 5: Integration testing

### Week 3: Documentation and Polish
- Days 1-2: Update documentation
- Days 3-4: Comprehensive testing
- Day 5: Code review and refinement

**Total Estimated Time**: 3 weeks (simplified from 4 weeks due to reduced complexity)

---

## References

### Related Documents
- `IMPLEMENTATION_PLAN.md` - Phase 1 feature strings implementation
- `ppc_target_features.md` - Feature documentation
- `ppc_builtin_cpu_supports_mapping_aix.md` - Runtime detection mapping

### Key Code Locations
- **Parsing**: `clang/lib/Sema/SemaPPC.cpp`
- **Feature maps**: `clang/lib/AST/ASTContext.cpp`
- **Resolver**: `clang/lib/CodeGen/CodeGenFunction.cpp`
- **Mangling**: `clang/lib/CodeGen/Targets/PPC.cpp`
- **Priority**: `clang/lib/Basic/Targets/PPC.cpp`

### Standards and References
- GCC target_clones documentation
- LLVM coding standards
- PowerPC ABI documentation
- AIX IFUNC mechanism

---

## Summary

This extension adds the ability to combine a CPU specification with a single feature in `target_clones`. The key design decisions are:

1. **Semicolon delimiter** for combining CPU and feature
2. **At most one CPU and one feature** per specification
3. **CPU must be first** if both present
4. **AND logic** for runtime checks
5. **Additive priority** calculation

The implementation is straightforward and significantly simpler than allowing multiple features. The restriction to at most one feature covers most practical use cases while keeping the implementation manageable.