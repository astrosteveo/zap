#!/usr/bin/env zsh
#
# downloader.zsh - Git plugin downloading and version management
#
# WHY: Centralized download logic ensures consistent Git operations and
# error handling across all plugin installations (per FR-003, FR-004)

# Source utilities
source "${0:A:h}/utils.zsh"

#
# _zap_clone_plugin - Clone plugin repository to cache
#
# Purpose: Download plugin from Git repository to local cache
# Parameters:
#   $1 - Owner
#   $2 - Repo
#   $3 - Version (tag, commit, or branch) - optional
#   $4 - Subdirectory (optional: use sparse checkout for this path only)
# Returns: 0 on success, 1 on failure
#
# WHY: Git clone is the primary mechanism for plugin installation (FR-003)
# Failures are logged but don't block shell startup (FR-015, FR-018)
# Sparse checkout reduces bandwidth and disk usage for large framework repos
#
_zap_clone_plugin() {
  local owner="$1"
  local repo="$2"
  local version="${3:-}"
  local subdir="${4:-}"
  local plugin_id="$(_zap_get_plugin_identifier "$owner" "$repo")"
  local cache_dir="$(_zap_get_plugin_cache_dir "$owner" "$repo")"

  # Check if already cloned
  if [[ -d "$cache_dir/.git" ]]; then
    # If this is a sparse checkout and a subdirectory is requested, add it
    # WHY: Multiple Oh-My-Zsh plugins need their own subdirectories added to sparse checkout
    if [[ -n "$subdir" ]]; then
      (
        cd "$cache_dir" 2>/dev/null || exit 1
        # Check if sparse checkout is active
        if git sparse-checkout list >/dev/null 2>&1; then
          # Check if this subdirectory is already in sparse checkout
          if ! git sparse-checkout list | grep -q "^${subdir}$"; then
            # Add subdirectory to sparse checkout
            git sparse-checkout add "$subdir" 2>/dev/null
            # Fetch and checkout the new files
            # WHY: With --filter=blob:none, files aren't fetched until explicitly requested
            timeout 10 git fetch --depth 1 >/dev/null 2>&1
            git checkout >/dev/null 2>&1
          fi
        fi
      )
    fi
    return 0
  fi

  # Ensure plugin directory exists
  mkdir -p "$(dirname "$cache_dir")" 2>/dev/null

  # Show download progress (FR-024)
  # WHY: Show subdirectory for framework plugins to clarify what's being loaded
  if [[ -n "$subdir" && ("$owner" == "ohmyzsh" || "$owner" == "sorin-ionescu") ]]; then
    _zap_print_downloading "$owner/$repo/$subdir"
  else
    _zap_print_downloading "$plugin_id"
  fi

  # Construct Git URL (support GitHub, GitLab, Bitbucket)
  # WHY: Default to HTTPS for GitHub but allow any Git hosting (FR-003)
  local git_url="https://github.com/${owner}/${repo}.git"

  # Clone with sparse checkout if subdirectory specified
  # WHY: Large repos like ohmyzsh/ohmyzsh (300+ plugins) waste bandwidth/disk
  # when only one subdirectory is needed. Sparse checkout downloads only needed files.
  local clone_output
  local clone_status

  if [[ -n "$subdir" ]]; then
    # Sparse checkout for subdirectory-only download
    # WHY: --filter=blob:none fetches only needed blobs, --sparse enables sparse checkout
    clone_output=$(
      timeout 10 git clone --filter=blob:none --sparse --depth 1 "$git_url" "$cache_dir" 2>&1 &&
      cd "$cache_dir" &&
      git sparse-checkout set "$subdir" 2>&1
    )
    clone_status=$?
  else
    # Full clone with depth 1 (shallow clone)
    clone_output=$(timeout 10 git clone --depth 1 "$git_url" "$cache_dir" 2>&1)
    clone_status=$?
  fi

  if [[ $clone_status -ne 0 ]]; then
    # Determine failure reason (FR-029)
    if [[ $clone_status -eq 124 ]]; then
      _zap_log_error "ERROR" "$plugin_id" "Network timeout after 10 seconds" \
        "Check network connection and try again"
      _zap_print_error "Failed to download $plugin_id" "Network timeout" \
        "Check your internet connection"
    elif [[ "$clone_output" == *"not found"* || "$clone_output" == *"404"* ]]; then
      _zap_log_error "ERROR" "$plugin_id" "Repository not found (HTTP 404)" \
        "Check repository name: $git_url"
      _zap_print_error "Failed to download $plugin_id" "Repository not found" \
        "Verify the repository exists at $git_url"
    elif [[ "$clone_output" == *"Authentication"* || "$clone_output" == *"Permission denied"* ]]; then
      _zap_log_error "ERROR" "$plugin_id" "Authentication failed" \
        "Configure Git credentials for private repositories"
      _zap_print_error "Failed to download $plugin_id" "Authentication required" \
        "This may be a private repository requiring credentials"
    else
      _zap_log_error "ERROR" "$plugin_id" "Git clone failed: $clone_output" \
        "See error log: $ZAP_ERROR_LOG"
      _zap_print_error "Failed to download $plugin_id" "Git clone failed" \
        "Run 'zap doctor' for diagnostics"
    fi

    return 1
  fi

  # Checkout specific version if provided (FR-004)
  if [[ -n "$version" ]]; then
    if ! _zap_checkout_version "$owner" "$repo" "$version"; then
      # Version checkout failed but plugin is downloaded
      # WHY: Fall back to latest version per FR-019
      _zap_print_error "Version $version not found" "Using latest version instead"
      _zap_log_error "WARN" "$plugin_id" "Invalid version pin: $version" \
        "Falling back to latest version (main/master)"
    fi
  fi

  return 0
}

