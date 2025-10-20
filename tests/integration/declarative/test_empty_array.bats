#!/usr/bin/env bats
#
# Integration test: User Story 1 - Empty array handling (T027)
#
# Purpose: Test that an empty plugins=() array results in no plugins being
# loaded, and that the shell remains fully functional without any plugins.
#
# Test scenarios:
# - Empty array with no whitespace
# - Empty array with whitespace/newlines
# - No plugins array at all
# - Commenting out all plugins in array
#

load '../test_helper'

setup() {
  export TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR"
  export ZAP_DIR="$TEST_DIR/.zap"
  export ZAP_DATA_DIR="$TEST_DIR/.local/share/zap"
  export ZDOTDIR="$TEST_DIR"

  mkdir -p "$ZAP_DIR/lib"
  mkdir -p "$ZAP_DATA_DIR"

  cp -r "$BATS_TEST_DIRNAME/../../../lib/"* "$ZAP_DIR/lib/"
  cp "$BATS_TEST_DIRNAME/../../../zap.zsh" "$ZAP_DIR/"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "US1-EA: Empty plugins array loads no plugins" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  assert_output --partial "Declared plugins: (none)"
  assert_output --partial "In sync with declared configuration"
}

@test "US1-EA: Empty array with whitespace" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(

)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  assert_output --partial "Declared plugins: (none)"
}

@test "US1-EA: Empty array with comments only" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  # No plugins yet
  # Will add later
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  assert_output --partial "Declared plugins: (none)"
}

@test "US1-EA: No plugins array at all" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
# No plugins array defined

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  assert_output --partial "Declared plugins: (none)"
}

@test "US1-EA: Shell functions work with empty array" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh

# Test basic shell functionality
test_function() {
  echo "Function works"
}
EOF

  run zsh -c "source $TEST_DIR/.zshrc && test_function"

  assert_success
  assert_output "Function works"
}

@test "US1-EA: Can add plugins after starting with empty array" {
  # Start with empty array
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins: (none)"

  # Create test plugin first
  create_test_plugin "test" "plugin"

  # Now add a plugin using try
  run zsh -c "source $TEST_DIR/.zshrc && zap try test/plugin && zap status"

  assert_success
  assert_output --partial "Experimental plugins (1)"
}

@test "US1-EA: Transition from empty to populated array" {
  # Start with empty array
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  # Update to add plugins
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'zsh-users/zsh-syntax-highlighting'
)

source ~/.zap/zap.zsh
EOF

  # New shell should load the plugin
  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  assert_output --partial "Declared plugins (1)"
  assert_output --partial "zsh-users/zsh-syntax-highlighting"
}

@test "US1-EA: Empty array shows helpful message" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  # Should indicate configuration is in sync (empty is a valid state)
  assert_output --partial "In sync"
}
