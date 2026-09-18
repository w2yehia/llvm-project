# Target Attribute Function Inlining Investigation

## 1. Cross-Target Call Acceptance

### Test Case
```c
__attribute__((target("cpu=pwr9")))
int callee(int x) {
    return x * 2;
}

__attribute__((target("cpu=pwr8")))
int caller(int x) {
    return callee(x) + 1;
}
```

### Observed Result
- **Compilation Status:** Accepted without compilation errors or warnings.

---

## 2. Inlining Behavior Under Optimization (`-O2` / `-O3`)

### Case A: Mismatched Target Attributes (`caller=pwr8`, `callee=pwr9`)

#### Test Case
```c
__attribute__((target("cpu=pwr9")))
int callee(int x) {
    return x * 2;
}

__attribute__((target("cpu=pwr8")))
int caller(int x) {
    return callee(x) + 1;
}
```

#### Observed Result
- **Inlining Result:** No inlining occurs.
- **Generated IR:**
  ```llvm
  define dso_local i32 @caller(i32 noundef %x) local_unnamed_addr #1 {
  entry:
    %call = tail call i32 @callee(i32 noundef %x)
    %add = add nsw i32 %call, 1
    ret i32 %add
  }
  ```

---

### Case B: Matching Target Attributes (`caller=pwr8`, `callee=pwr8`)

#### Test Case
```c
__attribute__((target("cpu=power8")))
int callee(int x) {
    return x * 2;
}

__attribute__((target("cpu=power8")))
int caller(int x) {
    return callee(x) + 1;
}
```

#### Observed Result
- **Inlining Result:** Inlining occurs.
- **Generated IR:**
  ```llvm
  define dso_local i32 @caller(i32 noundef %x) local_unnamed_addr #0 {
  entry:
    %mul.i = shl nsw i32 %x, 1
    %add = or disjoint i32 %mul.i, 1
    ret i32 %add
  }
  ```

---

### Case C: Caller Matches One Clone of a `target_clones` Function

#### Test Case
```c
__attribute__((target_clones("cpu=power8,default")))
int callee(int x) {
    return x * 2;
}

__attribute__((target("cpu=power8")))
int caller(int x) {
    return callee(x) + 1;
}
```

The caller's `cpu=power8` target exactly matches the `cpu=power8` clone emitted
by `target_clones`.

All results are for `--target=powerpc64-ibm-aix-xcoff`.

#### Observed Result (AIX, `-O2`)

- **Inlining Result:** **No inlining.** The call site remains an indirect IFunc call.
- **Generated IR (relevant excerpt):**
  ```llvm
  @callee = ifunc i32 (i32), ptr @callee.resolver

  define internal signext i32 @callee.cpu_pwr8(i32 noundef signext %x) #0 {
  entry:
    %mul = shl nsw i32 %x, 1
    ret i32 %mul
  }

  define internal signext i32 @callee.default(i32 noundef signext %x) #1 {
  entry:
    %mul = shl nsw i32 %x, 1
    ret i32 %mul
  }

  define internal nonnull ptr @callee.resolver() #2 {
  entry:
    %0 = load i32, ptr getelementptr inbounds nuw (i8, ptr @_system_configuration, i64 4), align 4
    %1 = icmp ugt i32 %0, 65535
    %callee.cpu_pwr8.callee.default = select i1 %1, ptr @callee.cpu_pwr8, ptr @callee.default
    ret ptr %callee.cpu_pwr8.callee.default
  }

  define signext i32 @caller(i32 noundef signext %x) local_unnamed_addr #3 {
  entry:
    %call = tail call signext i32 @callee(i32 noundef signext %x) #4
    %add = add nsw i32 %call, 1
    ret i32 %add
  }
  ```

#### Analysis

Even though `caller` is compiled for `cpu=power8` and `callee.cpu_pwr8` is the
exact matching clone, **no inlining occurs** for two reasons:

1. **IFunc indirection:** The call site targets `@callee` (the IFunc alias), not
   `@callee.cpu_pwr8` directly.  The inliner sees only the IFunc global; it
   cannot look through the indirection to find the concrete clone.

2. **No static IFunc folding for PowerPC:** `GlobalOpt`'s FMV-aware IFunc
   resolution pass ([`llvm/lib/Transforms/IPO/GlobalOpt.cpp:2568-2743`](llvm/lib/Transforms/IPO/GlobalOpt.cpp:2568))
   can statically resolve an IFunc call site to its best concrete clone when the
   caller's target features are known at compile time.  This optimization is
   currently gated on `TTI.isMultiversionedFunction` /
   `TTI.getFeatureMask`, which is only implemented for **AArch64** (see
   [`llvm/lib/Target/AArch64/AArch64TargetTransformInfo.cpp:250-290`](llvm/lib/Target/AArch64/AArch64TargetTransformInfo.cpp:250)).
   PowerPC has no equivalent TTI hooks, so the resolver call is never folded
   away.

#### Potential Fix

Implementing `isMultiversionedFunction`, `getFeatureMask`, and `getPriorityMask`
in [`llvm/lib/Target/PowerPC/PPCTargetTransformInfo.cpp`](llvm/lib/Target/PowerPC/PPCTargetTransformInfo.cpp)
would allow `GlobalOpt` to:
- Recognise `@callee` as an FMV IFunc.
- Determine that `caller`'s feature set satisfies the `cpu=power8` variant.
- Replace the `@callee` IFunc call with a direct call to `@callee.cpu_pwr8`.
- Allow the inliner to subsequently inline `@callee.cpu_pwr8` into `@caller`
  (the feature sets match, so `areInlineCompatible` would pass).

