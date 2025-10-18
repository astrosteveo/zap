#!/usr/bin/env zsh
#
# zap.zsh - Main entry point for Zap plugin manager
#
# Usage: Source this file in ~/.zshrc
#   source ~/.zap/zap.zsh
#
# WHY: Single entry point makes installation simple and provides consistent
# environment initialization (per FR-001)

# Determine Zap installation directory
# WHY: Use ${0:A:h} for reliable path resolution across different sourcing contexts
export ZAP_DIR="${0:A:h}"

# Set up environment variables (data-model.md)
export ZAP_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zap"
export ZAP_PLUGIN_DIR="$ZAP_DATA_DIR/plugins"
export ZAP_ERROR_LOG="$ZAP_DATA_DIR/errors.log"
export ZAP_VERSION="1.0.0"

# Create data directories if they don't exist
mkdir -p "$ZAP_PLUGIN_DIR" 2>/dev/null

# Check Zsh version (FR-032: warn if < 5.0)
# WHY: Zap requires Zsh 5.0+ for certain features; warn user but continue
if [[ "${ZSH_VERSION%%.*}" -lt 5 ]]; then
  echo "⚠ Warning: Zap requires Zsh 5.0 or later. Current version: $ZSH_VERSION" >&2
  echo "  Some features may not work correctly. Please upgrade Zsh." >&2
fi

# Detect conflicting plugin managers (FR-034)
# WHY: Multiple plugin managers can cause conflicts; warn user
if [[ -n "${ANTIGEN_CACHE:-}" ]] || [[ -n "${ZINIT_HOME:-}" ]] || [[ -n "${ZPLUG_HOME:-}" ]]; then
  echo "⚠ Warning: Detected another plugin manager (Antigen/zinit/zplug)" >&2
  echo "  Running multiple plugin managers may cause conflicts." >&2
  echo "  Consider removing other managers or use with caution." >&2
fi

# Source library modules
source "$ZAP_DIR/lib/utils.zsh"
source "$ZAP_DIR/lib/parser.zsh"
source "$ZAP_DIR/lib/downloader.zsh"
source "$ZAP_DIR/lib/loader.zsh"
source "$ZAP_DIR/lib/updater.zsh"
source "$ZAP_DIR/lib/framework.zsh"

# Source defaults (sensible keybindings and completions)
source "$ZAP_DIR/lib/defaults.zsh"

#
# zap - Main command dispatcher
#
# Purpose: Route subcommands to appropriate handlers
# Parameters:
#   $1 - Subcommand (load, update, list, clean, doctor, help)
#   $@ - Subcommand arguments
# Returns: Subcommand exit code
#
# WHY: Single entry point for all user commands (cli-interface.md)
#
zap() {
  local subcommand="$1"
  shift

  case "$subcommand" in
    load)
      _zap_cmd_load "$@"
      ;;
    update)
      _zap_cmd_update "$@"
      ;;
    list)
      _zap_cmd_list "$@"
      ;;
    clean)
      _zap_cmd_clean "$@"
      ;;
    doctor)
      _zap_cmd_doctor "$@"
      ;;
    uninstall)
      _zap_cmd_uninstall "$@"
      ;;
    help|--help|-h)
      _zap_cmd_help "$@"
      ;;
    *)
      echo "zap: unknown command '$subcommand'" >&2
      echo "Run 'zap help' for usage information" >&2
      return 1
      ;;
  esac
}

