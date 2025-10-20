#!/usr/bin/env zsh
#
# Contract Test: Plugin Specification Validation
#
# Tests the plugin specification format contract from
# specs/002-specify-scripts-bash/contracts/plugin-specification-format.md
#
# WHY: Plugin specifications are user-facing strings that control what
# plugins are loaded. We must enforce strict validation to prevent:
# - Path traversal attacks (../../../etc/passwd)
# - Command injection (owner/repo; rm -rf /)
# - Malformed specifications that could crash the shell
#
# Valid formats:
#   owner/repo
#   owner/repo@version
#   owner/repo:subdir
#   owner/repo@version:subdir
#
# TDD WORKFLOW: RED - these tests should FAIL until _zap_validate_plugin_spec() is implemented

# Load the declarative module
source "${0:A:h}/../../../lib/declarative.zsh"

# Test setup
TEST_NAME="Plugin Specification Validation Contract"
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

# TC-SPEC-001: Valid basic specification
run_test "TC-SPEC-001: Valid basic spec (owner/repo)"
if _zap_validate_plugin_spec "zsh-users/zsh-autosuggestions"; then
  pass "Basic specification validates"
else
  fail "Basic specification validates" "valid" "rejected"
fi

# TC-SPEC-002: Valid specification with version
run_test "TC-SPEC-002: Valid spec with version (owner/repo@version)"
if _zap_validate_plugin_spec "zsh-users/zsh-autosuggestions@v0.7.0"; then
  pass "Specification with version validates"
else
  fail "Specification with version validates" "valid" "rejected"
fi

# TC-SPEC-003: Valid specification with subdirectory
run_test "TC-SPEC-003: Valid spec with subdir (owner/repo:subdir)"
if _zap_validate_plugin_spec "ohmyzsh/ohmyzsh:plugins/git"; then
  pass "Specification with subdirectory validates"
else
  fail "Specification with subdirectory validates" "valid" "rejected"
fi

# TC-SPEC-004: Valid specification with version and subdirectory
run_test "TC-SPEC-004: Valid spec with version and subdir"
if _zap_validate_plugin_spec "ohmyzsh/ohmyzsh@master:plugins/git"; then
  pass "Full specification validates"
else
  fail "Full specification validates" "valid" "rejected"
fi

# TC-SPEC-005: Valid specification with commit hash
run_test "TC-SPEC-005: Valid spec with commit hash"
if _zap_validate_plugin_spec "zsh-users/zsh-syntax-highlighting@a0b56da"; then
  pass "Specification with commit hash validates"
else
  fail "Specification with commit hash validates" "valid" "rejected"
fi

# TC-SPEC-006: Valid specification with branch name
run_test "TC-SPEC-006: Valid spec with branch name"
if _zap_validate_plugin_spec "romkatv/powerlevel10k@develop"; then
  pass "Specification with branch validates"
else
  fail "Specification with branch validates" "valid" "rejected"
fi

# TC-SPEC-007: Invalid - missing owner
run_test "TC-SPEC-007: Invalid spec - missing owner"
if _zap_validate_plugin_spec "zsh-autosuggestions"; then
  fail "Missing owner rejected" "invalid" "accepted"
else
  pass "Missing owner rejected"
fi

# TC-SPEC-008: Invalid - missing repo
run_test "TC-SPEC-008: Invalid spec - missing repo"
if _zap_validate_plugin_spec "zsh-users/"; then
  fail "Missing repo rejected" "invalid" "accepted"
else
  pass "Missing repo rejected"
fi

# TC-SPEC-009: Invalid - path traversal (../)
run_test "TC-SPEC-009: Security - path traversal rejected (../)"
if _zap_validate_plugin_spec "zsh-users/../evil/repo"; then
  fail "Path traversal rejected" "invalid" "accepted"
else
  pass "Path traversal rejected"
fi

# TC-SPEC-010: Invalid - path traversal in subdirectory
run_test "TC-SPEC-010: Security - path traversal in subdir"
if _zap_validate_plugin_spec "owner/repo:../../../etc/passwd"; then
  fail "Path traversal in subdir rejected" "invalid" "accepted"
else
  pass "Path traversal in subdir rejected"
fi

# TC-SPEC-011: Invalid - absolute path
run_test "TC-SPEC-011: Security - absolute path rejected"
if _zap_validate_plugin_spec "/etc/passwd"; then
  fail "Absolute path rejected" "invalid" "accepted"
else
  pass "Absolute path rejected"
fi

# TC-SPEC-012: Invalid - command injection (semicolon)
run_test "TC-SPEC-012: Security - command injection (;) rejected"
if _zap_validate_plugin_spec "owner/repo; rm -rf /"; then
  fail "Command injection rejected" "invalid" "accepted"
else
  pass "Command injection rejected"
fi

# TC-SPEC-013: Invalid - command injection (backticks)
run_test "TC-SPEC-013: Security - command injection (\`) rejected"
if _zap_validate_plugin_spec "owner/repo\`whoami\`"; then
  fail "Backtick injection rejected" "invalid" "accepted"
else
  pass "Backtick injection rejected"
fi

# TC-SPEC-014: Invalid - command injection ($())
run_test "TC-SPEC-014: Security - command injection \$() rejected"
if _zap_validate_plugin_spec "owner/repo\$(whoami)"; then
  fail "Command substitution rejected" "invalid" "accepted"
else
  pass "Command substitution rejected"
fi

# TC-SPEC-015: Invalid - shell metacharacters (&)
run_test "TC-SPEC-015: Security - shell metacharacter (&) rejected"
if _zap_validate_plugin_spec "owner/repo&"; then
  fail "Shell metacharacter rejected" "invalid" "accepted"
else
  pass "Shell metacharacter rejected"
fi

# TC-SPEC-016: Invalid - shell metacharacters (|)
run_test "TC-SPEC-016: Security - shell metacharacter (|) rejected"
if _zap_validate_plugin_spec "owner/repo|cat"; then
  fail "Pipe metacharacter rejected" "invalid" "accepted"
else
  pass "Pipe metacharacter rejected"
fi

# TC-SPEC-017: Invalid - empty specification
run_test "TC-SPEC-017: Invalid - empty specification"
if _zap_validate_plugin_spec ""; then
  fail "Empty specification rejected" "invalid" "accepted"
else
  pass "Empty specification rejected"
fi

# TC-SPEC-018: Invalid - whitespace only
run_test "TC-SPEC-018: Invalid - whitespace only"
if _zap_validate_plugin_spec "   "; then
  fail "Whitespace-only specification rejected" "invalid" "accepted"
else
  pass "Whitespace-only specification rejected"
fi

# TC-SPEC-019: Valid - hyphens and underscores in names
run_test "TC-SPEC-019: Valid - hyphens and underscores"
if _zap_validate_plugin_spec "my-org_name/my-repo_name"; then
  pass "Hyphens and underscores accepted"
else
  fail "Hyphens and underscores accepted" "valid" "rejected"
fi

# TC-SPEC-020: Valid - dots in version
run_test "TC-SPEC-020: Valid - dots in version"
if _zap_validate_plugin_spec "owner/repo@v1.2.3"; then
  pass "Dots in version accepted"
else
  fail "Dots in version accepted" "valid" "rejected"
fi

# TC-SPEC-021: Valid - nested subdirectory path
run_test "TC-SPEC-021: Valid - nested subdirectory"
if _zap_validate_plugin_spec "owner/repo:path/to/plugin"; then
  pass "Nested subdirectory accepted"
else
  fail "Nested subdirectory accepted" "valid" "rejected"
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
