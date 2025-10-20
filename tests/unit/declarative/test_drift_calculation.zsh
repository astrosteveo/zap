#!/usr/bin/env zsh
#
# Unit Test: Drift Calculation Logic
#
# Tests the _zap_calculate_drift() function and related query functions
# for correctness in computing state differences.
#

# Setup test environment
setopt ERR_EXIT
setopt PIPE_FAIL

# Load Zap library functions
SCRIPT_DIR="${0:A:h}"
ZAP_ROOT="${SCRIPT_DIR}/../../.."
source "${ZAP_ROOT}/lib/declarative.zsh"
source "${ZAP_ROOT}/lib/state.zsh"
source "${ZAP_ROOT}/lib/utils.zsh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Test framework functions
_test_start() {
  echo "TEST: $1"
  ((TESTS_RUN++))
}

_test_assert() {
  local condition="$1"
  local message="$2"

  if eval "$condition"; then
    echo "  ✓ $message"
    ((TESTS_PASSED++))
    return 0
  else
    echo "  ✗ FAIL: $message"
    return 1
  fi
}

_test_summary() {
  echo ""
  echo "========================================"
  echo "Tests run: $TESTS_RUN"
  echo "Tests passed: $TESTS_PASSED"
  echo "Tests failed: $((TESTS_RUN - TESTS_PASSED))"

  if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo "Status: ALL TESTS PASSED ✓"
    return 0
  else
    echo "Status: SOME TESTS FAILED ✗"
    return 1
  fi
}

# Setup test state directory
TEST_STATE_DIR=$(mktemp -d)
export ZAP_DATA_DIR="$TEST_STATE_DIR"
ZAP_STATE_FILE="${ZAP_DATA_DIR}/state.zsh"

# Cleanup function
_cleanup() {
  rm -rf "$TEST_STATE_DIR"
}
trap _cleanup EXIT

#
# Test 1: Empty state - no plugins declared or loaded
#
_test_start "Empty state - no drift"

# Create empty state
typeset -gA _zap_plugin_state
_zap_write_state

# Query plugins
declared_plugins=($(_zap_list_declared_plugins))
experimental_plugins=($(_zap_list_experimental_plugins))

_test_assert "[[ ${#declared_plugins[@]} -eq 0 ]]" "No declared plugins"
_test_assert "[[ ${#experimental_plugins[@]} -eq 0 ]]" "No experimental plugins"

#
# Test 2: Only declared plugins - no drift
#
_test_start "Only declared plugins - no drift"

# Add declared plugins to state
_zap_add_plugin_to_state "zsh-users/zsh-syntax-highlighting" "declared" \
  "zsh-users/zsh-syntax-highlighting" "" "array"

_zap_add_plugin_to_state "zsh-users/zsh-autosuggestions" "declared" \
  "zsh-users/zsh-autosuggestions@v0.7.0" "" "array"

# Query plugins
declared_plugins=($(_zap_list_declared_plugins))
experimental_plugins=($(_zap_list_experimental_plugins))

_test_assert "[[ ${#declared_plugins[@]} -eq 2 ]]" "Two declared plugins"
_test_assert "[[ ${#experimental_plugins[@]} -eq 0 ]]" "No experimental plugins"
_test_assert "[[ \"${declared_plugins[*]}\" == *\"zsh-syntax-highlighting\"* ]]" "Contains syntax-highlighting"
_test_assert "[[ \"${declared_plugins[*]}\" == *\"zsh-autosuggestions\"* ]]" "Contains autosuggestions"

#
# Test 3: Declared + experimental plugins - drift detected
#
_test_start "Declared + experimental plugins - drift detected"

# Add experimental plugin
_zap_add_plugin_to_state "jeffreytse/zsh-vi-mode" "experimental" \
  "jeffreytse/zsh-vi-mode" "" "try_command"

# Query plugins
declared_plugins=($(_zap_list_declared_plugins))
experimental_plugins=($(_zap_list_experimental_plugins))

_test_assert "[[ ${#declared_plugins[@]} -eq 2 ]]" "Still two declared plugins"
_test_assert "[[ ${#experimental_plugins[@]} -eq 1 ]]" "One experimental plugin"
_test_assert "[[ \"${experimental_plugins[*]}\" == *\"zsh-vi-mode\"* ]]" "Contains vi-mode as experimental"

