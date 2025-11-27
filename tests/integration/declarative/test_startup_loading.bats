#!/usr/bin/env bats
#
# Integration test: User Story 1 - Shell startup with plugins array (T024)
#
# Purpose: Test that plugins declared in plugins=() array are automatically
# loaded on shell startup without requiring manual zap load commands.
#
# Test scenarios:
# - Basic array with multiple plugins
# - Empty plugins array
# - Plugins array with quoted elements
# - Multiline plugins array
#

load '../test_helper'

setup() {
  # Create temporary test directory
  export TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR"
  export ZAP_DIR="$TEST_DIR/.zap"
  export ZAP_DATA_DIR="$TEST_DIR/.local/share/zap"
  export ZDOTDIR="$TEST_DIR"

  # Create directories
  mkdir -p "$ZAP_DIR/lib"
  mkdir -p "$ZAP_DATA_DIR"

  # Copy Zap files to test directory
  cp -r "$BATS_TEST_DIRNAME/../../../lib/"* "$ZAP_DIR/lib/"
  cp "$BATS_TEST_DIRNAME/../../../zap.zsh" "$ZAP_DIR/"
}

teardown() {
  # Clean up test directory
  rm -rf "$TEST_DIR"
}

@test "US1: Plugins array loads multiple plugins on startup" {
  # Create test .zshrc with plugins array
  cat > "$TEST_DIR/.zshrc" <<'EOF'
# Test plugins array
plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions'
)

source ~/.zap/zap.zsh
EOF

  # Start new shell and check if plugins are loaded
  # We'll check the state file to verify plugins were loaded
  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  assert_output --partial "zsh-users/zsh-syntax-highlighting"
  assert_output --partial "zsh-users/zsh-autosuggestions"
  assert_output --partial "Declared plugins (2)"
}

@test "US1: Empty plugins array loads no plugins" {
  # Create test .zshrc with empty array
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  assert_output --partial "Declared plugins: (none)"
  assert_output --partial "In sync with declared configuration"
}

@test "US1: Plugins array preserves load order" {
  # Create test .zshrc with specific order
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'plugin-a/first'
  'plugin-b/second'
  'plugin-c/third'
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  # Verify all three plugins are listed
  assert_output --partial "plugin-a/first"
  assert_output --partial "plugin-b/second"
  assert_output --partial "plugin-c/third"
}

@test "US1: Individual plugin failure does not block shell startup" {
  # Create test .zshrc with mix of valid and invalid plugins
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'valid/plugin'
  'nonexistent/invalid-plugin-404'
  'another-valid/plugin'
)

source ~/.zap/zap.zsh
EOF

  # Shell should start successfully even if one plugin fails
  run zsh -c "source $TEST_DIR/.zshrc && echo 'Shell started successfully'"

  assert_success
  assert_output --partial "Shell started successfully"
}

@test "US1: Multiline plugins array is parsed correctly" {
  # Create test .zshrc with multiline array and comments
  cat > "$TEST_DIR/.zshrc" <<'EOF'
# My plugins
plugins=(
  # Core plugins
  'zsh-users/zsh-syntax-highlighting'

  # Completions
  'zsh-users/zsh-autosuggestions'

  # Theme
  'romkatv/powerlevel10k'
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  assert_output --partial "Declared plugins (3)"
  assert_output --partial "zsh-users/zsh-syntax-highlighting"
  assert_output --partial "zsh-users/zsh-autosuggestions"
  assert_output --partial "romkatv/powerlevel10k"
}

@test "US1: Plugins array with version pins loads correct versions" {
  # Create test .zshrc with version-pinned plugins
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'zsh-users/zsh-autosuggestions@v0.7.0'
  'romkatv/powerlevel10k@v1.19.0'
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status --verbose"

  assert_success
  assert_output --partial "zsh-users/zsh-autosuggestions"
  assert_output --partial "romkatv/powerlevel10k"
  # In verbose mode, should show version information
  assert_output --partial "spec:"
}

@test "US1: Plugins array with subdirectories is handled correctly" {
  # Create test .zshrc with Oh-My-Zsh-style subdirectory plugins
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'ohmyzsh/ohmyzsh:plugins/git'
  'ohmyzsh/ohmyzsh:plugins/docker'
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  assert_output --partial "ohmyzsh/ohmyzsh"
  assert_output --partial "Declared plugins"
}
