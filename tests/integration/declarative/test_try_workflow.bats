#!/usr/bin/env bats
#
# Integration test: User Story 2 - Experimental plugin loading (T036)
#
# Purpose: Test the `zap try` command for temporary/experimental plugin loading.
# Plugins loaded with `zap try` should be ephemeral and not persist across sessions.
#
# Test scenarios:
# - Basic zap try command
# - Try already-declared plugin (should be no-op)
# - Try already-experimental plugin (should be no-op)
# - Try with --verbose flag
# - Multiple experimental plugins
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

@test "US2-TRY: zap try loads plugin experimentally" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  # Create test plugin
  create_test_plugin "testuser" "testplugin"

  # Try the plugin
  run zsh -c "source $TEST_DIR/.zshrc && zap try testuser/testplugin"

  assert_success
  assert_output --partial "Loaded testuser/testplugin experimentally"
  assert_output --partial "will NOT be reloaded on shell restart"
}

@test "US2-TRY: Experimental plugin shows in status" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  # Try plugin and check status
  run zsh -c "source $TEST_DIR/.zshrc && zap try testuser/testplugin >/dev/null && zap status"

  assert_success
  assert_output --partial "Experimental plugins (1)"
  assert_output --partial "testuser/testplugin"
}

@test "US2-TRY: Try already-declared plugin is no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/declaredplugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "declaredplugin"

  # Try to load as experimental (should recognize it's already declared)
  run zsh -c "source $TEST_DIR/.zshrc && zap try testuser/declaredplugin"

  assert_success
  assert_output --partial "already declared in your configuration"
}

@test "US2-TRY: Try already-experimental plugin is no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  # Try same plugin twice
  run zsh -c "source $TEST_DIR/.zshrc && zap try testuser/testplugin >/dev/null && zap try testuser/testplugin"

  assert_success
  assert_output --partial "already loaded experimentally"
}

@test "US2-TRY: Try with --verbose shows detailed output" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  run zsh -c "source $TEST_DIR/.zshrc && zap try --verbose testuser/testplugin"

  assert_success
  assert_output --partial "[Verbose]"
  assert_output --partial "Validating plugin specification"
  assert_output --partial "Loaded testuser/testplugin experimentally"
}

@test "US2-TRY: Multiple experimental plugins can coexist" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  # Create multiple test plugins
  create_test_plugin "test1" "plugin1"
  create_test_plugin "test2" "plugin2"
  create_test_plugin "test3" "plugin3"

  # Try all three
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try test1/plugin1 >/dev/null && \
              zap try test2/plugin2 >/dev/null && \
              zap try test3/plugin3 >/dev/null && \
              zap status"

  assert_success
  assert_output --partial "Experimental plugins (3)"
  assert_output --partial "test1/plugin1"
  assert_output --partial "test2/plugin2"
  assert_output --partial "test3/plugin3"
}

@test "US2-TRY: Try with version pin works" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  run zsh -c "source $TEST_DIR/.zshrc && zap try testuser/testplugin@main"

  assert_success
  assert_output --partial "Loaded testuser/testplugin experimentally"
}

@test "US2-TRY: Try with subdirectory works" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  # Create plugin with subdirectory structure
  mkdir -p "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git"
  echo "# Test Oh-My-Zsh git plugin" > "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git/git.plugin.zsh"

  run zsh -c "source $TEST_DIR/.zshrc && zap try ohmyzsh/ohmyzsh:plugins/git"

  assert_success
  assert_output --partial "Loaded ohmyzsh/ohmyzsh experimentally"
}

@test "US2-TRY: Invalid plugin spec shows error" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  # Try invalid specification
  run zsh -c "source $TEST_DIR/.zshrc && zap try '../etc/passwd'"

  assert_failure
  assert_output --partial "Invalid plugin specification"
}

@test "US2-TRY: Try provides usage help when no args" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap try"

  assert_failure
  assert_output --partial "Usage: zap try"
  assert_output --partial "Examples:"
}
