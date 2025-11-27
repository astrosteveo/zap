#!/usr/bin/env zsh
#
# loader.zsh - Plugin file sourcing and loading
#
# WHY: Centralized loading logic ensures consistent plugin sourcing order
# and handles various plugin file naming conventions (per FR-021)

# Source utilities
source "${0:A:h}/utils.zsh"

#
# _zap_find_plugin_file - Locate plugin entry point file
#
# Purpose: Find the correct plugin file to source based on priority order
# Parameters:
#   $1 - Plugin cache directory
#   $2 - Plugin name (repo name)
#   $3 - Subdirectory path (optional)
# Returns: 0 if found, 1 if not found
# Output: Path to plugin file on stdout
#
# Priority order (FR-021):
#   1. <name>.plugin.zsh
#   2. <name>.zsh
#   3. <name>.zsh-theme  (for Oh-My-Zsh themes)
#   4. init.zsh
#   5. <repo>.plugin.zsh
#   6. <repo>.zsh
#   7. <repo>.zsh-theme
#
# WHY: Different plugin authors use different naming conventions. This priority
# order supports the most common patterns including Oh-My-Zsh themes (research.md §7)
#
_zap_find_plugin_file() {
  local cache_dir="$1"
  local plugin_name="$2"
  local subdir="${3:-}"

  # Search directory (root or subdirectory)
  local search_dir="$cache_dir"
  if [[ -n "$subdir" ]]; then
    search_dir="$cache_dir/$subdir"

    # Check if subdirectory exists (FR-037)
    if [[ ! -d "$search_dir" ]]; then
      # Use Zsh parameter expansion instead of basename (T059: minimize subshells)
      local cache_name="${cache_dir:t}"
      _zap_print_error "Subdirectory not found" "Expected path: $search_dir" \
        "Check the path: annotation in your plugin specification"
      _zap_log_error "ERROR" "$cache_name" \
        "Subdirectory '$subdir' does not exist" \
        "Verify path: annotation is correct"
      return 1
    fi
  fi

  # Use Zsh parameter expansion :t (tail) instead of basename (T059: avoid subprocess)
  local repo_name="${cache_dir:t}"

  # Try each pattern in priority order (T059: build patterns without subshells)
  local candidate
  for candidate in \
    "${search_dir}/${plugin_name}.plugin.zsh" \
    "${search_dir}/${plugin_name}.zsh" \
    "${search_dir}/${plugin_name}.zsh-theme" \
    "${search_dir}/init.zsh" \
    "${search_dir}/${repo_name}.plugin.zsh" \
    "${search_dir}/${repo_name}.zsh" \
    "${search_dir}/${repo_name}.zsh-theme"
  do
    # Early return on first match (T059: minimize iterations)
    [[ -f "$candidate" ]] && echo "$candidate" && return 0
  done

  # No plugin file found
  return 1
}

