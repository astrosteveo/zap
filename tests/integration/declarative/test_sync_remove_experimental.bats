#!/usr/bin/env bats
#
# Integration test: User Story 3 - Experimental plugin removal (T051)
#
# Purpose: Test that `zap sync` removes experimental plugins and returns
# the shell to the exact state defined in the plugins=() array.
#
# Test scenarios:
# - Remove single experimental plugin
# - Remove multiple experimental plugins
# - Keep declared plugins, remove experimental
# - Sync with no experimental plugins (no-op)
# - Sync provides preview before reload
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

@test "US3-SYNC: Remove single experimental plugin" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "explugin"

  # Load experimental plugin
  zsh -c "source $TEST_DIR/.zshrc && zap try testuser/explugin >/dev/null" 2>/dev/null

  # Check it's loaded
  run zsh -c "source $TEST_DIR/.zshrc && zap try testuser/explugin >/dev/null && zap status"
  assert_success
  assert_output --partial "Experimental plugins (1)"

  # Sync should show what will be removed
  run zsh -c "source $TEST_DIR/.zshrc && zap try testuser/explugin >/dev/null && zap sync --dry-run"
  assert_success
  assert_output --partial "testuser/explugin"
  assert_output --partial "Would remove 1 experimental plugin"
}

@test "US3-SYNC: Remove multiple experimental plugins" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  # Create test plugins
  for i in {1..3}; do
    create_test_plugin "test$i" "plugin$i"
  done

  # Load multiple experimental plugins
  zsh -c "source $TEST_DIR/.zshrc && \
          zap try test1/plugin1 >/dev/null && \
          zap try test2/plugin2 >/dev/null && \
          zap try test3/plugin3 >/dev/null" 2>/dev/null

  # Sync preview should show all 3
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try test1/plugin1 >/dev/null && \
              zap try test2/plugin2 >/dev/null && \
              zap try test3/plugin3 >/dev/null && \
              zap sync --dry-run"
  assert_success
  assert_output --partial "test1/plugin1"
  assert_output --partial "test2/plugin2"
  assert_output --partial "test3/plugin3"
}

@test "US3-SYNC: Keep declared, remove experimental" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/declared1'
  'testuser/declared2'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "declared1"
  create_test_plugin "testuser" "declared2"
  create_test_plugin "testuser" "experimental1"

  # Load declared + experimental
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/experimental1 >/dev/null && \
              zap status"
  assert_success
  assert_output --partial "Declared plugins (2)"
  assert_output --partial "Experimental plugins (1)"

  # Sync should only remove experimental
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/experimental1 >/dev/null && \
              zap sync --dry-run"
  assert_success
  assert_output --partial "testuser/experimental1"
  # Should NOT mention declared plugins in removal list
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/experimental1 >/dev/null && \
              zap sync --dry-run | grep -E 'declared[12]'"
  assert_failure  # Should not find declared plugins in output
}

@test "US3-SYNC: No-op when no experimental plugins" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"

  # Sync with no experimental plugins
  run zsh -c "source $TEST_DIR/.zshrc && zap sync"
  assert_success
  assert_output --partial "Already in sync"
}

@test "US3-SYNC: Preview shows what will be removed" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "explugin"

  # Sync preview with --dry-run
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/explugin >/dev/null && \
              zap sync --dry-run"
  assert_success
  assert_output --partial "Experimental plugins to be removed"
  assert_output --partial "testuser/explugin"
  assert_output --partial "[DRY RUN]"
  assert_output --partial "Would remove"
}

@test "US3-SYNC: Verbose mode shows detailed removal info" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "explugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/explugin >/dev/null && \
              zap sync --verbose --dry-run"
  assert_success
  assert_output --partial "[Verbose]"
  assert_output --partial "testuser/explugin"
  assert_output --partial "spec:"
}

@test "US3-SYNC: Empty config removes all experimental" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  # Create and load multiple experimental plugins
  for i in {1..5}; do
    create_test_plugin "test$i" "plugin$i"
  done

  # Sync should remove all
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try test1/plugin1 >/dev/null && \
              zap try test2/plugin2 >/dev/null && \
              zap try test3/plugin3 >/dev/null && \
              zap try test4/plugin4 >/dev/null && \
              zap try test5/plugin5 >/dev/null && \
              zap sync --dry-run"
  assert_success
  assert_output --partial "Would remove 5 experimental plugin"
}
