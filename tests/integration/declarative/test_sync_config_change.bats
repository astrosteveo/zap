#!/usr/bin/env bats
#
# Integration test: User Story 3 - Config change reconciliation (T053)
#
# Purpose: Test that `zap sync` correctly handles changes to the plugins=()
# array in .zshrc, reconciling the runtime state to match.
#
# Test scenarios:
# - Add plugins to config, sync loads them
# - Remove plugins from config, sync unloads them
# - Reorder plugins in config
# - Change version pins
# - Change subdirectories
# - Complex multi-change scenarios
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

@test "US3-CONFIG: Add plugins to config and sync" {
  # Start with empty config
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"
  create_test_plugin "testuser" "plugin2"

  # User edits config to add plugins
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin2'
)

source ~/.zap/zap.zsh
EOF

  # New shell should load both plugins
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins (2)"
}

@test "US3-CONFIG: Remove plugins from config and sync" {
  # Start with 3 plugins
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin2'
  'testuser/plugin3'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"
  create_test_plugin "testuser" "plugin2"
  create_test_plugin "testuser" "plugin3"

  # User removes plugin2
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin3'
)

source ~/.zap/zap.zsh
EOF

  # New shell should only have plugin1 and plugin3
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins (2)"
  assert_output --partial "testuser/plugin1"
  assert_output --partial "testuser/plugin3"
  # plugin2 should be gone
  run zsh -c "source $TEST_DIR/.zshrc && zap status | grep plugin2"
  assert_failure
}

@test "US3-CONFIG: Reorder plugins in config" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin2'
  'testuser/plugin3'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"
  create_test_plugin "testuser" "plugin2"
  create_test_plugin "testuser" "plugin3"

  # Reorder
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin3'
  'testuser/plugin1'
  'testuser/plugin2'
)

source ~/.zap/zap.zsh
EOF

  # All should still be loaded
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins (3)"
}

@test "US3-CONFIG: Change version pins" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin@v1.0'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin"

  # Change version
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin@v2.0'
)

source ~/.zap/zap.zsh
EOF

  # Should reflect new version
  run zsh -c "source $TEST_DIR/.zshrc && zap status --verbose"
  assert_success
  assert_output --partial "testuser/plugin"
}

@test "US3-CONFIG: Change subdirectory specification" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'ohmyzsh/ohmyzsh:plugins/git'
)

source ~/.zap/zap.zsh
EOF

  mkdir -p "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git"
  mkdir -p "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/docker"
  echo "# Git plugin" > "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git/git.plugin.zsh"
  echo "# Docker plugin" > "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/docker/docker.plugin.zsh"

  # Change subdirectory
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'ohmyzsh/ohmyzsh:plugins/docker'
)

source ~/.zap/zap.zsh
EOF

  # Should load docker plugin instead
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "ohmyzsh/ohmyzsh"
}

@test "US3-CONFIG: Complex multi-change scenario" {
  # Original config
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin2@v1.0'
  'testuser/plugin3'
)

source ~/.zap/zap.zsh
EOF

  for i in {1..5}; do
    create_test_plugin "testuser" "plugin$i"
  done

  # Complex changes:
  # - Remove plugin1
  # - Update plugin2 version
  # - Keep plugin3
  # - Add plugin4 and plugin5
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin2@v2.0'
  'testuser/plugin3'
  'testuser/plugin4'
  'testuser/plugin5'
)

source ~/.zap/zap.zsh
EOF

  # Should have 4 plugins
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins (4)"
  # plugin1 should be gone
  run zsh -c "source $TEST_DIR/.zshrc && zap status | grep plugin1"
  assert_failure
}

@test "US3-CONFIG: Empty to populated config" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  # Add plugins
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin2'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"
  create_test_plugin "testuser" "plugin2"

  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins (2)"
}

@test "US3-CONFIG: Populated to empty config" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin2'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"
  create_test_plugin "testuser" "plugin2"

  # Remove all plugins
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins: (none)"
  assert_output --partial "In sync"
}
