#!/usr/bin/env bats
#
# Integration test: User Story 3 - No-op when in sync (T054)
#
# Purpose: Test that `zap sync` is a no-op when the runtime state already
# matches the declared configuration. This validates idempotency.
#
# Test scenarios:
# - Sync with no experimental plugins
# - Multiple sync calls in succession
# - Sync after fresh shell start
# - Sync with only declared plugins loaded
# - Clear messaging for no-op case
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

@test "US3-NOOP: Sync with no experimental plugins is no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"

  run zsh -c "source $TEST_DIR/.zshrc && zap sync"
  assert_success
  assert_output --partial "Already in sync"
}

@test "US3-NOOP: Multiple sync calls are idempotent" {
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
  assert_output --partial "Already in sync"

  # Second sync
  run zsh -c "source $TEST_DIR/.zshrc && zap sync"
  assert_success
  assert_output --partial "Already in sync"

  # Third sync
  run zsh -c "source $TEST_DIR/.zshrc && zap sync"
  assert_success
  assert_output --partial "Already in sync"
}

@test "US3-NOOP: Sync after fresh shell start" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin2'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"
  create_test_plugin "testuser" "plugin2"

  # Fresh shell, then sync
  run zsh -c "source $TEST_DIR/.zshrc && zap sync"
  assert_success
  assert_output --partial "Already in sync"
}

@test "US3-NOOP: Sync with empty config and no experimental" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap sync"
  assert_success
  assert_output --partial "Already in sync"
}

@test "US3-NOOP: Clear message explains no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"

  run zsh -c "source $TEST_DIR/.zshrc && zap sync"
  assert_success
  assert_output --partial "Already in sync"
  assert_output --partial "no experimental plugins"
}

@test "US3-NOOP: Sync shows declared plugins in verbose mode" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin2'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"
  create_test_plugin "testuser" "plugin2"

  run zsh -c "source $TEST_DIR/.zshrc && zap sync --verbose"
  assert_success
  assert_output --partial "Already in sync"
  # Verbose should show declared plugins
  assert_output --partial "Declared plugins (2)"
  assert_output --partial "testuser/plugin1"
  assert_output --partial "testuser/plugin2"
}

@test "US3-NOOP: Exit code is 0 for no-op sync" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap sync"
  assert_success  # Exit code 0
}

@test "US3-NOOP: Dry-run also shows no changes needed" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"

  run zsh -c "source $TEST_DIR/.zshrc && zap sync --dry-run"
  assert_success
  assert_output --partial "Already in sync"
}

@test "US3-NOOP: Status confirms in-sync state" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"

  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "In sync with declared configuration"
  assert_output --partial "Experimental plugins: (none)"
}
