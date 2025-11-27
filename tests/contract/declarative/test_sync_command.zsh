#!/usr/bin/env zsh
#
# Contract Test: zap sync Command
#
# Tests the `zap sync` command contract for state reconciliation
#
# WHY: Sync must be idempotent, remove only experimental plugins,
# and preserve declared plugins exactly.

# Load modules
source "${0:A:h}/../../../lib/state.zsh"
source "${0:A:h}/../../../lib/declarative.zsh"

# Test setup
TEST_NAME="zap sync Command Contract"
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

# TC-SYNC-001: No experimental plugins
run_test "TC-SYNC-001: Already in sync"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_write_state

output=$(zap sync 2>&1)
if echo "$output" | grep -q "Already in sync"; then
  pass "Reports already in sync"
else
  fail "Reports sync status" "already in sync" "$output"
fi

# TC-SYNC-002: Remove experimental plugins
run_test "TC-SYNC-002: Removes experimental plugins"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_add_plugin_to_state "test/experimental" "test/experimental" "experimental" "/path" "v1" "try_command"
_zap_write_state

zap sync >/dev/null 2>&1

_zap_load_state
if [[ -n "${_zap_plugin_state[test/declared]}" && -z "${_zap_plugin_state[test/experimental]}" ]]; then
  pass "Removed experimental, kept declared"
else
  fail "Correct removal" "declared kept, experimental removed" "state mismatch"
fi

# TC-SYNC-003: Idempotent
run_test "TC-SYNC-003: Idempotent operation"
_zap_init_state
_zap_add_plugin_to_state "test/declared" "test/declared" "declared" "/path" "v1" "array"
_zap_write_state

zap sync >/dev/null 2>&1
zap sync >/dev/null 2>&1
zap sync >/dev/null 2>&1

_zap_load_state
if [[ -n "${_zap_plugin_state[test/declared]}" ]]; then
  pass "Idempotent - declared plugin remains"
else
  fail "Idempotent" "declared remains" "plugin missing"
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
