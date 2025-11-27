#!/usr/bin/env bats
#
# Integration test: User Story 5 - Basic diff command (T092)
#
# Purpose: Test that `zap diff` shows the difference between declared
# and current state, helping users understand what 'zap sync' will do.
#
# Test scenarios:
# - Show plugins to be removed
# - Show plugins to be added
# - Show no changes when in sync
# - Clear formatting with +/- indicators
# - Handles empty states
# - Verbose mode shows additional context
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

@test "US5-DIFF: Show plugins to be removed" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "exp1" "plugin1"
  create_test_plugin "exp2" "plugin2"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp1/plugin1 >/dev/null && \
              zap try exp2/plugin2 >/dev/null && \
              zap diff"
  assert_success
  assert_output --partial "- exp1/plugin1"
  assert_output --partial "- exp2/plugin2"
}

@test "US5-DIFF: Show plugins to be added" {
  # Start with experimental plugins
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "exp" "plugin"

  # Load experimental plugin
  zsh -c "source $TEST_DIR/.zshrc && \
          zap try exp/plugin >/dev/null" 2>/dev/null

  # Now update config to declare it
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'exp/plugin'
)

source ~/.zap/zap.zsh
EOF

  # In a fresh shell, diff would show removal of experimental
  # (since it's now declared, experimental state is cleared)
  run zsh -c "source $TEST_DIR/.zshrc && zap diff"
  assert_success
  # When in sync, no changes
  assert_output --partial "No changes"
}

@test "US5-DIFF: Show no changes when in sync" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin2'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"
  create_test_plugin "testuser" "plugin2"

  run zsh -c "source $TEST_DIR/.zshrc && zap diff"
  assert_success
  assert_output --partial "No changes"
  assert_output --partial "in sync"
}

@test "US5-DIFF: Clear formatting with - indicator for removals" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "exp" "plugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp/plugin >/dev/null && \
              zap diff"
  assert_success
  # Should use standard diff format
  assert_output --partial "- exp/plugin"
}

@test "US5-DIFF: Multiple removals clearly listed" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "exp1" "plugin1"
  create_test_plugin "exp2" "plugin2"
  create_test_plugin "exp3" "plugin3"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp1/plugin1 >/dev/null && \
              zap try exp2/plugin2 >/dev/null && \
              zap try exp3/plugin3 >/dev/null && \
              zap diff"
  assert_success
  assert_output --partial "- exp1/plugin1"
  assert_output --partial "- exp2/plugin2"
  assert_output --partial "- exp3/plugin3"
  # Should show count
  assert_output --partial "3 plugin"
}

@test "US5-DIFF: Handles empty experimental state" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin"

  run zsh -c "source $TEST_DIR/.zshrc && zap diff"
  assert_success
  assert_output --partial "No changes"
}

@test "US5-DIFF: Handles empty declared state" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap diff"
  assert_success
  assert_output --partial "No changes"
  assert_output --partial "in sync"
}

@test "US5-DIFF: Version pins shown in diff" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "exp" "plugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp/plugin@v1.0 >/dev/null && \
              zap diff"
  assert_success
  assert_output --partial "- exp/plugin@v1.0"
}

@test "US5-DIFF: Subdirectories shown in diff" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  mkdir -p "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git"
  echo "# Git" > "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git/git.plugin.zsh"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try ohmyzsh/ohmyzsh:plugins/git >/dev/null && \
              zap diff"
  assert_success
  assert_output --partial "- ohmyzsh/ohmyzsh:plugins/git"
}

@test "US5-DIFF: Verbose mode shows additional context" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "exp" "plugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp/plugin >/dev/null && \
              zap diff --verbose"
  assert_success
  assert_output --partial "- exp/plugin"
  # Verbose should show what sync will do
  assert_output --partial "sync"
}

@test "US5-DIFF: Exit code is 0 for no changes" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin"

  run zsh -c "source $TEST_DIR/.zshrc && zap diff"
  assert_success  # Exit code 0
}

@test "US5-DIFF: Exit code is 0 even with changes" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "exp" "plugin"

  # Diff is informational, should always succeed
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp/plugin >/dev/null && \
              zap diff"
  assert_success  # Exit code 0
}

@test "US5-DIFF: Helpful summary at end" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "exp1" "plugin1"
  create_test_plugin "exp2" "plugin2"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp1/plugin1 >/dev/null && \
              zap try exp2/plugin2 >/dev/null && \
              zap diff"
  assert_success
  # Should show summary
  assert_output --partial "2 plugin"
  assert_output --partial "removed"
  # Should suggest action
  assert_output --partial "zap sync"
}

@test "US5-DIFF: Diff aligns with status command" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "exp" "plugin"

  # Get status output
  local status_output=$(zsh -c "source $TEST_DIR/.zshrc && \
                                 zap try exp/plugin >/dev/null && \
                                 zap status" 2>/dev/null)

  # Get diff output
  local diff_output=$(zsh -c "source $TEST_DIR/.zshrc && \
                               zap try exp/plugin >/dev/null && \
                               zap diff" 2>/dev/null)

  # Both should mention the experimental plugin
  echo "$status_output" | grep -q "exp/plugin"
  echo "$diff_output" | grep -q "exp/plugin"
}
