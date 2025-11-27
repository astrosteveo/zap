#!/usr/bin/env zsh
#
# Contract Test: Security - Input Validation and Injection Prevention
#
# Tests that the declarative plugin system properly sanitizes user inputs
# and prevents common attack vectors per FR-027 (Input Validation).
#
# WHY: Plugin specifications come from user .zshrc files and could be
# maliciously crafted to:
# - Execute arbitrary commands (command injection)
# - Access files outside plugin directories (path traversal)
# - Cause shell crashes or hangs (malformed inputs)
#
# This test suite focuses on security-critical validations beyond just
# format correctness.
#
# TDD WORKFLOW: RED - these tests should FAIL until security measures are implemented

# Load the declarative module
source "${0:A:h}/../../../lib/declarative.zsh"

# Test setup
TEST_NAME="Security - Input Validation Contract"
TEST_DIR="$(mktemp -d)"

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
  [[ -n "$2" ]] && echo "    Attack vector: $2"
  [[ -n "$3" ]] && echo "    Result: $3"
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

# PATH TRAVERSAL ATTACKS
echo "## Path Traversal Attacks"

run_test "TC-SEC-001: Path traversal with ../"
if _zap_validate_plugin_spec "owner/../../../etc/passwd"; then
  fail "Path traversal blocked" "../../../etc/passwd" "ACCEPTED (VULNERABLE)"
else
  pass "Path traversal blocked"
fi

run_test "TC-SEC-002: Path traversal in owner field"
if _zap_validate_plugin_spec "../evil/repo"; then
  fail "Owner path traversal blocked" "../evil" "ACCEPTED (VULNERABLE)"
else
  pass "Owner path traversal blocked"
fi

run_test "TC-SEC-003: Path traversal in repo field"
if _zap_validate_plugin_spec "owner/../evil"; then
  fail "Repo path traversal blocked" "../evil" "ACCEPTED (VULNERABLE)"
else
  pass "Repo path traversal blocked"
fi

run_test "TC-SEC-004: Path traversal in subdir field"
if _zap_validate_plugin_spec "owner/repo:../../etc"; then
  fail "Subdir path traversal blocked" "../../etc" "ACCEPTED (VULNERABLE)"
else
  pass "Subdir path traversal blocked"
fi

run_test "TC-SEC-005: Absolute path in owner"
if _zap_validate_plugin_spec "/etc/shadow"; then
  fail "Absolute path blocked" "/etc/shadow" "ACCEPTED (VULNERABLE)"
else
  pass "Absolute path blocked"
fi

run_test "TC-SEC-006: Home directory expansion"
if _zap_validate_plugin_spec "~/evil/repo"; then
  fail "Home expansion blocked" "~/evil/repo" "ACCEPTED (VULNERABLE)"
else
  pass "Home expansion blocked"
fi

# COMMAND INJECTION ATTACKS
echo ""
echo "## Command Injection Attacks"

run_test "TC-SEC-007: Command injection with semicolon"
if _zap_validate_plugin_spec "owner/repo; rm -rf /tmp/test"; then
  fail "Semicolon injection blocked" "; rm -rf" "ACCEPTED (VULNERABLE)"
else
  pass "Semicolon injection blocked"
fi

run_test "TC-SEC-008: Command injection with backticks"
if _zap_validate_plugin_spec "owner/repo\`whoami\`"; then
  fail "Backtick injection blocked" "\`whoami\`" "ACCEPTED (VULNERABLE)"
else
  pass "Backtick injection blocked"
fi

run_test "TC-SEC-009: Command injection with \$()"
if _zap_validate_plugin_spec "owner/repo\$(id)"; then
  fail "Command substitution blocked" "\$(id)" "ACCEPTED (VULNERABLE)"
else
  pass "Command substitution blocked"
fi

run_test "TC-SEC-010: Command injection with pipe"
if _zap_validate_plugin_spec "owner/repo | cat /etc/passwd"; then
  fail "Pipe injection blocked" "| cat" "ACCEPTED (VULNERABLE)"
else
  pass "Pipe injection blocked"
fi

run_test "TC-SEC-011: Command injection with ampersand"
if _zap_validate_plugin_spec "owner/repo & curl evil.com"; then
  fail "Background process blocked" "& curl" "ACCEPTED (VULNERABLE)"
else
  pass "Background process blocked"
fi

run_test "TC-SEC-012: Command injection with double ampersand"
if _zap_validate_plugin_spec "owner/repo && rm file"; then
  fail "Logical AND blocked" "&& rm" "ACCEPTED (VULNERABLE)"
else
  pass "Logical AND blocked"
