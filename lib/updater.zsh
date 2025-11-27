#!/usr/bin/env zsh
#
# updater.zsh - Plugin update checking and management
#
# WHY: Centralized update logic enables consistent update behavior and
# respects version pins (per FR-007, FR-019)

# Source utilities
source "${0:A:h}/utils.zsh"
source "${0:A:h}/parser.zsh"

#
# _zap_load_metadata - Load plugin metadata from cache
#
# Purpose: Read metadata.zsh file containing plugin version information
# Parameters: None
# Returns: 0 always
# Side Effects: Sets global ZAP_PLUGIN_META associative array
#
# WHY: Metadata tracking enables update detection and status reporting (data-model.md §2)
#
_zap_load_metadata() {
  typeset -gA ZAP_PLUGIN_META

  local metadata_file="$ZAP_DATA_DIR/metadata.zsh"

  if [[ -f "$metadata_file" ]]; then
    source "$metadata_file" 2>/dev/null || true
  fi

  return 0
}

#
# _zap_save_metadata - Save plugin metadata to cache
#
# Purpose: Write metadata.zsh with current plugin information
# Parameters: None
# Returns: 0 on success, 1 on failure
# Side Effects: Writes to $ZAP_DATA_DIR/metadata.zsh
#
# WHY: Atomic writes prevent corruption during concurrent shell startup (FR-035)
#
_zap_save_metadata() {
  local metadata_file="$ZAP_DATA_DIR/metadata.zsh"
  local temp_file="${metadata_file}.tmp.$$"

  # Create directory if needed
  mkdir -p "$(dirname "$metadata_file")" 2>/dev/null

  # Write to temp file (atomic operation per FR-035)
  {
    echo "# Zap plugin metadata"
    echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)"
    echo ""
    echo "typeset -gA ZAP_PLUGIN_META"
    echo "ZAP_PLUGIN_META=("

    # Output all metadata entries
    for key in "${(@k)ZAP_PLUGIN_META}"; do
      echo "  \"$key\" \"${ZAP_PLUGIN_META[$key]}\""
    done

    echo ")"
  } > "$temp_file" 2>/dev/null

  # Atomic rename (FR-035)
  if mv "$temp_file" "$metadata_file" 2>/dev/null; then
    return 0
  else
    rm -f "$temp_file" 2>/dev/null
    return 1
  fi
}

#
# _zap_update_plugin_metadata - Update metadata for a plugin
#
# Purpose: Store version, commit, and status information for a plugin
# Parameters:
#   $1 - Owner
#   $2 - Repo
#   $3 - Version (optional)
#   $4 - Status (loaded, failed, disabled) - default: loaded
# Returns: 0 always
#
# WHY: Track plugin state for update checking and diagnostics (FR-007)
#
_zap_update_plugin_metadata() {
  local owner="$1"
  local repo="$2"
  local version="${3:-}"
  local plugin_status="${4:-loaded}"
  local plugin_id="$(_zap_get_plugin_identifier "$owner" "$repo")"
  local cache_dir="$(_zap_get_plugin_cache_dir "$owner" "$repo")"

  # Load current metadata
  _zap_load_metadata

  # Get current commit SHA if plugin is cached
  local commit_sha=""
  if [[ -d "$cache_dir/.git" ]]; then
    commit_sha=$(cd "$cache_dir" && git rev-parse HEAD 2>/dev/null || echo "unknown")
  fi

  # Update metadata entries
  ZAP_PLUGIN_META["${plugin_id}:version"]="$version"
  ZAP_PLUGIN_META["${plugin_id}:commit"]="$commit_sha"
  ZAP_PLUGIN_META["${plugin_id}:status"]="$plugin_status"
  ZAP_PLUGIN_META["${plugin_id}:last_check"]="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)"

  # Save metadata
  _zap_save_metadata

  return 0
}

#
# _zap_check_plugin_updates - Check if plugin has updates available
#
# Purpose: Compare local and remote commits to detect updates
# Parameters:
#   $1 - Owner
#   $2 - Repo
# Returns: 0 if update available, 1 if current or error
# Output: Version change string (e.g., "v1.0.0 → v1.1.0") if update available
#
# WHY: Non-intrusive update notification (FR-007, cli-interface.md)
#
_zap_check_plugin_updates() {
  local owner="$1"
  local repo="$2"
  local plugin_id="$(_zap_get_plugin_identifier "$owner" "$repo")"
  local cache_dir="$(_zap_get_plugin_cache_dir "$owner" "$repo")"

  # Check if plugin exists
  if [[ ! -d "$cache_dir/.git" ]]; then
    return 1
  fi

  # Get current commit
  local local_commit
  local_commit=$(cd "$cache_dir" && git rev-parse HEAD 2>/dev/null)
  if [[ -z "$local_commit" ]]; then
    return 1
  fi

  # Fetch latest (with timeout per FR-030)
  if ! (cd "$cache_dir" && timeout 10 git fetch origin 2>/dev/null); then
    return 1
  fi

  # Get remote commit
  local remote_commit
  remote_commit=$(cd "$cache_dir" && git rev-parse @{u} 2>/dev/null || git rev-parse origin/HEAD 2>/dev/null)
  if [[ -z "$remote_commit" ]]; then
    return 1
  fi

  # Compare commits
  if [[ "$local_commit" != "$remote_commit" ]]; then
    # Get short SHAs for display
    local local_short=$(cd "$cache_dir" && git rev-parse --short HEAD 2>/dev/null)
    local remote_short=$(cd "$cache_dir" && git rev-parse --short origin/HEAD 2>/dev/null)
    echo "${local_short} → ${remote_short}"
    return 0
  fi

  return 1
}

#
# _zap_list_installed_plugins - List all installed plugins
#
# Purpose: Get list of cached plugins from filesystem
# Parameters: None
# Returns: 0 always
# Output: One plugin per line (owner/repo format)
#
# WHY: Enable listing and status commands (FR-007)
#
_zap_list_installed_plugins() {
  if [[ ! -d "$ZAP_PLUGIN_DIR" ]]; then
    return 0
  fi

  # List all plugin directories
  # WHY: (N) glob qualifier makes pattern expand to nothing if no matches,
  # preventing "no matches found" error when plugin directory is empty
  for plugin_dir in "$ZAP_PLUGIN_DIR"/*(N); do
    if [[ ! -d "$plugin_dir" ]]; then
      continue
    fi

    local dirname=$(basename "$plugin_dir")

    # Convert double underscore back to slash
    if [[ "$dirname" == *__* ]]; then
      echo "${dirname/__//}"
    fi
  done

  return 0
}
