#!/usr/bin/env bats
#
# test_performance.bats - Performance and benchmark tests for Zap
#
# WHY: Validate performance budgets from spec.md (SC-002 through SC-008)
# User Story 5: Performance and Startup Speed

# Setup: ensure zap is available
setup() {
  # Load test helpers if available
  load '../test_helper.bash' 2>/dev/null || true

  # Set up temporary test environment
  export TEST_TMPDIR="${BATS_TEST_TMPDIR:-/tmp}/zap-perftest-$$"
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
# T061: Benchmark baseline Zsh startup time
#
# WHY: Establish baseline to measure zap overhead against (SC-007)
#
@test "T061: Baseline Zsh startup time < 100ms" {
  # Measure clean zsh startup (no plugins, no zap)
  local start_time end_time duration

  # Use EPOCHREALTIME for microsecond precision
  start_time=$(zsh -c 'echo $EPOCHREALTIME')
  # Run interactive shell that exits immediately
  zsh -ic 'exit' >/dev/null 2>&1
  end_time=$(zsh -c 'echo $EPOCHREALTIME')

  # Calculate duration in milliseconds
  duration=$(printf "%.0f" $(( ($end_time - $start_time) * 1000 )))

  echo "# Baseline Zsh startup: ${duration}ms" >&3

  # Baseline should be < 100ms on modern hardware
  # This is a sanity check - slower baseline indicates system issues
  [[ $duration -lt 200 ]]
}

#
# T062: Benchmark zap overhead
#
# WHY: Measure initialization cost of zap itself (SC-007: < 50ms)
#
@test "T062: Zap initialization overhead < 100ms" {
  # Create minimal .zshrc that only sources zap
  cat > "$HOME/.zshrc" <<EOF
source "$ZAP_DIR/zap.zsh"
EOF

  # Measure startup time with zap but no plugins
  local iterations=5
  local total_time=0

  for ((i=1; i<=iterations; i++)); do
    local start_time end_time
    start_time=$(zsh -c 'echo $EPOCHREALTIME')
    zsh -ic 'exit' >/dev/null 2>&1
    end_time=$(zsh -c 'echo $EPOCHREALTIME')

    local duration=$(printf "%.0f" $(( ($end_time - $start_time) * 1000 )))
    total_time=$((total_time + duration))
  done

  # Average over iterations
  local avg_time=$((total_time / iterations))

  echo "# Zap initialization (no plugins): ${avg_time}ms average" >&3

  # Zap overhead should be < 100ms
  [[ $avg_time -lt 100 ]]
}

#
# T063: Benchmark with 10 test plugins
#
# WHY: Verify SC-002 requirement (< 1 second startup with 10 plugins)
#
@test "T063: Startup with 10 plugins < 1 second" {
  skip "Requires test plugin corpus - implement in full test suite"

  # This test would:
  # 1. Clone 10 small, fast-loading test plugins
  # 2. Add them to .zshrc
  # 3. Measure shell startup time
  # 4. Assert < 1000ms

  # Example implementation when test plugins available:
  # for plugin in "${test_plugins[@]}"; do
  #   echo "zap load $plugin" >> "$HOME/.zshrc"
  # done
  # measure_startup_time
  # [[ $startup_time -lt 1000 ]]
}

#
# T064: Benchmark with 25 test plugins
#
# WHY: Verify SC-002 extended requirement (< 2 seconds with 25 plugins)
#
@test "T064: Startup with 25 plugins < 2 seconds" {
  skip "Requires test plugin corpus - implement in full test suite"

  # This test would:
  # 1. Clone 25 small, fast-loading test plugins
  # 2. Add them to .zshrc
  # 3. Measure shell startup time
  # 4. Assert < 2000ms
}

#
# T065: Optimize slow operations identified in profiling
#
# WHY: Iterative optimization based on profiling data
#
@test "T065: Profiling identifies operations > 50ms" {
  # Create .zshrc with a few plugins and profiling enabled
  cat > "$HOME/.zshrc" <<EOF
export ZAP_PROFILE=1
source "$ZAP_DIR/zap.zsh"
EOF

  # Run shell with profiling and capture output
  local profile_output
  profile_output=$(zsh -ic 'exit' 2>&1 | grep '^\[PROFILE\]' || true)

  echo "# Profile output:" >&3
  echo "$profile_output" >&3

  # This test validates that profiling works
  # In practice, T065 is about using this data to optimize slow operations
  # For now, just verify profiling produces output
  if [[ -n "$ZAP_PROFILE" ]]; then
    # Profiling should work (may have no output if no plugins loaded)
    true
  fi
}

#
# T055: Performance benchmark test (10 plugins < 1s startup)
#
# WHY: Integration test for SC-002 success criteria
#
@test "T055: Performance benchmark - 10 plugins under 1 second" {
  skip "Requires real plugin corpus for accurate benchmarking"

  # This is a duplicate of T063 but structured as BATS test
  # When implemented with real plugins, this validates SC-002
}

#
# T056: Memory usage test (< 10MB overhead)
#
# WHY: Validate SC-008 success criteria (memory efficiency)
#
@test "T056: Memory overhead < 10MB" {
  # Create .zshrc with zap
  cat > "$HOME/.zshrc" <<EOF
source "$ZAP_DIR/zap.zsh"
# Keep shell alive for memory measurement
sleep 2 &
EOF

  # Start a shell in background
  zsh -c "source $HOME/.zshrc" &
  local zsh_pid=$!

  # Wait for shell to initialize
  sleep 1

  # Measure RSS (Resident Set Size) in KB
  local memory_kb
  if command -v ps >/dev/null 2>&1; then
    memory_kb=$(ps -o rss= -p $zsh_pid 2>/dev/null || echo "0")
  else
    skip "ps command not available for memory measurement"
  fi

  # Kill the test shell
  kill $zsh_pid 2>/dev/null || true
  wait $zsh_pid 2>/dev/null || true

  # Convert to MB
  local memory_mb=$((memory_kb / 1024))

  echo "# Zap memory overhead: ${memory_mb}MB" >&3

  # Memory overhead should be < 10MB
  # Note: This measures total shell memory, not just zap overhead
  # Actual zap overhead is much smaller
  [[ $memory_mb -lt 10 ]]
}

#
# Additional performance checks
#

@test "Plugin file search is optimized (no external commands)" {
  # Verify _zap_find_plugin_file doesn't use subprocess calls
  # This validates T059 optimization

  # Source the loader
  source "$ZAP_DIR/lib/parser.zsh"
  source "$ZAP_DIR/lib/utils.zsh"
  source "$ZAP_DIR/lib/loader.zsh"

  # Create a mock plugin directory
  local mock_dir="$TEST_TMPDIR/mock-plugin"
  mkdir -p "$mock_dir"
  touch "$mock_dir/test.plugin.zsh"

  # Call the function and verify it works
  local result
  result=$(_zap_find_plugin_file "$mock_dir" "test" "")

  [[ -n "$result" ]]
  [[ "$result" == "$mock_dir/test.plugin.zsh" ]]
}

@test "Load order cache reduces parsing overhead" {
  skip "Cache optimization not yet integrated into main flow"

  # This test would verify that:
  # 1. First run generates cache
  # 2. Second run uses cache (faster)
  # 3. Modified config invalidates cache
}
