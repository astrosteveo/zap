#!/usr/bin/env bats
#
# test_install.bats - Full installation flow integration test
#
# WHY: Verify FR-001 (installation), FR-002 (plugin loading persistence)
# T018: Integration test for complete install → load → restart cycle

setup() {
  export TEST_DIR="/tmp/zap-install-test-$$"
  export HOME="$TEST_DIR/home"
  mkdir -p "$HOME"

  export ZAP_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"

  # Create fresh .zshrc
  touch "$HOME/.zshrc"
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

@test "T018.1: Fresh install creates all required directories" {
  # Run installer
  run zsh -c "source $ZAP_DIR/install.zsh"
  [[ $status -eq 0 ]]

  # Verify directories exist
  [[ -d "$HOME/.local/share/zap" ]]
  [[ -d "$HOME/.local/share/zap/plugins" ]]
  [[ -d "$HOME/.local/share/zap/cache" ]]
}

@test "T018.2: Fresh install modifies .zshrc correctly" {
  run zsh -c "source $ZAP_DIR/install.zsh"
  [[ $status -eq 0 ]]

  # Verify .zshrc contains zap section
  grep -q "=== Zap Plugin Manager ===" "$HOME/.zshrc"
  grep -q "source.*zap.zsh" "$HOME/.zshrc"
}

@test "T018.3: Fresh install creates .zshrc backup" {
  echo "# Original config" > "$HOME/.zshrc"

  run zsh -c "source $ZAP_DIR/install.zsh"
  [[ $status -eq 0 ]]

  # Verify backup exists
  local backup_file=$(ls "$HOME/.zshrc.backup."* 2>/dev/null | head -1)
  [[ -n "$backup_file" ]]
  [[ -f "$backup_file" ]]

  # Verify backup contains original content
  grep -q "# Original config" "$backup_file"
}

@test "T018.4: Idempotent install doesn't corrupt .zshrc" {
  # Install twice
  run zsh -c "source $ZAP_DIR/install.zsh"
  [[ $status -eq 0 ]]

  run zsh -c "source $ZAP_DIR/install.zsh"
  [[ $status -eq 0 ]]

  # Should have exactly one zap section
  local count=$(grep -c "=== Zap Plugin Manager ===" "$HOME/.zshrc")
  [[ $count -eq 1 ]]
}

@test "T018.5: Load plugin and verify it sources correctly" {
  # Install zap
  run zsh -c "source $ZAP_DIR/install.zsh"
  [[ $status -eq 0 ]]

  # Add plugin to .zshrc
  cat >> "$HOME/.zshrc" <<'EOF'
zap load zsh-users/zsh-syntax-highlighting
EOF

  # Source .zshrc and verify plugin loads
  run zsh -c "source $HOME/.zshrc && typeset -f _zsh_highlight"
  [[ $status -eq 0 ]]
}

@test "T018.6: Plugin persists across shell restarts" {
  # Install and load plugin
  run zsh -c "source $ZAP_DIR/install.zsh"
  cat >> "$HOME/.zshrc" <<'EOF'
zap load zsh-users/zsh-syntax-highlighting
EOF

  # First shell startup
  run zsh -c "source $HOME/.zshrc && echo 'first'"
  [[ $status -eq 0 ]]

  # Second shell startup (should use cache)
  run zsh -c "source $HOME/.zshrc && typeset -f _zsh_highlight"
  [[ $status -eq 0 ]]

  # Verify plugin cache exists
  [[ -d "$HOME/.local/share/zap/plugins/zsh-users__zsh-syntax-highlighting" ]]
}

@test "T018.7: Multiple plugins load in correct order" {
  run zsh -c "source $ZAP_DIR/install.zsh"
  cat >> "$HOME/.zshrc" <<'EOF'
zap load zsh-users/zsh-completions
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions
EOF

  # Load all plugins
  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Verify all caches exist
  [[ -d "$HOME/.local/share/zap/plugins/zsh-users__zsh-completions" ]]
  [[ -d "$HOME/.local/share/zap/plugins/zsh-users__zsh-syntax-highlighting" ]]
  [[ -d "$HOME/.local/share/zap/plugins/zsh-users__zsh-autosuggestions" ]]
}

@test "T018.8: Load order cache generates and is used" {
  run zsh -c "source $ZAP_DIR/install.zsh"
  cat >> "$HOME/.zshrc" <<'EOF'
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions
EOF

  # First startup generates cache
  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  local cache_file="$HOME/.local/share/zap/cache/load-order.cache"
  [[ -f "$cache_file" ]]

  # Verify cache contains plugin info
  grep -q "zsh-users__zsh-syntax-highlighting" "$cache_file"
  grep -q "zsh-users__zsh-autosuggestions" "$cache_file"
}

@test "T018.9: Cache invalidates when .zshrc changes" {
  run zsh -c "source $ZAP_DIR/install.zsh"
  cat >> "$HOME/.zshrc" <<'EOF'
zap load zsh-users/zsh-syntax-highlighting
EOF

  # First startup
  run zsh -c "source $HOME/.zshrc && exit 0"
  local cache_file="$HOME/.local/share/zap/cache/load-order.cache"
  local first_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)

  sleep 1

  # Modify .zshrc
  cat >> "$HOME/.zshrc" <<'EOF'
zap load zsh-users/zsh-autosuggestions
EOF

  # Second startup should regenerate cache
  run zsh -c "source $HOME/.zshrc && exit 0"
  local second_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)

  # Cache should be regenerated (different mtime)
  [[ "$first_mtime" != "$second_mtime" ]]
}

