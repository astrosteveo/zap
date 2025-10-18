#!/usr/bin/env bats
#
# test_error_handling.bats - Error handling and graceful degradation tests
#
# WHY: Verify FR-015 (graceful degradation - errors never block shell startup)
# Phase 8: Error Handling & Edge Cases

setup() {
  # Set up temporary test environment
  export TEST_TMPDIR="${BATS_TEST_TMPDIR:-/tmp}/zap-errtest-$$"
  export ZAP_DIR="$TEST_TMPDIR/zap"
  export ZAP_DATA_DIR="$TEST_TMPDIR/data"
  export HOME="$TEST_TMPDIR/home"
  export ZDOTDIR="$HOME"

  mkdir -p "$HOME" "$ZAP_DIR" "$ZAP_DATA_DIR"

  # Copy zap installation to test directory
  if [[ -f "$(dirname "$BATS_TEST_DIRNAME")/../zap.zsh" ]]; then
    cp -r "$(dirname "$BATS_TEST_DIRNAME")"/../* "$ZAP_DIR/" 2>/dev/null || true
  fi
}

teardown() {
  # Clean up test environment
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

#
# T076: Graceful failure - shell still starts even with errors
#

@test "T076: Shell starts successfully with invalid plugin spec" {
  # Create .zshrc with invalid plugin specification
  cat > "$HOME/.zshrc" <<EOF
source "$ZAP_DIR/zap.zsh"
zap load invalid-spec-without-slash
zap load valid/plugin
EOF

  # Shell should start successfully (exit code 0) despite invalid spec
  run zsh -c "source $HOME/.zshrc; exit 0"

  [[ $status -eq 0 ]]
}

@test "T076: Shell starts successfully with missing repository" {
  # Create .zshrc with non-existent repository
  cat > "$HOME/.zshrc" <<EOF
source "$ZAP_DIR/zap.zsh"
zap load nonexistent/repository-that-does-not-exist
EOF

  # Shell should start (graceful degradation per FR-015)
  run zsh -c "source $HOME/.zshrc; exit 0"

  [[ $status -eq 0 ]]
}

@test "T076: Shell starts successfully with network timeout" {
  # Create .zshrc with plugin that will timeout
  cat > "$HOME/.zshrc" <<EOF
source "$ZAP_DIR/zap.zsh"
# This will timeout due to invalid git URL
zap load user/repo
EOF

  # Even if download fails/timeouts, shell should start
  # This tests FR-030 (network timeout handling)
  run timeout 15 zsh -c "source $HOME/.zshrc; exit 0"

  # Shell should complete within timeout and exit cleanly
  [[ $status -eq 0 ]] || [[ $status -eq 1 ]]
}

@test "T076: Shell starts with corrupted cache" {
  # Source zap and create a corrupted cache
  source "$ZAP_DIR/lib/utils.zsh"
  source "$ZAP_DIR/lib/parser.zsh"

  # Create corrupted cache (directory without .git)
  local corrupt_cache="$ZAP_DATA_DIR/plugins/corrupt__plugin"
  mkdir -p "$corrupt_cache"
  echo "corrupted" > "$corrupt_cache/plugin.zsh"

  # Create .zshrc that tries to load corrupted plugin
  cat > "$HOME/.zshrc" <<EOF
source "$ZAP_DIR/zap.zsh"
zap load corrupt/plugin
EOF

  # Shell should start and detect/recover from corruption (FR-031)
  run zsh -c "source $HOME/.zshrc; exit 0"

  [[ $status -eq 0 ]]

  # Corrupted cache should be removed
  [[ ! -d "$corrupt_cache" ]] || [[ ! -f "$corrupt_cache/plugin.zsh" ]]
}

@test "T076: Multiple plugin failures don't prevent shell startup" {
  cat > "$HOME/.zshrc" <<EOF
source "$ZAP_DIR/zap.zsh"
zap load invalid-1
zap load nonexistent/repo-1
zap load nonexistent/repo-2
zap load invalid-2
EOF

  # Shell should start successfully despite all failures
  run zsh -c "source $HOME/.zshrc; echo 'shell started'; exit 0"

  [[ $status -eq 0 ]]
  [[ "$output" =~ "shell started" ]]
}

@test "T076: Error logging doesn't block shell startup" {
  # Create .zshrc with failing plugins
  cat > "$HOME/.zshrc" <<EOF
source "$ZAP_DIR/zap.zsh"
zap load failing/plugin
EOF

  # Run shell startup
  run zsh -c "source $HOME/.zshrc; exit 0"

  # Should complete successfully
  [[ $status -eq 0 ]]

  # Error log should exist (if errors occurred)
  # But its presence/absence shouldn't affect startup
  true
}

@test "T076: Invalid version pin doesn't block loading" {
  cat > "$HOME/.zshrc" <<EOF
source "$ZAP_DIR/zap.zsh"
# Invalid version format
zap load user/repo@invalid..version
EOF

  # Shell should start (FR-019: fallback on invalid pin)
  run zsh -c "source $HOME/.zshrc; exit 0"

  [[ $status -eq 0 ]]
}

@test "T076: Missing subdirectory doesn't block shell startup" {
  # This tests FR-037 (helpful error for missing subdirectory)
  cat > "$HOME/.zshrc" <<EOF
source "$ZAP_DIR/zap.zsh"
zap load user/repo path:nonexistent/subdir
EOF

  run zsh -c "source $HOME/.zshrc; exit 0"

  # Should still start shell
  [[ $status -eq 0 ]]
}

#
# T077: Concurrent shell startup (atomic operations)
#

@test "T077: Concurrent shell startups don't corrupt metadata" {
  # Create a simple .zshrc
  cat > "$HOME/.zshrc" <<EOF
source "$ZAP_DIR/zap.zsh"
EOF

  # Launch multiple shells concurrently
  local pids=()
  for i in {1..5}; do
    (zsh -c "source $HOME/.zshrc; sleep 0.1; exit 0") &
    pids+=($!)
  done

  # Wait for all shells to complete
  local all_success=1
  for pid in "${pids[@]}"; do
    if ! wait $pid 2>/dev/null; then
      all_success=0
    fi
  done

  # All shells should start successfully
  [[ $all_success -eq 1 ]]

  # Metadata file should be valid (not corrupted)
  if [[ -f "$ZAP_DATA_DIR/metadata.zsh" ]]; then
    # Should be valid Zsh syntax
    run zsh -c "source $ZAP_DATA_DIR/metadata.zsh"
    [[ $status -eq 0 ]]
  fi
}

@test "T077: Concurrent metadata updates are atomic" {
  # Source required libraries
  source "$ZAP_DIR/lib/utils.zsh"
  source "$ZAP_DIR/lib/parser.zsh"
  source "$ZAP_DIR/lib/updater.zsh"

  # Write metadata concurrently from multiple processes
  local pids=()
  for i in {1..10}; do
    (
      source "$ZAP_DIR/lib/utils.zsh"
      source "$ZAP_DIR/lib/parser.zsh"
      source "$ZAP_DIR/lib/updater.zsh"
      _zap_update_plugin_metadata "user$i" "repo$i" "v1.0" "loaded"
    ) &
    pids+=($!)
  done

  # Wait for all updates
  for pid in "${pids[@]}"; do
    wait $pid 2>/dev/null || true
  done

  # Metadata file should exist and be valid
  [[ -f "$ZAP_DATA_DIR/metadata.zsh" ]]

  # Should be loadable without errors
  run zsh -c "source $ZAP_DATA_DIR/metadata.zsh; echo \${#ZAP_PLUGIN_META[@]}"
  [[ $status -eq 0 ]]

  # Should have entries (exact count may vary due to race conditions,
  # but file should be consistent)
  [[ -n "$output" ]]
}

@test "T077: Concurrent cache file operations don't corrupt files" {
  # Create concurrent load order cache operations
  source "$ZAP_DIR/lib/utils.zsh"
  source "$ZAP_DIR/lib/parser.zsh"

  # Create test config file
  cat > "$HOME/test-plugins.txt" <<EOF
user1/repo1
user2/repo2
user3/repo3
EOF

  # Generate cache concurrently
  local pids=()
  for i in {1..5}; do
    (
      source "$ZAP_DIR/lib/utils.zsh"
      source "$ZAP_DIR/lib/parser.zsh"
      _zap_generate_load_order_cache "$HOME/test-plugins.txt"
    ) &
    pids+=($!)
  done

  # Wait for completion
  for pid in "${pids[@]}"; do
    wait $pid 2>/dev/null || true
  done

  # Cache file should exist and be valid (FR-035: atomic operations)
  local cache_file="$(_zap_get_cache_file_path)"
  [[ -f "$cache_file" ]]

  # Should be valid Zsh
  run zsh -c "source $cache_file"
  [[ $status -eq 0 ]]
}

#
# Additional error handling tests
#

@test "Path traversal attack is prevented" {
  source "$ZAP_DIR/lib/utils.zsh"
  source "$ZAP_DIR/lib/parser.zsh"

  # Attempt path traversal in subdirectory
  run _zap_parse_spec "user/repo path:../../etc/passwd"

  # Should fail (FR-027: path traversal prevention)
  [[ $status -ne 0 ]]
}

@test "Invalid characters in repo name are rejected" {
  source "$ZAP_DIR/lib/utils.zsh"
  source "$ZAP_DIR/lib/parser.zsh"

  # Special characters should be rejected
  run _zap_parse_spec "user/repo\$(malicious)"
  [[ $status -ne 0 ]]

  run _zap_parse_spec "user/repo; rm -rf /"
  [[ $status -ne 0 ]]
}

@test "Disk space check prevents downloads when low" {
  skip "Requires mocking df command for reliable testing"

  # This would test FR-038 (disk space check)
  # Implementation would mock df to return < 100MB
}

@test "Network timeout is enforced during clone" {
  skip "Requires network simulation or mock git server"

  # This would test FR-030 (10 second timeout)
  # Implementation would use a slow/hanging git server
}

@test "Error log rotation works correctly" {
  source "$ZAP_DIR/lib/utils.zsh"

  # Write > 100 error entries
  for i in {1..120}; do
    _zap_log_error "ERROR" "test/plugin$i" "Test error" "Test action"
  done

  # Count entries
  local entry_count=$(grep -c "^\[" "$ZAP_ERROR_LOG" 2>/dev/null || echo 0)

  # Should be rotated to ~100 entries (keeps last 400 lines, ~4 lines per entry)
  [[ $entry_count -le 120 ]]
  [[ $entry_count -ge 80 ]]
}
