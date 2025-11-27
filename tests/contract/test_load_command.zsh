#!/usr/bin/env zsh
#
# test_load_command.zsh - Contract tests for zap load command
#
# WHY: Verify zap load parsing and behavior (User Story 1)
# T017: Contract test for zap load parsing

# Test framework (same as test_installer.zsh)
typeset -i TESTS_RUN=0
typeset -i TESTS_PASSED=0
typeset -i TESTS_FAILED=0

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Assertion failed}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$expected" == "$actual" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ✓ $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ✗ $message (expected: $expected, got: $actual)"
    return 1
  fi
}

assert_true() {
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ $1 -eq 0 ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ✓ $2"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ✗ $2"
    return 1
  fi
}

# Setup
TEST_DIR="/tmp/zap-load-test-$$"
mkdir -p "$TEST_DIR"
export ZAP_DIR="$(dirname "$0")/../.."
export ZAP_DATA_DIR="$TEST_DIR/data"
export ZAP_PLUGIN_DIR="$ZAP_DATA_DIR/plugins"

# Source the parser
source "$ZAP_DIR/lib/utils.zsh"
source "$ZAP_DIR/lib/parser.zsh"

echo "Contract Test: zap load Command (T017)"
echo "======================================="
echo ""

#
# Test 1: Basic plugin specification parsing
#
echo "Test 1: Parse basic plugin spec (owner/repo)"

local result
result=$(_zap_parse_spec "zsh-users/zsh-syntax-highlighting" 2>/dev/null)
local parse_status=$?

assert_true $parse_status "Basic spec parses successfully"

if [[ $parse_status -eq 0 ]]; then
  local owner repo version subdir
  read owner repo version subdir <<< "$result"

  assert_equals "zsh-users" "$owner" "Owner parsed correctly"
  assert_equals "zsh-syntax-highlighting" "$repo" "Repo parsed correctly"
  assert_equals "" "$version" "No version when not specified"
  assert_equals "" "$subdir" "No subdir when not specified"
fi

echo ""

#
# Test 2: Version pinning parsing
#
echo "Test 2: Parse plugin spec with version"

result=$(_zap_parse_spec "zsh-users/zsh-autosuggestions@v0.7.0" 2>/dev/null)
parse_status=$?

assert_true $parse_status "Version spec parses successfully"

if [[ $parse_status -eq 0 ]]; then
  read owner repo version subdir <<< "$result"

  assert_equals "zsh-users" "$owner" "Owner correct with version"
  assert_equals "zsh-autosuggestions" "$repo" "Repo correct with version"
  assert_equals "v0.7.0" "$version" "Version parsed correctly"
fi

echo ""

#
# Test 3: Subdirectory path parsing
#
echo "Test 3: Parse plugin spec with path annotation"

result=$(_zap_parse_spec "ohmyzsh/ohmyzsh path:plugins/git" 2>/dev/null)
parse_status=$?

assert_true $parse_status "Path annotation parses successfully"

if [[ $parse_status -eq 0 ]]; then
  read owner repo version subdir <<< "$result"

  assert_equals "ohmyzsh" "$owner" "Owner correct with path"
  assert_equals "ohmyzsh" "$repo" "Repo correct with path"
  assert_equals "plugins/git" "$subdir" "Subdirectory parsed correctly"
fi

echo ""

#
# Test 4: Complex spec with both version and path
#
echo "Test 4: Parse complex spec (version + path)"

result=$(_zap_parse_spec "owner/repo@v1.0.0 path:subdir/deep" 2>/dev/null)
parse_status=$?

assert_true $parse_status "Complex spec parses successfully"

if [[ $parse_status -eq 0 ]]; then
  read owner repo version subdir <<< "$result"

  assert_equals "owner" "$owner" "Owner in complex spec"
  assert_equals "repo" "$repo" "Repo in complex spec"
  assert_equals "v1.0.0" "$version" "Version in complex spec"
  assert_equals "subdir/deep" "$subdir" "Subdirectory in complex spec"
fi

echo ""

#
# Test 5: Invalid specs are rejected
#
echo "Test 5: Invalid specs are rejected"

# Missing owner/repo separator
result=$(_zap_parse_spec "invalid-spec-without-slash" 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Rejects spec without slash"

# Empty spec
result=$(_zap_parse_spec "" 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Rejects empty spec"

# Comment line
result=$(_zap_parse_spec "# comment" 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Rejects comment lines"

echo ""

#
# Test 6: Whitespace handling
#
echo "Test 6: Whitespace is handled correctly"

result=$(_zap_parse_spec "  owner/repo  " 2>/dev/null)
parse_status=$?

assert_true $parse_status "Handles leading/trailing whitespace"

if [[ $parse_status -eq 0 ]]; then
  read owner repo version subdir <<< "$result"
  assert_equals "owner" "$owner" "Whitespace trimmed from owner"
  assert_equals "repo" "$repo" "Whitespace trimmed from repo"
fi

echo ""

#
# Test 7: Security - Path traversal prevention
#
echo "Test 7: Path traversal attempts are blocked"

result=$(_zap_parse_spec "owner/repo path:../../etc/passwd" 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Blocks path traversal with .."

result=$(_zap_parse_spec "owner/repo path:/absolute/path" 2>/dev/null)
[[ $? -ne 0 ]]
assert_true $? "Blocks absolute paths"

echo ""

#
# Test 8: Plugin cache directory naming
#
echo "Test 8: Cache directory naming convention"

local cache_dir
cache_dir=$(_zap_get_plugin_cache_dir "owner" "repo")

assert_equals "${ZAP_PLUGIN_DIR}/owner__repo" "$cache_dir" "Cache dir uses double underscore"

echo ""

# Clean up
rm -rf "$TEST_DIR" 2>/dev/null

# Summary
echo "======================================="
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
