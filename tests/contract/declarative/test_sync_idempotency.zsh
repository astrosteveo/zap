#!/usr/bin/env zsh
#
# Contract Test: zap sync Idempotency
#
# Tests that zap sync is truly idempotent - can be run multiple times safely
#
# WHY: Idempotent operations are critical for declarative systems.
# Users should be able to run sync repeatedly without side effects.

# Load modules
source "${0:A:h}/../../../lib/state.zsh"
source "${0:A:h}/../../../lib/declarative.zsh"

# Test setup
TEST_NAME="zap sync Idempotency Contract"
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

# TC-IDEMPOTENT-001: Running sync multiple times produces same result
run_test "TC-IDEMPOTENT-001: Multiple syncs produce same result"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_add_plugin_to_state "test/experimental" "test/experimental" "experimental" "/path" "v1" "try_command"
_zap_write_state

# Run sync three times
zap sync >/dev/null 2>&1
zap sync >/dev/null 2>&1
zap sync >/dev/null 2>&1

# Check final state
_zap_load_state
if [[ -n "${_zap_plugin_state[test/declared]}" && -z "${_zap_plugin_state[test/experimental]}" ]]; then
  pass "Multiple syncs produce consistent state"
else
  fail "Consistent state" "declared kept, experimental removed" "state mismatch"
fi

# TC-IDEMPOTENT-002: Sync when already in sync is no-op
run_test "TC-IDEMPOTENT-002: Sync when in sync is no-op"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_write_state

output=$(zap sync 2>&1)
if echo "$output" | grep -q "Already in sync" || echo "$output" | grep -q "already in sync"; then
  pass "No-op when already in sync"
else
  fail "No-op detection" "Already in sync message" "$output"
fi

# TC-IDEMPOTENT-003: State file not corrupted by multiple syncs
run_test "TC-IDEMPOTENT-003: State file remains valid"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_add_plugin_to_state "test/experimental" "test/experimental" "experimental" "/path" "v1" "try_command"
_zap_write_state

# Run sync multiple times
for i in {1..5}; do
  zap sync >/dev/null 2>&1
done

# Verify state file is still loadable
_zap_load_state
if [[ ${(t)_zap_plugin_state} == "association" ]]; then
  pass "State file remains valid after multiple syncs"
else
  fail "State file validity" "associative array" "${(t)_zap_plugin_state}"
fi

# TC-IDEMPOTENT-004: Exit code consistent across runs
run_test "TC-IDEMPOTENT-004: Consistent exit codes"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_write_state

zap sync >/dev/null 2>&1
exit1=$?
zap sync >/dev/null 2>&1
exit2=$?
zap sync >/dev/null 2>&1
exit3=$?

if [[ $exit1 -eq $exit2 && $exit2 -eq $exit3 ]]; then
  pass "Exit codes consistent across runs"
else
  fail "Exit code consistency" "all same" "$exit1, $exit2, $exit3"
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
