#!/usr/bin/env zsh
#
# Contract Test: plugins=() Array Parsing
#
# Tests the array parsing infrastructure that extracts plugin specifications
# from the plugins=() array in .zshrc files.
#
# WHY: The plugins=() array is the primary user interface for declarative
# plugin management. It must handle various formatting styles (single-line,
# multi-line, quoted, unquoted) and extract clean plugin specifications.
#
# Array formats to support:
#   plugins=( owner/repo )
#   plugins=(
#     owner/repo1
#     owner/repo2@version
#   )
#   plugins=( "owner/repo" 'owner/repo2' )
#
# TDD WORKFLOW: RED - these tests should FAIL until array parsing is implemented

# Load modules
source "${0:A:h}/../../../lib/declarative.zsh"

# Test setup
TEST_NAME="plugins=() Array Parsing Contract"
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

# TC-ARRAY-001: Single-line array
run_test "TC-ARRAY-001: Parse single-line array"
cat > "$TEST_DIR/test1.zsh" <<'EOF'
plugins=( zsh-users/zsh-autosuggestions )
EOF

result=$(_zap_extract_plugins_array "$TEST_DIR/test1.zsh")
expected="zsh-users/zsh-autosuggestions"

if [[ "$result" == "$expected" ]]; then
  pass "Single-line array parsed"
else
  fail "Single-line array parsed" "$expected" "$result"
fi

# TC-ARRAY-002: Multi-line array
run_test "TC-ARRAY-002: Parse multi-line array"
cat > "$TEST_DIR/test2.zsh" <<'EOF'
plugins=(
  zsh-users/zsh-autosuggestions
  zsh-users/zsh-syntax-highlighting
)
EOF

result=$(_zap_extract_plugins_array "$TEST_DIR/test2.zsh")
count=$(echo "$result" | wc -l)

if [[ $count -eq 2 ]]; then
  pass "Multi-line array parsed (2 plugins)"
else
  fail "Multi-line array parsed" "2 plugins" "$count plugins"
fi

# TC-ARRAY-003: Array with versions
run_test "TC-ARRAY-003: Parse array with versions"
cat > "$TEST_DIR/test3.zsh" <<'EOF'
plugins=(
  zsh-users/zsh-autosuggestions@v0.7.0
  romkatv/powerlevel10k@master
)
EOF

result=$(_zap_extract_plugins_array "$TEST_DIR/test3.zsh")
if echo "$result" | grep -q "zsh-users/zsh-autosuggestions@v0.7.0" && \
   echo "$result" | grep -q "romkatv/powerlevel10k@master"; then
  pass "Array with versions parsed"
else
  fail "Array with versions parsed" "both versioned plugins" "$result"
fi

# TC-ARRAY-004: Array with subdirectories
run_test "TC-ARRAY-004: Parse array with subdirectories"
cat > "$TEST_DIR/test4.zsh" <<'EOF'
plugins=(
  ohmyzsh/ohmyzsh:plugins/git
  ohmyzsh/ohmyzsh:plugins/docker
)
EOF

result=$(_zap_extract_plugins_array "$TEST_DIR/test4.zsh")
if echo "$result" | grep -q "ohmyzsh/ohmyzsh:plugins/git"; then
  pass "Array with subdirectories parsed"
else
  fail "Array with subdirectories parsed" "plugins with subdirs" "$result"
fi

# TC-ARRAY-005: Array with double quotes
run_test "TC-ARRAY-005: Parse array with double quotes"
cat > "$TEST_DIR/test5.zsh" <<'EOF'
plugins=(
  "zsh-users/zsh-autosuggestions"
  "zsh-users/zsh-syntax-highlighting"
)
EOF

result=$(_zap_extract_plugins_array "$TEST_DIR/test5.zsh")
# Quotes should be stripped
if echo "$result" | grep -q "^zsh-users/zsh-autosuggestions$"; then
  pass "Double-quoted elements parsed (quotes stripped)"
else
  fail "Double-quoted elements parsed" "zsh-users/zsh-autosuggestions" "$result"
fi

# TC-ARRAY-006: Array with single quotes
run_test "TC-ARRAY-006: Parse array with single quotes"
cat > "$TEST_DIR/test6.zsh" <<'EOF'
plugins=(
  'zsh-users/zsh-autosuggestions'
  'zsh-users/zsh-syntax-highlighting'
)
EOF

