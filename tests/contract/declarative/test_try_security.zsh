#!/usr/bin/env zsh
#
# Contract Test: zap try Security
#
# Tests security validation for the zap try command
#
# WHY: zap try accepts user input and must validate it thoroughly
# to prevent path traversal, command injection, and other attacks.

# Load modules
source "${0:A:h}/../../../lib/state.zsh"
source "${0:A:h}/../../../lib/declarative.zsh"

# Test setup
TEST_NAME="zap try Security Contract"
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

# TC-TRY-SEC-001: Path traversal prevention
run_test "TC-TRY-SEC-001: Rejects path traversal attempts"
if zap try "../evil/plugin" 2>/dev/null; then
  fail "Path traversal prevention" "rejected" "accepted"
else
  pass "Path traversal rejected"
fi

# TC-TRY-SEC-002: Absolute path prevention
run_test "TC-TRY-SEC-002: Rejects absolute paths"
if zap try "/etc/passwd" 2>/dev/null; then
  fail "Absolute path prevention" "rejected" "accepted"
else
  pass "Absolute path rejected"
fi

# TC-TRY-SEC-003: Home directory expansion prevention
run_test "TC-TRY-SEC-003: Rejects home directory expansion"
if zap try "~/evil/plugin" 2>/dev/null; then
  fail "Home expansion prevention" "rejected" "accepted"
else
  pass "Home expansion rejected"
fi

# TC-TRY-SEC-004: Command injection prevention (semicolon)
run_test "TC-TRY-SEC-004: Rejects semicolon injection"
if zap try "user/plugin; rm -rf /" 2>/dev/null; then
  fail "Semicolon injection prevention" "rejected" "accepted"
else
  pass "Semicolon injection rejected"
fi

# TC-TRY-SEC-005: Command injection prevention (backticks)
run_test "TC-TRY-SEC-005: Rejects backtick injection"
if zap try "user/plugin\`whoami\`" 2>/dev/null; then
  fail "Backtick injection prevention" "rejected" "accepted"
else
  pass "Backtick injection rejected"
fi

# TC-TRY-SEC-006: Command injection prevention (dollar paren)
run_test "TC-TRY-SEC-006: Rejects dollar-paren injection"
if zap try "user/plugin\$(whoami)" 2>/dev/null; then
  fail "Dollar-paren injection prevention" "rejected" "accepted"
else
  pass "Dollar-paren injection rejected"
fi

# TC-TRY-SEC-007: Pipe character prevention
run_test "TC-TRY-SEC-007: Rejects pipe character"
if zap try "user/plugin | cat /etc/passwd" 2>/dev/null; then
  fail "Pipe prevention" "rejected" "accepted"
else
  pass "Pipe character rejected"
fi

# TC-TRY-SEC-008: Ampersand prevention
run_test "TC-TRY-SEC-008: Rejects ampersand"
if zap try "user/plugin & whoami" 2>/dev/null; then
  fail "Ampersand prevention" "rejected" "accepted"
else
  pass "Ampersand rejected"
fi

# TC-TRY-SEC-009: Redirect prevention
run_test "TC-TRY-SEC-009: Rejects redirect operators"
if zap try "user/plugin > /tmp/evil" 2>/dev/null; then
  fail "Redirect prevention" "rejected" "accepted"
else
  pass "Redirect rejected"
fi

# TC-TRY-SEC-010: Newline injection prevention
run_test "TC-TRY-SEC-010: Rejects newline characters"
if zap try "user/plugin\nrm -rf /" 2>/dev/null; then
  fail "Newline injection prevention" "rejected" "accepted"
else
  pass "Newline injection rejected"
fi

# TC-TRY-SEC-011: Null byte injection prevention
run_test "TC-TRY-SEC-011: Rejects null bytes"
if zap try "user/plugin\x00evil" 2>/dev/null; then
  fail "Null byte prevention" "rejected" "accepted"
else
  pass "Null byte rejected"
fi

# TC-TRY-SEC-012: Wildcard prevention
run_test "TC-TRY-SEC-012: Rejects wildcards"
if zap try "user/*" 2>/dev/null; then
  fail "Wildcard prevention" "rejected" "accepted"
else
  pass "Wildcard rejected"
fi

# TC-TRY-SEC-013: Length limit enforcement
run_test "TC-TRY-SEC-013: Enforces length limits"
long_spec=$(printf 'a%.0s' {1..300})
if zap try "$long_spec" 2>/dev/null; then
  fail "Length limit" "rejected" "accepted"
else
  pass "Excessive length rejected"
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
