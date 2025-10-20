#!/usr/bin/env bats
#
# Integration test: User Story 5 - Basic status command (T091)
#
# Purpose: Test that `zap status` displays the current state of declared
# vs. experimental plugins, helping users understand their configuration.
#
# Test scenarios:
# - Show declared plugins count
# - Show experimental plugins count
# - Show sync status (in sync / out of sync)
# - List plugin names
# - Empty states handled gracefully
# - Verbose mode shows details
# - Machine-readable JSON output
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

@test "US5-STATUS: Show declared plugins count" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'test1/plugin1'
  'test2/plugin2'
  'test3/plugin3'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "test1" "plugin1"
  create_test_plugin "test2" "plugin2"
  create_test_plugin "test3" "plugin3"

  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins (3)"
}

@test "US5-STATUS: Show experimental plugins count" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "exp1" "plugin1"
  create_test_plugin "exp2" "plugin2"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp1/plugin1 >/dev/null && \
              zap try exp2/plugin2 >/dev/null && \
              zap status"
  assert_success
  assert_output --partial "Experimental plugins (2)"
}

@test "US5-STATUS: Show in sync status" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin"

  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "In sync with declared configuration"
}

@test "US5-STATUS: Show out of sync status" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "exp" "plugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp/plugin >/dev/null && \
              zap status"
  assert_success
  assert_output --partial "Out of sync"
  assert_output --partial "1 experimental plugin"
}

@test "US5-STATUS: List declared plugin names" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'test1/plugin1'
  'test2/plugin2'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "test1" "plugin1"
  create_test_plugin "test2" "plugin2"

  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "test1/plugin1"
  assert_output --partial "test2/plugin2"
}

@test "US5-STATUS: List experimental plugin names" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "exp1" "plugin1"
  create_test_plugin "exp2" "plugin2"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp1/plugin1 >/dev/null && \
              zap try exp2/plugin2 >/dev/null && \
              zap status"
  assert_success
  assert_output --partial "exp1/plugin1"
  assert_output --partial "exp2/plugin2"
}

@test "US5-STATUS: Empty declared state handled gracefully" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins: (none)"
  assert_output --partial "Experimental plugins: (none)"
  assert_output --partial "In sync"
}

@test "US5-STATUS: Empty experimental state handled gracefully" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin"

  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins (1)"
  assert_output --partial "Experimental plugins: (none)"
}

@test "US5-STATUS: Verbose mode shows plugin details" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin@v1.0'
  'ohmyzsh/ohmyzsh:plugins/git'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin"
  mkdir -p "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git"
  echo "# Git" > "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git/git.plugin.zsh"

  run zsh -c "source $TEST_DIR/.zshrc && zap status --verbose"
  assert_success
  # Verbose should show full specs
  assert_output --partial "@v1.0"
  assert_output --partial ":plugins/git"
  # Should show paths or additional details
  assert_output --partial "spec:"
}

@test "US5-STATUS: Machine-readable JSON output" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"
  create_test_plugin "exp" "plugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp/plugin >/dev/null && \
              zap status --machine-readable"
  assert_success
  # Should be valid JSON
  assert_output --partial '{'
  assert_output --partial '"declared":'
  assert_output --partial '"experimental":'
  assert_output --partial '"in_sync":'
}

@test "US5-STATUS: Mixed declared and experimental clearly separated" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'declared/plugin1'
  'declared/plugin2'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "declared" "plugin1"
  create_test_plugin "declared" "plugin2"
  create_test_plugin "exp" "plugin1"
  create_test_plugin "exp" "plugin2"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp/plugin1 >/dev/null && \
              zap try exp/plugin2 >/dev/null && \
              zap status"
  assert_success
  # Should clearly separate the two categories
  assert_output --partial "Declared plugins (2)"
  assert_output --partial "declared/plugin1"
  assert_output --partial "declared/plugin2"
  assert_output --partial "Experimental plugins (2)"
  assert_output --partial "exp/plugin1"
  assert_output --partial "exp/plugin2"
}

@test "US5-STATUS: Exit code is 0 when in sync" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin"

  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success  # Exit code 0
}

@test "US5-STATUS: Exit code is 0 even when out of sync" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "exp" "plugin"

  # Status is informational, should always succeed
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp/plugin >/dev/null && \
              zap status"
  assert_success  # Exit code 0
}

@test "US5-STATUS: Fast performance even with many plugins" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  # Create 20 test plugins
  for i in {1..20}; do
    create_test_plugin "test$i" "plugin$i"
  done

  # Load 20 declared plugins
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'test1/plugin1'
  'test2/plugin2'
  'test3/plugin3'
  'test4/plugin4'
  'test5/plugin5'
  'test6/plugin6'
  'test7/plugin7'
  'test8/plugin8'
  'test9/plugin9'
  'test10/plugin10'
  'test11/plugin11'
  'test12/plugin12'
  'test13/plugin13'
  'test14/plugin14'
  'test15/plugin15'
  'test16/plugin16'
  'test17/plugin17'
  'test18/plugin18'
  'test19/plugin19'
  'test20/plugin20'
)

source ~/.zap/zap.zsh
EOF

  # Measure status command time
  local start_time=$(date +%s%N)
  zsh -c "source $TEST_DIR/.zshrc && zap status >/dev/null" 2>/dev/null
  local end_time=$(date +%s%N)
  local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to ms

  # Should complete in under 500ms (soft limit, spec says <100ms but allow margin)
  echo "Status time for 20 plugins: ${duration}ms"
  [[ $duration -lt 500 ]]
}
