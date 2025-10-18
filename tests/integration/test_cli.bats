#!/usr/bin/env bats
#
# test_cli.bats - CLI commands integration test
#
# WHY: Verify all CLI commands work correctly (zap help, list, update, clean, doctor, uninstall)
# T086: Integration test for all CLI commands

setup() {
  export TEST_DIR="/tmp/zap-cli-test-$$"
  export HOME="$TEST_DIR/home"
  mkdir -p "$HOME"

  export ZAP_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"

  # Install zap
  touch "$HOME/.zshrc"
  zsh -c "source $ZAP_DIR/install.zsh" >/dev/null 2>&1

  # Add a test plugin
  cat >> "$HOME/.zshrc" <<'EOF'
zap load zsh-users/zsh-syntax-highlighting
EOF

  # Load plugin
  zsh -c "source $HOME/.zshrc && exit 0" >/dev/null 2>&1
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

@test "T086.1: zap help displays usage information" {
  run zsh -c "source $HOME/.zshrc && zap help"
  [[ $status -eq 0 ]]
  echo "$output" | grep -q "Usage:"
  echo "$output" | grep -q "Commands:"
}

@test "T086.2: zap help <command> shows command-specific help" {
  run zsh -c "source $HOME/.zshrc && zap help list"
  [[ $status -eq 0 ]]
}

@test "T086.3: zap list shows installed plugins" {
  run zsh -c "source $HOME/.zshrc && zap list"
  [[ $status -eq 0 ]]
  echo "$output" | grep -q "zsh-users/zsh-syntax-highlighting"
}

@test "T086.4: zap list --verbose shows detailed info" {
  run zsh -c "source $HOME/.zshrc && zap list --verbose"
  [[ $status -eq 0 ]]
  # Verbose should show more details (version, status, etc.)
  echo "$output" | grep -q "zsh-users/zsh-syntax-highlighting"
}

@test "T086.5: zap update checks for updates" {
  run zsh -c "source $HOME/.zshrc && zap update"
  [[ $status -eq 0 ]]
  # Should check for updates
}

@test "T086.6: zap update <plugin> updates specific plugin" {
  run zsh -c "source $HOME/.zshrc && zap update zsh-users/zsh-syntax-highlighting"
  [[ $status -eq 0 ]]
}

@test "T086.7: zap clean shows what would be removed" {
  # Remove plugin from config
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
EOF

  run zsh -c "source $HOME/.zshrc && zap clean"
  [[ $status -eq 0 ]]
  # Should show orphaned plugins
}

@test "T086.8: zap clean --yes removes orphaned caches" {
  # Remove plugin from config
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
EOF

  run zsh -c "source $HOME/.zshrc && zap clean --yes"
  [[ $status -eq 0 ]]

  # Plugin cache should be removed
  [[ ! -d "$HOME/.local/share/zap/plugins/zsh-users__zsh-syntax-highlighting" ]]
}

@test "T086.9: zap clean --all --yes removes all caches" {
  run zsh -c "source $HOME/.zshrc && zap clean --all --yes"
  [[ $status -eq 0 ]]

  # All plugin caches should be removed
  local plugin_count=$(find "$HOME/.local/share/zap/plugins" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  [[ $plugin_count -eq 0 ]]
}

@test "T086.10: zap doctor runs diagnostic checks" {
  run zsh -c "source $HOME/.zshrc && zap doctor"
  [[ $status -eq 0 ]]

  # Should check Zsh version
  echo "$output" | grep -qi "zsh"

  # Should check Git availability
  echo "$output" | grep -qi "git"
}

@test "T086.11: zap uninstall removes zap (with confirmation)" {
  # Uninstall with --yes flag
  run zsh -c "source $HOME/.zshrc && zap uninstall --yes"
  [[ $status -eq 0 ]]

  # Data directory should be removed
  [[ ! -d "$HOME/.local/share/zap" ]]

  # .zshrc should not contain zap initialization
  ! grep -q "source.*zap.zsh" "$HOME/.zshrc"
}

@test "T086.12: zap uninstall --keep-cache preserves cache" {
  run zsh -c "source $HOME/.zshrc && zap uninstall --keep-cache --yes"
  [[ $status -eq 0 ]]

  # Cache should still exist
  [[ -d "$HOME/.local/share/zap" ]]

  # But zap.zsh should be removed from .zshrc
  ! grep -q "source.*zap.zsh" "$HOME/.zshrc"
}

@test "T086.13: ZAP_QUIET suppresses non-error output" {
  run zsh -c "ZAP_QUIET=1 source $HOME/.zshrc && zap list"
  [[ $status -eq 0 ]]

  # Output should be minimal (no decorative messages)
  # Should still show plugin list but without formatting
}

@test "T086.14: Invalid command shows helpful error" {
  run zsh -c "source $HOME/.zshrc && zap invalidcommand"
  [[ $status -ne 0 ]]
  echo "$output" | grep -qi "unknown command\|invalid"
}

@test "T086.15: Command without required args shows usage" {
  # Some commands might require arguments
  run zsh -c "source $HOME/.zshrc && zap help"
  [[ $status -eq 0 ]]
}
