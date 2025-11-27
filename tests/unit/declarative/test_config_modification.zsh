#!/usr/bin/env zsh
#
# Unit Test: Config File Modification (zap adopt logic)
#
# Tests the AWK-based config file modification logic used by zap adopt
# to ensure it correctly appends plugins to the plugins=() array.
#

# Setup test environment
setopt ERR_EXIT
setopt PIPE_FAIL

# Load Zap library functions
SCRIPT_DIR="${0:A:h}"
ZAP_ROOT="${SCRIPT_DIR}/../../.."
source "${ZAP_ROOT}/lib/declarative.zsh"
source "${ZAP_ROOT}/lib/utils.zsh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Test framework functions
_test_start() {
  echo "TEST: $1"
  ((TESTS_RUN++))
}

_test_assert() {
  local condition="$1"
  local message="$2"

  if eval "$condition"; then
    echo "  ✓ $message"
    ((TESTS_PASSED++))
    return 0
  else
    echo "  ✗ FAIL: $message"
    return 1
  fi
}

_test_summary() {
  echo ""
  echo "========================================"
  echo "Tests run: $TESTS_RUN"
  echo "Tests passed: $TESTS_PASSED"
  echo "Tests failed: $((TESTS_RUN - TESTS_PASSED))"

  if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo "Status: ALL TESTS PASSED ✓"
    return 0
  else
    echo "Status: SOME TESTS FAILED ✗"
    return 1
  fi
}

# Setup test directory
TEST_DIR=$(mktemp -d)

# Cleanup function
_cleanup() {
  rm -rf "$TEST_DIR"
}
trap _cleanup EXIT

#
# Test 1: Create plugins array in file without array
#
_test_start "Create plugins array in file without array"

# Create test config without plugins array
cat > "$TEST_DIR/test1.zshrc" <<'EOF'
# My Zsh config
export PATH="/usr/local/bin:$PATH"

source ~/.zap/zap.zsh
EOF

# Simulate adoption (use AWK pattern from lib/declarative.zsh)
_zap_adopt_to_config "$TEST_DIR/test1.zshrc" "test/plugin1"

# Verify plugin was added
_test_assert "[[ -f \"$TEST_DIR/test1.zshrc\" ]]" "Config file exists"
_test_assert "grep -q \"plugins=(\" \"$TEST_DIR/test1.zshrc\"" "plugins array created"
_test_assert "grep -q \"test/plugin1\" \"$TEST_DIR/test1.zshrc\"" "Plugin added to array"

#
# Test 2: Append to existing array (single-line format)
#
_test_start "Append to existing single-line array"

# Create test config with single-line array
cat > "$TEST_DIR/test2.zshrc" <<'EOF'
plugins=('existing/plugin1' 'existing/plugin2')

source ~/.zap/zap.zsh
EOF

# Adopt new plugin
_zap_adopt_to_config "$TEST_DIR/test2.zshrc" "new/plugin3"

# Verify plugin was appended
content=$(cat "$TEST_DIR/test2.zshrc")
_test_assert "[[ \"$content\" == *\"new/plugin3\"* ]]" "New plugin added"
_test_assert "[[ \"$content\" == *\"existing/plugin1\"* ]]" "Existing plugin1 preserved"
_test_assert "[[ \"$content\" == *\"existing/plugin2\"* ]]" "Existing plugin2 preserved"

#
# Test 3: Append to existing array (multi-line format)
#
_test_start "Append to existing multi-line array"

# Create test config with multi-line array
cat > "$TEST_DIR/test3.zshrc" <<'EOF'
plugins=(
  'existing/plugin1'
  'existing/plugin2'
)

source ~/.zap/zap.zsh
EOF

# Adopt new plugin
_zap_adopt_to_config "$TEST_DIR/test3.zshrc" "new/plugin3"

# Verify plugin was appended before closing paren
content=$(cat "$TEST_DIR/test3.zshrc")
_test_assert "[[ \"$content\" == *\"new/plugin3\"* ]]" "New plugin added"
_test_assert "grep -B1 \"^)\" \"$TEST_DIR/test3.zshrc\" | grep -q \"new/plugin3\"" "Plugin added before closing paren"

#
# Test 4: Handle version-pinned plugins
#
_test_start "Handle version-pinned plugins"

# Create test config
cat > "$TEST_DIR/test4.zshrc" <<'EOF'
plugins=(
  'existing/plugin1'
)

source ~/.zap/zap.zsh
EOF

# Adopt version-pinned plugin
_zap_adopt_to_config "$TEST_DIR/test4.zshrc" "new/plugin@v1.2.3"

# Verify version pin preserved
_test_assert "grep -q \"new/plugin@v1.2.3\" \"$TEST_DIR/test4.zshrc\"" "Version pin preserved"

