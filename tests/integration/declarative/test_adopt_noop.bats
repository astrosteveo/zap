#!/usr/bin/env bats
#
# Integration test: User Story 4 - Adopt no-op (T072)
#
# Purpose: Test that `zap adopt` is a no-op when trying to adopt a plugin
# that is already declared in the plugins=() array.
#
# Test scenarios:
# - Adopt on already-declared plugin is no-op
# - Clear message explains no-op
# - No backup created for no-op
# - No config modification for no-op
# - Exit code is 0 for no-op
# - Dry-run also shows no-op
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

@test "US4-NOOP: Adopt on already-declared plugin is no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/testplugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --yes testuser/testplugin"
  assert_success
  assert_output --partial "already declared"
}

@test "US4-NOOP: Clear message explains no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin1'
  'testuser/plugin2'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin1"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --yes testuser/plugin1"
  assert_success
  assert_output --partial "testuser/plugin1"
  assert_output --partial "already declared"
  assert_output --partial "Nothing to do"
}

@test "US4-NOOP: No backup created for no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/testplugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  zsh -c "source $TEST_DIR/.zshrc && \
          zap adopt --yes testuser/testplugin" 2>/dev/null

  # No backup should exist
  run ls "$TEST_DIR/.zshrc.backup"*
  assert_failure
}

@test "US4-NOOP: No config modification for no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
# My config
plugins=(
  'testuser/testplugin'
)

# Important comment
source ~/.zap/zap.zsh
EOF

  local original_content=$(cat "$TEST_DIR/.zshrc")

  create_test_plugin "testuser" "testplugin"

  zsh -c "source $TEST_DIR/.zshrc && \
          zap adopt --yes testuser/testplugin" 2>/dev/null

  # Config should be unchanged
  local new_content=$(cat "$TEST_DIR/.zshrc")
  [[ "$original_content" == "$new_content" ]]
}

@test "US4-NOOP: Exit code is 0 for no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/testplugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --yes testuser/testplugin"
  assert_success  # Exit code 0
}

@test "US4-NOOP: Dry-run also shows no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/testplugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --dry-run testuser/testplugin"
  assert_success
  assert_output --partial "already declared"
  assert_output --partial "Nothing to do"
}

@test "US4-NOOP: Multiple declared plugins all show no-op" {
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

  # Try to adopt all three
  for plugin in test1/plugin1 test2/plugin2 test3/plugin3; do
    run zsh -c "source $TEST_DIR/.zshrc && \
                zap adopt --yes $plugin"
    assert_success
    assert_output --partial "already declared"
  done

  # No backups should exist
  run ls "$TEST_DIR/.zshrc.backup"*
  assert_failure
}

@test "US4-NOOP: Version-pinned already-declared plugin is no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/testplugin@v1.0'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --yes testuser/testplugin@v1.0"
  assert_success
  assert_output --partial "already declared"
}

@test "US4-NOOP: Subdirectory already-declared plugin is no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'ohmyzsh/ohmyzsh:plugins/git'
)

source ~/.zap/zap.zsh
EOF

  mkdir -p "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git"
  echo "# Git plugin" > "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git/git.plugin.zsh"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --yes ohmyzsh/ohmyzsh:plugins/git"
  assert_success
  assert_output --partial "already declared"
}

@test "US4-NOOP: Verbose mode shows declared status" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/testplugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --yes --verbose testuser/testplugin"
  assert_success
  assert_output --partial "already declared"
  assert_output --partial "plugins=("
}
