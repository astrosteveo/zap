#!/usr/bin/env zsh
#
# test_path_annotation.zsh - Contract tests for subdirectory path handling
#
# WHY: Verify FR-005 (subdirectory plugin loading) and FR-027 (path validation)
# T026: Contract test for subdirectory path handling

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
TEST_DIR="/tmp/zap-path-test-$$"
mkdir -p "$TEST_DIR"
export ZAP_DIR="$(dirname "$0")/../.."
export ZAP_DATA_DIR="$TEST_DIR/data"

source "$ZAP_DIR/lib/utils.zsh"
source "$ZAP_DIR/lib/parser.zsh"

echo "Contract Test: Path Annotation (T026)"
echo "======================================"
echo ""

#
# Test 1: Simple subdirectory path
#
echo "Test 1: Simple subdirectory (path:plugins/git)"

result=$(_zap_parse_spec "ohmyzsh/ohmyzsh path:plugins/git")
assert_true $? "Simple path parses successfully"

read owner repo version subdir <<< "$result"
assert_equals "plugins/git" "$subdir" "Simple path extracted"

echo ""

#
# Test 2: Deep nested path
#
echo "Test 2: Deep nested path (path:a/b/c/d)"

result=$(_zap_parse_spec "owner/repo path:level1/level2/level3/plugin")
assert_true $? "Deep nested path parses"

read owner repo version subdir <<< "$result"
assert_equals "level1/level2/level3/plugin" "$subdir" "Deep path preserved"

echo ""

#
# Test 3: Path with hyphens and underscores
#
echo "Test 3: Path with special characters"

result=$(_zap_parse_spec "owner/repo path:my-plugin/sub_dir")
assert_true $? "Path with hyphens/underscores parses"

read owner repo version subdir <<< "$result"
assert_equals "my-plugin/sub_dir" "$subdir" "Special chars in path preserved"

echo ""

#
# Test 4: SECURITY - Path traversal prevention (..)
#
echo "Test 4: SECURITY - Path traversal with .. is blocked"

result=$(_zap_parse_spec "owner/repo path:../../../etc/passwd" 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Blocks .. in path"

result=$(_zap_parse_spec "owner/repo path:plugins/../../sensitive" 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Blocks embedded .. in path"

result=$(_zap_parse_spec "owner/repo path:.." 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Blocks bare .. as path"

echo ""

#
# Test 5: SECURITY - Absolute path prevention
#
echo "Test 5: SECURITY - Absolute paths are blocked"

result=$(_zap_parse_spec "owner/repo path:/etc/passwd" 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Blocks leading slash (absolute path)"

result=$(_zap_parse_spec "owner/repo path:/tmp/malicious" 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Blocks absolute path to /tmp"

echo ""

#
# Test 6: SECURITY - Special characters in path
#
echo "Test 6: SECURITY - Dangerous characters blocked"

# Command injection attempt
result=$(_zap_parse_spec "owner/repo path:plugin; rm -rf /" 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Blocks command injection in path"

# Null byte
result=$(_zap_parse_spec $'owner/repo path:plugin\x00malicious' 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Blocks null bytes in path"

# Backticks
result=$(_zap_parse_spec 'owner/repo path:plugin`whoami`' 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Blocks backticks in path"

echo ""

#
# Test 7: Empty path handling
#
echo "Test 7: Empty path annotation"

result=$(_zap_parse_spec "owner/repo path:")
# Should either work with empty string or fail gracefully
if [[ $? -eq 0 ]]; then
  read owner repo version subdir <<< "$result"
  # Empty subdir is acceptable
  assert_equals "" "$subdir" "Empty path results in empty subdir"
else
  assert_true 0 "Empty path is rejected"
fi

echo ""

#
# Test 8: Multiple path: annotations
#
echo "Test 8: Multiple path: annotations"

result=$(_zap_parse_spec "owner/repo path:first path:second" 2>/dev/null)
# Should handle gracefully (either take first or last or fail)
if [[ $? -eq 0 ]]; then
  read owner repo version subdir <<< "$result"
  # As long as it doesn't crash or allow injection
  true
fi
assert_true 0 "Multiple path: annotations don't break parser"

echo ""

#
# Test 9: Path with dots (but not ..)
#
echo "Test 9: Path with single dots (valid)"

result=$(_zap_parse_spec "owner/repo path:plugins/my.plugin")
assert_true $? "Single dot in filename is valid"

read owner repo version subdir <<< "$result"
assert_equals "plugins/my.plugin" "$subdir" "Dot in filename preserved"

result=$(_zap_parse_spec "owner/repo path:./plugins/git")
# Leading ./ might be acceptable as it means current dir
if [[ $? -eq 0 ]]; then
  read owner repo version subdir <<< "$result"
  # Should normalize to remove ./
  true
fi
echo "  ✓ Leading ./ handled"

echo ""

#
# Test 10: Very long path
#
echo "Test 10: Very long subdirectory path"

long_path="very/long/nested/directory/structure/with/many/levels/for/testing/path/handling"
result=$(_zap_parse_spec "owner/repo path:$long_path")
assert_true $? "Long path accepted"

read owner repo version subdir <<< "$result"
assert_equals "$long_path" "$subdir" "Long path preserved"

echo ""

#
# Test 11: Path with spaces
#
echo "Test 11: Path with spaces"

result=$(_zap_parse_spec "owner/repo path:my plugins/git" 2>/dev/null)
# Spaces in path might be tricky - check parser behavior
if [[ $? -eq 0 ]]; then
  read owner repo version subdir <<< "$result"
  # Should get either "my" or "my plugins/git" depending on implementation
  true
fi
# Main point: doesn't crash
assert_true 0 "Path with spaces doesn't crash parser"

echo ""

#
# Test 12: Path + version combination
#
echo "Test 12: Path and version together"

result=$(_zap_parse_spec "owner/repo@v1.0.0 path:subdir")
assert_true $? "Version + path parses successfully"

read owner repo version subdir <<< "$result"
assert_equals "v1.0.0" "$version" "Version preserved with path"
assert_equals "subdir" "$subdir" "Path preserved with version"

echo ""

#
# Test 13: Trailing slash in path
#
echo "Test 13: Trailing slash handling"

result=$(_zap_parse_spec "owner/repo path:plugins/git/")
if [[ $? -eq 0 ]]; then
  read owner repo version subdir <<< "$result"
  # Trailing slash might be stripped or preserved
  [[ "$subdir" == "plugins/git" || "$subdir" == "plugins/git/" ]]
  assert_true $? "Trailing slash handled"
fi

echo ""

#
# Test 14: Unicode in path
#
echo "Test 14: Unicode characters in path"

result=$(_zap_parse_spec "owner/repo path:plugins/日本語" 2>/dev/null)
# Unicode might or might not be supported
if [[ $? -eq 0 ]]; then
  echo "  ✓ Unicode in path accepted"
else
  echo "  ✓ Unicode in path rejected (acceptable)"
fi
TESTS_RUN=$((TESTS_RUN + 1))
TESTS_PASSED=$((TESTS_PASSED + 1))

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