---

### Case D: AArch64 — Caller Feature Set Implies a `target_version` Clone (Working Reference)

This case documents the **working** AArch64 FMV inlining path as a reference for
the PowerPC work.  Source file: [`t_aarch64.c`](t_aarch64.c).

#### Test Case
```c
/* Two distinct clones */
__attribute__((target_version("sve")))
int callee(int x) { return x + 100; }   /* SVE clone: adds 100 */

__attribute__((target_version("default")))
int callee(int x) { return x + 1; }     /* default clone: adds 1 */

/* +sve caller: should resolve & inline the SVE clone */
__attribute__((target("arch=armv8-a+sve")))
int caller_sve(int x) { return callee(x) + 1; }

/* baseline caller: cannot resolve statically */
int caller_default(int x) { return callee(x) + 1; }
```

#### Compilation command
```bash
clang -cc1 -triple aarch64-none-linux-gnu -O2 -emit-llvm -S -o - t_aarch64.c
```

> **Note:** `-cc1` is required because the driver adds `-fmv` to `target-features`
> on non-AArch64 hosts, which suppresses FMV IFunc emission.  Using `-cc1` with
> the explicit triple avoids this.

#### Observed Result (AArch64, `-O2`)

- **`caller_sve`** — **Fully inlined and folded.**  GlobalOpt resolved the IFunc
  to `@callee._Msve`, the inliner then inlined it, and constant-folding merged
  the two additions.
- **`caller_default`** — **Not inlined.**  The baseline caller has no FMV
  features, so GlobalOpt cannot statically determine which clone to use; the
  IFunc call is preserved for runtime dispatch.

```llvm
; @callee = weak_odr ifunc i32 (i32), ptr @callee.resolver   <-- emitted but
;   resolved away at call sites where the caller has +sve

define dso_local i32 @caller_sve(i32 noundef %x) local_unnamed_addr #2 {
entry:
  %add = add nsw i32 %x, 101        ; (x + 100) + 1 — SVE clone inlined & folded
  ret i32 %add
}

define dso_local i32 @caller_default(i32 noundef %x) local_unnamed_addr #3 {
entry:
  %call = tail call i32 @callee(i32 noundef %x) #5   ; IFunc call preserved
  %add = add nsw i32 %call, 1
  ret i32 %add
}
```

#### How it works

1. **`fmv-features` attribute:** Clang annotates each FMV clone with the
   `"fmv-features"` function attribute (e.g. `"fmv-features"="sve"`).
   This is the key marker that distinguishes FMV clones from plain functions.

2. **`TTI.isMultiversionedFunction`:** `GlobalOpt` calls this to identify FMV
   IFuncs.  On AArch64 it checks for the `"fmv-features"` attribute
   ([`AArch64TargetTransformInfo.cpp:276`](llvm/lib/Target/AArch64/AArch64TargetTransformInfo.cpp:276)).

3. **`TTI.getFeatureMask` / `TTI.getPriorityMask`:** Returns bitmasks of the
   features and priority for each clone/caller.  Used by `GlobalOpt` to pick
   the best clone the caller's features statically imply
   ([`AArch64TargetTransformInfo.cpp:264-274`](llvm/lib/Target/AArch64/AArch64TargetTransformInfo.cpp:264)).

4. **`OptimizeNonFMVCallers` (default: on):** Allows non-FMV callers (plain
   functions with a known `target-features` set) to also benefit from static
   IFunc resolution ([`GlobalOpt.cpp:98-101`](llvm/lib/Transforms/IPO/GlobalOpt.cpp:98)).

5. **Inliner:** Once the call site is rewritten from `@callee` (IFunc) to the
   concrete `@callee._Msve`, the normal inliner applies because both functions
   now share compatible `target-features`.

#### Why the same path does not work for PowerPC today

PowerPC's `PPCTargetTransformInfo` does not implement `isMultiversionedFunction`,
`getFeatureMask`, or `getPriorityMask`.  Without these hooks, `GlobalOpt` never
enters the FMV resolution path for PowerPC IFuncs, so the IFunc call is always
preserved as an indirect call regardless of the caller's CPU.

---

## Summary Matrix

| Target | Caller | Callee | Inlined at `-O2`? | Reason |
|:---|:---|:---|:---:|:---|
| PowerPC | `cpu=pwr8` | `cpu=pwr9` | No | Feature mismatch: `areInlineCompatible` fails |
| PowerPC | `cpu=power8` | `cpu=power8` | Yes | Matching features |
| PowerPC (AIX) | `cpu=power8` | `target_clones("cpu=power8,default")` | No | IFunc indirection; no PPC TTI hooks |
| AArch64 | `arch=armv8-a+sve` | `target_version("sve")` + `target_version("default")` | **Yes** | GlobalOpt resolves IFunc → `_Msve` clone; inliner folds result |
| AArch64 | baseline (no SVE) | `target_version("sve")` + `target_version("default")` | No | GlobalOpt cannot statically pick clone; runtime dispatch preserved |
