#!/usr/bin/env zsh
#
# Contract Test: zap try Command
#
# Tests the `zap try` command contract for experimental plugin loading
#
# WHY: Experimental plugins must be ephemeral (not persist across sessions),
# tracked correctly in state, and provide clear feedback to users.

# Load modules
source "${0:A:h}/../../../lib/state.zsh"
source "${0:A:h}/../../../lib/declarative.zsh"

# Test setup
TEST_NAME="zap try Command Contract"
TEST_DIR="$(mktemp -d)"
export ZAP_DATA_DIR="$TEST_DIR"
export ZAP_PLUGIN_DIR="$TEST_DIR/plugins"

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

# TC-TRY-001: zap try requires argument
run_test "TC-TRY-001: Error when no plugin specified"
if zap try 2>/dev/null; then
  fail "Requires plugin spec" "error exit code" "success"
else
  pass "Requires plugin spec"
fi

# TC-TRY-002: zap try validates spec
run_test "TC-TRY-002: Invalid spec rejected"
if zap try "../evil/plugin" 2>/dev/null; then
  fail "Invalid spec rejected" "error" "accepted"
else
  pass "Invalid spec rejected"
fi

# TC-TRY-003: Already declared plugin handled
run_test "TC-TRY-003: Already declared plugin is no-op"
_zap_init_state
_zap_add_plugin_to_state "test/plugin" "test/plugin" "declared" "/path" "v1" "array"
_zap_write_state

output=$(zap try "test/plugin" 2>&1)
if echo "$output" | grep -q "already declared"; then
  pass "Already declared detected"
else
  fail "Already declared detected" "already declared message" "$output"
fi

# TC-TRY-004: State tracking
run_test "TC-TRY-004: Experimental plugin tracked correctly"
# This test validates state tracking contract
_zap_init_state

# Mock a plugin directory (use owner__repo format for cache dir)
mkdir -p "$ZAP_PLUGIN_DIR/mock__test/.git"
echo "# Mock plugin" > "$ZAP_PLUGIN_DIR/mock__test/test.plugin.zsh"

# Try the plugin
if zap try "mock/test" 2>/dev/null; then
  # Check state
  metadata="${_zap_plugin_state[mock/test]}"
  state_field="${${(@s:|:)metadata}[1]}"
  source_field="${${(@s:|:)metadata}[6]}"

  if [[ "$state_field" == "experimental" && "$source_field" == "try_command" ]]; then
    pass "Tracked as experimental from try_command"
  else
    fail "Tracked correctly" "experimental|try_command" "$state_field|$source_field"
  fi
else
  fail "Plugin loads" "success" "failed"
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
