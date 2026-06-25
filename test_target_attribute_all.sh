#!/bin/bash

# Test all 28 Clang-supported PowerPC features with __attribute__((target("feature")))
# Each feature tested in a temporary C file that gets overwritten

CLANG="/home/wyehia/Source/build.upstream.new/bin/clang"
TEST_FILE="test_target_attr_temp.c"
TARGET="--target=powerpc64-ibm-aix-xcoff"
RESULTS_FILE="target_attribute_test_results.txt"

echo "Testing __attribute__((target(\"feature\"))) for 28 PowerPC features on AIX..."
echo "==============================================================================="

# Clear results file
> "$RESULTS_FILE"

SUCCESS=0
FAILED=0

test_target_attribute() {
    local feature="$1"
    local cpu_flag="$2"
    local feature_in_IR="$3"
    [[ -z $feature_in_IR ]] && feature_in_IR="$feature"
    local test_num=$((SUCCESS + FAILED + 1))
    
    # Generate test C file
    cat > "$TEST_FILE" << EOF
__attribute__((target("$feature")))
int test_function(void) {
    return 42;
}

int main(void) {
    return test_function();
}
EOF
    
    echo -n "[$test_num/28] Testing target(\"$feature\") ${cpu_flag}... "
    
    # Compile
    local output
    output=$($CLANG $TARGET $cpu_flag -Werror "$TEST_FILE" -emit-llvm -S -o - 2>&1)
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
      echo "$output" | grep -q "target-features.*\+${feature_in_IR}" || exit_code=-1
    fi
    if [ $exit_code -eq 0 ]; then
      output=$($CLANG $TARGET $cpu_flag -Werror "$TEST_FILE" -S -o - 2>&1)
      exit_code=$?
    fi
    
    if [ $exit_code -eq 0 ]; then
        echo "✓ SUCCESS"
        echo "$feature|1|$cpu_flag|" >> "$RESULTS_FILE"
        ((SUCCESS++))
        return 0
    else
        # Extract error message
        local error;
        [ $exit_code -eq -1 ] \
           && error="feature not present in target-features" \
           || error=$(echo "$output" | grep -E "(error:|warning:|unsupported)" | head -1 | sed 's/^.*: //')
        echo "✗ FAILED: $error"
        echo "$feature|0|$cpu_flag|$error" >> "$RESULTS_FILE"
        ((FAILED++))
        return 1
    fi
}

# AIX-specific features (3 features)
test_target_attribute "aix-shared-lib-tls-model-opt" ""
test_target_attribute "aix-small-local-dynamic-tls" ""
test_target_attribute "aix-small-local-exec-tls" ""

# Standard features (no CPU requirement) (15 features)
test_target_attribute "altivec" ""
test_target_attribute "cmpb" ""
test_target_attribute "crbits" ""
test_target_attribute "crypto" ""
test_target_attribute "direct-move" ""
test_target_attribute "float128" ""
test_target_attribute "fprnd" ""
test_target_attribute "htm" ""
test_target_attribute "invariant-function-descriptors" ""
test_target_attribute "isel" ""
test_target_attribute "longcall" ""
test_target_attribute "mfcrf" ""
test_target_attribute "mfocrf" ""
test_target_attribute "popcntd" ""
test_target_attribute "secure-plt" ""

# Power8 vector features (2 features)
test_target_attribute "power8-vector" ""
test_target_attribute "power9-vector" ""

# Features requiring -mcpu=power8 on AIX (2 features)
test_target_attribute "privileged" "-mcpu=power8"
test_target_attribute "rop-protect" "-mcpu=power8"

# VSX feature (1 feature)
test_target_attribute "vsx" ""

# Power10 features (5 features)
test_target_attribute "mma" "-mcpu=power10"
test_target_attribute "paired-vector-memops" "-mcpu=power10"
test_target_attribute "pcrel" "-mcpu=power10" "pcrelative-memops"
test_target_attribute "power10-vector" "-mcpu=power10" 
test_target_attribute "prefixed" "-mcpu=power10" "prefix-instrs"

# Clean up temporary test file
rm -f "$TEST_FILE"

echo ""
echo "==============================================================================="
echo "Target Attribute Test Summary:"
echo "  Successful: $SUCCESS/28"
echo "  Failed:     $FAILED/28"
echo "==============================================================================="
echo "Results saved to: $RESULTS_FILE"

if [ $SUCCESS -eq 28 ]; then
    echo "✓ All 28 features work with __attribute__((target(\"feature\")))!"
    exit 0
else
    echo "✗ Some features failed with target attribute"
    exit 1
fi
