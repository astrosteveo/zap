#!/usr/bin/env zsh
#
# Unit Test: State Metadata Operations
#
# Tests the state management functions in lib/state.zsh
#
# WHY: State operations are the foundation of the declarative system.
# We must verify atomic writes, corruption recovery, and query operations.
#

# Load the state module
source "${0:A:h}/../../../lib/state.zsh"

# Test setup
TEST_NAME="State Metadata Operations"
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

# TC-STATE-001: Add plugin to state
run_test "TC-STATE-001: Add plugin to state"
_zap_add_plugin_to_state "test/plugin" "test/plugin@v1.0" "declared" "/path/to/plugin" "v1.0" "array"

if [[ -n "${_zap_plugin_state[test/plugin]}" ]]; then
  pass "Plugin added to state"
else
  fail "Plugin added to state" "metadata present" "metadata missing"
fi

# TC-STATE-002: Metadata format validation
run_test "TC-STATE-002: Metadata has correct format"
metadata="${_zap_plugin_state[test/plugin]}"
field_count=$(echo "$metadata" | awk -F'|' '{print NF}')

if [[ $field_count -eq 6 ]]; then
  pass "Metadata has 6 pipe-delimited fields"
else
  fail "Metadata has 6 pipe-delimited fields" "6" "$field_count"
fi

# TC-STATE-003: Write state to file
run_test "TC-STATE-003: Write state to file"
_zap_write_state

if [[ -f "$ZAP_DATA_DIR/state.zsh" ]]; then
  pass "State file created"
else
  fail "State file created" "file exists" "file missing"
fi

# TC-STATE-004: Load state from file
run_test "TC-STATE-004: Load state from file"
unset _zap_plugin_state
_zap_load_state

if [[ -n "${_zap_plugin_state[test/plugin]}" ]]; then
  pass "State loaded from file"
else
  fail "State loaded from file" "plugin present" "plugin missing"
fi

# TC-STATE-005: Remove plugin from state
run_test "TC-STATE-005: Remove plugin from state"
_zap_remove_plugin_from_state "test/plugin"

if [[ -z "${_zap_plugin_state[test/plugin]}" ]]; then
  pass "Plugin removed from state"
else
  fail "Plugin removed from state" "no metadata" "metadata still present"
fi

# TC-STATE-006: Update plugin state
run_test "TC-STATE-006: Update plugin state"
_zap_add_plugin_to_state "test/plugin2" "test/plugin2" "experimental" "/path" "v1" "try_command"
_zap_update_plugin_state "test/plugin2" "declared" "array"

metadata="${_zap_plugin_state[test/plugin2]}"
state_field="${${(@s:|:)metadata}[1]}"
source_field="${${(@s:|:)metadata}[6]}"

if [[ "$state_field" == "declared" && "$source_field" == "array" ]]; then
  pass "Plugin state updated correctly"
else
  fail "Plugin state updated correctly" "declared|array" "$state_field|$source_field"
fi

# TC-STATE-007: List declared plugins
run_test "TC-STATE-007: List declared plugins"
_zap_add_plugin_to_state "declared/plugin1" "declared/plugin1" "declared" "/path1" "v1" "array"
_zap_add_plugin_to_state "experimental/plugin1" "experimental/plugin1" "experimental" "/path2" "v1" "try_command"
_zap_add_plugin_to_state "declared/plugin2" "declared/plugin2" "declared" "/path3" "v1" "array"

declared_list=$(_zap_list_declared_plugins)
declared_count=$(echo "$declared_list" | grep -c "declared/")

if [[ $declared_count -eq 3 ]]; then
  pass "List declared plugins (found 3 declared)"
else
  fail "List declared plugins" "3 declared" "$declared_count declared"
fi

# TC-STATE-008: List experimental plugins
run_test "TC-STATE-008: List experimental plugins"
experimental_list=$(_zap_list_experimental_plugins)
experimental_count=$(echo "$experimental_list" | grep -c "experimental/")

if [[ $experimental_count -eq 1 ]]; then
  pass "List experimental plugins (found 1 experimental)"
else
  fail "List experimental plugins" "1 experimental" "$experimental_count experimental"
fi

# TC-STATE-009: Corruption recovery
run_test "TC-STATE-009: Corruption recovery"
echo "garbage data" > "$ZAP_DATA_DIR/state.zsh"
unset _zap_plugin_state
_zap_load_state

if [[ -f "$ZAP_DATA_DIR/state.zsh.corrupted."* ]]; then
  pass "Corrupted file backed up"
else
  fail "Corrupted file backed up" "backup exists" "no backup"
fi

if [[ ${(t)_zap_plugin_state} == "association" ]]; then
  pass "State reinitialized after corruption"
else
  fail "State reinitialized after corruption" "association" "${(t)_zap_plugin_state}"
fi

# TC-STATE-010: Atomic write (temp file cleaned up)
run_test "TC-STATE-010: Atomic write cleanup"
_zap_add_plugin_to_state "atomic/test" "atomic/test" "declared" "/path" "v1" "array"
_zap_write_state

temp_files=$(ls "$ZAP_DATA_DIR"/state.zsh.tmp.* 2>/dev/null | wc -l)

if [[ $temp_files -eq 0 ]]; then
  pass "No temp files left behind"
else
  fail "No temp files left behind" "0 temp files" "$temp_files temp files"
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
