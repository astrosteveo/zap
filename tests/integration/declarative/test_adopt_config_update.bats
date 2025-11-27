#!/usr/bin/env bats
#
# Integration test: User Story 4 - Config file modification (T070)
#
# Purpose: Test that `zap adopt` correctly modifies the .zshrc file to add
# experimental plugins to the plugins=() array.
#
# Test scenarios:
# - Adopt single experimental plugin
# - Plugin appears in config file
# - Array formatting preserved
# - Multiple adopts
# - Adopt with version pin
# - Adopt with subdirectory
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

@test "US4-ADOPT: Single experimental plugin adopted to config" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  # Try and adopt
  zsh -c "source $TEST_DIR/.zshrc && \
          zap try testuser/testplugin >/dev/null && \
          zap adopt --yes testuser/testplugin" 2>/dev/null

  # Check config file was updated
  run grep "testuser/testplugin" "$TEST_DIR/.zshrc"
  assert_success
}

@test "US4-ADOPT: Plugin appears in plugins array" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  zsh -c "source $TEST_DIR/.zshrc && \
          zap try testuser/testplugin >/dev/null && \
          zap adopt --yes testuser/testplugin" 2>/dev/null

  # Verify it's inside the plugins array
  run cat "$TEST_DIR/.zshrc"
  assert_success
  assert_output --partial "plugins=("
  assert_output --partial "testuser/testplugin"
  assert_output --partial ")"
}

@test "US4-ADOPT: Array formatting preserved" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
# My zsh config
plugins=(
  'existing/plugin1'
  'existing/plugin2'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "newplugin"

  zsh -c "source $TEST_DIR/.zshrc && \
          zap try testuser/newplugin >/dev/null && \
          zap adopt --yes testuser/newplugin" 2>/dev/null

  # Check formatting is maintained
  run cat "$TEST_DIR/.zshrc"
  assert_success
  assert_output --partial "# My zsh config"
  assert_output --partial "plugins=("
  assert_output --partial "testuser/newplugin"
}

@test "US4-ADOPT: Multiple sequential adopts" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "test1" "plugin1"
  create_test_plugin "test2" "plugin2"
  create_test_plugin "test3" "plugin3"

  # Adopt each one
  zsh -c "source $TEST_DIR/.zshrc && \
          zap try test1/plugin1 >/dev/null && \
          zap adopt --yes test1/plugin1" 2>/dev/null

  zsh -c "source $TEST_DIR/.zshrc && \
          zap try test2/plugin2 >/dev/null && \
          zap adopt --yes test2/plugin2" 2>/dev/null

  zsh -c "source $TEST_DIR/.zshrc && \
          zap try test3/plugin3 >/dev/null && \
          zap adopt --yes test3/plugin3" 2>/dev/null

  # All three should be in config
  run cat "$TEST_DIR/.zshrc"
  assert_success
  assert_output --partial "test1/plugin1"
  assert_output --partial "test2/plugin2"
  assert_output --partial "test3/plugin3"
}

@test "US4-ADOPT: Adopt with version pin preserves spec" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  zsh -c "source $TEST_DIR/.zshrc && \
          zap try testuser/testplugin@v1.0 >/dev/null && \
          zap adopt --yes testuser/testplugin@v1.0" 2>/dev/null

  # Version pin should be preserved
  run grep "@v1.0" "$TEST_DIR/.zshrc"
  assert_success
}

@test "US4-ADOPT: Adopt with subdirectory preserves spec" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  mkdir -p "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git"
  echo "# Test" > "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git/git.plugin.zsh"

  zsh -c "source $TEST_DIR/.zshrc && \
          zap try ohmyzsh/ohmyzsh:plugins/git >/dev/null && \
          zap adopt --yes ohmyzsh/ohmyzsh:plugins/git" 2>/dev/null

  # Subdirectory should be preserved
  run grep ":plugins/git" "$TEST_DIR/.zshrc"
  assert_success
}

@test "US4-ADOPT: Adopt creates array if missing" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
# Config without plugins array

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  zsh -c "source $TEST_DIR/.zshrc && \
          zap try testuser/testplugin >/dev/null && \
          zap adopt --yes testuser/testplugin" 2>/dev/null

  # Should create plugins array
  run grep "plugins=(" "$TEST_DIR/.zshrc"
  assert_success
  run grep "testuser/testplugin" "$TEST_DIR/.zshrc"
  assert_success
}

@test "US4-ADOPT: Adopted plugin shows as declared" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  # Try, adopt, check status
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/testplugin >/dev/null && \
              zap adopt --yes testuser/testplugin >/dev/null && \
              source $TEST_DIR/.zshrc && \
              zap status"
  assert_success
  # After reload, should be declared
  assert_output --partial "Declared plugins"
}
