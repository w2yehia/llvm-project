# CLAUDE.md Project Context for Bob

## Repository

This directory is the root of a clone of [w2yehia/llvm-project](https://github.com/w2yehia/llvm-project),
a fork of the upstream [llvm/llvm-project](https://github.com/llvm/llvm-project) monorepo
for LLVM, Clang, LLD, compiler-rt, and related sub-projects.

## Current Branch: `fmv_dev`

This branch is implementing **Function Multi-Versioning (FMV)** support for
PowerPC on AIX. The work extends Clang's `target_clones` attribute to support
runtime dispatch based on `__builtin_cpu_supports()` on 64-bit XCOFF AIX targets.

Key areas of work:
- Mapping `target_clones` feature strings to `__builtin_cpu_supports()` strings on AIX
- Categorizing features into those that can be disabled at runtime vs. compile-time-only features
- Validating feature names via `isValidFeatureName` assertion
- Integrating FMV priority into `PPC_AIX_CLONES_FEATURE`

Reference documents in the repo root:
- NULL

## Build Environment

- **Host OS:** ppc64le Linux
- **Build tree:** `/home/wyehia/Source/build.upstream.new`
- **Install prefix:** NULL
- **Build system:** Ninja
- **CMake preset:** `community-OpenXLC-Linux-dev`
- **Build type:** Release with assertions (`-DLLVM_ENABLE_ASSERTIONS=On`)
- **Projects built:** `clang`, `clang-tools-extra`, `llvm`, `lld`
- **Runtimes built:** `compiler-rt`

### Building

```bash
cd /home/wyehia/Source/build.upstream.new
ninja
```

### Running tests

```bash
cd /home/wyehia/Source/build.upstream.new
ninja check-clang        # Clang tests
ninja check-llvm         # LLVM tests
```

LIT is configured with `--threads=30 -v --time-tests`.

## Cross-Compiling for AIX (64-bit XCOFF)

The target of interest is **64-bit PowerPC AIX with XCOFF object format**.

To cross-compile a source file for this target, pass the `--target` flag to the
built `clang`:

```bash
/home/wyehia/Source/build.upstream.new/bin/clang \
    --target=powerpc64-ibm-aix-xcoff \
    -o output.o -c input.c
```

Key target triple: `powerpc64-ibm-aix-xcoff`

This is relevant for testing FMV codegen and `target_clones` behaviour as it
would appear on an AIX system, without needing a native AIX build machine.

## Notes

any reference to clang or ibm-clang in the current query is talking about the clang version in the current source tree and the executable is in the build tree.
