#!/usr/bin/env zsh
#
# state.zsh - Plugin state metadata tracking for declarative management
#
# This module manages the plugin state metadata file that tracks which plugins
# are loaded, their source (declared vs experimental), versions, and timestamps.
# All state operations use atomic writes to prevent corruption.
#
# Key functions:
#   _zap_load_state()               - Load state metadata from file
#   _zap_write_state()              - Write state metadata with atomic operations
#   _zap_add_plugin_to_state()      - Add plugin entry to state
#   _zap_remove_plugin_from_state() - Remove plugin entry from state
#   _zap_update_plugin_state()      - Update plugin state (declared/experimental)
#   _zap_list_declared_plugins()    - Query declared plugins
#   _zap_list_experimental_plugins()- Query experimental plugins
#
# State file format: $ZAP_DATA_DIR/state.zsh
#   Associative array with pipe-delimited metadata:
#   'plugin-name' → 'state|spec|timestamp|path|version|source'
#
# WHY: State tracking enables reconciliation, drift detection, and clear
# separation between declared and experimental plugins. Atomic operations
# prevent corruption from concurrent shell sessions.
#

#
# _zap_init_state - Initialize state metadata structure
#
# Creates the global associative array for plugin state tracking.
# Called automatically on module load.
#
# WHY: Global state must be initialized before any state operations.
# Using typeset -gA ensures the array is global and associative.
#
_zap_init_state() {
  typeset -gA _zap_plugin_state
  _zap_plugin_state=()
}

#
# _zap_write_state - Write state metadata to file with atomic operations
#
# Writes the current _zap_plugin_state to $ZAP_DATA_DIR/state.zsh
# using atomic temp file + mv to prevent corruption.
#
# Returns: 0 on success, 1 on error
#
# WHY: Atomic writes prevent corruption if interrupted mid-write.
# Multiple shell sessions can safely write without race conditions.
#
_zap_write_state() {
  local state_file="${ZAP_DATA_DIR}/state.zsh"
  local tmp_file="${state_file}.tmp.$$"
  local session_pid="$$"
  # Use command to bypass any aliases/functions
  local timestamp=$(command date -Iseconds 2>/dev/null || command date +%Y-%m-%dT%H:%M:%S 2>/dev/null || echo "$(command date +%s 2>/dev/null)")

  # Ensure data directory exists
  mkdir -p "$ZAP_DATA_DIR" 2>/dev/null

  # Build state file content
  {
    echo "# Zap Plugin State Metadata"
    echo "# Auto-generated - do not edit manually"
    echo "# Session: $session_pid"
    echo "# Last updated: $timestamp"
    echo ""
    echo "# Only declare if not already declared"
    echo "[[ \${(t)_zap_plugin_state} != \"association\" ]] && typeset -A _zap_plugin_state"
    echo ""
    echo "_zap_plugin_state=("

    # Write plugin entries
    for plugin_name plugin_metadata in "${(@kv)_zap_plugin_state}"; do
      echo "  '$plugin_name' '$plugin_metadata'"
    done

    echo ")"
  } > "$tmp_file"

  # Atomic move
  if mv "$tmp_file" "$state_file" 2>/dev/null; then
    return 0
  else
    rm -f "$tmp_file" 2>/dev/null
    return 1
  fi
}

#
# _zap_load_state - Load state metadata from file with corruption recovery
#
# Loads the state metadata from $ZAP_DATA_DIR/state.zsh. If the file
# is corrupted or missing, initializes empty state.
#
# Returns: 0 on success, 1 if file was corrupted (recovered)
#
# WHY: Corruption recovery prevents loss of state from interrupted writes
# or file system errors. We back up corrupted files for debugging.
#
_zap_load_state() {
  local state_file="${ZAP_DATA_DIR}/state.zsh"

  # Ensure the variable exists first (in case it was unset)
  if ! typeset -p _zap_plugin_state &>/dev/null; then
    _zap_init_state
  fi

  # If file doesn't exist, initialize empty state
  if [[ ! -f "$state_file" ]]; then
    _zap_init_state
    return 0
  fi

  # Try to source the state file
  if source "$state_file" 2>/dev/null; then
    # Validate it's an associative array
    if [[ ${(t)_zap_plugin_state} == "association" ]]; then
      return 0
    else
      # Wrong type - reinitialize
      echo "Warning: State file has wrong type, reinitializing" >&2
      mv "$state_file" "$state_file.corrupted.$(date +%s)" 2>/dev/null
      _zap_init_state
      return 1
    fi
  else
    # Source failed - corrupted file
    echo "Warning: State file corrupted, reinitializing" >&2
    mv "$state_file" "$state_file.corrupted.$(date +%s)" 2>/dev/null
    _zap_init_state
    return 1
  fi
}