#
# _zap_source_plugin - Source plugin file into shell environment
#
# Purpose: Load plugin by sourcing its entry point file
# Parameters:
#   $1 - Owner
#   $2 - Repo
#   $3 - Subdirectory path (optional)
# Returns: 0 on success, 1 on failure
#
# WHY: Plugin loading is the core operation of the plugin manager (FR-006, FR-008)
# Errors are logged but don't block shell startup (FR-015)
#
_zap_source_plugin() {
  local owner="$1"
  local repo="$2"
  local subdir="${3:-}"

  # T059: Inline identifier construction instead of function call
  local plugin_id="${owner}/${repo}"

  # T059: Inline cache dir construction instead of function call
  local cache_dir="${ZAP_PLUGIN_DIR}/${owner}__${repo}"

  # Combined existence and corruption check (T059: minimize stat calls)
  if [[ ! -d "$cache_dir/.git" ]]; then
    if [[ ! -d "$cache_dir" ]]; then
      _zap_print_error "Plugin not cached" "$plugin_id not found" \
        "This should have been downloaded automatically"
      _zap_log_error "ERROR" "$plugin_id" "Plugin cache directory missing" \
        "Cache directory should exist at: $cache_dir"
    else
      # Cache exists but .git is missing - corrupted
      _zap_print_error "Cache corrupted" "$plugin_id is missing .git directory" \
        "Run 'zap clean && zap load $plugin_id' to re-download"
      _zap_log_error "ERROR" "$plugin_id" "Corrupted cache (missing .git directory)" \
        "Remove corrupted cache and re-download"
      # Remove corrupted cache (FR-031)
      rm -rf "$cache_dir" 2>/dev/null
    fi
    return 1
  fi

  # Find plugin file
  # WHY: For subdirectory plugins, the plugin name is the subdirectory basename (e.g., "docker" from "plugins/docker")
  local plugin_name="$repo"
  if [[ -n "$subdir" ]]; then
    plugin_name="${subdir:t}"  # Use Zsh :t modifier to get basename
  fi

  local plugin_file
  if ! plugin_file=$(_zap_find_plugin_file "$cache_dir" "$plugin_name" "$subdir"); then
    _zap_print_error "Plugin file not found" "No entry point in $plugin_id" \
      "Plugin may not be compatible with zap"
    _zap_log_error "ERROR" "$plugin_id" "No plugin file found" \
      "Searched for: *.plugin.zsh, *.zsh, init.zsh"
    return 1
  fi

  # Source the plugin file
  # WHY: Silent sourcing prevents plugin output from cluttering shell startup
  # T059: Direct source is faster than testing return code separately
  if source "$plugin_file" 2>/dev/null; then
    # Post-load actions for special plugin types
    _zap_handle_post_load "$plugin_id" "$plugin_file"
    return 0
  fi

  # Source failed
  _zap_print_error "Failed to load $plugin_id" "Plugin source failed" \
    "Plugin may have syntax errors or missing dependencies"
  _zap_log_error "ERROR" "$plugin_id" "Source command failed" \
    "Check plugin for syntax errors"
  return 1
}

#
# _zap_handle_post_load - Handle special post-load actions for specific plugins
#
# Purpose: Provide helpful guidance for plugins that need additional configuration
# Parameters:
#   $1 - Plugin identifier (owner/repo)
#   $2 - Plugin file path that was sourced
# Returns: 0 always
#
# WHY: Some plugins (especially themes) require additional configuration steps
# that aren't obvious to new users. This improves first-time user experience.
#
_zap_handle_post_load() {
  local plugin_id="$1"
  local plugin_file="$2"

  # Detect theme files
  if [[ "$plugin_file" == *.zsh-theme ]]; then
    # Special handling for powerlevel10k
    if [[ "$plugin_id" == *"powerlevel10k"* ]]; then
      # Only show configuration hint if p10k config doesn't exist and not in quiet mode
      if [[ ! -f ~/.p10k.zsh ]] && [[ -z "${ZAP_QUIET:-}" ]]; then
        echo ""
        echo "💡 Powerlevel10k Quick Start:"
        echo "   Run: p10k configure"
        echo "   This will guide you through prompt customization."
        echo ""
        echo "   After configuration, add to your .zshrc:"
        echo "   [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh"
        echo ""
      fi
    fi
  fi

  return 0
}

#
# _zap_add_to_fpath - Add plugin directory to fpath for completions
#
# Purpose: Enable plugin completions by adding to fpath
# Parameters:
#   $1 - Directory path to add
# Returns: 0 always
#
# WHY: Many plugins provide completions that need to be on fpath (FR-022)
#
_zap_add_to_fpath() {
  local dir="$1"

  # Only add if directory exists and not already on fpath
  if [[ -d "$dir" ]] && (( ! ${fpath[(I)$dir]} )); then
    fpath=("$dir" $fpath)
  fi

  return 0
}