#
# _zap_checkout_version - Checkout specific plugin version
#
# Purpose: Switch plugin to specific Git ref (tag, commit, or branch)
# Parameters:
#   $1 - Owner
#   $2 - Repo
#   $3 - Version (tag, commit, or branch)
# Returns: 0 on success, 1 on failure
#
# WHY: Version pinning requirement (FR-004, FR-019)
#
_zap_checkout_version() {
  local owner="$1"
  local repo="$2"
  local version="$3"
  local plugin_id="$(_zap_get_plugin_identifier "$owner" "$repo")"
  local cache_dir="$(_zap_get_plugin_cache_dir "$owner" "$repo")"

  # Validate cache directory exists
  if [[ ! -d "$cache_dir/.git" ]]; then
    return 1
  fi

  # Try checkout (research.md §7: tags, commits, branches)
  (
    cd "$cache_dir" || exit 1

    # Fetch if not a local ref
    git fetch --depth 1 origin "$version" 2>/dev/null || true

    # Try as tag first, then commit, then branch
    if git checkout --quiet "tags/$version" 2>/dev/null; then
      return 0
    elif git checkout --quiet "$version" 2>/dev/null; then
      return 0
    else
      return 1
    fi
  )

  return $?
}

#
# _zap_check_disk_space - Verify sufficient disk space before download
#
# Purpose: Prevent partial downloads when disk is full
# Parameters: None
# Returns: 0 if sufficient space (>= 100MB), 1 if insufficient
#
# WHY: Disk space failures should be detected early with clear messages (FR-038)
#
_zap_check_disk_space() {
  # Get available space in MB for ZAP_DATA_DIR
  # WHY: Different systems use different df output formats
  local available_mb

  if df -m "$ZAP_DATA_DIR" 2>/dev/null | tail -1 | awk '{print $4}' | grep -q '^[0-9]\+$'; then
    available_mb=$(df -m "$ZAP_DATA_DIR" 2>/dev/null | tail -1 | awk '{print $4}')
  else
    # Fallback: assume sufficient space if check fails
    return 0
  fi

  if (( available_mb < 100 )); then
    _zap_print_error "Insufficient disk space" "Only ${available_mb}MB available" \
      "Free up at least 100MB and try again"
    _zap_log_error "ERROR" "disk-space" "Insufficient space: ${available_mb}MB available" \
      "Free up disk space before downloading plugins"
    return 1
  fi

  return 0
}

#
# _zap_update_plugin - Update plugin to latest version
#
# Purpose: Pull latest changes from plugin repository
# Parameters:
#   $1 - Owner
#   $2 - Repo
#   $3 - Respect version pin (1 = skip pinned plugins, 0 = update anyway)
# Returns: 0 if updated, 1 if already current or error, 2 if pinned
#
# WHY: Update command requirement (FR-007)
#
_zap_update_plugin() {
  local owner="$1"
  local repo="$2"
  local respect_pin="${3:-1}"
  local plugin_id="$(_zap_get_plugin_identifier "$owner" "$repo")"
  local cache_dir="$(_zap_get_plugin_cache_dir "$owner" "$repo")"

  # Check if plugin exists
  if [[ ! -d "$cache_dir/.git" ]]; then
    _zap_print_error "Plugin not installed" "$plugin_id" \
      "Run 'zap load $plugin_id' first"
    return 1
  fi

  # Pull latest changes
  (
    cd "$cache_dir" || exit 1

    # Fetch with timeout
    if ! timeout 10 git fetch origin 2>/dev/null; then
      _zap_print_error "Failed to check updates for $plugin_id" "Network timeout"
      return 1
    fi

    # Check if updates available
    local local_commit=$(git rev-parse HEAD 2>/dev/null)
    local remote_commit=$(git rev-parse @{u} 2>/dev/null || git rev-parse origin/HEAD 2>/dev/null)

    if [[ "$local_commit" == "$remote_commit" ]]; then
      return 1  # Already current
    fi

    # Pull updates
    if git pull --ff-only 2>/dev/null; then
      return 0  # Updated
    else
      return 1  # Update failed
    fi
  )

  return $?
}
