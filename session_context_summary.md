# Session Context & Investigation Transcript

> **Purpose:** Load this file into a new Bob session to resume the investigation on Clang/LLVM function multi-versioning (FMV), target attributes, and inlining behavior on PowerPC and AIX.

---

## 1. Summary of Topics Covered

1. **Target Attribute Function Calls (`__attribute__((target("...")))`):**
   - Direct call from `cpu=power8` function to another `cpu=power8` function: **Accepted and inlines** at `-O2`.
   - Direct call from `cpu=power8` function to a `cpu=pwr9` function: **Compiles without error**, but **does NOT inline** at `-O2` due to target feature mismatch checks in LLVM inliner.
   - Files created/modified: [`t.c`](t.c:1), [`target_inlining_investigation.md`](target_inlining_investigation.md:1).

2. **Target Clones / FMV Calls (`__attribute__((target_clones("...")))`):**
   - When a `cpu=power8` caller invokes a `target_clones("cpu=power8,default")` function:
     - Clang emits an `@ifunc` symbol (or resolver) on both Linux ELF and AIX XCOFF (`powerpc64-ibm-aix-xcoff`).
     - The call remains an indirect / IFunc call (`tail call i32 @callee(...)`) and is **not inlined** by the default inliner.

3. **LLVM `GlobalOpt` IFunc Resolution (`llvm/lib/Transforms/IPO/GlobalOpt.cpp`):**
   - **`OptimizeStaticIFuncs`**: Can eliminate IFunc calls when the resolver function trivially and unconditionally returns a single constant function pointer.
   - **FMV-aware Optimization (`GlobalOpt.cpp:2568-2743`)**: Resolves IFunc call sites to concrete clones when the caller's target features statically satisfy a version. Currently hooked up via TTI (`isMultiversionedFunction`, `getFeatureMask`, `getPriorityMask`) primarily on **AArch64** (`"fmv-features"`), but **not yet implemented for PowerPC**.

---

## 2. Test Cases & Observed Behaviors

### Test Case 1: Matching Target Attribute Call & Inlining
```c
__attribute__((target("cpu=power8")))
int callee(int x) { return x * 2; }

__attribute__((target("cpu=power8")))
int caller(int x) { return callee(x) + 1; }
```
- **Result at `-O2`:** Inlined. Caller computes `(x << 1) | 1` directly.

---

### Test Case 2: Mismatched Target Attribute Call
```c
__attribute__((target("cpu=pwr9")))
int callee(int x) { return x * 2; }

__attribute__((target("cpu=pwr8")))
int caller(int x) { return callee(x) + 1; }
```
- **Result at `-O2`:** Compiles cleanly, but call is **not inlined** (`TargetTransformInfo::areInlineCompatible` fails due to differing `target-cpu` and `target-features`).

---

### Test Case 3: Calling a `target_clones` Function from Target-Specific Caller
```c
__attribute__((target_clones("cpu=power8,default")))
int callee(int x) { return x * 2; }

__attribute__((target("cpu=power8")))
int caller(int x) { return callee(x) + 1; }
```
- **Linux (`powerpc64le-linux-gnu`) & AIX (`powerpc64-ibm-aix-xcoff`):**
  - `@callee` is emitted as an `@ifunc` pointing to `@callee.resolver`.
  - `@caller` issues `call i32 @callee(i32 %x)`.
  - Inliner does not inline the call because target is an `@ifunc`.

---

## 3. Relevant Codebase Locations in LLVM/Clang

- **Clang Call Feature Checks:** [`clang/lib/CodeGen/CGCall.cpp:5665-5685`](clang/lib/CodeGen/CGCall.cpp:5665)
  - Checks compatibility only for `always_inline` or `flatten`.
- **Target Inlining Compatibility Check:** [`llvm/lib/Analysis/InlineCost.cpp:3208`](llvm/lib/Analysis/InlineCost.cpp:3208) and [`llvm/include/llvm/Analysis/TargetTransformInfoImpl.h:1084`](llvm/include/llvm/Analysis/TargetTransformInfoImpl.h:1084)
- **AIX IFunc Support:** [`clang/include/clang/Basic/TargetInfo.h:1592`](clang/include/clang/Basic/TargetInfo.h:1592) & [`clang/test/CodeGen/PowerPC/attr-target-clones.c`](clang/test/CodeGen/PowerPC/attr-target-clones.c:1)
- **GlobalOpt IFunc Resolution:** [`llvm/lib/Transforms/IPO/GlobalOpt.cpp:2480-2743`](llvm/lib/Transforms/IPO/GlobalOpt.cpp:2480)
- **AArch64 FMV TTI Implementation (Reference for PPC FMV TTI):** [`llvm/lib/Target/AArch64/AArch64TargetTransformInfo.cpp:250-290`](llvm/lib/Target/AArch64/AArch64TargetTransformInfo.cpp:250)

---

## 4. Potential Next Steps / Open Questions

1. Investigating adding PowerPC support for `TTI.isMultiversionedFunction` and feature mask extraction so `GlobalOpt` can resolve IFunc calls for PowerPC.
2. Exploring early direct call binding for target clones when caller CPU is known at compile-time.
3. Checking compiler flags or optimizations that bypass IFunc resolution for internal/static linkage target clones.