#
# _zap_cmd_load - Load a plugin
#
# Purpose: Parse, download (if needed), and source a plugin
# Parameters:
#   $@ - Plugin specification (owner/repo[@version] [path:subdir])
# Returns: 0 on success, 1 on failure
#
# WHY: Core plugin loading operation (FR-006, FR-008)
# Implements graceful degradation - errors don't block shell startup (FR-015)
#
_zap_cmd_load() {
  # Join all arguments to support both "owner/repo path:subdir" and "owner/repo path:sub dir"
  local spec="$*"

  if [[ -z "$spec" ]]; then
    _zap_print_error "Missing plugin specification" "Usage: zap load owner/repo[@version] [path:subdir]"
    return 1
  fi

  # T060: Profile plugin loading if ZAP_PROFILE is set
  _zap_profile_start "zap load $spec"

  # Parse plugin specification
  local parsed
  if ! parsed=$(_zap_parse_spec "$spec"); then
    # Parse error already logged by _zap_parse_spec
    _zap_profile_end "zap load $spec"
    return 1
  fi

  # Parse pipe-separated output (preserves empty fields)
  # Format: owner|repo|version|subdir
  IFS='|' read owner repo version subdir <<< "$parsed"

  # Check if this is a framework plugin (T051: detect before loading)
  local framework
  local is_framework_base=0
  if framework=$(_zap_detect_framework "$owner" "$repo"); then
    is_framework_base=1
    # Load framework plugin (T052: auto-install framework base)
    if ! _zap_load_framework_plugin "$owner" "$repo" "$subdir"; then
      # Framework setup error already logged
      return 1
    fi
  fi

  # Check if plugin is already cached
  local cache_dir="$(_zap_get_plugin_cache_dir "$owner" "$repo")"

  if [[ ! -d "$cache_dir/.git" ]]; then
    # Download plugin (FR-006, FR-024: synchronous download with progress)
    if ! _zap_check_disk_space; then
      # Disk space error already logged
      return 1
    fi

    if ! _zap_clone_plugin "$owner" "$repo" "$version" "$subdir"; then
      # Clone error already logged
      return 1
    fi
  fi

  # If this is a framework base without subdirectory, don't try to source it
  # Framework bases (ohmyzsh/ohmyzsh, sorin-ionescu/prezto) are libraries, not plugins
  if [[ $is_framework_base -eq 1 && -z "$subdir" ]]; then
    _zap_update_plugin_metadata "$owner" "$repo" "$version" "loaded"
    _zap_print_success "Loaded $framework framework"

    # T060: End profiling
    _zap_profile_end "zap load $spec"
    return 0
  fi

  # Source the plugin (FR-021: file sourcing priority)
  if _zap_source_plugin "$owner" "$repo" "$subdir"; then
    # Update metadata (T033: track version and status)
    _zap_update_plugin_metadata "$owner" "$repo" "$version" "loaded"

    # Only show success on first load (FR-024: subsequent loads silent)
    if [[ ! -f "$cache_dir/.zap_loaded" ]]; then
      _zap_print_success "Loaded $owner/$repo"
      touch "$cache_dir/.zap_loaded" 2>/dev/null
    fi

    # T060: End profiling
    _zap_profile_end "zap load $spec"
    return 0
  else
    # Update metadata with failed status
    _zap_update_plugin_metadata "$owner" "$repo" "$version" "failed"
    # Source error already logged

    # T060: End profiling
    _zap_profile_end "zap load $spec"
    return 1
  fi
}

#
# _zap_cmd_help - Display help information
#
# Purpose: Show usage information and available commands
# Parameters: None
# Returns: 0 always
#
_zap_cmd_help() {
  cat <<'EOF'
Zap - Lightweight Zsh Plugin Manager

Usage:
  zap load <owner>/<repo>[@<version>] [path:<subdir>]
  zap update [<plugin>]
  zap list [--verbose]
  zap clean [--all]
  zap doctor
  zap help [<command>]

Examples:
  zap load zsh-users/zsh-syntax-highlighting
  zap load zsh-users/zsh-autosuggestions@v0.7.0
  zap load ohmyzsh/ohmyzsh path:plugins/git
  zap update
  zap list

For more help: zap help <command>
Documentation: https://github.com/astrosteveo/zap
EOF

  return 0
}

