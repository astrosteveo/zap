#!/usr/bin/env zsh
#
# Contract Test: zap adopt Command
#
# Tests the `zap adopt` command contract for promoting experimental plugins
#
# WHY: Adopt must safely modify .zshrc, create backups, and transition
# experimental plugins to declared state.

# Load modules
source "${0:A:h}/../../../lib/state.zsh"
source "${0:A:h}/../../../lib/declarative.zsh"

# Test setup
TEST_NAME="zap adopt Command Contract"
TEST_DIR="$(mktemp -d)"
export ZAP_DATA_DIR="$TEST_DIR"
export ZDOTDIR="$TEST_DIR"

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

# TC-ADOPT-001: Error when no plugin specified
run_test "TC-ADOPT-001: Error when no plugin specified"
if zap adopt 2>/dev/null; then
  fail "Requires plugin spec" "error exit code" "success"
else
  pass "Requires plugin spec"
fi

# TC-ADOPT-002: Invalid spec rejected
run_test "TC-ADOPT-002: Invalid spec rejected"
if zap adopt "../evil/plugin" 2>/dev/null; then
  fail "Invalid spec rejected" "error" "accepted"
else
  pass "Invalid spec rejected"
fi

# TC-ADOPT-003: Already declared plugin is no-op
run_test "TC-ADOPT-003: Already declared plugin is no-op"
_zap_init_state
_zap_add_plugin_to_state "test/plugin" "test/plugin" "declared" "/path" "v1" "array"
_zap_write_state

output=$(zap adopt "test/plugin" 2>&1)
if echo "$output" | grep -q "already declared"; then
  pass "Already declared detected"
else
  fail "Already declared detected" "already declared message" "$output"
fi

# TC-ADOPT-004: Creates backup before modifying .zshrc
run_test "TC-ADOPT-004: Creates backup before modifying .zshrc"
echo "# Test .zshrc" > "$ZDOTDIR/.zshrc"
_zap_init_state
_zap_add_plugin_to_state "test/experimental" "test/experimental" "experimental" "/path" "v1" "try_command"
_zap_write_state

zap adopt "test/experimental" >/dev/null 2>&1

if ls "$ZDOTDIR"/.zshrc.backup-* >/dev/null 2>&1; then
  pass "Backup created"
else
  fail "Backup created" "backup file exists" "no backup"
fi

# TC-ADOPT-005: Updates state from experimental to declared
run_test "TC-ADOPT-005: Updates state to declared"
_zap_init_state
_zap_add_plugin_to_state "test/exp2" "test/exp2" "experimental" "/path" "v1" "try_command"
_zap_write_state

echo "plugins=()" > "$ZDOTDIR/.zshrc"
zap adopt "test/exp2" >/dev/null 2>&1

_zap_load_state
metadata="${_zap_plugin_state[test/exp2]}"
state_field="${${(@s:|:)metadata}[1]}"
source_field="${${(@s:|:)metadata}[6]}"

if [[ "$state_field" == "declared" && "$source_field" == "array" ]]; then
  pass "State updated to declared/array"
else
  fail "State updated" "declared|array" "$state_field|$source_field"
fi

# TC-ADOPT-006: Adds plugin to existing plugins=() array
run_test "TC-ADOPT-006: Adds to existing array"
_zap_init_state
_zap_add_plugin_to_state "test/exp3" "test/exp3" "experimental" "/path" "v1" "try_command"
_zap_write_state

cat > "$ZDOTDIR/.zshrc" <<'EOF'
plugins=(
  existing/plugin
)
EOF

zap adopt "test/exp3" >/dev/null 2>&1

if grep -q "test/exp3" "$ZDOTDIR/.zshrc"; then
  pass "Plugin added to array"
else
  fail "Plugin added" "test/exp3 in .zshrc" "not found"
fi

# TC-ADOPT-007: Creates plugins=() array if missing
run_test "TC-ADOPT-007: Creates array if missing"
_zap_init_state
_zap_add_plugin_to_state "test/exp4" "test/exp4" "experimental" "/path" "v1" "try_command"
_zap_write_state

echo "# Empty .zshrc" > "$ZDOTDIR/.zshrc"
zap adopt "test/exp4" >/dev/null 2>&1

if grep -q "plugins=(" "$ZDOTDIR/.zshrc" && grep -q "test/exp4" "$ZDOTDIR/.zshrc"; then
  pass "Array created with plugin"
else
  fail "Array created" "plugins=() with test/exp4" "not found"
fi

# TC-ADOPT-008: Adopt --all flag (list experimental plugins)
run_test "TC-ADOPT-008: Lists all experimental plugins for --all"
_zap_init_state
_zap_add_plugin_to_state "test/exp5" "test/exp5" "experimental" "/path" "v1" "try_command"
_zap_add_plugin_to_state "test/exp6" "test/exp6" "experimental" "/path" "v1" "try_command"
_zap_write_state

echo "plugins=()" > "$ZDOTDIR/.zshrc"
output=$(zap adopt --all 2>&1)

if echo "$output" | grep -q "Adopting 2 experimental plugin" && echo "$output" | grep -q "test/exp5" && echo "$output" | grep -q "test/exp6"; then
  pass "Lists all experimental plugins for adoption"
else
  fail "Lists experimental plugins" "Adopting 2 experimental plugins, test/exp5, test/exp6" "$output"
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
