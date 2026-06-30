#!/bin/bash

# Test all 28 Clang-supported PowerPC features with __attribute__((target("feature")))
# Tests both positive and negative forms (56 tests total)
# Each feature tested in a temporary C file that gets overwritten

CLANG="/home/wyehia/Source/build.upstream.new/bin/clang"
TEST_FILE="test_target_attr_temp.c"
TARGET="--target=powerpc64-ibm-aix-xcoff"
RESULTS_FILE="target_attribute_test_results.txt"

echo "Testing __attribute__((target(\"feature\"))) for PowerPC features on AIX..."
echo "Testing both positive (+feature) and negative (-feature) forms"
echo "==============================================================================="

# Clear results file
> "$RESULTS_FILE"

SUCCESS=0
FAILED=0

test_target_attribute() {
    local feature="$1"
    local cpu_flag="$2"
    local feature_in_IR="$3"
    local is_negative="$4"  # "yes" for negative test
    
    [[ -z $feature_in_IR ]] && feature_in_IR="$feature"
    local test_num=$((SUCCESS + FAILED + 1))
    
    local target_attr="$feature"
    local expected_ir_prefix="+"
    
    if [[ "$is_negative" == "yes" ]]; then
        target_attr="no-$feature"
        feature_in_IR="-${feature_in_IR}"
    else
	feature_in_IR="+${feature_in_IR}"
    fi
 
    
    # Generate test C file
    cat > "$TEST_FILE" << EOF
__attribute__((target("$target_attr")))
int test_function(void) {
    return 42;
}

int main(void) {
    return test_function();
}
EOF
    
    echo -n "[$test_num/56] Testing target(\"$target_attr\") ${cpu_flag}... "
    
    # Compile to IR and check for feature
    local output
    output=$($CLANG $TARGET $cpu_flag -Werror "$TEST_FILE" -emit-llvm -S -o - 2>&1)
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "$output" | grep -q "target-features.*\\${feature_in_IR}" || exit_code=-1
    fi
    
    # Compile to assembly
    if [ $exit_code -eq 0 ]; then
        output=$($CLANG $TARGET $cpu_flag -Werror "$TEST_FILE" -S -o - 2>&1)
        exit_code=$?
    fi
    
    if [ $exit_code -eq 0 ]; then
        echo "✓ SUCCESS"
        echo "$target_attr|1|$cpu_flag|${feature_in_IR}" >> "$RESULTS_FILE"
        ((SUCCESS++))
        return 0
    else
        # Extract error message
        local error;
        if [ $exit_code -eq -1 ]; then
            error="feature '${feature_in_IR}' not present in target-features"
        else
            error=$(echo "$output" | grep -E "(error:|warning:|unsupported)" | head -1 | sed 's/^.*: //')
        fi
        echo "✗ FAILED: $error"
        echo "$target_attr|0|$cpu_flag|$error" >> "$RESULTS_FILE"
        ((FAILED++))
        return 1
    fi
}

# Test each feature in both positive and negative forms

# AIX-specific features (3 features × 2 = 6 tests)
test_target_attribute "aix-shared-lib-tls-model-opt" "" "" ""
test_target_attribute "aix-shared-lib-tls-model-opt" "" "" "yes"
test_target_attribute "aix-small-local-dynamic-tls" "" "" ""
test_target_attribute "aix-small-local-dynamic-tls" "" "" "yes"
test_target_attribute "aix-small-local-exec-tls" "" "" ""
test_target_attribute "aix-small-local-exec-tls" "" "" "yes"

# Standard features (15 features × 2 = 30 tests)
test_target_attribute "altivec" "" "" ""
test_target_attribute "altivec" "" "" "yes"
test_target_attribute "cmpb" "" "" ""
test_target_attribute "cmpb" "" "" "yes"
test_target_attribute "crbits" "" "" ""
test_target_attribute "crbits" "" "" "yes"
test_target_attribute "crypto" "" "" ""
test_target_attribute "crypto" "" "" "yes"
test_target_attribute "direct-move" "" "" ""
test_target_attribute "direct-move" "" "" "yes"
test_target_attribute "float128" "" "" ""
test_target_attribute "float128" "" "" "yes"
test_target_attribute "fprnd" "" "" ""
test_target_attribute "fprnd" "" "" "yes"
test_target_attribute "htm" "" "" ""
test_target_attribute "htm" "" "" "yes"
test_target_attribute "invariant-function-descriptors" "" "" ""
test_target_attribute "invariant-function-descriptors" "" "" "yes"
test_target_attribute "isel" "" "" ""
test_target_attribute "isel" "" "" "yes"
test_target_attribute "longcall" "" "" ""
test_target_attribute "longcall" "" "" "yes"
test_target_attribute "mfcrf" "" "" ""
test_target_attribute "mfcrf" "" "" "yes"
test_target_attribute "mfocrf" "" "" ""
test_target_attribute "mfocrf" "" "" "yes"
test_target_attribute "popcntd" "" "" ""
test_target_attribute "popcntd" "" "" "yes"
test_target_attribute "secure-plt" "" "" ""
test_target_attribute "secure-plt" "" "" "yes"

# Power8 vector features (2 features × 2 = 4 tests)
test_target_attribute "power8-vector" "" "" ""
test_target_attribute "power8-vector" "" "" "yes"
test_target_attribute "power9-vector" "" "" ""
test_target_attribute "power9-vector" "" "" "yes"

# Features requiring -mcpu=power8 on AIX (2 features × 2 = 4 tests)
test_target_attribute "privileged" "-mcpu=power8" "" ""
test_target_attribute "privileged" "-mcpu=power8" "" "yes"
test_target_attribute "rop-protect" "-mcpu=power8" "" ""
test_target_attribute "rop-protect" "-mcpu=power8" "" "yes"

# VSX feature (1 feature × 2 = 2 tests)
test_target_attribute "vsx" "" "" ""
test_target_attribute "vsx" "" "" "yes"

# Power10 features (5 features × 2 = 10 tests)
test_target_attribute "mma" "-mcpu=power10" "" ""
test_target_attribute "mma" "-mcpu=power10" "" "yes"
test_target_attribute "paired-vector-memops" "-mcpu=power10" "" ""
test_target_attribute "paired-vector-memops" "-mcpu=power10" "" "yes"
test_target_attribute "pcrel" "-mcpu=power10" "pcrelative-memops" ""
test_target_attribute "pcrel" "-mcpu=power10" "pcrelative-memops" "yes"
test_target_attribute "power10-vector" "-mcpu=power10" "" ""
test_target_attribute "power10-vector" "-mcpu=power10" "" "yes"
test_target_attribute "prefixed" "-mcpu=power10" "prefix-instrs" ""
test_target_attribute "prefixed" "-mcpu=power10" "prefix-instrs" "yes"

# Clean up temporary test file
rm -f "$TEST_FILE"

echo ""
echo "==============================================================================="
echo "Target Attribute Test Summary:"
echo "  Successful: $SUCCESS/56 (28 positive + 28 negative)"
echo "  Failed:     $FAILED/56"
echo "==============================================================================="
echo "Results saved to: $RESULTS_FILE"

if [ $SUCCESS -eq 56 ]; then
    echo "✓ All 56 tests passed (28 features × 2 forms)!"
    exit 0
else
    echo "✗ Some features failed with target attribute"
    exit 1
fi