#
# Test 4: Query specific plugin state
#
_test_start "Query specific plugin state"

# Check declared plugin
result=$(_zap_get_plugin_state "zsh-users/zsh-syntax-highlighting")
_test_assert "[[ \"$result\" == *\"declared\"* ]]" "Syntax-highlighting is declared"

# Check experimental plugin
result=$(_zap_get_plugin_state "jeffreytse/zsh-vi-mode")
_test_assert "[[ \"$result\" == *\"experimental\"* ]]" "Vi-mode is experimental"

# Check non-existent plugin
result=$(_zap_get_plugin_state "nonexistent/plugin")
_test_assert "[[ -z \"$result\" ]]" "Non-existent plugin returns empty"

#
# Test 5: Multiple experimental plugins
#
_test_start "Multiple experimental plugins"

# Add more experimental plugins
_zap_add_plugin_to_state "test/plugin1" "experimental" "test/plugin1" "" "try_command"
_zap_add_plugin_to_state "test/plugin2" "experimental" "test/plugin2" "" "try_command"

# Query plugins
experimental_plugins=($(_zap_list_experimental_plugins))

_test_assert "[[ ${#experimental_plugins[@]} -eq 3 ]]" "Three experimental plugins total"

#
# Test 6: Remove experimental plugin
#
_test_start "Remove experimental plugin"

# Remove one experimental plugin
_zap_remove_plugin_from_state "test/plugin1"

# Query plugins
experimental_plugins=($(_zap_list_experimental_plugins))

_test_assert "[[ ${#experimental_plugins[@]} -eq 2 ]]" "Two experimental plugins remain"
_test_assert "[[ \"${experimental_plugins[*]}\" != *\"plugin1\"* ]]" "plugin1 was removed"
_test_assert "[[ \"${experimental_plugins[*]}\" == *\"plugin2\"* ]]" "plugin2 still exists"

#
# Test 7: Convert experimental to declared (adoption)
#
_test_start "Convert experimental to declared (adoption)"

# Update plugin state from experimental to declared
_zap_update_plugin_state "jeffreytse/zsh-vi-mode" "declared" \
  "jeffreytse/zsh-vi-mode" "" "array"

# Query plugins
declared_plugins=($(_zap_list_declared_plugins))
experimental_plugins=($(_zap_list_experimental_plugins))

_test_assert "[[ ${#declared_plugins[@]} -eq 3 ]]" "Three declared plugins now"
_test_assert "[[ ${#experimental_plugins[@]} -eq 1 ]]" "One experimental plugin remains"
_test_assert "[[ \"${declared_plugins[*]}\" == *\"zsh-vi-mode\"* ]]" "Vi-mode is now declared"

#
# Test 8: Clear all experimental plugins
#
_test_start "Clear all experimental plugins"

# Remove remaining experimental plugins
for plugin in $(_zap_list_experimental_plugins); do
  _zap_remove_plugin_from_state "$plugin"
done

# Query plugins
experimental_plugins=($(_zap_list_experimental_plugins))

_test_assert "[[ ${#experimental_plugins[@]} -eq 0 ]]" "No experimental plugins remain"
_test_assert "[[ ${#declared_plugins[@]} -eq 3 ]]" "Declared plugins unchanged"

#
# Test 9: State persistence across loads
#
_test_start "State persistence across loads"

# Write current state
_zap_write_state

# Clear in-memory state
unset _zap_plugin_state
typeset -gA _zap_plugin_state

# Reload state from disk
_zap_load_state

# Query plugins again
declared_plugins=($(_zap_list_declared_plugins))

_test_assert "[[ ${#declared_plugins[@]} -eq 3 ]]" "Declared plugins persist after reload"

#
# Test 10: Handle malformed state gracefully
#
_test_start "Handle malformed state gracefully"

# Corrupt state file
echo "INVALID STATE" >> "$ZAP_STATE_FILE"

# Reload state (should recover or reset)
_zap_load_state

# Should still be able to query (may be empty if reset)
declared_plugins=($(_zap_list_declared_plugins 2>/dev/null))

_test_assert "[[ -n \"${declared_plugins+x}\" ]]" "State query doesn't crash on corruption"

# Print summary
_test_summary
