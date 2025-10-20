#!/usr/bin/env bats
#
# Integration test: User Story 2 - Ephemeral behavior (T037)
#
# Purpose: Test that experimental plugins do NOT persist across shell sessions.
# This is a critical requirement - experimental state must be ephemeral.
#
# Test scenarios:
# - Experimental plugin not reloaded on new shell
# - State file doesn't persist experimental plugins
# - Shell restart shows only declared plugins
# - Multiple sessions don't interfere
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

@test "US2-EPH: Experimental plugin NOT reloaded on new shell" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "explugin"

  # Session 1: Try plugin
  run zsh -c "source $TEST_DIR/.zshrc && zap try testuser/explugin >/dev/null && zap status"
  assert_success
  assert_output --partial "Experimental plugins (1)"

  # Session 2: New shell should NOT have experimental plugin
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Experimental plugins: (none)"
  assert_output --partial "In sync"
}

@test "US2-EPH: Declared plugins persist, experimental do not" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/declared'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "declared"
  create_test_plugin "testuser" "experimental"

  # Session 1: Load declared + try experimental
  run zsh -c "source $TEST_DIR/.zshrc && zap try testuser/experimental >/dev/null && zap status"
  assert_success
  assert_output --partial "Declared plugins (1)"
  assert_output --partial "Experimental plugins (1)"

  # Session 2: Only declared should remain
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins (1)"
  assert_output --partial "testuser/declared"
  # Experimental should be gone
  run zsh -c "source $TEST_DIR/.zshrc && zap status | grep -c experimental"
  assert_failure  # grep should fail (not found)
}

@test "US2-EPH: State file reflects ephemeral nature" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "explugin"

  # Try plugin in one session
  zsh -c "source $TEST_DIR/.zshrc && zap try testuser/explugin >/dev/null" 2>/dev/null

  # Check state file doesn't persist experimental across restart
  # New shell initialization should clear experimental state
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Experimental plugins: (none)"
}

@test "US2-EPH: Multiple experimental plugins all ephemeral" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  # Create multiple test plugins
  for i in {1..5}; do
    create_test_plugin "test$i" "plugin$i"
  done

  # Session 1: Try all plugins
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try test1/plugin1 >/dev/null && \
              zap try test2/plugin2 >/dev/null && \
              zap try test3/plugin3 >/dev/null && \
              zap try test4/plugin4 >/dev/null && \
              zap try test5/plugin5 >/dev/null && \
              zap status"
  assert_success
  assert_output --partial "Experimental plugins (5)"

  # Session 2: All should be gone
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Experimental plugins: (none)"
}

@test "US2-EPH: Experimental state cleared on zap sync" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/declared'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "declared"
  create_test_plugin "testuser" "explugin"

  # Try experimental plugin
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/explugin >/dev/null && \
              zap status"
  assert_success
  assert_output --partial "Experimental plugins (1)"

  # Sync should remove experimental
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/explugin >/dev/null && \
              zap sync 2>&1"
  # Note: sync does exec zsh, so this test verifies the sync command runs
  assert_success
  assert_output --partial "Synchronizing to declared state"
}

@test "US2-EPH: Concurrent sessions don't interfere" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "test1" "plugin1"
  create_test_plugin "test2" "plugin2"

  # Session A tries plugin1
  zsh -c "source $TEST_DIR/.zshrc && zap try test1/plugin1 >/dev/null" 2>/dev/null &
  local pid1=$!

  # Session B tries plugin2
  zsh -c "source $TEST_DIR/.zshrc && zap try test2/plugin2 >/dev/null" 2>/dev/null &
  local pid2=$!

  wait $pid1
  wait $pid2

  # Fresh session C should see neither
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Experimental plugins: (none)"
}

@test "US2-EPH: Ephemeral state message is clear" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  run zsh -c "source $TEST_DIR/.zshrc && zap try testuser/testplugin"

  assert_success
  # Should clearly indicate ephemeral nature
  assert_output --partial "will NOT be reloaded on shell restart"
  assert_output --partial "To make it permanent"
}