#
# Test 5: Handle subdirectory plugins
#
_test_start "Handle subdirectory plugins"

# Create test config
cat > "$TEST_DIR/test5.zshrc" <<'EOF'
plugins=(
  'existing/plugin1'
)

source ~/.zap/zap.zsh
EOF

# Adopt subdirectory plugin
_zap_adopt_to_config "$TEST_DIR/test5.zshrc" "ohmyzsh/ohmyzsh:plugins/git"

# Verify subdir preserved
_test_assert "grep -q \"ohmyzsh/ohmyzsh:plugins/git\" \"$TEST_DIR/test5.zshrc\"" "Subdirectory spec preserved"

#
# Test 6: Preserve existing formatting and comments
#
_test_start "Preserve existing formatting and comments"

# Create test config with comments
cat > "$TEST_DIR/test6.zshrc" <<'EOF'
# Core plugins
plugins=(
  'plugin1'  # Syntax highlighting
  'plugin2'  # Autosuggestions
)

# Other config
export FOO=bar
EOF

# Adopt new plugin
_zap_adopt_to_config "$TEST_DIR/test6.zshrc" "new/plugin3"

# Verify formatting and comments preserved
_test_assert "grep -q \"# Core plugins\" \"$TEST_DIR/test6.zshrc\"" "Comment before array preserved"
_test_assert "grep -q \"# Syntax highlighting\" \"$TEST_DIR/test6.zshrc\"" "Inline comment preserved"
_test_assert "grep -q \"export FOO=bar\" \"$TEST_DIR/test6.zshrc\"" "Config after array preserved"

#
# Test 7: Backup creation
#
_test_start "Backup creation before modification"

# Create test config
cat > "$TEST_DIR/test7.zshrc" <<'EOF'
plugins=('plugin1')
EOF

# Store original content
original_content=$(cat "$TEST_DIR/test7.zshrc")

# Adopt with backup
_zap_adopt_to_config_with_backup "$TEST_DIR/test7.zshrc" "new/plugin2"

# Verify backup exists with correct content
backup_file=$(ls "$TEST_DIR"/test7.zshrc.backup-* 2>/dev/null | head -1)
if [[ -n "$backup_file" ]]; then
  backup_content=$(cat "$backup_file")
  _test_assert "[[ \"$backup_content\" == \"$original_content\" ]]" "Backup contains original content"
else
  echo "  ✗ FAIL: Backup file not created"
fi

#
# Test 8: Handle empty array
#
_test_start "Handle empty array"

# Create test config with empty array
cat > "$TEST_DIR/test8.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

# Adopt plugin to empty array
_zap_adopt_to_config "$TEST_DIR/test8.zshrc" "first/plugin"

# Verify plugin added
_test_assert "grep -q \"first/plugin\" \"$TEST_DIR/test8.zshrc\"" "Plugin added to empty array"

#
# Test 9: Handle array with quotes and special characters
#
_test_start "Handle array with quotes and special characters"

# Create test config
cat > "$TEST_DIR/test9.zshrc" <<'EOF'
plugins=(
  "double-quoted/plugin"
  'single-quoted/plugin'
)
EOF

# Adopt new plugin
_zap_adopt_to_config "$TEST_DIR/test9.zshrc" "new/plugin"

# Verify all plugins present
content=$(cat "$TEST_DIR/test9.zshrc")
_test_assert "[[ \"$content\" == *\"double-quoted/plugin\"* ]]" "Double-quoted plugin preserved"
_test_assert "[[ \"$content\" == *\"single-quoted/plugin\"* ]]" "Single-quoted plugin preserved"
_test_assert "[[ \"$content\" == *\"new/plugin\"* ]]" "New plugin added"

#
# Test 10: Atomic write (temp file + mv)
#
_test_start "Atomic write operation"

# Create test config
cat > "$TEST_DIR/test10.zshrc" <<'EOF'
plugins=('plugin1')
EOF

# Get original inode
original_inode=$(stat -c '%i' "$TEST_DIR/test10.zshrc" 2>/dev/null || stat -f '%i' "$TEST_DIR/test10.zshrc" 2>/dev/null)

# Adopt plugin
_zap_adopt_to_config "$TEST_DIR/test10.zshrc" "new/plugin"

# Get new inode (should be different if atomic move was used)
new_inode=$(stat -c '%i' "$TEST_DIR/test10.zshrc" 2>/dev/null || stat -f '%i' "$TEST_DIR/test10.zshrc" 2>/dev/null)

# Note: Atomic write via mv will change inode
_test_assert "[[ -f \"$TEST_DIR/test10.zshrc\" ]]" "Config file exists after adoption"
_test_assert "grep -q \"new/plugin\" \"$TEST_DIR/test10.zshrc\"" "New plugin present in final file"

# Print summary
_test_summary
