#!/usr/bin/env bats
#
# Integration test: User Story 4 - Adopt error handling (T073)
#
# Purpose: Test that `zap adopt` provides clear error messages when trying
# to adopt a plugin that is not currently loaded as experimental.
#
# Test scenarios:
# - Error when plugin not loaded
# - Error when plugin never tried
# - Clear guidance to use 'zap try' first
# - Exit code is non-zero on error
# - No config modification on error
# - No backup created on error
# - Helpful error message format
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

@test "US4-ERROR: Error when plugin not loaded" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  # Try to adopt without trying first
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --yes testuser/testplugin"
  assert_failure
  assert_output --partial "not currently loaded"
}

@test "US4-ERROR: Error when plugin never tried" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  # Plugin doesn't even exist
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --yes nonexistent/plugin"
  assert_failure
  assert_output --partial "not currently loaded"
}

@test "US4-ERROR: Clear guidance to use 'zap try' first" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --yes testuser/testplugin"
  assert_failure
  assert_output --partial "zap try"
  assert_output --partial "testuser/testplugin"
}

@test "US4-ERROR: Exit code is non-zero on error" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --yes testuser/testplugin"
  assert_failure  # Exit code != 0
  [[ $status -ne 0 ]]
}

@test "US4-ERROR: No config modification on error" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
# My config
plugins=(
  'existing/plugin'
)

source ~/.zap/zap.zsh
EOF

  local original_content=$(cat "$TEST_DIR/.zshrc")

  create_test_plugin "testuser" "testplugin"

  # Try to adopt without loading first
  zsh -c "source $TEST_DIR/.zshrc && \
          zap adopt --yes testuser/testplugin" 2>/dev/null || true

  # Config should be unchanged
  local new_content=$(cat "$TEST_DIR/.zshrc")
  [[ "$original_content" == "$new_content" ]]
}

@test "US4-ERROR: No backup created on error" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  # Try to adopt without loading first
  zsh -c "source $TEST_DIR/.zshrc && \
          zap adopt --yes testuser/testplugin" 2>/dev/null || true

  # No backup should exist
  run ls "$TEST_DIR/.zshrc.backup"*
  assert_failure
}

@test "US4-ERROR: Helpful error message format" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --yes testuser/testplugin"
  assert_failure
  # Should include plugin name
  assert_output --partial "testuser/testplugin"
  # Should explain the issue
  assert_output --partial "not currently loaded"
  # Should suggest action
  assert_output --partial "zap try"
}

@test "US4-ERROR: Error on partial match (wrong version pin)" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  # Try with v1.0
  zsh -c "source $TEST_DIR/.zshrc && \
          zap try testuser/testplugin@v1.0 >/dev/null" 2>/dev/null

  # Try to adopt with different version
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/testplugin@v1.0 >/dev/null && \
              zap adopt --yes testuser/testplugin@v2.0"
  assert_failure
  assert_output --partial "not currently loaded"
}

@test "US4-ERROR: Multiple errors show all failures" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "test1" "plugin1"
  create_test_plugin "test2" "plugin2"

  # Try plugin1 but not plugin2
  zsh -c "source $TEST_DIR/.zshrc && \
          zap try test1/plugin1 >/dev/null" 2>/dev/null

  # Try to adopt both with --all (or individually)
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try test1/plugin1 >/dev/null && \
              zap adopt --yes test2/plugin2"
  assert_failure
  assert_output --partial "test2/plugin2"
  assert_output --partial "not currently loaded"
}

@test "US4-ERROR: Verbose mode provides additional context" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --yes --verbose testuser/testplugin"
  assert_failure
  assert_output --partial "not currently loaded"
  # Verbose should show what IS loaded (experimental plugins list)
  assert_output --partial "Experimental plugins"
}

@test "US4-ERROR: Dry-run also shows error" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --dry-run testuser/testplugin"
  assert_failure
  assert_output --partial "not currently loaded"
}
