#!/bin/bash

# Compile test with all Clang-supported PowerPC features for AIX target
# 28 features total, each compiled separately

CLANG="/home/wyehia/Source/build.upstream.new/bin/clang"
TEST_FILE="test_ppc_feature2.c"
TARGET="--target=powerpc64-ibm-aix-xcoff"

echo "Compiling with all 28 Clang-supported PowerPC features for AIX..."
echo "=================================================================="

# Counter for successful compilations
SUCCESS=0
FAILED=0

compile_feature() {
    local feature="$1"
    local cpu_flag="$2"
    local desc="$3"
    
    echo -n "[$((SUCCESS + FAILED + 1))/28] Compiling with -m${feature} ${cpu_flag}... "
    
    if $CLANG $TARGET -m${feature} ${cpu_flag} -c $TEST_FILE -o /dev/null 2>&1; then
        echo "✓ SUCCESS"
        ((SUCCESS++))
        return 0
    else
        echo "✗ FAILED"
        ((FAILED++))
        return 1
    fi
}

# AIX-specific features (3 features)
compile_feature "aix-shared-lib-tls-model-opt" "" "AIX TLS model optimization"
compile_feature "aix-small-local-dynamic-tls" "" "AIX small local dynamic TLS"
compile_feature "aix-small-local-exec-tls" "" "AIX small local exec TLS"

# Standard features (no CPU requirement) (15 features)
compile_feature "altivec" "" "AltiVec/VMX"
compile_feature "cmpb" "" "Compare bytes"
compile_feature "crbits" "" "Condition register bits"
compile_feature "crypto" "" "Crypto extensions"
compile_feature "direct-move" "" "Direct move VSR<->GPR"
compile_feature "float128" "" "IEEE 128-bit float"
compile_feature "fprnd" "" "FP round to integer"
compile_feature "htm" "" "Hardware transactional memory"
compile_feature "invariant-function-descriptors" "" "Invariant function descriptors"
compile_feature "isel" "" "Integer select"
compile_feature "longcall" "" "Long call sequences"
compile_feature "mfcrf" "" "Move from CR fields"
compile_feature "mfocrf" "" "Move from one CR field"
compile_feature "popcntd" "" "Population count doubleword"
compile_feature "secure-plt" "" "Secure PLT"

# Power8 vector features (2 features)
compile_feature "power8-vector" "" "POWER8 vector"
compile_feature "power9-vector" "" "POWER9 vector"

# Features requiring -mcpu=power8 on AIX (2 features)
compile_feature "privileged" "-mcpu=power8" "Privileged mode"
compile_feature "rop-protect" "-mcpu=power8" "ROP protection"

# VSX feature (1 feature)
compile_feature "vsx" "" "Vector-scalar extensions"

# Power10 features (5 features)
compile_feature "mma" "-mcpu=power10" "Matrix-multiply assist"
compile_feature "paired-vector-memops" "-mcpu=power10" "Paired vector memory ops"
compile_feature "pcrel" "-mcpu=power10" "PC-relative addressing"
compile_feature "power10-vector" "-mcpu=power10" "POWER10 vector"
compile_feature "prefixed" "-mcpu=power10" "Prefixed instructions"

echo ""
echo "=================================================================="
echo "Compilation Summary:"
echo "  Successful: $SUCCESS/28"
echo "  Failed:     $FAILED/28"
echo "=================================================================="

if [ $SUCCESS -eq 28 ]; then
    echo "✓ All 28 features compiled successfully!"
    exit 0
else
    echo "✗ Some compilations failed"
    exit 1
fi
