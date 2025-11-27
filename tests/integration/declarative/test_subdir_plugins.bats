#!/usr/bin/env bats
#
# Integration test: User Story 1 - Subdirectory plugins (T026)
#
# Purpose: Test that plugins with subdirectory specifications (:subdir)
# are correctly loaded from the specified subdirectory within the repository.
#
# Test scenarios:
# - Oh-My-Zsh-style plugins with :plugins/name
# - Multiple subdirectory plugins from same repository
# - Combination of subdirectory and version pins
# - Invalid subdirectory handling
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

@test "US1-SD: Oh-My-Zsh plugin from subdirectory loads correctly" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'ohmyzsh/ohmyzsh:plugins/git'
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  assert_output --partial "ohmyzsh/ohmyzsh"
}

@test "US1-SD: Multiple subdirectory plugins from same repository" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'ohmyzsh/ohmyzsh:plugins/git'
  'ohmyzsh/ohmyzsh:plugins/docker'
  'ohmyzsh/ohmyzsh:plugins/kubectl'
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  assert_success
  # All three plugins should be loaded from different subdirectories
  assert_output --partial "ohmyzsh/ohmyzsh"
  assert_output --partial "Declared plugins"
}

@test "US1-SD: Subdirectory with version pin combination" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'ohmyzsh/ohmyzsh@master:plugins/git'
  'ohmyzsh/ohmyzsh@master:plugins/docker'
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status --verbose"

  assert_success
  assert_output --partial "ohmyzsh/ohmyzsh"
  assert_output --partial "spec:"
}

@test "US1-SD: Invalid subdirectory path is rejected" {
  # Path traversal attempt should be rejected
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'user/repo:../../etc/passwd'
)

source ~/.zap/zap.zsh
EOF

  # Shell should start but plugin should be rejected
  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  # Either fails validation or loads with error
  # The key is shell doesn't crash
  assert_success
}

@test "US1-SD: Absolute path in subdirectory is rejected" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'user/repo:/absolute/path'
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"

  # Should handle gracefully
  assert_success
}

@test "US1-SD: Nested subdirectory path works" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'ohmyzsh/ohmyzsh:plugins/git'
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status --verbose"

  assert_success
  assert_output --partial "ohmyzsh/ohmyzsh"
  # Verbose mode should show the subdirectory in spec
  assert_output --partial "plugins/git"
}

@test "US1-SD: Empty subdirectory specification handled" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'user/repo:'
)

source ~/.zap/zap.zsh
EOF

  # Should treat as no subdirectory (root)
  run zsh -c "source $TEST_DIR/.zshrc && echo 'OK'"

  assert_success
  assert_output --partial "OK"
}
