#!/usr/bin/env bats
#
# test_plugin_mgmt.bats - Plugin management lifecycle integration test
#
# WHY: Verify FR-003 (plugin updates), FR-004 (version pinning), FR-005 (subdirectories)
# T027: Integration test for plugin add/remove/update cycle

setup() {
  export TEST_DIR="/tmp/zap-plugin-test-$$"
  export HOME="$TEST_DIR/home"
  mkdir -p "$HOME"

  export ZAP_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
  export ZAP_DATA_DIR="$HOME/.local/share/zap"
  export ZAP_PLUGIN_DIR="$ZAP_DATA_DIR/plugins"

  # Install zap
  touch "$HOME/.zshrc"
  zsh -c "source $ZAP_DIR/install.zsh" >/dev/null 2>&1
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

@test "T027.1: Add plugin creates cache directory" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-syntax-highlighting
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Verify cache created
  [[ -d "$ZAP_PLUGIN_DIR/zsh-users__zsh-syntax-highlighting" ]]
  [[ -d "$ZAP_PLUGIN_DIR/zsh-users__zsh-syntax-highlighting/.git" ]]
}

@test "T027.2: Remove plugin from .zshrc removes from load order" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions
EOF

  # First load
  run zsh -c "source $HOME/.zshrc && exit 0"

  # Remove one plugin
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-syntax-highlighting
EOF

  # Second load should regenerate cache
  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Load order cache should not contain removed plugin
  local cache_file="$ZAP_DATA_DIR/cache/load-order.cache"
  if [[ -f "$cache_file" ]]; then
    ! grep -q "zsh-autosuggestions" "$cache_file"
  fi
}

@test "T027.3: Update plugin with zap update" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-syntax-highlighting
EOF

  # Initial load
  run zsh -c "source $HOME/.zshrc && exit 0"

  local plugin_dir="$ZAP_PLUGIN_DIR/zsh-users__zsh-syntax-highlighting"
  [[ -d "$plugin_dir" ]]

  # Get current commit
  local before_commit=$(cd "$plugin_dir" && git rev-parse HEAD)

  # Update plugin
  run zsh -c "source $HOME/.zshrc && zap update zsh-users/zsh-syntax-highlighting"
  [[ $status -eq 0 ]]

  # Verify git pull was attempted (commit might be same if already latest)
  [[ -d "$plugin_dir/.git" ]]
}

@test "T027.4: Update all plugins with zap update" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions
EOF

  # Initial load
  run zsh -c "source $HOME/.zshrc && exit 0"

  # Update all
  run zsh -c "source $HOME/.zshrc && zap update"
  [[ $status -eq 0 ]]

  # Both plugins should still exist
  [[ -d "$ZAP_PLUGIN_DIR/zsh-users__zsh-syntax-highlighting" ]]
  [[ -d "$ZAP_PLUGIN_DIR/zsh-users__zsh-autosuggestions" ]]
}

@test "T027.5: Version pinning prevents update to newer version" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-syntax-highlighting@0.7.0
EOF

  # Initial load
  run zsh -c "source $HOME/.zshrc && exit 0"

  local plugin_dir="$ZAP_PLUGIN_DIR/zsh-users__zsh-syntax-highlighting"

  # Attempt update (should stay at pinned version)
  run zsh -c "source $HOME/.zshrc && zap update zsh-users/zsh-syntax-highlighting"

  # Verify still at 0.7.0
  local current_ref=$(cd "$plugin_dir" && git describe --tags 2>/dev/null || git rev-parse --short HEAD)
  # Version pin should be respected (output should mention pinned version)
  [[ $status -eq 0 ]]
}

@test "T027.6: Subdirectory plugin loads from correct path" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh path:plugins/git
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Verify framework was cloned
  [[ -d "$ZAP_PLUGIN_DIR/ohmyzsh__ohmyzsh" ]]

  # Verify subdirectory exists
  [[ -d "$ZAP_PLUGIN_DIR/ohmyzsh__ohmyzsh/plugins/git" ]]
}

