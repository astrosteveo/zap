#!/usr/bin/env zsh
#
# test_parser.zsh - Unit tests for plugin specification parsing
#
# WHY: TDD workflow requires tests before implementation (constitution II)
# Run: zsh tests/unit/test_parser.zsh

# Load the parser module
source "$(dirname "$0")/../../lib/parser.zsh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local test_name="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ "$expected" == "$actual" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ $test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ $test_name"
    echo "  Expected: $expected"
    echo "  Got:      $actual"
  fi
}

assert_success() {
  local command="$1"
  local test_name="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if eval "$command" >/dev/null 2>&1; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ $test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ $test_name (command failed)"
  fi
}

assert_failure() {
  local command="$1"
  local test_name="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if eval "$command" >/dev/null 2>&1; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ $test_name (expected failure but succeeded)"
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ $test_name"
  fi
}

echo "=== Parser Unit Tests ==="
echo ""

# Test basic plugin spec parsing
result=$(_zap_parse_spec "zsh-users/zsh-syntax-highlighting")
assert_equals "zsh-users zsh-syntax-highlighting  " "$result" "Parse basic plugin spec"

# Test plugin spec with version
result=$(_zap_parse_spec "zsh-users/zsh-autosuggestions@v0.7.0")
assert_equals "zsh-users zsh-autosuggestions v0.7.0 " "$result" "Parse plugin spec with version"

# Test plugin spec with subdirectory
result=$(_zap_parse_spec "ohmyzsh/ohmyzsh path:plugins/git")
assert_equals "ohmyzsh ohmyzsh  plugins/git" "$result" "Parse plugin spec with subdirectory"

# Test plugin spec with version and subdirectory
result=$(_zap_parse_spec "ohmyzsh/ohmyzsh@master path:plugins/kubectl")
assert_equals "ohmyzsh ohmyzsh master plugins/kubectl" "$result" "Parse plugin spec with version and subdirectory"

# Test commit hash version
result=$(_zap_parse_spec "user/repo@abc123def")
assert_equals "user repo abc123def " "$result" "Parse plugin spec with commit hash"

# Test branch name version
result=$(_zap_parse_spec "user/repo@develop")
assert_equals "user repo develop " "$result" "Parse plugin spec with branch name"

# Test invalid specs (should fail)
assert_failure "_zap_parse_spec 'invalid-no-slash'" "Reject spec without owner/repo separator"
assert_failure "_zap_parse_spec 'owner/repo path:../../../etc/passwd'" "Reject path traversal in subdirectory"
assert_failure "_zap_parse_spec 'owner/repo@version;rm -rf /'" "Reject version with shell metacharacters"

# Test comment and empty line handling
assert_failure "_zap_parse_spec '# comment line'" "Skip comment lines"
assert_failure "_zap_parse_spec ''" "Skip empty lines"
assert_failure "_zap_parse_spec '   '" "Skip whitespace-only lines"

# Test cache directory generation
cache_dir=$(_zap_get_plugin_cache_dir "zsh-users" "zsh-syntax-highlighting")
expected="${ZAP_PLUGIN_DIR}/zsh-users__zsh-syntax-highlighting"
assert_equals "$expected" "$cache_dir" "Generate correct cache directory path"

# Test plugin identifier generation
identifier=$(_zap_get_plugin_identifier "zsh-users" "zsh-syntax-highlighting")
assert_equals "zsh-users/zsh-syntax-highlighting" "$identifier" "Generate correct plugin identifier"

# Summary
echo ""
echo "=== Test Summary ==="
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo ""
  echo "✓ All tests passed!"
  exit 0
else
  echo ""
  echo "✗ Some tests failed"
  exit 1
fi
