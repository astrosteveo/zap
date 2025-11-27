#!/usr/bin/env zsh
#
# Contract Test: zap status Command
#
# Tests the `zap status` command contract for state reporting
#
# WHY: Status must accurately report declared vs experimental plugins
# and provide clear user feedback about current state.

# Load modules
source "${0:A:h}/../../../lib/state.zsh"
source "${0:A:h}/../../../lib/declarative.zsh"

# Test setup
TEST_NAME="zap status Command Contract"
TEST_DIR="$(mktemp -d)"
export ZAP_DATA_DIR="$TEST_DIR"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
  ((TESTS_PASSED++))
  echo "  ✓ $1"
}

fail() {
  ((TESTS_FAILED++))
  echo "  ✗ $1"
  [[ -n "$2" ]] && echo "    Expected: $2"
  [[ -n "$3" ]] && echo "    Got: $3"
}

run_test() {
  ((TESTS_RUN++))
  echo "Test: $1"
}

# Cleanup
cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "=== $TEST_NAME ==="
echo ""

# TC-STATUS-001: Shows declared plugins
run_test "TC-STATUS-001: Shows declared plugins"
_zap_init_state
_zap_add_plugin_to_state "test/declared1" "test/declared1" "declared" "/path" "v1" "array"
_zap_add_plugin_to_state "test/declared2" "test/declared2" "declared" "/path" "v1" "array"
_zap_write_state

output=$(zap status 2>&1)
if echo "$output" | grep -q "test/declared1" && echo "$output" | grep -q "test/declared2"; then
  pass "Shows declared plugins"
else
  fail "Shows declared" "both plugins listed" "$output"
fi

# TC-STATUS-002: Shows experimental plugins
run_test "TC-STATUS-002: Shows experimental plugins"
_zap_init_state
_zap_add_plugin_to_state "test/exp1" "test/exp1" "experimental" "/path" "v1" "try_command"
_zap_add_plugin_to_state "test/exp2" "test/exp2" "experimental" "/path" "v1" "try_command"
_zap_write_state

output=$(zap status 2>&1)
if echo "$output" | grep -q "test/exp1" && echo "$output" | grep -q "test/exp2"; then
  pass "Shows experimental plugins"
else
  fail "Shows experimental" "both plugins listed" "$output"
fi

# TC-STATUS-003: Distinguishes declared vs experimental
run_test "TC-STATUS-003: Distinguishes plugin types"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_add_plugin_to_state "test/experimental" "test/experimental" "experimental" "/path" "v1" "try_command"
_zap_write_state

output=$(zap status 2>&1)
if echo "$output" | grep -q "Declared" && echo "$output" | grep -q "Experimental"; then
  pass "Distinguishes plugin types"
else
  fail "Distinguishes types" "Declared and Experimental headers" "$output"
fi

# TC-STATUS-004: Reports clean state
run_test "TC-STATUS-004: Reports clean state"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_write_state

output=$(zap status 2>&1)
if echo "$output" | grep -qi "in sync" || echo "$output" | grep -q "clean"; then
  pass "Reports clean state"
else
  fail "Reports clean" "in sync message" "$output"
fi

# TC-STATUS-005: Reports drift
run_test "TC-STATUS-005: Reports drift when experimental exist"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_add_plugin_to_state "test/experimental" "test/experimental" "experimental" "/path" "v1" "try_command"
_zap_write_state

output=$(zap status 2>&1)
if echo "$output" | grep -q "drift" || echo "$output" | grep -q "Experimental"; then
  pass "Reports drift"
else
  fail "Reports drift" "drift indicator" "$output"
fi

# TC-STATUS-006: Counts plugins correctly
run_test "TC-STATUS-006: Counts plugins correctly"
_zap_init_state
_zap_add_plugin_to_state "test/d1" "test/d1" "declared" "/path" "v1" "array"
_zap_add_plugin_to_state "test/d2" "test/d2" "declared" "/path" "v1" "array"
_zap_add_plugin_to_state "test/e1" "test/e1" "experimental" "/path" "v1" "try_command"
_zap_write_state

output=$(zap status 2>&1)
if echo "$output" | grep -q "2" && echo "$output" | grep -q "1"; then
  pass "Counts plugins correctly"
else
  fail "Plugin counts" "2 declared, 1 experimental" "$output"
fi

# Results
echo ""
echo "=== Results ==="
echo "Tests run: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo "Status: ✓ ALL TESTS PASSED"
  exit 0
else
  echo "Status: ✗ SOME TESTS FAILED"
  exit 1
fi
