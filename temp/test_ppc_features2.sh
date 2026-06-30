#!/bin/bash

# PowerPC Feature Testing Script
# Tests all 43 features across Clang (native + AIX) and GCC

CLANG="/home/wyehia/Source/build.upstream.new/bin/clang"
GCC="/opt/at17.0/bin/gcc"
TEST_FILE="test_ppc_feature2.c"
RESULTS_FILE="ppc_feature_test_results2.txt"

# Feature list (43 features)
FEATURES=(
    "aix-shared-lib-tls-model-opt"
    "aix-small-local-dynamic-tls"
    "aix-small-local-exec-tls"
    "altivec"
    "avoid-indexed-addresses"
    "cmpb"
    "crbits"
    "crypto"
    "direct-move"
    "dlmzb"
    "efpu2"
    "float128"
    "fprnd"
    "friz"
    "hard-dfp"
    "htm"
    "invariant-function-descriptors"
    "isel"
    "longcall"
    "mfcrf"
    "mfocrf"
    "mma"
    "mulhw"
    "multiple"
    "paired"
    "paired-vector-memops"
    "pcrel"
    "popcntb"
    "popcntd"
    "power8-vector"
    "power9-vector"
    "power10-vector"
    "powerpc-gfxopt"
    "powerpc-gpopt"
    "prefixed"
    "privileged"
    "recip-precision"
    "rop-protect"
    "secure-plt"
    "spe"
    "string"
    "update"
    "vsx"
)

CPU_LEVELS=("" "power8" "power9" "power10")

# Clear results file
> "$RESULTS_FILE"

echo "Testing ${#FEATURES[@]} PowerPC features..."
echo "=========================================="

test_feature() {
    local compiler="$1"
    local feature="$2"
    local extra_flags="$3"
    local compiler_name="$4"
    
    local flag="-m${feature}"
    local cmd="$compiler $flag $extra_flags -c $TEST_FILE -o /dev/null 2>&1"
    local output
    
    output=$(eval "$cmd")
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo "1"
        return 0
    else
        # Extract first meaningful error line
        local error=$(echo "$output" | grep -E "(error:|unknown|unrecognized|cannot be specified)" | head -1 | sed 's/^.*: //')
        echo "0|$error"
        return 1
    fi
}

test_feature_with_retry() {
    local compiler="$1"
    local feature="$2"
    local base_flags="$3"
    local compiler_name="$4"
    
    # Try without CPU flag first
    result=$(test_feature "$compiler" "$feature" "$base_flags" "$compiler_name")
    if [[ "$result" == "1" ]]; then
        echo "$result||"
        return 0
    fi
    
    # Try with different CPU levels
    for cpu in "power8" "power9" "power10"; do
        result=$(test_feature "$compiler" "$feature" "$base_flags -mcpu=$cpu" "$compiler_name")
        if [[ "$result" == "1" ]]; then
            echo "$result|$cpu|"
            return 0
        fi
    done
    
    # All failed, return original error
    echo "$result||"
    return 1
}

# Test each feature
for feature in "${FEATURES[@]}"; do
    echo -n "Testing $feature... "
    
    # Test Clang native (ppc64le Linux)
    clang_linux=$(test_feature_with_retry "$CLANG" "$feature" "" "clang-linux")
    
    # Test Clang AIX cross-compile
    clang_aix=$(test_feature_with_retry "$CLANG" "$feature" "--target=powerpc64-ibm-aix-xcoff" "clang-aix")
    
    # Test GCC native (ppc64le Linux)
    gcc_linux=$(test_feature_with_retry "$GCC" "$feature" "" "gcc-linux")
    
    echo "done"
    
    # Write results
    echo "$feature|$clang_linux|$clang_aix|$gcc_linux" >> "$RESULTS_FILE"
done

echo ""
echo "Testing complete! Results saved to $RESULTS_FILE"
echo ""
echo "Summary:"
grep -c "^[^|]*|1|" "$RESULTS_FILE" | xargs echo "Clang Linux supported:"
grep -c "|1|[^|]*|[^|]*|1|" "$RESULTS_FILE" | xargs echo "Clang AIX supported:"
grep -c "|1|[^|]*|[^|]*|[^|]*|1|" "$RESULTS_FILE" | xargs echo "GCC Linux supported:"
