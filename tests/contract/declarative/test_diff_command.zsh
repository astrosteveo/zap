#!/usr/bin/env zsh
#
# Contract Test: zap diff Command
#
# Tests the `zap diff` command contract for state drift detection
#
# WHY: Diff must accurately detect drift, provide clear preview of changes,
# and use exit codes correctly (0 = drift, 1 = in sync).

# Load modules
source "${0:A:h}/../../../lib/state.zsh"
source "${0:A:h}/../../../lib/declarative.zsh"

# Test setup
TEST_NAME="zap diff Command Contract"
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

# TC-DIFF-001: Exit code 1 when in sync (no drift)
run_test "TC-DIFF-001: Exit code 1 when in sync"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_write_state

zap diff >/dev/null 2>&1
exit_code=$?

if [[ $exit_code -eq 1 ]]; then
  pass "Exit code 1 when in sync"
else
  fail "Exit code" "1 (in sync)" "$exit_code"
fi

# TC-DIFF-002: Exit code 0 when drift detected
run_test "TC-DIFF-002: Exit code 0 when drift detected"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_add_plugin_to_state "test/experimental" "test/experimental" "experimental" "/path" "v1" "try_command"
_zap_write_state

zap diff >/dev/null 2>&1
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
  pass "Exit code 0 when drift detected"
else
  fail "Exit code" "0 (drift)" "$exit_code"
fi

# TC-DIFF-003: Shows declared plugins
run_test "TC-DIFF-003: Shows declared plugins"
_zap_init_state
_zap_add_plugin_to_state "test/declared1" "test/declared1" "declared" "/path" "v1" "array"
_zap_add_plugin_to_state "test/declared2" "test/declared2" "declared" "/path" "v1" "array"
_zap_write_state

output=$(zap diff 2>&1)
if echo "$output" | grep -q "test/declared1" && echo "$output" | grep -q "test/declared2"; then
  pass "Shows declared plugins"
else
  fail "Shows declared" "both plugins listed" "$output"
fi

# TC-DIFF-004: Shows experimental plugins
run_test "TC-DIFF-004: Shows experimental plugins"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_add_plugin_to_state "test/exp1" "test/exp1" "experimental" "/path" "v1" "try_command"
_zap_add_plugin_to_state "test/exp2" "test/exp2" "experimental" "/path" "v1" "try_command"
_zap_write_state

output=$(zap diff 2>&1)
if echo "$output" | grep -q "test/exp1" && echo "$output" | grep -q "test/exp2"; then
  pass "Shows experimental plugins"
else
  fail "Shows experimental" "both plugins listed" "$output"
fi

# TC-DIFF-005: Indicates removal action
run_test "TC-DIFF-005: Indicates what will be removed"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_add_plugin_to_state "test/experimental" "test/experimental" "experimental" "/path" "v1" "try_command"
_zap_write_state

output=$(zap diff 2>&1)
if echo "$output" | grep -q "removed" || echo "$output" | grep -q "will be removed"; then
  pass "Indicates removal action"
else
  fail "Removal indication" "removed/will be removed" "$output"
fi

# TC-DIFF-006: Suggests sync command
run_test "TC-DIFF-006: Suggests sync command when drift detected"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_add_plugin_to_state "test/experimental" "test/experimental" "experimental" "/path" "v1" "try_command"
_zap_write_state

output=$(zap diff 2>&1)
if echo "$output" | grep -q "zap sync"; then
  pass "Suggests sync command"
else
  fail "Sync suggestion" "zap sync mentioned" "$output"
fi

# TC-DIFF-007: Reports clean state message
run_test "TC-DIFF-007: Reports clean state when no drift"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_write_state

output=$(zap diff 2>&1)
if echo "$output" | grep -q "No drift" || echo "$output" | grep -q "in sync"; then
  pass "Reports clean state"
else
  fail "Clean state message" "No drift/in sync" "$output"
fi

# TC-DIFF-008: Handles empty state
run_test "TC-DIFF-008: Handles empty state (no plugins)"
_zap_init_state
_zap_write_state

output=$(zap diff 2>&1)
if [[ $? -eq 1 ]]; then
  pass "Handles empty state correctly"
else
  fail "Empty state" "exit code 1" "exit code $?"
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