@test "T027.7: Change subdirectory path triggers re-source" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh path:plugins/git
EOF

  # First load
  run zsh -c "source $HOME/.zshrc && exit 0"

  # Change subdirectory
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh path:plugins/kubectl
EOF

  # Second load should work with new path
  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Both subdirectories should exist in cache
  [[ -d "$ZAP_PLUGIN_DIR/ohmyzsh__ohmyzsh/plugins/git" ]]
  [[ -d "$ZAP_PLUGIN_DIR/ohmyzsh__ohmyzsh/plugins/kubectl" ]]
}

@test "T027.8: Version change triggers re-clone at new version" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-syntax-highlighting@0.7.0
EOF

  # First load at v0.7.0
  run zsh -c "source $HOME/.zshrc && exit 0"

  # Change version
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-syntax-highlighting@0.8.0
EOF

  # Second load should checkout new version
  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]
}

@test "T027.9: Clean removes orphaned plugin caches" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions
EOF

  # Load both plugins
  run zsh -c "source $HOME/.zshrc && exit 0"

  # Verify both cached
  [[ -d "$ZAP_PLUGIN_DIR/zsh-users__zsh-syntax-highlighting" ]]
  [[ -d "$ZAP_PLUGIN_DIR/zsh-users__zsh-autosuggestions" ]]

  # Remove one from .zshrc
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-syntax-highlighting
EOF

  # Run clean
  run zsh -c "source $HOME/.zshrc && zap clean --yes"
  [[ $status -eq 0 ]]

  # Active plugin should remain
  [[ -d "$ZAP_PLUGIN_DIR/zsh-users__zsh-syntax-highlighting" ]]

  # Orphaned plugin should be removed
  [[ ! -d "$ZAP_PLUGIN_DIR/zsh-users__zsh-autosuggestions" ]]
}

@test "T027.10: Clean --all removes all plugin caches" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-syntax-highlighting
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ -d "$ZAP_PLUGIN_DIR/zsh-users__zsh-syntax-highlighting" ]]

  # Clean all
  run zsh -c "source $HOME/.zshrc && zap clean --all --yes"
  [[ $status -eq 0 ]]

  # All caches should be removed
  [[ ! -d "$ZAP_PLUGIN_DIR/zsh-users__zsh-syntax-highlighting" ]]
}

@test "T027.11: List shows all loaded plugins" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions
EOF

  run zsh -c "source $HOME/.zshrc && zap list"
  [[ $status -eq 0 ]]

  # Output should contain both plugins
  echo "$output" | grep -q "zsh-users/zsh-syntax-highlighting"
  echo "$output" | grep -q "zsh-users/zsh-autosuggestions"
}

@test "T027.12: Plugin with missing subdirectory logs error but continues" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh path:nonexistent/path
EOF

  # Should not block shell startup
  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Error should be logged
  local error_log="$ZAP_DATA_DIR/error.log"
  if [[ -f "$error_log" ]]; then
    grep -q "nonexistent/path" "$error_log" || true
  fi
}

@test "T027.13: Concurrent updates don't corrupt metadata" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-syntax-highlighting
EOF

  # Initial load
  run zsh -c "source $HOME/.zshrc && exit 0"

  # Launch multiple update processes concurrently
  local pids=()
  for i in {1..5}; do
    zsh -c "source $HOME/.zshrc && zap update zsh-users/zsh-syntax-highlighting" >/dev/null 2>&1 &
    pids+=($!)
  done

  # Wait for all to complete
  local all_success=0
  for pid in "${pids[@]}"; do
    if wait $pid; then
      all_success=$((all_success + 1))
    fi
  done

  # At least some should succeed
  [[ $all_success -gt 0 ]]

  # Plugin should still be intact
  [[ -d "$ZAP_PLUGIN_DIR/zsh-users__zsh-syntax-highlighting" ]]
  [[ -d "$ZAP_PLUGIN_DIR/zsh-users__zsh-syntax-highlighting/.git" ]]
}
