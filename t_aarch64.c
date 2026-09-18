/*
 * AArch64 FMV inlining example.
 *
 * Demonstrates that GlobalOpt resolves and inlines a target_version IFunc call
 * when the caller's static target features imply one of the concrete clones.
 *
 * Compile for AArch64 via clang -cc1 to avoid the -fmv feature suppression
 * that the driver adds on non-AArch64 hosts:
 *
 *   clang -cc1 -triple aarch64-none-linux-gnu -O2 -emit-llvm -S -o - t_aarch64.c
 *
 * AArch64 uses target_version (single-version declaration) or target_clones
 * (comma-separated list in one declaration) for FMV.  Both produce the same
 * IFunc + resolver IR.
 */

/* callee has two distinct clones with clearly different behaviour */
__attribute__((target_version("sve")))
int callee(int x) { return x + 100; }   /* SVE clone: adds 100 */

__attribute__((target_version("default")))
int callee(int x) { return x + 1; }     /* default clone: adds 1 */

/*
 * Caller compiled for +sve (via target attribute).
 * GlobalOpt resolves @callee IFunc -> @callee._Msve, then inlines it.
 * Result: x + 100 + 1  =>  x + 101  (no call, no IFunc).
 */
__attribute__((target("arch=armv8-a+sve")))
int caller_sve(int x) { return callee(x) + 1; }

/*
 * Caller with no extra features (plain armv8-a baseline).
 * GlobalOpt cannot statically pick the SVE clone, so the IFunc call
 * is left as-is and resolved at runtime via @callee.resolver.
 */
int caller_default(int x) { return callee(x) + 1; }