fi

run_test "TC-SEC-013: Command injection with double pipe"
if _zap_validate_plugin_spec "owner/repo || echo pwned"; then
  fail "Logical OR blocked" "|| echo" "ACCEPTED (VULNERABLE)"
else
  pass "Logical OR blocked"
fi

run_test "TC-SEC-014: Command injection with newline"
if _zap_validate_plugin_spec "owner/repo\nrm -rf /"; then
  fail "Newline injection blocked" "\\n rm -rf" "ACCEPTED (VULNERABLE)"
else
  pass "Newline injection blocked"
fi

run_test "TC-SEC-015: Command injection with redirect"
if _zap_validate_plugin_spec "owner/repo > /tmp/evil"; then
  fail "Redirect blocked" "> /tmp/evil" "ACCEPTED (VULNERABLE)"
else
  pass "Redirect blocked"
fi

run_test "TC-SEC-016: Command injection in version field"
if _zap_validate_plugin_spec "owner/repo@\$(whoami)"; then
  fail "Version field injection blocked" "@\$(whoami)" "ACCEPTED (VULNERABLE)"
else
  pass "Version field injection blocked"
fi

run_test "TC-SEC-017: Command injection in subdir field"
if _zap_validate_plugin_spec "owner/repo:plugins\`id\`"; then
  fail "Subdir field injection blocked" ":plugins\`id\`" "ACCEPTED (VULNERABLE)"
else
  pass "Subdir field injection blocked"
fi

# MALFORMED INPUT ATTACKS
echo ""
echo "## Malformed Input Attacks"

run_test "TC-SEC-018: Null byte injection"
if _zap_validate_plugin_spec "owner/repo\x00evil"; then
  fail "Null byte blocked" "\\x00" "ACCEPTED (VULNERABLE)"
else
  pass "Null byte blocked"
fi

run_test "TC-SEC-019: Excessive length (DoS)"
long_spec=$(printf 'a%.0s' {1..10000})
if _zap_validate_plugin_spec "$long_spec"; then
  fail "Long input rejected" "10000 chars" "ACCEPTED (VULNERABLE)"
else
  pass "Long input rejected"
fi

run_test "TC-SEC-020: Special characters in owner"
if _zap_validate_plugin_spec "own*er/repo"; then
  fail "Wildcard in owner blocked" "own*er" "ACCEPTED (VULNERABLE)"
else
  pass "Wildcard in owner blocked"
fi

run_test "TC-SEC-021: Special characters in repo"
if _zap_validate_plugin_spec "owner/rep?o"; then
  fail "Wildcard in repo blocked" "rep?o" "ACCEPTED (VULNERABLE)"
else
  pass "Wildcard in repo blocked"
fi

run_test "TC-SEC-022: Unicode normalization attack"
if _zap_validate_plugin_spec "owner/repo/../\u202eevil"; then
  fail "Unicode normalization blocked" "\\u202e" "ACCEPTED (VULNERABLE)"
else
  pass "Unicode normalization blocked"
fi

# VALID EDGE CASES (should NOT be blocked)
echo ""
echo "## Valid Edge Cases (Should Pass)"

run_test "TC-SEC-023: Valid - dots in repo name"
if _zap_validate_plugin_spec "owner/repo.name"; then
  pass "Dots in repo name allowed"
else
  fail "Dots in repo name allowed" "repo.name" "REJECTED (FALSE POSITIVE)"
fi

run_test "TC-SEC-024: Valid - dots in version"
if _zap_validate_plugin_spec "owner/repo@v1.2.3"; then
  pass "Dots in version allowed"
else
  fail "Dots in version allowed" "@v1.2.3" "REJECTED (FALSE POSITIVE)"
fi

run_test "TC-SEC-025: Valid - hyphens in all fields"
if _zap_validate_plugin_spec "my-org/my-repo@my-branch:my-path"; then
  pass "Hyphens allowed"
else
  fail "Hyphens allowed" "my-org/my-repo" "REJECTED (FALSE POSITIVE)"
fi

run_test "TC-SEC-026: Valid - underscores in all fields"
if _zap_validate_plugin_spec "my_org/my_repo@my_branch:my_path"; then
  pass "Underscores allowed"
else
  fail "Underscores allowed" "my_org/my_repo" "REJECTED (FALSE POSITIVE)"
fi

run_test "TC-SEC-027: Valid - numbers in all fields"
if _zap_validate_plugin_spec "org123/repo456@v1:path2"; then
  pass "Numbers allowed"
else
  fail "Numbers allowed" "org123/repo456" "REJECTED (FALSE POSITIVE)"
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
