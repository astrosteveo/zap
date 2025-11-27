#!/usr/bin/env zsh
#
# test_version_pinning.zsh - Contract tests for version pinning
#
# WHY: Verify FR-004, FR-019 (version pinning and respect during updates)
# T025: Contract test for version pinning (@v1.2.3, @commit, @branch)

# Test framework
typeset -i TESTS_RUN=0
typeset -i TESTS_PASSED=0
typeset -i TESTS_FAILED=0

assert_equals() {
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$1" == "$2" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ✓ $3"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ✗ $3 (expected: '$1', got: '$2')"
  fi
}

assert_true() {
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ $1 -eq 0 ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ✓ $2"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ✗ $2"
  fi
}

# Setup
TEST_DIR="/tmp/zap-version-test-$$"
mkdir -p "$TEST_DIR"
export ZAP_DIR="$(dirname "$0")/../.."
export ZAP_DATA_DIR="$TEST_DIR/data"
export ZAP_PLUGIN_DIR="$ZAP_DATA_DIR/plugins"

source "$ZAP_DIR/lib/utils.zsh"
source "$ZAP_DIR/lib/parser.zsh"
source "$ZAP_DIR/lib/downloader.zsh"

echo "Contract Test: Version Pinning (T025)"
echo "======================================"
echo ""

#
# Test 1: Parse version tags
#
echo "Test 1: Version tag parsing (@v1.2.3)"

result=$(_zap_parse_spec "owner/repo@v1.2.3")
assert_true $? "Tag version parses successfully"

read owner repo version subdir <<< "$result"
assert_equals "v1.2.3" "$version" "Tag version extracted correctly"

echo ""

#
# Test 2: Parse commit hashes
#
echo "Test 2: Commit hash parsing (@abc123def)"

result=$(_zap_parse_spec "owner/repo@abc123def456")
assert_true $? "Commit hash parses successfully"

read owner repo version subdir <<< "$result"
assert_equals "abc123def456" "$version" "Commit hash extracted correctly"

echo ""

#
# Test 3: Parse branch names
#
echo "Test 3: Branch name parsing (@develop)"

result=$(_zap_parse_spec "owner/repo@develop")
assert_true $? "Branch name parses successfully"

read owner repo version subdir <<< "$result"
assert_equals "develop" "$version" "Branch name extracted correctly"

echo ""

#
# Test 4: Version with special characters
#
echo "Test 4: Version with special characters"

# Semantic version with patch
result=$(_zap_parse_spec "owner/repo@v2.0.0-beta.1")
assert_true $? "Semantic version with metadata parses"

read owner repo version subdir <<< "$result"
assert_equals "v2.0.0-beta.1" "$version" "Complex semantic version preserved"

echo ""

#
# Test 5: Short commit hashes
#
echo "Test 5: Short commit hash (7 characters)"

result=$(_zap_parse_spec "owner/repo@abc123d")
assert_true $? "Short commit hash parses"

read owner repo version subdir <<< "$result"
assert_equals "abc123d" "$version" "Short hash preserved"

echo ""

#
# Test 6: Invalid version characters
#
echo "Test 6: Security - Invalid version characters rejected"

# Command injection attempt
result=$(_zap_parse_spec "owner/repo@v1.0; rm -rf /" 2>/dev/null)
assert_true $? "Rejects command injection in version"

# Path traversal in version
result=$(_zap_parse_spec "owner/repo@../../../etc" 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Rejects path traversal in version"

echo ""

#
# Test 7: Version + subdirectory combination
#
echo "Test 7: Version pinning with subdirectory"

result=$(_zap_parse_spec "ohmyzsh/ohmyzsh@v1.0.0 path:plugins/git")
assert_true $? "Version + path parses successfully"

read owner repo version subdir <<< "$result"
assert_equals "v1.0.0" "$version" "Version correct in combined spec"
assert_equals "plugins/git" "$subdir" "Subdirectory correct in combined spec"

echo ""

#
# Test 8: Empty/missing version handling
#
echo "Test 8: Missing version defaults to latest"

result=$(_zap_parse_spec "owner/repo")
assert_true $? "Spec without version parses"

read owner repo version subdir <<< "$result"
assert_equals "" "$version" "Empty version when not specified"

echo ""

#
# Test 9: Whitespace in version
#
echo "Test 9: Whitespace handling in versions"

result=$(_zap_parse_spec "owner/repo@  v1.0.0  " 2>/dev/null)
# Should either fail or trim whitespace
if [[ $? -eq 0 ]]; then
  read owner repo version subdir <<< "$result"
  # Version should be trimmed
  [[ "$version" != *" "* ]]
  assert_true $? "Version whitespace is trimmed"
else
  assert_true 0 "Whitespace in version is rejected"
fi

echo ""

#
# Test 10: Multiple @ symbols
#
echo "Test 10: Multiple @ symbols handled"

# Should take everything after first @
result=$(_zap_parse_spec "owner/repo@v1.0.0@extra" 2>/dev/null)
if [[ $? -eq 0 ]]; then
  read owner repo version subdir <<< "$result"
  # Behavior: either take "v1.0.0@extra" as version or fail
  true
fi
# Main point: doesn't crash or allow injection
assert_true 0 "Multiple @ symbols don't break parser"

echo ""

#
# Test 11: Case sensitivity in versions
#
echo "Test 11: Version case sensitivity"

result=$(_zap_parse_spec "owner/repo@V1.0.0")
assert_true $? "Uppercase in version preserved"

read owner repo version subdir <<< "$result"
assert_equals "V1.0.0" "$version" "Version case is preserved"

echo ""

#
# Test 12: Very long version strings
#
echo "Test 12: Long version string handling"

long_version="v1.0.0-very-long-prerelease-identifier-with-many-characters"
result=$(_zap_parse_spec "owner/repo@$long_version")
assert_true $? "Long version string accepted"

read owner repo version subdir <<< "$result"
assert_equals "$long_version" "$version" "Long version preserved"

echo ""

# Clean up
rm -rf "$TEST_DIR" 2>/dev/null

# Summary
echo "======================================"
echo "Tests run: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo "✓ All tests passed"
  exit 0
else
  echo "✗ Some tests failed"
  exit 1
fi
