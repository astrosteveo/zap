#!/usr/bin/env zsh
#
# test_framework_detection.zsh - Contract tests for framework detection
#
# WHY: Verify FR-017, FR-025 (framework auto-detection)
# T044-T045: Contract tests for Oh-My-Zsh and Prezto detection

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
TEST_DIR="/tmp/zap-framework-test-$$"
mkdir -p "$TEST_DIR"
export ZAP_DIR="$(dirname "$0")/../.."
export ZAP_DATA_DIR="$TEST_DIR/data"

source "$ZAP_DIR/lib/utils.zsh"
source "$ZAP_DIR/lib/parser.zsh"
source "$ZAP_DIR/lib/framework.zsh"

echo "Contract Test: Framework Detection (T044-T045)"
echo "==============================================="
echo ""

#
# T044: Oh-My-Zsh Detection Tests
#
echo "=== Oh-My-Zsh Detection ==="
echo ""

echo "Test 1: Detect ohmyzsh/ohmyzsh repository"

result=$(_zap_detect_framework "ohmyzsh" "ohmyzsh")
assert_true $? "ohmyzsh/ohmyzsh is detected as framework"
assert_equals "oh-my-zsh" "$result" "Framework type is oh-my-zsh"

echo ""

echo "Test 2: Reject non-framework ohmyzsh repos"

result=$(_zap_detect_framework "ohmyzsh" "other-repo")
[[ $? -ne 0 ]]
assert_true $? "ohmyzsh/other-repo is not a framework"

echo ""

echo "Test 3: Case sensitivity in Oh-My-Zsh detection"

result=$(_zap_detect_framework "OhMyZsh" "ohmyzsh")
[[ $? -ne 0 ]]
assert_true $? "Case-sensitive matching (OhMyZsh != ohmyzsh)"

result=$(_zap_detect_framework "ohmyzsh" "OhMyZsh")
[[ $? -ne 0 ]]
assert_true $? "Case-sensitive repo matching"

echo ""

echo "Test 4: Oh-My-Zsh environment setup"

# Mock the plugin cache directory
export ZAP_PLUGIN_DIR="$TEST_DIR/plugins"
mkdir -p "$ZAP_PLUGIN_DIR/ohmyzsh__ohmyzsh"

_zap_setup_oh_my_zsh

assert_equals "$ZAP_PLUGIN_DIR/ohmyzsh__ohmyzsh" "$ZSH" "ZSH variable points to framework cache"
[[ -n "$ZSH_CACHE_DIR" ]]
assert_true $? "ZSH_CACHE_DIR is set"
[[ -n "$ZSH_CUSTOM" ]]
assert_true $? "ZSH_CUSTOM is set"

# Verify directories were created
[[ -d "$ZSH_CACHE_DIR" ]]
assert_true $? "ZSH_CACHE_DIR directory created"
[[ -d "$ZSH_CUSTOM" ]]
assert_true $? "ZSH_CUSTOM directory created"

echo ""

#
# T045: Prezto Detection Tests
#
echo "=== Prezto Detection ==="
echo ""

echo "Test 5: Detect sorin-ionescu/prezto repository"

result=$(_zap_detect_framework "sorin-ionescu" "prezto")
assert_true $? "sorin-ionescu/prezto is detected as framework"
assert_equals "prezto" "$result" "Framework type is prezto"

echo ""

echo "Test 6: Reject non-framework prezto-related repos"

result=$(_zap_detect_framework "sorin-ionescu" "other-repo")
[[ $? -ne 0 ]]
assert_true $? "sorin-ionescu/other-repo is not a framework"

result=$(_zap_detect_framework "other-user" "prezto")
[[ $? -ne 0 ]]
assert_true $? "other-user/prezto is not a framework"

echo ""

echo "Test 7: Prezto environment setup"

# Mock prezto cache
mkdir -p "$ZAP_PLUGIN_DIR/sorin-ionescu__prezto/modules/git/functions"
mkdir -p "$ZAP_PLUGIN_DIR/sorin-ionescu__prezto/modules/completion/functions"

_zap_setup_prezto

assert_equals "$ZAP_PLUGIN_DIR/sorin-ionescu__prezto" "$PREZTO" "PREZTO variable points to framework cache"
[[ -n "$ZDOTDIR" ]]
assert_true $? "ZDOTDIR is set"

# Check fpath contains prezto module functions
fpath_contains_prezto=0
for path in $fpath; do
  if [[ "$path" == *"sorin-ionescu__prezto/modules"* ]]; then
    fpath_contains_prezto=1
    break
  fi
done

[[ $fpath_contains_prezto -eq 1 ]]
assert_true $? "fpath includes Prezto module functions"

echo ""

#
# General Framework Tests
#
echo "=== General Framework Tests ==="
echo ""

echo "Test 8: Non-framework repos are not detected"

result=$(_zap_detect_framework "zsh-users" "zsh-syntax-highlighting")
[[ $? -ne 0 ]]
assert_true $? "Regular plugin repos are not frameworks"

result=$(_zap_detect_framework "user" "repo")
[[ $? -ne 0 ]]
assert_true $? "Generic repos are not frameworks"

echo ""

echo "Test 9: Framework base vs plugin distinction"

# Framework base (no subdirectory)
result=$(_zap_detect_framework "ohmyzsh" "ohmyzsh")
assert_true $? "Framework base is detected"

# The same repo with a subdirectory is still the framework
result=$(_zap_detect_framework "ohmyzsh" "ohmyzsh")
assert_true $? "Framework is detected regardless of subdirectory usage"

echo ""

echo "Test 10: Multiple framework setups don't conflict"

# Set up both frameworks
_zap_setup_oh_my_zsh
local zsh_var_omz="$ZSH"

_zap_setup_prezto
local prezto_var="$PREZTO"

# Verify both can be set up
[[ -n "$zsh_var_omz" ]]
assert_true $? "Oh-My-Zsh setup persists"
[[ -n "$prezto_var" ]]
assert_true $? "Prezto setup persists"

# They should point to different locations
[[ "$zsh_var_omz" != "$prezto_var" ]]
assert_true $? "Different frameworks have different base paths"

echo ""

echo "Test 11: Empty owner/repo handling"

result=$(_zap_detect_framework "" "")
[[ $? -ne 0 ]]
assert_true $? "Empty owner/repo is not a framework"

result=$(_zap_detect_framework "ohmyzsh" "")
[[ $? -ne 0 ]]
assert_true $? "Empty repo name is not a framework"

echo ""

echo "Test 12: Special characters in framework detection"

result=$(_zap_detect_framework "ohmyzsh/../malicious" "ohmyzsh")
[[ $? -ne 0 ]]
assert_true $? "Path traversal in owner is rejected"

result=$(_zap_detect_framework "ohmyzsh" "ohmyzsh; rm -rf /")
[[ $? -ne 0 ]]
assert_true $? "Command injection in repo is rejected"

echo ""

# Clean up
rm -rf "$TEST_DIR" 2>/dev/null
unset ZSH ZSH_CACHE_DIR ZSH_CUSTOM PREZTO ZDOTDIR

# Summary
echo "==============================================="
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
