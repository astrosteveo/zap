#!/usr/bin/env bats
#
# Integration test: User Story 4 - Adopt all experimental (T074)
#
# Purpose: Test that `zap adopt --all` adopts all currently loaded
# experimental plugins to the config file in one operation.
#
# Test scenarios:
# - Adopt all experimental plugins
# - Preserves all version pins and subdirs
# - Clear summary of adopted plugins
# - Single backup created
# - Confirmation prompt for --all
# - --yes skips confirmation
# - Empty experimental list is no-op
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

@test "US4-ALL: Adopt all experimental plugins" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "test1" "plugin1"
  create_test_plugin "test2" "plugin2"
  create_test_plugin "test3" "plugin3"

  # Try multiple plugins
  zsh -c "source $TEST_DIR/.zshrc && \
          zap try test1/plugin1 >/dev/null && \
          zap try test2/plugin2 >/dev/null && \
          zap try test3/plugin3 >/dev/null && \
          zap adopt --all --yes" 2>/dev/null

  # All should be in config
  run cat "$TEST_DIR/.zshrc"
  assert_success
  assert_output --partial "test1/plugin1"
  assert_output --partial "test2/plugin2"
  assert_output --partial "test3/plugin3"
}

@test "US4-ALL: Preserves all version pins" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "test1" "plugin1"
  create_test_plugin "test2" "plugin2"

  # Try with different version pins
  zsh -c "source $TEST_DIR/.zshrc && \
          zap try test1/plugin1@v1.0 >/dev/null && \
          zap try test2/plugin2@abc123 >/dev/null && \
          zap adopt --all --yes" 2>/dev/null

  # Version pins should be preserved
  run cat "$TEST_DIR/.zshrc"
  assert_success
  assert_output --partial "test1/plugin1@v1.0"
  assert_output --partial "test2/plugin2@abc123"
}

@test "US4-ALL: Preserves all subdirectory specs" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  mkdir -p "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git"
  mkdir -p "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/docker"
  echo "# Git" > "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/git/git.plugin.zsh"
  echo "# Docker" > "$ZAP_DATA_DIR/plugins/ohmyzsh--ohmyzsh/plugins/docker/docker.plugin.zsh"

  # Try multiple subdirectories
  zsh -c "source $TEST_DIR/.zshrc && \
          zap try ohmyzsh/ohmyzsh:plugins/git >/dev/null && \
          zap try ohmyzsh/ohmyzsh:plugins/docker >/dev/null && \
          zap adopt --all --yes" 2>/dev/null

  # Subdirectories should be preserved
  run cat "$TEST_DIR/.zshrc"
  assert_success
  assert_output --partial "ohmyzsh/ohmyzsh:plugins/git"
  assert_output --partial "ohmyzsh/ohmyzsh:plugins/docker"
}

@test "US4-ALL: Clear summary of adopted plugins" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "test1" "plugin1"
  create_test_plugin "test2" "plugin2"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try test1/plugin1 >/dev/null && \
              zap try test2/plugin2 >/dev/null && \
              zap adopt --all --yes"
  assert_success
  assert_output --partial "Adopted 2 plugins"
  assert_output --partial "test1/plugin1"
  assert_output --partial "test2/plugin2"
}

@test "US4-ALL: Single backup created for --all" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "test1" "plugin1"
  create_test_plugin "test2" "plugin2"
  create_test_plugin "test3" "plugin3"

  zsh -c "source $TEST_DIR/.zshrc && \
          zap try test1/plugin1 >/dev/null && \
          zap try test2/plugin2 >/dev/null && \
          zap try test3/plugin3 >/dev/null && \
          zap adopt --all --yes" 2>/dev/null

  # Should have exactly 1 backup
  local backup_count=$(ls "$TEST_DIR/.zshrc.backup."* 2>/dev/null | wc -l)
  [[ $backup_count -eq 1 ]]
}

@test "US4-ALL: Empty experimental list is no-op" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'existing/plugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "existing" "plugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap adopt --all --yes"
  assert_success
  assert_output --partial "No experimental plugins"
}

@test "US4-ALL: Mixed experimental and declared handled correctly" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=(
  'declared/plugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "declared" "plugin"
  create_test_plugin "exp1" "plugin1"
  create_test_plugin "exp2" "plugin2"

  # Try experimental plugins
  zsh -c "source $TEST_DIR/.zshrc && \
          zap try exp1/plugin1 >/dev/null && \
          zap try exp2/plugin2 >/dev/null && \
          zap adopt --all --yes" 2>/dev/null

  # Should have declared + 2 experimental
  run cat "$TEST_DIR/.zshrc"
  assert_success
  assert_output --partial "declared/plugin"
  assert_output --partial "exp1/plugin1"
  assert_output --partial "exp2/plugin2"

  # Count plugins in array
  local plugin_count=$(grep -E "^\s*'[^']+/[^']+'.*$" "$TEST_DIR/.zshrc" | wc -l)
  [[ $plugin_count -eq 3 ]]
}

@test "US4-ALL: Dry-run shows what would be adopted" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "test1" "plugin1"
  create_test_plugin "test2" "plugin2"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try test1/plugin1 >/dev/null && \
              zap try test2/plugin2 >/dev/null && \
              zap adopt --all --dry-run"
  assert_success
  assert_output --partial "Would adopt 2 plugins"
  assert_output --partial "test1/plugin1"
  assert_output --partial "test2/plugin2"

  # Config should not be modified
  run grep "test1/plugin1" "$TEST_DIR/.zshrc"
  assert_failure
}

@test "US4-ALL: Verbose mode shows detailed progress" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "test1" "plugin1"
  create_test_plugin "test2" "plugin2"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try test1/plugin1 >/dev/null && \
              zap try test2/plugin2 >/dev/null && \
              zap adopt --all --yes --verbose"
  assert_success
  assert_output --partial "Backup created"
  assert_output --partial "Adding to config"
  assert_output --partial "test1/plugin1"
  assert_output --partial "test2/plugin2"
  assert_output --partial "Adopted 2 plugins"
}

@test "US4-ALL: Performance acceptable for many plugins" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  # Create 10 test plugins
  for i in {1..10}; do
    create_test_plugin "test$i" "plugin$i"
  done

  # Try all 10
  local try_cmd="source $TEST_DIR/.zshrc"
  for i in {1..10}; do
    try_cmd="$try_cmd && zap try test$i/plugin$i >/dev/null"
  done
  try_cmd="$try_cmd && zap adopt --all --yes"

  local start_time=$(date +%s%N)
  zsh -c "$try_cmd" 2>/dev/null
  local end_time=$(date +%s%N)
  local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to ms

  # Should complete in under 2 seconds (2000ms)
  [[ $duration -lt 2000 ]]

  # All 10 should be in config
  local plugin_count=$(grep -E "^\s*'test[0-9]+/plugin[0-9]+'.*$" "$TEST_DIR/.zshrc" | wc -l)
  [[ $plugin_count -eq 10 ]]
}
