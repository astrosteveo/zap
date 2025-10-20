#!/usr/bin/env zsh
#
# Contract Test: State File Format
#
# Tests the state metadata file format specification from
# specs/002-specify-scripts-bash/contracts/state-file-format.md
#
# WHY: State file format is the contract between zap sessions and commands.
# It must be stable, parseable, and follow the documented spec exactly.
#
# TDD WORKFLOW: RED - these tests should FAIL until state.zsh is implemented

# Test setup
TEST_NAME="State File Format Contract"
TEST_DIR="$(mktemp -d)"
STATE_FILE="$TEST_DIR/state.zsh"

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
  echo "    Expected: $2"
  echo "    Got: $3"
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

# TC-STATE-FORMAT-001: File can be sourced as valid Zsh
run_test "TC-STATE-FORMAT-001: File is valid Zsh script"
cat > "$STATE_FILE" <<'EOF'
# Zap Plugin State Metadata
# Auto-generated - do not edit manually
# Session: 12345
# Last updated: 2025-10-18T14:32:15-07:00

typeset -A _zap_plugin_state

_zap_plugin_state=(
  'test/plugin' 'declared|test/plugin|1729267935|/path/to/plugin|abc123|array'
)
EOF

if source "$STATE_FILE" 2>/dev/null; then
  pass "State file sources without errors"
else
  fail "State file sources without errors" "source success" "source failed"
fi

# TC-STATE-FORMAT-002: Associative array is created
run_test "TC-STATE-FORMAT-002: Associative array created"
if [[ ${(t)_zap_plugin_state} == "association" ]]; then
  pass "Associative array type correct"
else
  fail "Associative array type correct" "association" "${(t)_zap_plugin_state}"
fi

# TC-STATE-FORMAT-003: Metadata has 6 pipe-delimited fields
run_test "TC-STATE-FORMAT-003: Metadata format (6 fields)"
metadata="${_zap_plugin_state[test/plugin]}"
field_count=$(echo "$metadata" | awk -F'|' '{print NF}')

if [[ $field_count -eq 6 ]]; then
  pass "Metadata has 6 fields"
else
  fail "Metadata has 6 fields" "6" "$field_count"
fi

# TC-STATE-FORMAT-004: Fields parse correctly
run_test "TC-STATE-FORMAT-004: Field parsing"
fields=("${(@s:|:)metadata}")

state_field="${fields[1]}"
spec_field="${fields[2]}"
timestamp_field="${fields[3]}"
path_field="${fields[4]}"
version_field="${fields[5]}"
source_field="${fields[6]}"

if [[ "$state_field" == "declared" ]]; then
  pass "State field parses"
else
  fail "State field parses" "declared" "$state_field"
fi

if [[ "$spec_field" == "test/plugin" ]]; then
  pass "Specification field parses"
else
  fail "Specification field parses" "test/plugin" "$spec_field"
fi

if [[ "$timestamp_field" =~ ^[0-9]+$ ]]; then
  pass "Timestamp field is numeric"
else
  fail "Timestamp field is numeric" "numeric" "$timestamp_field"
fi

# TC-STATE-FORMAT-005: State field validation
run_test "TC-STATE-FORMAT-005: State field values"
valid_states=("declared" "experimental")
is_valid=0

for valid_state in $valid_states; do
  if [[ "$state_field" == "$valid_state" ]]; then
    is_valid=1
    break
  fi
done

if [[ $is_valid -eq 1 ]]; then
  pass "State field is valid (declared or experimental)"
else
  fail "State field is valid" "declared or experimental" "$state_field"
fi

# TC-STATE-FORMAT-006: Source field validation
run_test "TC-STATE-FORMAT-006: Source field values"
valid_sources=("array" "try_command" "legacy_load")
is_valid_source=0

for valid_source in $valid_sources; do
  if [[ "$source_field" == "$valid_source" ]]; then
    is_valid_source=1
    break
  fi
done

if [[ $is_valid_source -eq 1 ]]; then
  pass "Source field is valid (array, try_command, or legacy_load)"
else
  fail "Source field is valid" "array, try_command, or legacy_load" "$source_field"
fi

# TC-STATE-FORMAT-007: Multiple plugins in state
run_test "TC-STATE-FORMAT-007: Multiple plugins"
cat > "$STATE_FILE" <<'EOF'
typeset -A _zap_plugin_state

_zap_plugin_state=(
  'plugin1/test' 'declared|plugin1/test|1729267935|/path1|abc123|array'
  'plugin2/test' 'experimental|plugin2/test|1729267936|/path2|def456|try_command'
  'plugin3/test' 'declared|plugin3/test@v1.0|1729267937|/path3|v1.0|array'
)
EOF

unset _zap_plugin_state
source "$STATE_FILE"

plugin_count=${#_zap_plugin_state[@]}
if [[ $plugin_count -eq 3 ]]; then
  pass "Multiple plugins stored correctly"
else
  fail "Multiple plugins stored correctly" "3" "$plugin_count"
fi

# TC-STATE-FORMAT-008: Empty state file (no plugins)
run_test "TC-STATE-FORMAT-008: Empty state (no plugins)"
cat > "$STATE_FILE" <<'EOF'
typeset -A _zap_plugin_state
_zap_plugin_state=()
EOF

unset _zap_plugin_state
source "$STATE_FILE"

if [[ ${#_zap_plugin_state[@]} -eq 0 ]]; then
  pass "Empty state file sources correctly"
else
  fail "Empty state file sources correctly" "0" "${#_zap_plugin_state[@]}"
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