#
# _zap_cmd_update - Update plugins to latest versions
#
# Purpose: Check for and apply updates to installed plugins
# Parameters:
#   $1 - Specific plugin (owner/repo) or empty for all plugins
# Returns: 0 if successful, 1 on error
#
# WHY: Core plugin management operation (FR-007)
#
_zap_cmd_update() {
  local specific_plugin="$1"
  local updated_count=0
  local current_count=0
  local error_count=0

  echo "Checking for updates..."
  echo ""

  # Load metadata
  _zap_load_metadata

  # Get list of plugins to check
  local plugins
  if [[ -n "$specific_plugin" ]]; then
    # Specific plugin requested
    plugins=("$specific_plugin")
  else
    # All installed plugins
    plugins=($(_zap_list_installed_plugins))
  fi

  if [[ ${#plugins[@]} -eq 0 ]]; then
    echo "No plugins installed"
    return 0
  fi

  # Check each plugin
  for plugin in "${plugins[@]}"; do
    # Parse plugin identifier
    local owner="${plugin%%/*}"
    local repo="${plugin##*/}"
    local plugin_id="$(_zap_get_plugin_identifier "$owner" "$repo")"

    # Check if version is pinned (FR-019: respect pins)
    local pinned_version="${ZAP_PLUGIN_META[${plugin_id}:version]}"
    if [[ -n "$pinned_version" && "$pinned_version" != "main" && "$pinned_version" != "master" ]]; then
      echo "  $plugin_id  pinned (skipped)"
      continue
    fi

    # Check for updates
    local update_info
    if update_info=$(_zap_check_plugin_updates "$owner" "$repo"); then
      # Update available
      echo "  $plugin_id  $update_info"

      # Apply update
      if _zap_update_plugin "$owner" "$repo" 0; then
        updated_count=$((updated_count + 1))
      else
        error_count=$((error_count + 1))
      fi
    else
      echo "  $plugin_id  current"
      current_count=$((current_count + 1))
    fi
  done

  # Summary
  echo ""
  if (( updated_count > 0 )); then
    echo "Updated $updated_count plugin(s). Restart your shell to apply changes."
  elif (( error_count > 0 )); then
    echo "Errors occurred during update. Check zap doctor for details."
    return 1
  else
    echo "All plugins are up to date."
  fi

  return 0
}

#
# _zap_cmd_list - List installed plugins with status
#
# Purpose: Display all cached plugins and their versions
# Parameters:
#   --verbose: Show detailed information
# Returns: 0 always
#
# WHY: Enable users to see what's installed (FR-007, cli-interface.md)
#
_zap_cmd_list() {
  local verbose=0

  # Parse flags
  if [[ "$1" == "--verbose" ]]; then
    verbose=1
  fi

  # Load metadata
  _zap_load_metadata

  # Get installed plugins
  local plugins
  plugins=($(_zap_list_installed_plugins))

  if [[ ${#plugins[@]} -eq 0 ]]; then
    echo "No plugins installed"
    echo ""
    echo "Add plugins to your ~/.zshrc:"
    echo "  zap load zsh-users/zsh-syntax-highlighting"
    return 0
  fi

  echo "Installed plugins:"
  echo ""

  # List each plugin
  for plugin in "${plugins[@]}"; do
    local owner="${plugin%%/*}"
    local repo="${plugin##*/}"
    local plugin_id="$(_zap_get_plugin_identifier "$owner" "$repo")"
    local cache_dir="$(_zap_get_plugin_cache_dir "$owner" "$repo")"

    # Get metadata
    local version="${ZAP_PLUGIN_META[${plugin_id}:version]:-unknown}"
    local plugin_status="${ZAP_PLUGIN_META[${plugin_id}:status]:-unknown}"
    local commit="${ZAP_PLUGIN_META[${plugin_id}:commit]:-unknown}"
    local last_check="${ZAP_PLUGIN_META[${plugin_id}:last_check]:-never}"

    # Detect framework plugins
    local framework_note=""
    if [[ "$owner" == "ohmyzsh" || "$owner" == "sorin-ionescu" ]]; then
      framework_note=" (framework)"
    fi

    if [[ $verbose -eq 1 ]]; then
      # Verbose output
      echo "  $plugin_id"
      echo "    Version:  ${version:-latest}"
      echo "    Commit:   ${commit:0:12}"
      echo "    Status:   ✓ $plugin_status$framework_note"
      echo "    Checked:  $last_check"
      echo ""
    else
      # Compact output
      local status_symbol="✓"
      [[ "$plugin_status" == "failed" ]] && status_symbol="✗"
      [[ "$plugin_status" == "disabled" ]] && status_symbol="○"

      printf "  %-40s %-15s %s %s%s\n" \
        "$plugin_id" \
        "${version:-latest}" \
        "$status_symbol" \
        "$plugin_status" \
        "$framework_note"
    fi
  done

  if [[ $verbose -eq 0 ]]; then
    echo ""
  fi

  echo "Total: ${#plugins[@]} plugin(s)"
  echo ""
  echo "Run 'zap list --verbose' for detailed information"

  return 0
}

#
# _zap_cmd_clean - Clean plugin cache
#
# Purpose: Remove unused plugin caches and orphaned files
# Parameters:
#   --all: Remove all caches (requires confirmation)
# Returns: 0 on success, 1 on error
#
# WHY: Allow users to reclaim disk space from unused plugins (FR-023, T078-T079)
#
_zap_cmd_clean() {
  local remove_all=0

  # Parse flags
  if [[ "$1" == "--all" ]]; then
    remove_all=1
  fi

  if [[ $remove_all -eq 1 ]]; then
    # Clean ALL caches (requires confirmation per FR-023)
    echo "This will remove ALL plugin caches and data."
    echo "Plugins will be re-downloaded on next shell startup."
    echo ""
    read "REPLY?Continue? [y/N] "

    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
      echo "Clean cancelled."
      return 0
    fi

    echo "Removing all caches..."

    # Remove plugin directory
    if [[ -d "$ZAP_PLUGIN_DIR" ]]; then
      rm -rf "$ZAP_PLUGIN_DIR" 2>/dev/null
      echo "✓ Removed plugin caches"
    fi

    # Remove metadata
    if [[ -f "$ZAP_DATA_DIR/metadata.zsh" ]]; then
      rm -f "$ZAP_DATA_DIR/metadata.zsh" 2>/dev/null
      echo "✓ Removed metadata"
    fi

    # Remove load order cache
    if [[ -f "$ZAP_DATA_DIR/load-order.cache" ]]; then
      rm -f "$ZAP_DATA_DIR/load-order.cache" 2>/dev/null
      echo "✓ Removed load order cache"
    fi

    # Recreate plugin directory
    mkdir -p "$ZAP_PLUGIN_DIR" 2>/dev/null

    echo ""
    echo "Clean complete. Restart your shell to reload plugins."
    return 0
  else
    # Clean orphaned caches (plugins not in current config)
    echo "Scanning for orphaned plugin caches..."

    # Load metadata to find installed plugins
    _zap_load_metadata

    # Get list of plugins from .zshrc
    local zshrc="${ZDOTDIR:-$HOME}/.zshrc"
    local active_plugins=()

    if [[ -f "$zshrc" ]]; then
      while IFS= read -r line; do
        # Match: zap load owner/repo...
        if [[ "$line" =~ ^[[:space:]]*zap[[:space:]]+load[[:space:]]+([^[:space:]#]+) ]]; then
          local spec="${match[1]}"
          # Parse to get owner/repo
          if parsed=$(_zap_parse_spec "$spec" 2>/dev/null); then
            IFS='|' read owner repo version subdir <<< "$parsed"
            active_plugins+=("${owner}__${repo}")
          fi
        fi
      done < "$zshrc"
    fi

    # Find orphaned caches
    local orphaned_count=0
    local reclaimed_space=0

    for cache_dir in "$ZAP_PLUGIN_DIR"/*; do
      [[ ! -d "$cache_dir" ]] && continue

      local cache_name=$(basename "$cache_dir")

      # Check if this plugin is active
      local is_active=0
      for active in "${active_plugins[@]}"; do
        if [[ "$active" == "$cache_name" ]]; then
          is_active=1
          break
        fi
      done

      if [[ $is_active -eq 0 ]]; then
        # Orphaned cache - calculate size
        local size_kb=$(du -sk "$cache_dir" 2>/dev/null | awk '{print $1}')
        reclaimed_space=$((reclaimed_space + size_kb))

        # Convert cache name back to owner/repo for display
        local display_name="${cache_name/__//}"
        echo "  Removing: $display_name"

        rm -rf "$cache_dir" 2>/dev/null
        orphaned_count=$((orphaned_count + 1))
      fi
    done

    if [[ $orphaned_count -eq 0 ]]; then
      echo "No orphaned caches found."
    else
      local reclaimed_mb=$((reclaimed_space / 1024))
      echo ""
      echo "Removed $orphaned_count orphaned cache(s)"
      echo "Reclaimed ${reclaimed_mb}MB of disk space"
    fi

    return 0
  fi
}

#
# _zap_cmd_doctor - Diagnose issues and display system information
#
# Purpose: Help users troubleshoot problems with zap
# Parameters: None
# Returns: 0 always (diagnostic tool)
#
# WHY: Users need visibility into configuration and potential issues (FR-013, T080)
#
_zap_cmd_doctor() {
  echo "Zap Plugin Manager - System Diagnostics"
  echo "========================================"
  echo ""

  local issues_found=0

  # Check Zsh version
  echo "Zsh Version:"
  local zsh_version="${ZSH_VERSION%%[^0-9.]*}"
  local zsh_major="${zsh_version%%.*}"

  echo "  Installed: Zsh $ZSH_VERSION"

  if (( zsh_major >= 5 )); then
    echo "  Status: ✓ Supported (5.0+ required)"
  else
    echo "  Status: ✗ Unsupported (5.0+ required, found $zsh_version)"
    issues_found=$((issues_found + 1))
  fi
  echo ""

  # Check Git
  echo "Git:"
  if command -v git >/dev/null 2>&1; then
    local git_version=$(git --version 2>&1 | awk '{print $3}')
    echo "  Installed: Git $git_version"
    echo "  Status: ✓ Available"
  else
    echo "  Status: ✗ Not found (required for plugin downloads)"
    issues_found=$((issues_found + 1))
  fi
  echo ""

  # Check Zap installation
  echo "Zap Installation:"
  echo "  ZAP_DIR: $ZAP_DIR"

  if [[ -f "$ZAP_DIR/zap.zsh" ]]; then
    echo "  Status: ✓ Installed"
    if [[ -n "$ZAP_VERSION" ]]; then
      echo "  Version: $ZAP_VERSION"
    fi
  else
    echo "  Status: ✗ zap.zsh not found at $ZAP_DIR"
    issues_found=$((issues_found + 1))
  fi
  echo ""

  # Check data directory
  echo "Data Directory:"
  echo "  Location: $ZAP_DATA_DIR"

  if [[ -d "$ZAP_DATA_DIR" ]]; then
    echo "  Status: ✓ Exists"

    # Check permissions
    if [[ -w "$ZAP_DATA_DIR" ]]; then
      echo "  Permissions: ✓ Writable"
    else
      echo "  Permissions: ✗ Not writable"
      issues_found=$((issues_found + 1))
    fi

    # Check disk space
    local available_mb=$(df -m "$ZAP_DATA_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
    if [[ -n "$available_mb" ]]; then
      echo "  Disk Space: ${available_mb}MB available"

      if (( available_mb < 100 )); then
        echo "  Warning: ⚠ Low disk space (< 100MB)"
        issues_found=$((issues_found + 1))
      fi
    fi
  else
    echo "  Status: ✗ Directory not found"
    issues_found=$((issues_found + 1))
  fi
  echo ""

  # Check plugins
  echo "Plugins:"
  _zap_load_metadata

  local plugins
  plugins=($(_zap_list_installed_plugins))

  if [[ ${#plugins[@]} -eq 0 ]]; then
    echo "  Installed: 0 plugins"
    echo "  Status: ○ No plugins configured"
  else
    echo "  Installed: ${#plugins[@]} plugin(s)"

    local failed_count=0
    for plugin in "${plugins[@]}"; do
      local owner="${plugin%%/*}"
      local repo="${plugin##*/}"
      local plugin_id="$(_zap_get_plugin_identifier "$owner" "$repo")"
      local plugin_status="${ZAP_PLUGIN_META[${plugin_id}:status]:-unknown}"

      if [[ "$plugin_status" == "failed" ]]; then
        failed_count=$((failed_count + 1))
      fi
    done

    if [[ $failed_count -eq 0 ]]; then
      echo "  Status: ✓ All plugins loaded successfully"
    else
      echo "  Status: ✗ $failed_count plugin(s) failed to load"
      issues_found=$((issues_found + 1))
    fi
  fi
  echo ""

  # Check error log
  echo "Error Log:"
  if [[ -f "$ZAP_ERROR_LOG" ]]; then
    local error_count=$(grep -c "ERROR:" "$ZAP_ERROR_LOG" 2>/dev/null || echo 0)
    local warn_count=$(grep -c "WARN:" "$ZAP_ERROR_LOG" 2>/dev/null || echo 0)

    echo "  Location: $ZAP_ERROR_LOG"
    echo "  Errors: $error_count"
    echo "  Warnings: $warn_count"

    if [[ $error_count -gt 0 ]]; then
      echo ""
      echo "  Recent errors (last 5):"
      grep "ERROR:" "$ZAP_ERROR_LOG" | tail -5 | while IFS= read -r line; do
        echo "    $line"
      done
    fi
  else
    echo "  Status: ○ No error log (no errors recorded)"
  fi
  echo ""

  # Check for conflicting plugin managers
  echo "Plugin Manager Conflicts:"
  local conflicts=0

  if [[ -n "${ANTIGEN_RUNNING:-}" ]] || [[ -f "${HOME}/.antigen/antigen.zsh" ]]; then
    echo "  ⚠ Antigen detected"
    conflicts=$((conflicts + 1))
  fi

  if [[ -n "${ZINIT_HOME:-}" ]] || [[ -d "${HOME}/.zinit" ]]; then
    echo "  ⚠ Zinit detected"
    conflicts=$((conflicts + 1))
  fi

  if [[ -n "${ZPLUG_HOME:-}" ]] || [[ -d "${HOME}/.zplug" ]]; then
    echo "  ⚠ Zplug detected"
    conflicts=$((conflicts + 1))
  fi

  if [[ $conflicts -eq 0 ]]; then
    echo "  Status: ✓ No conflicts detected"
  else
    echo "  Warning: Multiple plugin managers may conflict"
    issues_found=$((issues_found + 1))
  fi
  echo ""

  # Summary
  echo "========================================"
  if [[ $issues_found -eq 0 ]]; then
    echo "Status: ✓ All checks passed"
    echo ""
    echo "Your zap installation is healthy!"
  else
    echo "Status: ✗ $issues_found issue(s) found"
    echo ""
    echo "Please address the issues above."
    echo "For help, see: https://github.com/astrosteveo/zap/issues"
  fi

  return 0
}

#
# _zap_cmd_uninstall - Completely remove zap from the system
#
# Purpose: Clean uninstallation with backup of .zshrc
# Parameters: None
# Returns: 0 on success, 1 if cancelled
#
# WHY: Users should be able to cleanly remove zap if they want (FR-023, T085)
#
_zap_cmd_uninstall() {
  echo "Zap Uninstaller"
  echo "==============="
  echo ""
  echo "This will:"
  echo "  1. Remove zap installation from $ZAP_DIR"
  echo "  2. Remove all plugin caches from $ZAP_DATA_DIR"
  echo "  3. Remove zap initialization from .zshrc"
  echo "  4. Create backup of .zshrc"
  echo ""
  echo "WARNING: This cannot be undone!"
  echo ""
  read "REPLY?Continue with uninstall? [y/N] "

  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    return 1
  fi

  echo ""
  echo "Uninstalling zap..."

  # 1. Backup .zshrc
  local zshrc="${ZDOTDIR:-$HOME}/.zshrc"
  if [[ -f "$zshrc" ]]; then
    local backup="${zshrc}.backup.before-zap-uninstall.$(date +%Y%m%d%H%M%S)"
    cp "$zshrc" "$backup" 2>/dev/null
    echo "✓ Created backup: $backup"

    # 2. Remove zap lines from .zshrc
    # Remove from "# === Zap Plugin Manager ===" to the last "# zap load" line
    local temp_file="${zshrc}.tmp.$$"
    local in_zap_section=0

    while IFS= read -r line; do
      # Start of zap section
      if [[ "$line" =~ "=== Zap Plugin Manager ===" ]]; then
        in_zap_section=1
        continue
      fi

      # Skip lines in zap section
      if [[ $in_zap_section -eq 1 ]]; then
        # Check if this is a zap load command or related comment
        if [[ "$line" =~ ^[[:space:]]*(#.*zap|zap[[:space:]]+load|source.*zap\.zsh) ]]; then
          continue
        elif [[ -z "$line" ]]; then
          # Skip empty lines in zap section
          continue
        else
          # End of zap section
          in_zap_section=0
        fi
      fi

      # Keep non-zap lines
      echo "$line"
    done < "$zshrc" > "$temp_file"

    mv "$temp_file" "$zshrc" 2>/dev/null
    echo "✓ Removed zap configuration from .zshrc"
  fi

  # 3. Remove data directory
  if [[ -d "$ZAP_DATA_DIR" ]]; then
    rm -rf "$ZAP_DATA_DIR" 2>/dev/null
    echo "✓ Removed data directory: $ZAP_DATA_DIR"
  fi

  # 4. Remove installation directory
  if [[ -d "$ZAP_DIR" ]]; then
    rm -rf "$ZAP_DIR" 2>/dev/null
    echo "✓ Removed installation: $ZAP_DIR"
  fi

  echo ""
  echo "Uninstall complete!"
  echo ""
  echo "To finish, restart your shell or run: exec zsh"
  echo ""
  echo "Thank you for trying zap! 👋"

  return 0
}

# Initialize completion system
# WHY: Run compinit once after all plugins loaded (FR-022)
# Must be called to activate completions - autoload alone isn't enough
autoload -Uz compinit
compinit -i  # -i flag: silently ignore insecure directories
