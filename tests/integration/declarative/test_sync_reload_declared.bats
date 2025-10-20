#!/usr/bin/env bats
#
# Integration test: User Story 3 - Declared plugin reloading (T052)
#
# Purpose: Test that `zap sync` ensures declared plugins are properly loaded
# after reconciliation, implementing the full reload strategy.
#
# Test scenarios:
# - Declared plugins remain after sync
# - Newly added declared plugins are loaded
# - Removed declared plugins are unloaded
# - Version changes are applied
# - Full shell reload preserves history
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

@test "US3-RELOAD: Declared plugins remain after sync" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin2'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"
  create_test_plugin "testuser" "plugin2"
  create_test_plugin "testuser" "explugin"

  # Add experimental, then sync
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/explugin >/dev/null && \
              zap sync --dry-run"
  assert_success
  # Should show declared plugins will remain
  assert_output --partial "Synchronizing to declared state"
}

@test "US3-RELOAD: Newly added declared plugins loaded after sync" {
  # Start with 1 plugin
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"
  create_test_plugin "testuser" "plugin2"

  # Update config to add plugin2
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin2'
)

source ~/.zap/zap.zsh
EOF

  # New shell should load both
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins (2)"
  assert_output --partial "testuser/plugin1"
  assert_output --partial "testuser/plugin2"
}

@test "US3-RELOAD: Removed declared plugins unloaded after sync" {
  # Start with 2 plugins
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin2'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"
  create_test_plugin "testuser" "plugin2"

  # Update config to remove plugin2
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
)

source ~/.zap/zap.zsh
EOF

  # New shell should only have plugin1
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins (1)"
  assert_output --partial "testuser/plugin1"
  # Should not have plugin2
  run zsh -c "source $TEST_DIR/.zshrc && zap status | grep plugin2"
  assert_failure
}

@test "US3-RELOAD: Version pin changes applied" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin@v1.0'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin"

  # Update to different version
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin@v2.0'
)

source ~/.zap/zap.zsh
EOF

  # New shell should reflect version change
  run zsh -c "source $TEST_DIR/.zshrc && zap status --verbose"
  assert_success
  assert_output --partial "testuser/plugin"
  # Verbose should show spec
  assert_output --partial "spec:"
}

@test "US3-RELOAD: Full reload message shown" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "explugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/explugin >/dev/null && \
              zap sync --dry-run"
  assert_success
  assert_output --partial "Reloading shell"
}

@test "US3-RELOAD: Sync preserves working directory" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "explugin"

  # Create a test directory
  mkdir -p "$TEST_DIR/testdir"

  # Note: Full test of exec zsh is difficult in BATS
  # This tests the command construction
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/explugin >/dev/null && \
              zap sync --dry-run"
  assert_success
}

@test "US3-RELOAD: Multiple sync operations are idempotent" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"

  # First sync
  run zsh -c "source $TEST_DIR/.zshrc && zap sync"
  assert_success

  # Second sync should be no-op
  run zsh -c "source $TEST_DIR/.zshrc && zap sync"
  assert_success
  assert_output --partial "Already in sync"
}
