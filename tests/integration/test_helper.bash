#!/usr/bin/env bash
#
# BATS test helper functions for Zap integration tests
#
# This file provides common utilities and assertions for integration tests.
#

# Load bats-support and bats-assert if available
# These provide enhanced assertion functions
if [[ -f "/usr/lib/bats/bats-support/load.bash" ]]; then
  load "/usr/lib/bats/bats-support/load"
fi

if [[ -f "/usr/lib/bats/bats-assert/load.bash" ]]; then
  load "/usr/lib/bats/bats-assert/load"
fi

# Fallback assertion functions if bats-assert is not available
if ! command -v assert_success >/dev/null 2>&1; then
  assert_success() {
    if [[ "$status" -ne 0 ]]; then
      echo "Expected success (exit code 0) but got: $status"
      echo "Output: $output"
      return 1
    fi
  }
fi

if ! command -v assert_failure >/dev/null 2>&1; then
  assert_failure() {
    if [[ "$status" -eq 0 ]]; then
      echo "Expected failure (non-zero exit code) but got success"
      echo "Output: $output"
      return 1
    fi
  }
fi

if ! command -v assert_output >/dev/null 2>&1; then
  assert_output() {
    local expected="$1"

    if [[ "$1" == "--partial" ]]; then
      expected="$2"
      if [[ "$output" != *"$expected"* ]]; then
        echo "Expected output to contain: $expected"
        echo "Actual output: $output"
        return 1
      fi
    else
      if [[ "$output" != "$expected" ]]; then
        echo "Expected output: $expected"
        echo "Actual output: $output"
        return 1
      fi
    fi
  }
fi

if ! command -v assert_line >/dev/null 2>&1; then
  assert_line() {
    local pattern="$1"
    local found=false

    while IFS= read -r line; do
      if [[ "$line" == *"$pattern"* ]]; then
        found=true
        break
      fi
    done <<< "$output"

    if ! $found; then
      echo "Expected line containing: $pattern"
      echo "Output: $output"
      return 1
    fi
  }
fi

# Custom helper: Create a minimal test plugin
create_test_plugin() {
  local owner="$1"
  local repo="$2"
  local plugin_dir="$ZAP_DATA_DIR/plugins/${owner}__${repo}"

  mkdir -p "$plugin_dir"

  # Create a minimal plugin file
  cat > "$plugin_dir/${repo}.plugin.zsh" <<EOF
# Test plugin: ${owner}/${repo}
# This is a minimal test plugin for integration testing

echo "[Test] Loaded ${owner}/${repo}"
EOF

  # Create a fake git repository
  mkdir -p "$plugin_dir/.git"
  echo "ref: refs/heads/main" > "$plugin_dir/.git/HEAD"
}

# Custom helper: Wait for background operation
wait_for_file() {
  local file="$1"
  local timeout="${2:-5}"
  local elapsed=0

  while [[ ! -f "$file" && $elapsed -lt $timeout ]]; do
    sleep 0.1
    elapsed=$((elapsed + 1))
  done

  [[ -f "$file" ]]
}

# Custom helper: Count plugins in state file
count_declared_plugins() {
  if [[ ! -f "$ZAP_DATA_DIR/state.zsh" ]]; then
    echo "0"
    return
  fi

  # Source state file and count declared plugins
  (
    source "$ZAP_DATA_DIR/state.zsh" 2>/dev/null || true
    local count=0
    for key in "${(@k)_zap_plugin_state}"; do
      local metadata="${_zap_plugin_state[$key]}"
      local state="${${(@s:|:)metadata}[1]}"
      if [[ "$state" == "declared" ]]; then
        ((count++))
      fi
    done
    echo "$count"
  )
}

count_experimental_plugins() {
  if [[ ! -f "$ZAP_DATA_DIR/state.zsh" ]]; then
    echo "0"
    return
  fi

  # Source state file and count experimental plugins
  (
    source "$ZAP_DATA_DIR/state.zsh" 2>/dev/null || true
    local count=0
    for key in "${(@k)_zap_plugin_state}"; do
      local metadata="${_zap_plugin_state[$key]}"
      local state="${${(@s:|:)metadata}[1]}"
      if [[ "$state" == "experimental" ]]; then
        ((count++))
      fi
    done
    echo "$count"
  )
}

# Export test root directory
export BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME:-$(dirname "${BASH_SOURCE[0]}")}"
export ZAP_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
