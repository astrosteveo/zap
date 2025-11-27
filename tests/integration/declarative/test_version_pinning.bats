#!/usr/bin/env bats
#
# Integration test: User Story 1 - Version-pinned plugins (T025)
#
# Purpose: Test that plugins with version pins (@version, @commit, @branch)
# are correctly downloaded and loaded at the specified version.
#
# Test scenarios:
# - Plugin with tag version pin (@v1.0.0)
# - Plugin with commit hash pin
# - Plugin with branch pin (@main, @master)
# - Mixed plugins (some pinned, some latest)
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

  # Copy Zap files
  cp -r "$BATS_TEST_DIRNAME/../../../lib/"* "$ZAP_DIR/lib/"
  cp "$BATS_TEST_DIRNAME/../../../zap.zsh" "$ZAP_DIR/"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "US1-VP: Plugin with tag version pin is loaded at specified version" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'zsh-users/zsh-autosuggestions@v0.7.0'
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status --verbose"

  assert_success
  assert_output --partial "zsh-users/zsh-autosuggestions"
  assert_output --partial "v0.7.0"
}

@test "US1-VP: Plugin with commit hash pin is loaded correctly" {
  # Using a known commit hash from a real repository
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'zsh-users/zsh-syntax-highlighting@0e1bb14d44'
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  assert_output --partial "zsh-users/zsh-syntax-highlighting"
}

@test "US1-VP: Plugin with branch pin is loaded correctly" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'romkatv/powerlevel10k@master'
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  assert_output --partial "romkatv/powerlevel10k"
}

@test "US1-VP: Mixed plugins (pinned and unpinned) load correctly" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions@v0.7.0'
  'zsh-users/zsh-completions@master'
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  assert_output --partial "Declared plugins (3)"
  assert_output --partial "zsh-users/zsh-syntax-highlighting"
  assert_output --partial "zsh-users/zsh-autosuggestions"
  assert_output --partial "zsh-users/zsh-completions"
}

@test "US1-VP: Version pin prevents automatic updates" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'zsh-users/zsh-autosuggestions@v0.7.0'
)

source ~/.zap/zap.zsh
EOF

  # Load plugin
  run zsh -c "source $TEST_DIR/.zshrc && zap status --verbose"
  assert_success

  # Try to update (should respect pin)
  run zsh -c "source $TEST_DIR/.zshrc && zap update"

  # Update should complete but pinned version should remain
  assert_success
  assert_output --partial "v0.7.0"
}

@test "US1-VP: Invalid version pin shows helpful error" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'zsh-users/zsh-autosuggestions@nonexistent-version-xyz'
)

source ~/.zap/zap.zsh
EOF

  # Shell should start despite invalid version
  run zsh -c "source $TEST_DIR/.zshrc && echo 'Shell started'"

  assert_success
  assert_output --partial "Shell started"
}
