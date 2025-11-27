#!/usr/bin/env zsh
#
# parser.zsh - Plugin specification parsing
#
# WHY: Centralized parsing ensures consistent interpretation of plugin specs
# across all zap commands (per FR-020, FR-002)

# Source utilities
source "${0:A:h}/utils.zsh"

#
# _zap_parse_spec - Parse plugin specification into components
#
# Purpose: Extract owner, repo, version, and subdirectory from plugin spec
# Parameters:
#   $1 - Plugin specification (owner/repo[@version] [path:subdir])
# Returns: 0 on success, 1 on parse error
# Output: Four pipe-separated values: owner|repo|version|subdir
#
# Format: owner/repo[@version] [path:subdir]
# Examples:
#   zsh-users/zsh-syntax-highlighting → "zsh-users|zsh-syntax-highlighting||"
#   zsh-users/zsh-autosuggestions@v0.7.0 → "zsh-users|zsh-autosuggestions|v0.7.0|"
#   ohmyzsh/ohmyzsh path:plugins/git → "ohmyzsh|ohmyzsh||plugins/git"
#   romkatv/powerlevel10k@v1.16.1 → "romkatv|powerlevel10k|v1.16.1|"
#
# WHY: Structured parsing enables validation and prevents malformed specs
# from causing errors downstream (FR-027)
#
_zap_parse_spec() {
  local spec="$1"
  local owner repo version subdir

  # Remove leading/trailing whitespace
  spec="${spec##[[:space:]]}"
  spec="${spec%%[[:space:]]}"

  # Skip empty lines and comments
  [[ -z "$spec" || "$spec" == \#* ]] && return 1

  # Extract path annotation if present (FR-005)
  if [[ "$spec" == *" path:"* ]]; then
    subdir="${spec##* path:}"
    spec="${spec%% path:*}"
  else
    subdir=""
  fi

  # Extract version pin if present (FR-004)
  if [[ "$spec" == *@* ]]; then
    version="${spec##*@}"
    spec="${spec%@*}"
  else
    version=""
  fi

  # Split owner/repo (FR-002)
  if [[ "$spec" == */* ]]; then
    owner="${spec%%/*}"
    repo="${spec##*/}"
  else
    _zap_print_error "Invalid plugin specification" "Missing owner/repo format" \
      "Use format: owner/repo (e.g., zsh-users/zsh-syntax-highlighting)"
    return 1
  fi

  # Validate components (FR-027)
  if ! _zap_sanitize_repo_name "$owner/$repo" >/dev/null; then
    _zap_print_error "Invalid repository name" "$owner/$repo contains invalid characters" \
      "Repository names must be alphanumeric with dashes/underscores only"
    return 1
  fi

  if [[ -n "$version" ]] && ! _zap_sanitize_version "$version" >/dev/null; then
    _zap_print_error "Invalid version string" "$version contains invalid characters" \
      "Version must be a valid Git ref (tag, branch, or commit)"
    return 1
  fi

  if [[ -n "$subdir" ]] && ! _zap_sanitize_path "$subdir" >/dev/null; then
    _zap_print_error "Invalid subdirectory path" "$subdir is not a safe relative path" \
      "Path must be relative with no parent directory traversal (..)"
    return 1
  fi

  # Output parsed components (pipe-separated to preserve empty fields)
  # WHY: Space delimiter causes issues when fields are empty (consecutive spaces collapse)
  echo "$owner|$repo|$version|$subdir"
  return 0
}

#
# _zap_parse_config_file - Parse plugin configuration file
#
# Purpose: Read and parse all plugin specifications from config file
# Parameters:
#   $1 - Path to configuration file
# Returns: 0 on success, 1 if file doesn't exist
# Output: One parsed spec per line (owner repo version subdir)
#
# WHY: File-based configuration enables clean separation of plugin list
# from .zshrc and supports bulk operations (FR-014)
#
_zap_parse_config_file() {
  local config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    _zap_print_error "Configuration file not found" "$config_file does not exist"
    return 1
  fi

  # Parse each line (FR-020: one spec per line, # for comments)
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue

    # Parse the specification
    if _zap_parse_spec "$line"; then
      # Success - output already written by _zap_parse_spec
      :
    else
      # Parse error - already logged by _zap_parse_spec
      # Continue with next line (graceful degradation per FR-015)
      continue
    fi
  done < "$config_file"

  return 0
}

#
# _zap_get_plugin_cache_dir - Get cache directory path for plugin
#
# Purpose: Compute standardized cache directory name for plugin
# Parameters:
#   $1 - Owner
#   $2 - Repo
# Returns: 0 always
# Output: Absolute path to plugin cache directory
#
# Format: ${ZAP_PLUGIN_DIR}/<owner>__<repo>
# WHY: Double underscore separator prevents filename conflicts and makes
# cache directory names deterministic (data-model.md §2)
#
_zap_get_plugin_cache_dir() {
  local owner="$1"
  local repo="$2"

  echo "${ZAP_PLUGIN_DIR}/${owner}__${repo}"
  return 0
}

#
# _zap_get_plugin_identifier - Get standardized plugin identifier
#
# Purpose: Create consistent plugin identifier for logging and display
# Parameters:
#   $1 - Owner
#   $2 - Repo
# Returns: 0 always
# Output: Plugin identifier (owner/repo)
#
_zap_get_plugin_identifier() {
  local owner="$1"
  local repo="$2"

  echo "${owner}/${repo}"
  return 0
}

#
# _zap_get_config_hash - Generate hash of configuration file
#
# Purpose: Create fingerprint of config to detect changes
# Parameters:
#   $1 - Path to configuration file
# Returns: 0 on success, 1 on error
# Output: Hash string (using git hash-object if available, or cksum)
#
# WHY: Hash-based cache invalidation is more reliable than mtime alone
# (handles file reverts, cross-system sync issues per T058)
#
_zap_get_config_hash() {
  local config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    return 1
  fi

  # Try git hash-object first (deterministic, content-based)
  if command -v git >/dev/null 2>&1; then
    git hash-object "$config_file" 2>/dev/null && return 0
  fi

  # Fallback to cksum (available on all POSIX systems)
  cksum "$config_file" 2>/dev/null | awk '{print $1}' && return 0

  return 1
}

#
# _zap_get_cache_file_path - Get path to load order cache file
#
# Purpose: Standardized cache file location
# Parameters: None
# Returns: 0 always
# Output: Absolute path to cache file
#
_zap_get_cache_file_path() {
  echo "${ZAP_DATA_DIR}/load-order.cache"
  return 0
}

#
# _zap_is_cache_valid - Check if load order cache is valid
#
# Purpose: Determine if cached load order can be used
# Parameters:
#   $1 - Path to configuration file
# Returns: 0 if cache is valid, 1 if invalid/missing
#
# WHY: Avoid reparsing config on every shell startup when nothing changed
# (performance optimization per T058, data-model.md §3)
#
_zap_is_cache_valid() {
  local config_file="$1"
  local cache_file="$(_zap_get_cache_file_path)"

  # Cache file must exist
  [[ ! -f "$cache_file" ]] && return 1

  # Config file must exist
  [[ ! -f "$config_file" ]] && return 1

  # Get current config hash
  local current_hash
  current_hash=$(_zap_get_config_hash "$config_file") || return 1

  # Read cached hash from cache file header
  local cached_hash
  cached_hash=$(grep "^# Config hash:" "$cache_file" 2>/dev/null | awk '{print $4}')

  # Compare hashes
  [[ "$current_hash" == "$cached_hash" ]] && return 0

  return 1
}

#
# _zap_generate_load_order_cache - Generate load order cache from config
#
# Purpose: Parse config file and write cached load order
# Parameters:
#   $1 - Path to configuration file
# Returns: 0 on success, 1 on error
# Side Effects: Writes to $ZAP_DATA_DIR/load-order.cache
#
# WHY: Pre-parsed cache eliminates parsing overhead on shell startup
# (FR-008, T057, data-model.md §3)
#
_zap_generate_load_order_cache() {
  local config_file="$1"
  local cache_file="$(_zap_get_cache_file_path)"
  local temp_file="${cache_file}.tmp.$$"

  # Create data directory if needed
  mkdir -p "$(dirname "$cache_file")" 2>/dev/null

  # Get config hash for cache invalidation
  local config_hash
  config_hash=$(_zap_get_config_hash "$config_file") || config_hash="unknown"

  # Write cache header and array declaration
  {
    echo "# Generated cache - DO NOT EDIT MANUALLY"
    echo "# Config hash: $config_hash"
    echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)"
    echo ""
    echo "typeset -ga ZAP_LOAD_ORDER"
    echo "ZAP_LOAD_ORDER=("
  } > "$temp_file" 2>/dev/null || return 1

  # Parse config file and write entries
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue

    # Parse the specification
    local parsed
    if parsed=$(_zap_parse_spec "$line"); then
      IFS='|' read owner repo version subdir <<< "$parsed"
      # Format: owner/repo:version:subdirectory:flags
      echo "  \"${owner}/${repo}:${version}:${subdir}:\""
    fi
  done < "$config_file" >> "$temp_file" 2>/dev/null

  # Close array
  echo ")" >> "$temp_file" 2>/dev/null

  # Atomic rename (FR-035)
  if mv "$temp_file" "$cache_file" 2>/dev/null; then
    return 0
  else
    rm -f "$temp_file" 2>/dev/null
    return 1
  fi
}

#
# _zap_load_cached_order - Load plugins from cache
#
# Purpose: Source cached load order instead of parsing config
# Parameters: None
# Returns: 0 on success, 1 on error
# Side Effects: Sets global ZAP_LOAD_ORDER array
#
# WHY: Sourcing pre-parsed cache is faster than parsing on every startup
# (performance optimization per T057)
#
_zap_load_cached_order() {
  local cache_file="$(_zap_get_cache_file_path)"

  if [[ ! -f "$cache_file" ]]; then
    return 1
  fi

  # Source the cache file to set ZAP_LOAD_ORDER
  source "$cache_file" 2>/dev/null || return 1

  return 0
}
