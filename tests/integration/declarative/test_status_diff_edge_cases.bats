#!/usr/bin/env bats
#
# Integration test: User Story 5 - Status/diff edge cases (T093)
#
# Purpose: Test edge cases for status and diff commands including
# version mismatches, subdirectory handling, and complex scenarios.
#
# Test scenarios:
# - Version pin differences
# - Subdirectory specification differences
# - Mixed declared and experimental with same base repo
# - Large plugin counts
# - Special characters in plugin names
# - Corrupted state handling
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

@test "US5-EDGE: Same plugin with different version pins" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin@v1.0'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin"

  # Try with different version
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/plugin@v2.0 >/dev/null && \
              zap status"
  assert_success
  # Should show both versions
  assert_output --partial "@v1.0"
  assert_output --partial "@v2.0"
}

@test "US5-EDGE: Same repo with different subdirectories" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'ohmyzsh/ohmyzsh:plugins/git'
)

source ~/.zap/zap.zsh
EOF

  mkdir -p "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git"
  mkdir -p "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/docker"
  echo "# Git" > "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git/git.plugin.zsh"
  echo "# Docker" > "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/docker/docker.plugin.zsh"

  # Try different subdirectory
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try ohmyzsh/ohmyzsh:plugins/docker >/dev/null && \
              zap status"
  assert_success
  # Should show both subdirectories
  assert_output --partial ":plugins/git"
  assert_output --partial ":plugins/docker"
}

@test "US5-EDGE: Plugin with hyphens and underscores" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'user_name/plugin_name'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "zsh-users" "zsh-syntax-highlighting"
  create_test_plugin "user_name" "plugin_name"

  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "zsh-users/zsh-syntax-highlighting"
  assert_output --partial "user_name/plugin_name"
}

@test "US5-EDGE: Large number of plugins (50+)" {
  # Create 50 test plugins
  for i in {1..50}; do
    create_test_plugin "test$i" "plugin$i"
  done

  # Build plugins array
  local plugins_array="plugins=(\n"
  for i in {1..50}; do
    plugins_array+="  'test$i/plugin$i'\n"
  done
  plugins_array+=")\n\nsource ~/.zap/zap.zsh"

  echo -e "$plugins_array" > "$TEST_DIR/.zshrc"

  # Status should handle large lists
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins (50)"
}

@test "US5-EDGE: Status with no state file" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin"

  # Remove state file if it exists
  rm -f "$ZAP_DATA_DIR/state.zsh"

  # Should handle gracefully
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins (1)"
}

@test "US5-EDGE: Status with corrupted state file" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin"

  # Create corrupted state file
  mkdir -p "$ZAP_DATA_DIR"
  echo "CORRUPTED DATA { invalid zsh }" > "$ZAP_DATA_DIR/state.zsh"

  # Should handle gracefully
  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  # Should succeed or warn, but not crash
  [[ $status -eq 0 || $status -eq 1 ]]
}

@test "US5-EDGE: Diff shows complex changes" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'keep/plugin1'
  'keep/plugin2'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "keep" "plugin1"
  create_test_plugin "keep" "plugin2"
  create_test_plugin "exp1" "plugin"
  create_test_plugin "exp2" "plugin"
  create_test_plugin "exp3" "plugin"

  # Load declared + experimental
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp1/plugin >/dev/null && \
              zap try exp2/plugin >/dev/null && \
              zap try exp3/plugin >/dev/null && \
              zap diff"
  assert_success
  # Should show removals
  assert_output --partial "- exp1/plugin"
  assert_output --partial "- exp2/plugin"
  assert_output --partial "- exp3/plugin"
  # Should NOT show declared plugins in diff
  refute_output --partial "keep/plugin1"
  refute_output --partial "keep/plugin2"
}

@test "US5-EDGE: Status handles empty plugins array correctly" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
)

source ~/.zap/zap.zsh
EOF

  run zsh -c "source $TEST_DIR/.zshrc && zap status"
  assert_success
  assert_output --partial "Declared plugins: (none)"
}

@test "US5-EDGE: Status handles multiline plugins array" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'test1/plugin1'

  # Comment in array
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

@test "US5-EDGE: Diff handles version pin changes" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin@v1.0'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin"

  # Load with different version as experimental
  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/plugin@v2.0 >/dev/null && \
              zap diff"
  assert_success
  # Should show experimental version will be removed
  assert_output --partial "v2.0"
}

@test "US5-EDGE: Status shows plugins in consistent order" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'zuser/zplugin'
  'auser/aplugin'
  'muser/mplugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "zuser" "zplugin"
  create_test_plugin "auser" "aplugin"
  create_test_plugin "muser" "mplugin"

  # Run status multiple times
  local output1=$(zsh -c "source $TEST_DIR/.zshrc && zap status" 2>/dev/null)
  local output2=$(zsh -c "source $TEST_DIR/.zshrc && zap status" 2>/dev/null)

  # Output should be identical (consistent ordering)
  [[ "$output1" == "$output2" ]]
}

@test "US5-EDGE: Machine-readable output is valid JSON" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'test1/plugin1'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "test1" "plugin1"
  create_test_plugin "exp" "plugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try exp/plugin >/dev/null && \
              zap status --machine-readable"
  assert_success

  # Validate JSON structure (basic check)
  echo "$output" | grep -q '{'
  echo "$output" | grep -q '}'
  echo "$output" | grep -q '"declared"'
  echo "$output" | grep -q '"experimental"'
}

@test "US5-EDGE: Verbose status shows plugin load paths" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'testuser/plugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "plugin"

  run zsh -c "source $TEST_DIR/.zshrc && zap status --verbose"
  assert_success
  # Verbose should show paths
  assert_output --partial "testuser--plugin"
}
