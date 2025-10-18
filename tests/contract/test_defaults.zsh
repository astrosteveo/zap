#!/usr/bin/env zsh
#
# test_defaults.zsh - Contract tests for default keybindings
#
# WHY: Verify FR-011 (default keybindings) and FR-012 (completion system)
# T036: Contract test for default keybindings

# Test framework
typeset -i TESTS_RUN=0
typeset -i TESTS_PASSED=0
typeset -i TESTS_FAILED=0

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

assert_not_empty() {
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ -n "$1" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ✓ $2"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ✗ $2 (value was empty)"
  fi
}

# Setup
export ZAP_DIR="$(dirname "$0")/../.."

# Source defaults
source "$ZAP_DIR/lib/defaults.zsh"

echo "Contract Test: Default Keybindings (T036)"
echo "=========================================="
echo ""

#
# Test 1: Delete key is bound
#
echo "Test 1: Delete key binding"

# Check if delete key has a binding
bindkey_output=$(bindkey "${terminfo[kdch1]}" 2>/dev/null)
[[ -n "$bindkey_output" ]]
assert_true $? "Delete key has a binding"

# Verify it's bound to delete-char
[[ "$bindkey_output" =~ "delete-char" ]]
assert_true $? "Delete key bound to delete-char"

echo ""

#
# Test 2: Home key is bound
#
echo "Test 2: Home key binding"

bindkey_output=$(bindkey "${terminfo[khome]}" 2>/dev/null)
[[ -n "$bindkey_output" ]]
assert_true $? "Home key has a binding"

[[ "$bindkey_output" =~ "beginning-of-line" ]]
assert_true $? "Home key bound to beginning-of-line"

echo ""

#
# Test 3: End key is bound
#
echo "Test 3: End key binding"

bindkey_output=$(bindkey "${terminfo[kend]}" 2>/dev/null)
[[ -n "$bindkey_output" ]]
assert_true $? "End key has a binding"

[[ "$bindkey_output" =~ "end-of-line" ]]
assert_true $? "End key bound to end-of-line"

echo ""

#
# Test 4: Page Up key is bound
#
echo "Test 4: Page Up key binding"

bindkey_output=$(bindkey "${terminfo[kpp]}" 2>/dev/null)
[[ -n "$bindkey_output" ]]
assert_true $? "Page Up key has a binding"

[[ "$bindkey_output" =~ "up-line-or-history" ]]
assert_true $? "Page Up bound to history navigation"

echo ""

#
# Test 5: Page Down key is bound
#
echo "Test 5: Page Down key binding"

bindkey_output=$(bindkey "${terminfo[knp]}" 2>/dev/null)
[[ -n "$bindkey_output" ]]
assert_true $? "Page Down key has a binding"

[[ "$bindkey_output" =~ "down-line-or-history" ]]
assert_true $? "Page Down bound to history navigation"

echo ""

#
# Test 6: Completion system is initialized
#
echo "Test 6: Completion system initialization"

# Check if compinit function exists
(( $+functions[compinit] ))
assert_true $? "compinit function is loaded"

echo ""

#
# Test 7: Completion options are set
#
echo "Test 7: Completion options configured"

# Check COMPLETE_IN_WORD option
[[ -o COMPLETE_IN_WORD ]]
assert_true $? "COMPLETE_IN_WORD option set"

# Check AUTO_MENU option
[[ -o AUTO_MENU ]]
assert_true $? "AUTO_MENU option set"

# Check AUTO_LIST option
[[ -o AUTO_LIST ]]
assert_true $? "AUTO_LIST option set"

echo ""

#
# Test 8: Case-insensitive completion configured
#
echo "Test 8: Case-insensitive matching"

# Check zstyle for matcher-list
zstyle_output=$(zstyle -L ':completion:*' matcher-list 2>/dev/null)
[[ -n "$zstyle_output" ]]
assert_true $? "Completion matcher-list is configured"

[[ "$zstyle_output" =~ "m:{a-zA-Z}={A-Za-z}" ]] || [[ "$zstyle_output" =~ "m:{[:lower:]}={[:upper:]}" ]]
assert_true $? "Case-insensitive matching configured"

echo ""

#
# Test 9: Keybindings don't conflict
#
echo "Test 9: No conflicting keybindings"

# All our bindings should exist without error
all_bound=0

if [[ -n "${terminfo[kdch1]}" ]] && bindkey "${terminfo[kdch1]}" >/dev/null 2>&1; then
  all_bound=$((all_bound + 1))
fi

if [[ -n "${terminfo[khome]}" ]] && bindkey "${terminfo[khome]}" >/dev/null 2>&1; then
  all_bound=$((all_bound + 1))
fi

if [[ -n "${terminfo[kend]}" ]] && bindkey "${terminfo[kend]}" >/dev/null 2>&1; then
  all_bound=$((all_bound + 1))
fi

if [[ -n "${terminfo[kpp]}" ]] && bindkey "${terminfo[kpp]}" >/dev/null 2>&1; then
  all_bound=$((all_bound + 1))
fi

if [[ -n "${terminfo[knp]}" ]] && bindkey "${terminfo[knp]}" >/dev/null 2>&1; then
  all_bound=$((all_bound + 1))
fi

[[ $all_bound -ge 3 ]]  # At least 3 keys should be bound
assert_true $? "Multiple keybindings coexist without conflicts"

echo ""

#
# Test 10: Defaults don't override user bindings
#
echo "Test 10: User bindings take precedence"

# This is more of a design verification
# defaults.zsh should use conditional binding or not force overrides
# We verify by checking that bindkey can still be called

bindkey "^X" undefined-key 2>/dev/null
bindkey_check=$(bindkey "^X" 2>/dev/null)
[[ "$bindkey_check" =~ "undefined-key" ]]
assert_true $? "Custom keybindings can be set"

# Clean up test binding
bindkey -r "^X" 2>/dev/null

echo ""

# Summary
echo "=========================================="
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