#
# _zap_add_plugin_to_state - Add plugin entry to state metadata
#
# Parameters:
#   $1 - plugin_name (e.g., "owner/repo")
#   $2 - specification (e.g., "owner/repo@v1.0")
#   $3 - state (declared or experimental)
#   $4 - path (absolute path to plugin directory)
#   $5 - version (actual version loaded)
#   $6 - source (array, try_command, or legacy_load)
#
# Returns: 0 on success
#
# WHY: Centralized state updates ensure consistent metadata format.
#
_zap_add_plugin_to_state() {
  local plugin_name="$1"
  local specification="$2"
  local state="$3"
  local path="$4"
  local version="$5"
  local source="$6"
  # Use command to bypass any aliases/functions
  local timestamp=$(command date +%s 2>/dev/null || echo "0")

  # Build metadata string (pipe-delimited)
  local metadata="${state}|${specification}|${timestamp}|${path}|${version}|${source}"

  # Add to associative array
  _zap_plugin_state[$plugin_name]="$metadata"

  return 0
}

#
# _zap_remove_plugin_from_state - Remove plugin entry from state
#
# Parameters:
#   $1 - plugin_name (e.g., "owner/repo")
#
# Returns: 0 on success
#
# WHY: Clean removal prevents stale metadata accumulation.
#
_zap_remove_plugin_from_state() {
  local plugin_name="$1"

  # Remove from associative array
  unset "_zap_plugin_state[$plugin_name]"

  return 0
}

#
# _zap_update_plugin_state - Update plugin state (declared/experimental)
#
# Parameters:
#   $1 - plugin_name (e.g., "owner/repo")
#   $2 - new_state (declared or experimental)
#   $3 - new_source (array, try_command, or legacy_load)
#
# Returns: 0 on success, 1 if plugin not found
#
# WHY: State transitions (experimental → declared via zap adopt) require
# updating existing metadata without losing timestamps or versions.
#
_zap_update_plugin_state() {
  local plugin_name="$1"
  local new_state="$2"
  local new_source="$3"

  # Check if plugin exists in state
  local entry="${_zap_plugin_state[$plugin_name]}"
  if [[ -z "$entry" ]]; then
    echo "Error: Plugin not found in state: $plugin_name" >&2
    return 1
  fi

  # Parse existing entry
  local -a fields
  fields=("${(@s:|:)entry}")

  # Update state and source fields
  fields[1]="$new_state"
  fields[6]="$new_source"

  # Rebuild metadata string
  local new_metadata="${(j:|:)fields}"

  # Update associative array
  _zap_plugin_state[$plugin_name]="$new_metadata"

  return 0
}

#
# _zap_list_declared_plugins - Query declared plugins
#
# Returns: List of declared plugin names (one per line)
#
# WHY: Reconciliation needs to query only declared plugins to calculate drift.
#
_zap_list_declared_plugins() {
  local -a declared_plugins

  for plugin_name plugin_metadata in "${(@kv)_zap_plugin_state}"; do
    local state="${${(@s:|:)plugin_metadata}[1]}"
    if [[ "$state" == "declared" ]]; then
      declared_plugins+=("$plugin_name")
    fi
  done

  # Output one per line
  printf '%s\n' "${declared_plugins[@]}"
}

#
# _zap_list_experimental_plugins - Query experimental plugins
#
# Returns: List of experimental plugin names (one per line)
#
# WHY: zap status and zap sync need to distinguish experimental plugins.
#
_zap_list_experimental_plugins() {
  local -a experimental_plugins

  for plugin_name plugin_metadata in "${(@kv)_zap_plugin_state}"; do
    local state="${${(@s:|:)plugin_metadata}[1]}"
    if [[ "$state" == "experimental" ]]; then
      experimental_plugins+=("$plugin_name")
    fi
  done

  # Output one per line
  printf '%s\n' "${experimental_plugins[@]}"
}

# Initialize state on module load
_zap_init_state

# Module initialization
typeset -g ZAP_STATE_LOADED=1