result=$(_zap_extract_plugins_array "$TEST_DIR/test6.zsh")
# Quotes should be stripped
if echo "$result" | grep -q "^zsh-users/zsh-autosuggestions$"; then
  pass "Single-quoted elements parsed (quotes stripped)"
else
  fail "Single-quoted elements parsed" "zsh-users/zsh-autosuggestions" "$result"
fi

# TC-ARRAY-007: Array with comments
run_test "TC-ARRAY-007: Parse array with comments"
cat > "$TEST_DIR/test7.zsh" <<'EOF'
plugins=(
  # Essential plugins
  zsh-users/zsh-autosuggestions
  # Syntax highlighting
  zsh-users/zsh-syntax-highlighting
)
EOF

result=$(_zap_extract_plugins_array "$TEST_DIR/test7.zsh")
# Comments should be ignored
count=$(echo "$result" | wc -l)
if [[ $count -eq 2 ]]; then
  pass "Array with comments parsed (comments ignored)"
else
  fail "Array with comments parsed" "2 plugins" "$count plugins"
fi

# TC-ARRAY-008: Array with blank lines
run_test "TC-ARRAY-008: Parse array with blank lines"
cat > "$TEST_DIR/test8.zsh" <<'EOF'
plugins=(
  zsh-users/zsh-autosuggestions

  zsh-users/zsh-syntax-highlighting
)
EOF

result=$(_zap_extract_plugins_array "$TEST_DIR/test8.zsh")
# Blank lines should be ignored
count=$(echo "$result" | grep -c "zsh-users/")
if [[ $count -eq 2 ]]; then
  pass "Array with blank lines parsed (blanks ignored)"
else
  fail "Array with blank lines parsed" "2 plugins" "$count plugins"
fi

# TC-ARRAY-009: No plugins array (file doesn't declare array)
run_test "TC-ARRAY-009: Handle missing plugins array"
cat > "$TEST_DIR/test9.zsh" <<'EOF'
# No plugins array in this file
source ~/.zshrc
EOF

result=$(_zap_extract_plugins_array "$TEST_DIR/test9.zsh")
if [[ -z "$result" ]]; then
  pass "Missing array returns empty result"
else
  fail "Missing array returns empty result" "empty" "$result"
fi

# TC-ARRAY-010: Empty array
run_test "TC-ARRAY-010: Handle empty array"
cat > "$TEST_DIR/test10.zsh" <<'EOF'
plugins=()
EOF

result=$(_zap_extract_plugins_array "$TEST_DIR/test10.zsh")
if [[ -z "$result" ]]; then
  pass "Empty array returns empty result"
else
  fail "Empty array returns empty result" "empty" "$result"
fi

# TC-ARRAY-011: Array with mixed formatting
run_test "TC-ARRAY-011: Parse array with mixed formatting"
cat > "$TEST_DIR/test11.zsh" <<'EOF'
plugins=(
  zsh-users/zsh-autosuggestions
  "zsh-users/zsh-syntax-highlighting@v0.7.0"
  'ohmyzsh/ohmyzsh:plugins/git'
  romkatv/powerlevel10k@master:config
)
EOF

result=$(_zap_extract_plugins_array "$TEST_DIR/test11.zsh")
count=$(echo "$result" | wc -l)
if [[ $count -eq 4 ]]; then
  pass "Mixed formatting parsed (4 plugins)"
else
  fail "Mixed formatting parsed" "4 plugins" "$count plugins"
fi

# TC-ARRAY-012: Multiple arrays (only first should be used)
run_test "TC-ARRAY-012: Multiple arrays (use first)"
cat > "$TEST_DIR/test12.zsh" <<'EOF'
plugins=(
  zsh-users/zsh-autosuggestions
)

# Another array later (should be ignored)
plugins=(
  evil/plugin
)
EOF

result=$(_zap_extract_plugins_array "$TEST_DIR/test12.zsh")
if echo "$result" | grep -q "zsh-users/zsh-autosuggestions" && \
   ! echo "$result" | grep -q "evil/plugin"; then
  pass "First array used, subsequent ignored"
else
  fail "First array used" "only zsh-autosuggestions" "$result"
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
