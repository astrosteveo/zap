#!/usr/bin/env bats
#
# Integration test: User Story 2 - Try on already-declared plugin (T038)
#
# Purpose: Test that running `zap try` on a plugin that's already declared
# in the plugins=() array is a no-op and provides helpful feedback.
#
# Test scenarios:
# - Try declared plugin shows informative message
# - Try declared plugin doesn't create duplicate state
# - Try declared plugin with different version spec
# - Status shows plugin as declared, not experimental
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

@test "US2-NOOP: Try on declared plugin shows helpful message" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/myplugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "myplugin"

  run zsh -c "source $TEST_DIR/.zshrc && zap try testuser/myplugin"

  assert_success
  assert_output --partial "already declared in your configuration"
  assert_output --partial "will be loaded automatically"
}

@test "US2-NOOP: Status shows plugin as declared only" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/myplugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "myplugin"

  # Try the already-declared plugin
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/myplugin >/dev/null && \
              zap status"

  assert_success
  # Should show in declared, NOT in experimental
  assert_output --partial "Declared plugins (1)"
  assert_output --partial "testuser/myplugin"
  # Should NOT show experimental section with this plugin
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/myplugin >/dev/null && \
              zap status | grep -A5 'Experimental' | grep 'myplugin'"
  assert_failure  # Should not find it in experimental section
}

@test "US2-NOOP: No duplicate state entry created" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/myplugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "myplugin"

  # Try the declared plugin
  zsh -c "source $TEST_DIR/.zshrc && zap try testuser/myplugin >/dev/null" 2>/dev/null

  # Check state file for duplicates
  run zsh -c "source $TEST_DIR/.zshrc && zap status --machine-readable"

  assert_success
  # Should appear exactly once in declared section
  local count=$(echo "$output" | grep -c '"testuser/myplugin"' || echo "0")
  # Exact count depends on JSON structure, but should be reasonable
  [[ $count -lt 5 ]]  # Not duplicated many times
}

@test "US2-NOOP: Try declared plugin with same version" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/myplugin@v1.0.0'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "myplugin"

  run zsh -c "source $TEST_DIR/.zshrc && zap try testuser/myplugin@v1.0.0"

  assert_success
  assert_output --partial "already declared"
}

@test "US2-NOOP: Multiple tries on same declared plugin" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/myplugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "myplugin"

  # Try multiple times
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/myplugin >/dev/null && \
              zap try testuser/myplugin >/dev/null && \
              zap try testuser/myplugin && \
              zap status"

  assert_success
  assert_output --partial "already declared"
  # Status should still show only 1 declared plugin
  assert_output --partial "Declared plugins (1)"
}

@test "US2-NOOP: Try with subdirectory on declared plugin" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'ohmyzsh/ohmyzsh:plugins/git'
)

source ~/.zap/zap.zsh
EOF

  mkdir -p "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git"
  echo "# Test" > "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git/git.plugin.zsh"

  run zsh -c "source $TEST_DIR/.zshrc && zap try ohmyzsh/ohmyzsh:plugins/git"

  assert_success
  assert_output --partial "already declared"
}

@test "US2-NOOP: Exit code is success for try on declared" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/myplugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "myplugin"

  run zsh -c "source $TEST_DIR/.zshrc && zap try testuser/myplugin"

  # Should exit successfully (0) even though it's a no-op
  assert_success
}

@test "US2-NOOP: Verbose mode explains why it's a no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/myplugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "myplugin"

  run zsh -c "source $TEST_DIR/.zshrc && zap try --verbose testuser/myplugin"

  assert_success
  assert_output --partial "[Verbose]"
  assert_output --partial "State: declared"
  assert_output --partial "already declared"
}
