#!/usr/bin/env zsh
#
# test_loader.zsh - Unit tests for loader module
#
# Run: zsh tests/unit/test_loader.zsh

source "$(dirname "$0")/../../lib/loader.zsh"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_success() {
  local command="$1"
  local test_name="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if eval "$command" >/dev/null 2>&1; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ $test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ $test_name"
  fi
}

echo "=== Loader Unit Tests ==="
echo ""

# Test finding plugin file in fixtures
fixture_dir="$(dirname "$0")/../fixtures/simple-plugin"
plugin_file=$(_zap_find_plugin_file "$fixture_dir" "simple" "")

if [[ -n "$plugin_file" && -f "$plugin_file" ]]; then
  echo "✓ Find plugin file in test fixture"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "✗ Find plugin file in test fixture"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Test fpath addition
test_dir="/tmp/zap-test-fpath-$$"
mkdir -p "$test_dir"
_zap_add_to_fpath "$test_dir"

if (( ${fpath[(I)$test_dir]} )); then
  echo "✓ Add directory to fpath"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "✗ Add directory to fpath"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

rm -rf "$test_dir"

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
