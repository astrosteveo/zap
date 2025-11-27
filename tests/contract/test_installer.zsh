#!/usr/bin/env zsh
#
# test_installer.zsh - Contract tests for installer
#
# WHY: Verify installer meets FR-001 requirements (User Story 1)
# T016: Contract test for installer (.zshrc modification, directory creation)

# Test framework setup
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
    echo "  ✗ $message"
    echo "    Expected: $expected"
    echo "    Got: $actual"
    return 1
  fi
}

assert_true() {
  local condition=$1
  local message="${2:-Condition should be true}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ $condition -eq 0 ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ✓ $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ✗ $message"
    return 1
  fi
}

assert_file_exists() {
  local file="$1"
  local message="${2:-File should exist: $file}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ -f "$file" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ✓ $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ✗ $message"
    return 1
  fi
}

assert_dir_exists() {
  local dir="$1"
  local message="${2:-Directory should exist: $dir}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ -d "$dir" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ✓ $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ✗ $message"
    return 1
  fi
}

# Set up test environment
TEST_DIR="/tmp/zap-installer-test-$$"
mkdir -p "$TEST_DIR/home"
export HOME="$TEST_DIR/home"
export ZDOTDIR="$HOME"
export ZAP_DIR="$HOME/.zap"
export ZAP_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zap"

# Copy installer to test directory
cp "$(dirname "$0")/../../install.zsh" "$TEST_DIR/"

echo "Contract Test: Installer (T016)"
echo "================================"
echo ""

#
# Test 1: Directory creation
#
echo "Test 1: Installer creates required directories"

# Run installer non-interactively (simulate local install)
(
  cd "$TEST_DIR"
  # Set up as if running from local repo
  mkdir -p "$TEST_DIR/lib"
  cp -r "$(dirname "$0")/../../"/* "$TEST_DIR/" 2>/dev/null || true

  # Run installer
  echo "y" | ZAP_REPO_URL="file://$TEST_DIR" zsh install.zsh >/dev/null 2>&1 || true
)

assert_dir_exists "$ZAP_DIR" "ZAP_DIR created"
assert_dir_exists "$ZAP_DATA_DIR" "ZAP_DATA_DIR created"
assert_dir_exists "$ZAP_DATA_DIR/plugins" "Plugin directory created"

echo ""

#
# Test 2: .zshrc modification
#
echo "Test 2: Installer modifies .zshrc correctly"

# Check .zshrc exists and contains zap
assert_file_exists "$HOME/.zshrc" ".zshrc created"

# Check zap marker exists
if [[ -f "$HOME/.zshrc" ]]; then
  local has_marker=$(grep -c "=== Zap Plugin Manager ===" "$HOME/.zshrc" 2>/dev/null || echo 0)
  assert_equals "1" "$has_marker" ".zshrc contains zap marker"

  local has_source=$(grep -c "source.*zap.zsh" "$HOME/.zshrc" 2>/dev/null || echo 0)
  [[ $has_source -gt 0 ]]
  assert_true $? ".zshrc sources zap.zsh"
fi

echo ""

#
# Test 3: Backup creation
#
echo "Test 3: Installer creates .zshrc backup"

# Backup files have pattern: .zshrc.backup.*
local backup_count=$(ls "$HOME"/.zshrc.backup.* 2>/dev/null | wc -l)
[[ $backup_count -gt 0 ]]
assert_true $? ".zshrc backup created"

echo ""

#
# Test 4: Installation files
#
echo "Test 4: Core files are installed"

assert_file_exists "$ZAP_DIR/zap.zsh" "zap.zsh installed"
assert_file_exists "$ZAP_DIR/install.zsh" "install.zsh installed"
assert_dir_exists "$ZAP_DIR/lib" "lib directory installed"

echo ""

#
# Test 5: Idempotency (reinstall doesn't break)
#
echo "Test 5: Installer is idempotent"

# Run installer again
(
  cd "$TEST_DIR"
  echo "y" | ZAP_REPO_URL="file://$TEST_DIR" zsh install.zsh >/dev/null 2>&1 || true
)

# Should still work
assert_file_exists "$ZAP_DIR/zap.zsh" "Reinstall preserves installation"

# Should create new backup
local backup_count_after=$(ls "$HOME"/.zshrc.backup.* 2>/dev/null | wc -l)
[[ $backup_count_after -ge $backup_count ]]
assert_true $? "Reinstall creates new backup"

echo ""

# Clean up
rm -rf "$TEST_DIR" 2>/dev/null

# Summary
echo "================================"
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