@test "T018.10: Uninstall removes all zap components" {
  # Install and load plugin
  run zsh -c "source $ZAP_DIR/install.zsh"
  cat >> "$HOME/.zshrc" <<'EOF'
zap load zsh-users/zsh-syntax-highlighting
EOF
  run zsh -c "source $HOME/.zshrc && exit 0"

  # Verify zap is active
  [[ -d "$HOME/.local/share/zap" ]]
  grep -q "source.*zap.zsh" "$HOME/.zshrc"

  # Uninstall
  run zsh -c "source $ZAP_DIR/zap.zsh && zap uninstall --yes"
  [[ $status -eq 0 ]]

  # Verify data directory removed
  [[ ! -d "$HOME/.local/share/zap" ]]

  # Verify .zshrc cleaned
  ! grep -q "source.*zap.zsh" "$HOME/.zshrc"
  ! grep -q "=== Zap Plugin Manager ===" "$HOME/.zshrc"

  # Verify backup exists
  local backup_file=$(ls "$HOME/.zshrc.backup."* 2>/dev/null | head -1)
  [[ -n "$backup_file" ]]
}

@test "T018.11: Error in one plugin doesn't block shell startup" {
  run zsh -c "source $ZAP_DIR/install.zsh"
  cat >> "$HOME/.zshrc" <<'EOF'
zap load nonexistent/plugin
zap load zsh-users/zsh-syntax-highlighting
EOF

  # Shell should start successfully despite error
  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Second plugin should still load
  run zsh -c "source $HOME/.zshrc && typeset -f _zsh_highlight"
  [[ $status -eq 0 ]]
}

@test "T018.12: Rollback to backup after failed modification" {
  echo "# Original safe config" > "$HOME/.zshrc"

  # Install
  run zsh -c "source $ZAP_DIR/install.zsh"

  # Backup should exist
  local backup_file=$(ls "$HOME/.zshrc.backup."* 2>/dev/null | head -1)
  [[ -f "$backup_file" ]]

  # Manually restore backup
  cp "$backup_file" "$HOME/.zshrc"

  # Verify original content restored
  grep -q "# Original safe config" "$HOME/.zshrc"
  ! grep -q "zap.zsh" "$HOME/.zshrc"
}
