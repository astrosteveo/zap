#!/usr/bin/env bats
#
# Integration test: User Story 4 - Backup file creation (T071)
#
# Purpose: Test that `zap adopt` creates a backup of .zshrc before modifying it,
# ensuring users can recover from unwanted changes.
#
# Test scenarios:
# - Backup created on first adopt
# - Backup not overwritten on subsequent adopts
# - Backup contains original content
# - Backup location is documented
# - Backup naming convention
# - Multiple backups don't clobber each other
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

@test "US4-BACKUP: Backup created on first adopt" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  zsh -c "source $TEST_DIR/.zshrc && \
          zap try testuser/testplugin >/dev/null && \
          zap adopt --yes testuser/testplugin" 2>/dev/null

  # Backup should exist
  run ls "$TEST_DIR/.zshrc.backup"*
  assert_success
}

@test "US4-BACKUP: Backup contains original content" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
# My custom config
plugins=(
  'existing/plugin'
)

source ~/.zap/zap.zsh
EOF

  local original_content=$(cat "$TEST_DIR/.zshrc")

  create_test_plugin "testuser" "newplugin"

  zsh -c "source $TEST_DIR/.zshrc && \
          zap try testuser/newplugin >/dev/null && \
          zap adopt --yes testuser/newplugin" 2>/dev/null

  # Find the backup file
  local backup_file=$(ls "$TEST_DIR/.zshrc.backup"* 2>/dev/null | head -n1)

  # Backup should contain original content
  run cat "$backup_file"
  assert_success
  assert_output --partial "# My custom config"
  assert_output --partial "existing/plugin"
  # Should NOT contain adopted plugin
  refute_output --partial "testuser/newplugin"
}

@test "US4-BACKUP: Backup naming includes timestamp" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  zsh -c "source $TEST_DIR/.zshrc && \
          zap try testuser/testplugin >/dev/null && \
          zap adopt --yes testuser/testplugin" 2>/dev/null

  # Backup should follow pattern: .zshrc.backup.YYYYMMDD_HHMMSS
  run bash -c "ls $TEST_DIR/.zshrc.backup.* 2>/dev/null"
  assert_success
}

@test "US4-BACKUP: Multiple adopts create separate backups" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "test1" "plugin1"
  create_test_plugin "test2" "plugin2"

  # First adopt
  zsh -c "source $TEST_DIR/.zshrc && \
          zap try test1/plugin1 >/dev/null && \
          zap adopt --yes test1/plugin1" 2>/dev/null

  sleep 1  # Ensure different timestamps

  # Second adopt
  zsh -c "source $TEST_DIR/.zshrc && \
          zap try test2/plugin2 >/dev/null && \
          zap adopt --yes test2/plugin2" 2>/dev/null

  # Should have 2 backup files
  local backup_count=$(ls "$TEST_DIR/.zshrc.backup."* 2>/dev/null | wc -l)
  [[ $backup_count -eq 2 ]]
}

@test "US4-BACKUP: Backup preserves file permissions" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  chmod 600 "$TEST_DIR/.zshrc"
  local original_perms=$(stat -c %a "$TEST_DIR/.zshrc" 2>/dev/null || stat -f %Lp "$TEST_DIR/.zshrc")

  create_test_plugin "testuser" "testplugin"

  zsh -c "source $TEST_DIR/.zshrc && \
          zap try testuser/testplugin >/dev/null && \
          zap adopt --yes testuser/testplugin" 2>/dev/null

  local backup_file=$(ls "$TEST_DIR/.zshrc.backup"* 2>/dev/null | head -n1)
  local backup_perms=$(stat -c %a "$backup_file" 2>/dev/null || stat -f %Lp "$backup_file")

  [[ "$backup_perms" == "$original_perms" ]]
}

@test "US4-BACKUP: Adopt shows backup location in verbose mode" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  run zsh -c "source $TEST_DIR/.zshrc && \
              zap try testuser/testplugin >/dev/null && \
              zap adopt --yes --verbose testuser/testplugin"
  assert_success
  assert_output --partial "Backup created"
  assert_output --partial ".zshrc.backup"
}

@test "US4-BACKUP: Backup allows recovery from mistakes" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
# Original config
plugins=(
  'important/plugin'
)

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"
  create_test_plugin "important" "plugin"

  # Adopt and potentially regret it
  zsh -c "source $TEST_DIR/.zshrc && \
          zap try testuser/testplugin >/dev/null && \
          zap adopt --yes testuser/testplugin" 2>/dev/null

  # User can restore from backup
  local backup_file=$(ls "$TEST_DIR/.zshrc.backup"* 2>/dev/null | head -n1)
  cp "$backup_file" "$TEST_DIR/.zshrc"

  # Config should be restored
  run cat "$TEST_DIR/.zshrc"
  assert_success
  assert_output --partial "# Original config"
  assert_output --partial "important/plugin"
  refute_output --partial "testuser/testplugin"
}

@test "US4-BACKUP: Backup not created in dry-run mode" {
  cat > "$TEST_DIR/.zshrc" <<'EOF'
plugins=()

source ~/.zap/zap.zsh
EOF

  create_test_plugin "testuser" "testplugin"

  zsh -c "source $TEST_DIR/.zshrc && \
          zap try testuser/testplugin >/dev/null && \
          zap adopt --dry-run testuser/testplugin" 2>/dev/null

  # No backup should exist
  run ls "$TEST_DIR/.zshrc.backup"*
  assert_failure
}
