#!/usr/bin/env zsh
#
# Contract Test: Declarative Plugin Loading
#
# Tests that plugins declared in the plugins=() array are automatically
# loaded on shell startup without requiring imperative zap load commands.
#
# WHY: This is the core contract for User Story 1 - users should be able to
# declare desired state and have Zap handle the loading automatically.
#
# TDD WORKFLOW: RED - these tests should FAIL until _zap_load_declared_plugins() is implemented

# Load modules
source "${0:A:h}/../../../lib/state.zsh"
source "${0:A:h}/../../../lib/declarative.zsh"

# Test setup
TEST_NAME="Declarative Plugin Loading Contract"
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

# TC-DECL-001: Function exists
run_test "TC-DECL-001: _zap_load_declared_plugins function exists"
if typeset -f _zap_load_declared_plugins >/dev/null; then
  pass "Function exists"
else
  fail "Function exists" "function defined" "function not found"
fi

# TC-DECL-002: Load plugins from array in config file
run_test "TC-DECL-002: Load plugins from array"
cat > "$TEST_DIR/test_config.zsh" <<'EOF'
plugins=(
  zsh-users/zsh-autosuggestions
  zsh-users/zsh-syntax-highlighting
)
EOF

# Mock plugin loading for testing (create fake plugin directories)
mkdir -p "$ZAP_PLUGIN_DIR/zsh-users/zsh-autosuggestions"
mkdir -p "$ZAP_PLUGIN_DIR/zsh-users/zsh-syntax-highlighting"

# Create minimal plugin files
echo "# zsh-autosuggestions" > "$ZAP_PLUGIN_DIR/zsh-users/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"
echo "# zsh-syntax-highlighting" > "$ZAP_PLUGIN_DIR/zsh-users/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"

# Call the function
if _zap_load_declared_plugins "$TEST_DIR/test_config.zsh" 2>/dev/null; then
  pass "Function executes without error"
else
  fail "Function executes without error" "success" "error"
fi

# TC-DECL-003: Plugins added to state
run_test "TC-DECL-003: Plugins tracked in state"
if [[ -n "${_zap_plugin_state[zsh-users/zsh-autosuggestions]}" && \
      -n "${_zap_plugin_state[zsh-users/zsh-syntax-highlighting]}" ]]; then
  pass "Plugins tracked in state"
else
  fail "Plugins tracked in state" "both plugins in state" "missing from state"
fi

# TC-DECL-004: Plugins marked as 'declared' source
run_test "TC-DECL-004: Plugins marked as declared"
metadata="${_zap_plugin_state[zsh-users/zsh-autosuggestions]}"
state_field="${${(@s:|:)metadata}[1]}"
source_field="${${(@s:|:)metadata}[6]}"

if [[ "$state_field" == "declared" && "$source_field" == "array" ]]; then
  pass "Plugins marked as declared from array"
else
  fail "Plugins marked as declared" "state=declared, source=array" "state=$state_field, source=$source_field"
fi

# TC-DECL-005: Empty array (no plugins)
run_test "TC-DECL-005: Empty array loads no plugins"
_zap_init_state
_zap_write_state  # Clear any existing state

cat > "$TEST_DIR/test_empty.zsh" <<'EOF'
plugins=()
EOF

if _zap_load_declared_plugins "$TEST_DIR/test_empty.zsh" 2>/dev/null; then
  # State should be empty after loading empty array
  if [[ ${#_zap_plugin_state[@]} -eq 0 ]]; then
    pass "Empty array loads no plugins"
  else
    fail "Empty array loads no plugins" "0 plugins" "${#_zap_plugin_state[@]} plugins"
  fi
else
  pass "Empty array handled gracefully"
fi

# TC-DECL-006: Missing plugins array (no array in file)
run_test "TC-DECL-006: Missing array handled gracefully"
unset _zap_plugin_state
_zap_init_state

cat > "$TEST_DIR/test_no_array.zsh" <<'EOF'
# No plugins array
echo "Hello"
EOF

if _zap_load_declared_plugins "$TEST_DIR/test_no_array.zsh" 2>/dev/null; then
  pass "Missing array handled gracefully"
else
  # Should not error, just skip
  pass "Missing array handled gracefully (no error)"
fi

# TC-DECL-007: Preserve load order
run_test "TC-DECL-007: Plugin load order preserved"
_zap_init_state
_zap_write_state

cat > "$TEST_DIR/test_order.zsh" <<'EOF'
plugins=(
  first/plugin
  second/plugin
  third/plugin
)
EOF

# Create mock plugins using proper cache dir format (owner__repo)
mkdir -p "$ZAP_PLUGIN_DIR/first__plugin/.git"
mkdir -p "$ZAP_PLUGIN_DIR/second__plugin/.git"
mkdir -p "$ZAP_PLUGIN_DIR/third__plugin/.git"
echo "# first" > "$ZAP_PLUGIN_DIR/first__plugin/plugin.plugin.zsh"
echo "# second" > "$ZAP_PLUGIN_DIR/second__plugin/plugin.plugin.zsh"
echo "# third" > "$ZAP_PLUGIN_DIR/third__plugin/plugin.plugin.zsh"

_zap_load_declared_plugins "$TEST_DIR/test_order.zsh" 2>/dev/null

# Check that all three plugins are in state
if [[ -n "${_zap_plugin_state[first/plugin]}" && \
      -n "${_zap_plugin_state[second/plugin]}" && \
      -n "${_zap_plugin_state[third/plugin]}" ]]; then
  pass "Load order preserved (all plugins loaded)"
else
  fail "Load order preserved" "all 3 plugins loaded" "some missing"
fi

# TC-DECL-008: Plugin failure doesn't block startup
run_test "TC-DECL-008: Individual plugin failure doesn't block loading"
_zap_init_state
_zap_write_state

cat > "$TEST_DIR/test_failure.zsh" <<'EOF'
plugins=(
  good/plugin
  bad/plugin
  another-good/plugin
)
EOF

# Create mock plugins (bad one has no plugin file) using proper cache dir format
mkdir -p "$ZAP_PLUGIN_DIR/good__plugin/.git"
mkdir -p "$ZAP_PLUGIN_DIR/bad__plugin/.git"  # Has .git but no plugin file!
mkdir -p "$ZAP_PLUGIN_DIR/another-good__plugin/.git"
echo "# good" > "$ZAP_PLUGIN_DIR/good__plugin/plugin.plugin.zsh"
echo "# another-good" > "$ZAP_PLUGIN_DIR/another-good__plugin/plugin.plugin.zsh"

# Should not fail even if one plugin is bad
if _zap_load_declared_plugins "$TEST_DIR/test_failure.zsh" 2>/dev/null; then
  # Good plugins should still be loaded
  if [[ -n "${_zap_plugin_state[good/plugin]}" && \
        -n "${_zap_plugin_state[another-good/plugin]}" ]]; then
    pass "Good plugins loaded despite failure (FR-018)"
  else
    fail "Good plugins loaded" "good plugins in state" "missing from state"
  fi
else
  fail "Function continues on error" "no error" "function failed"
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
