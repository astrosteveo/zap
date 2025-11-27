#!/usr/bin/env bats
#
# test_concurrent.bats - Concurrent shell startup tests
#
# WHY: Verify FR-035 (atomic file operations) and concurrent safety
# Phase 8: T077 - Concurrent shell startup validation

setup() {
  export TEST_TMPDIR="${BATS_TEST_TMPDIR:-/tmp}/zap-conctest-$$"
  export ZAP_DIR="$TEST_TMPDIR/zap"
  export ZAP_DATA_DIR="$TEST_TMPDIR/data"
  export HOME="$TEST_TMPDIR/home"
  export ZDOTDIR="$HOME"

  mkdir -p "$HOME" "$ZAP_DIR" "$ZAP_DATA_DIR"

  # Copy zap installation
  if [[ -f "$(dirname "$BATS_TEST_DIRNAME")/../zap.zsh" ]]; then
    cp -r "$(dirname "$BATS_TEST_DIRNAME")"/../* "$ZAP_DIR/" 2>/dev/null || true
  fi
}

teardown() {
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

@test "T077: Multiple shells can start simultaneously" {
  cat > "$HOME/.zshrc" <<EOF
source "$ZAP_DIR/zap.zsh"
EOF

  # Launch 10 shells concurrently
  local pids=()
  for i in {1..10}; do
    zsh -c "source $HOME/.zshrc; exit 0" &
    pids+=($!)
  done

  # All should complete successfully
  local failed=0
  for pid in "${pids[@]}"; do
    if ! wait $pid 2>/dev/null; then
      failed=$((failed + 1))
    fi
  done

  [[ $failed -eq 0 ]]
}

@test "T077: Metadata writes are atomic (no corruption)" {
  source "$ZAP_DIR/lib/utils.zsh"
  source "$ZAP_DIR/lib/parser.zsh"
  source "$ZAP_DIR/lib/updater.zsh"

  # Concurrent metadata updates
  local pids=()
  for i in {1..20}; do
    (
      source "$ZAP_DIR/lib/utils.zsh"
      source "$ZAP_DIR/lib/parser.zsh"
      source "$ZAP_DIR/lib/updater.zsh"
      _zap_update_plugin_metadata "owner$i" "repo$i" "v1.$i.0" "loaded"
    ) &
    pids+=($!)
  done

  for pid in "${pids[@]}"; do
    wait $pid
  done

  # Metadata should be valid Zsh
  [[ -f "$ZAP_DATA_DIR/metadata.zsh" ]]
  run zsh -c "source $ZAP_DATA_DIR/metadata.zsh; echo 'valid'"

  [[ $status -eq 0 ]]
  [[ "$output" =~ "valid" ]]
}

@test "T077: Cache file generation is safe under concurrency" {
  source "$ZAP_DIR/lib/utils.zsh"
  source "$ZAP_DIR/lib/parser.zsh"

  # Create config file
  cat > "$HOME/plugins.txt" <<EOF
user1/repo1
user2/repo2
EOF

  # Generate cache concurrently
  local pids=()
  for i in {1..10}; do
    (
      source "$ZAP_DIR/lib/utils.zsh"
      source "$ZAP_DIR/lib/parser.zsh"
      _zap_generate_load_order_cache "$HOME/plugins.txt"
    ) &
    pids+=($!)
  done

  for pid in "${pids[@]}"; do
    wait $pid
  done

  # Cache should be valid
  local cache_file="$ZAP_DATA_DIR/load-order.cache"
  [[ -f "$cache_file" ]]

  run zsh -c "source $cache_file; echo \${#ZAP_LOAD_ORDER[@]}"
  [[ $status -eq 0 ]]
  [[ "$output" =~ [0-9]+ ]]
}
