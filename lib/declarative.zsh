#!/usr/bin/env zsh
#
# declarative.zsh - Declarative plugin management for Zap
#
# This module implements the core declarative plugin management paradigm,
# inspired by NixOS, Docker Compose, and Kubernetes patterns. It enables users
# to declare their desired plugin state in a plugins=() array and provides
# commands for experimentation, reconciliation, and state inspection.
#
# Key functions:
#   _zap_validate_plugin_spec()      - Validate plugin specifications
#   _zap_parse_plugin_spec()         - Parse owner/repo/@version/:subdir
#   _zap_load_declared_plugins()     - Load plugins from plugins=() array
#   _zap_calculate_drift()           - Compare declared vs current state
#   zap try                          - Load experimental plugin
#   zap sync                         - Reconcile to declared state
#   zap adopt                        - Promote experimental to declared
#   zap status                       - Show current plugin state
#   zap diff                         - Preview sync changes
#
# WHY: Declarative configuration eliminates repetitive zap load commands,
# enables version-controlled dotfiles, and provides infrastructure-as-code
# semantics for shell plugin management. This aligns with Constitution
# Principle VIII (Declarative Configuration).
#

# Source dependencies - integrate with existing Zap infrastructure
source "${0:A:h}/utils.zsh"
source "${0:A:h}/parser.zsh"
source "${0:A:h}/state.zsh"
source "${0:A:h}/downloader.zsh"
source "${0:A:h}/loader.zsh"

#
# _zap_validate_plugin_spec - Validate plugin specification format and security
#
# Parameters:
#   $1 - plugin_spec (e.g., "owner/repo@version:subdir")
#
# Returns: 0 if valid, 1 if invalid
#
# Valid formats:
#   owner/repo
#   owner/repo@version
#   owner/repo:subdir
#   owner/repo@version:subdir
#
# WHY: Plugin specifications come from user .zshrc files and must be strictly
# validated to prevent path traversal (../../../etc/passwd) and command
# injection (owner/repo; rm -rf /) attacks per FR-027.
#
# Security checks:
# - No path traversal (../, absolute paths, ~/)
# - No command injection (;, `, $(), |, &, etc.)
# - No shell metacharacters or wildcards
# - Reasonable length limit (< 256 chars)
# - Valid character set only
#
_zap_validate_plugin_spec() {
  local spec="$1"

  # Empty or whitespace-only check
  if [[ -z "$spec" || "$spec" =~ ^[[:space:]]*$ ]]; then
    return 1
  fi

  # Length limit (DoS prevention)
  if [[ ${#spec} -gt 256 ]]; then
    echo "Error: Plugin specification too long (max 256 chars)" >&2
    return 1
  fi

  # Path traversal checks - reject consecutive dots (..)
  if [[ "$spec" == *..* ]]; then
    echo "Error: Path traversal detected in plugin specification" >&2
    return 1
  fi

  # Absolute path check
  if [[ "$spec" =~ ^/ ]]; then
    echo "Error: Absolute paths not allowed in plugin specification" >&2
    return 1
  fi

  # Home directory expansion check
  if [[ "$spec" =~ ^~ ]]; then
    echo "Error: Home directory expansion not allowed in plugin specification" >&2
    return 1
  fi

  # Command injection checks (shell metacharacters)
  # Use glob patterns for dangerous characters instead of regex
  case "$spec" in
    *\;* | *\`* | *\$* | *\&* | *\|* | *\>* | *\<* | *\** | *\?* | *\[* | *\]* | *\{* | *\}* | *\(* | *\)* | *\\*)
      echo "Error: Invalid characters detected in plugin specification" >&2
      return 1
      ;;
  esac

  # Additional check for newlines and control characters
  if [[ "$spec" == *$'\n'* || "$spec" == *$'\r'* || "$spec" == *$'\x00'* ]]; then
    echo "Error: Control characters not allowed in plugin specification" >&2
    return 1
  fi

  # Format validation: owner/repo[@version][:subdir]
  # Allowed characters: a-z, A-Z, 0-9, hyphen, underscore, dot, forward slash, @, :
  if ! [[ "$spec" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9._-]+(@[a-zA-Z0-9._-]+)?(:[a-zA-Z0-9/_-]+)?$ ]]; then
    echo "Error: Invalid plugin specification format" >&2
    return 1
  fi

  return 0
}

#
# _zap_parse_plugin_spec - Parse plugin specification into components
#
# Parameters:
#   $1 - plugin_spec (e.g., "owner/repo@version:subdir")
#
# Output: Sets global variables:
#   ZAP_PARSED_OWNER       - Repository owner (e.g., "zsh-users")
#   ZAP_PARSED_REPO        - Repository name (e.g., "zsh-autosuggestions")
#   ZAP_PARSED_VERSION     - Version/tag/branch/commit (empty if not specified)
#   ZAP_PARSED_SUBDIR      - Subdirectory path (empty if not specified)
#   ZAP_PARSED_NAME        - Full name "owner/repo" (for state tracking)
#
# Returns: 0 on success, 1 on parse error
#
# WHY: Plugin specifications have optional components (@version, :subdir).
# We need to extract each component for use in Git operations, path resolution,
# and state tracking. Using global variables avoids subshell array return complexity.
#
_zap_parse_plugin_spec() {
  local spec="$1"

  # Validate first
  if ! _zap_validate_plugin_spec "$spec"; then
    return 1
  fi

  # Clear previous parse results
  typeset -g ZAP_PARSED_OWNER=""
  typeset -g ZAP_PARSED_REPO=""
  typeset -g ZAP_PARSED_VERSION=""
  typeset -g ZAP_PARSED_SUBDIR=""
  typeset -g ZAP_PARSED_NAME=""

  # Extract subdirectory (after :)
  if [[ "$spec" =~ :([^:]+)$ ]]; then
    ZAP_PARSED_SUBDIR="${match[1]}"
    # Remove :subdir from spec for further parsing
    spec="${spec%:*}"
  fi

  # Extract version (after @)
  if [[ "$spec" =~ @([^@]+)$ ]]; then
    ZAP_PARSED_VERSION="${match[1]}"
    # Remove @version from spec for further parsing
    spec="${spec%@*}"
  fi

  # Extract owner/repo (what's left)
  if [[ "$spec" =~ ^([^/]+)/(.+)$ ]]; then
    ZAP_PARSED_OWNER="${match[1]}"
    ZAP_PARSED_REPO="${match[2]}"
    ZAP_PARSED_NAME="${match[1]}/${match[2]}"
  else
    echo "Error: Failed to parse owner/repo from: $spec" >&2
    return 1
  fi

  return 0
}

#
# _zap_extract_plugins_array - Extract plugin specifications from plugins=() array
#
# Parameters:
#   $1 - file_path (path to .zshrc or config file containing plugins=() array)
#
# Output: Prints plugin specifications (one per line) to stdout
#
# Returns: 0 on success, 1 on error
#
# WHY: Users declare plugins in a plugins=() array in their .zshrc. This function
# extracts those declarations using text-based parsing (not eval) to avoid
# executing arbitrary code during parsing. We handle multiline arrays, quoted
# elements, comments, and blank lines.
#
# Security: Uses text parsing, never eval, to prevent code execution.
#
_zap_extract_plugins_array() {
  local file_path="$1"

  # Validate input
  if [[ ! -f "$file_path" ]]; then
    echo "Error: File not found: $file_path" >&2
    return 1
  fi

  # Strategy: Extract the plugins=() array declaration using text parsing
  # 1. Find the line starting with "plugins=("
  # 2. Extract all content until we find the closing ")"
  # 3. Parse each line, stripping quotes and comments
  # 4. Return one plugin per line

  local in_array=0
  local found_array=0
  local -a plugins

  while IFS= read -r line; do
    # Strip leading whitespace for easier matching
    local trimmed="${line#"${line%%[![:space:]]*}"}"

    # If we already found and finished an array, stop processing
    if [[ $found_array -eq 1 && $in_array -eq 0 ]]; then
      break
    fi

    # Check if we're starting the plugins array (using glob pattern, not regex)
    if [[ "$trimmed" == plugins=\(* ]]; then
      in_array=1
      found_array=1
      # Handle single-line array: plugins=( plugin1 plugin2 )
      if [[ "$trimmed" == *\) ]]; then
        # Extract content between ( and )
        local content="${trimmed#plugins=\(}"
        content="${content%\)*}"
        # Parse elements from single line
        local -a elements
        elements=(${(z)content})  # Use (z) flag for shell word splitting
        for elem in "${elements[@]}"; do
          # Strip quotes using (Q) flag
          elem="${(Q)elem}"
          # Skip empty or comment lines
          if [[ -n "$elem" && "$elem" != \#* ]]; then
            plugins+=("$elem")
          fi
        done
        in_array=0
        # Break immediately after single-line array
        break
      fi
      continue
    fi

    # If we're inside the array, parse elements
    if [[ $in_array -eq 1 ]]; then
      # Check for closing ) (using glob pattern)
      if [[ "$trimmed" == \) || "$trimmed" == \)* ]]; then
        in_array=0
        # Don't continue - let the break condition at top of loop handle it
        continue
      fi

      # Skip comments and blank lines
      if [[ "$line" =~ ^[[:space:]]*# || "$line" =~ ^[[:space:]]*$ ]]; then
        continue
      fi

      # Extract plugin specification from line
      # Remove leading/trailing whitespace
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"

      # Parse elements (may have multiple per line, or quotes)
      local -a elements
      elements=(${(z)line})  # Use (z) flag for shell word splitting

      for elem in "${elements[@]}"; do
        # Strip quotes using (Q) flag
        elem="${(Q)elem}"
        # Skip empty elements, comments, or closing parenthesis
        if [[ -n "$elem" && "$elem" != \#* && "$elem" != ")" ]]; then
          plugins+=("$elem")
        fi
      done
    fi
  done < "$file_path"

  # Output plugins (one per line)
  printf '%s\n' "${plugins[@]}"
  return 0
}

#
# _zap_load_declared_plugins - Load plugins from plugins=() array declaration
#
# Parameters:
#   $1 - config_file (path to .zshrc or config file containing plugins=() array)
#
# Returns: 0 on success, 1 on error
#
# WHY: This is the core function for User Story 1 - automatically loading plugins
# declared in the plugins=() array. It reads the array, validates each specification,
# and loads each plugin while tracking them in state metadata.
#
# Design decisions:
# - Individual plugin failures don't block loading (FR-018: graceful degradation)
# - Plugins are loaded in array order (preserves user's intended dependency order)
# - All loaded plugins are tracked with state="declared" and source="array"
# - Errors are logged but don't stop shell startup
#
_zap_load_declared_plugins() {
  local config_file="$1"

  # Validate input
  if [[ ! -f "$config_file" ]]; then
    echo "Error: Config file not found: $config_file" >&2
    return 1
  fi

  # Load state metadata
  _zap_load_state

  # Extract plugin specifications from array
  local -a plugin_specs
  local specs_output
  specs_output=$(_zap_extract_plugins_array "$config_file" 2>/dev/null)

  # If no plugins array found or empty, return success (not an error)
  if [[ -z "$specs_output" ]]; then
    return 0
  fi

  # Convert output to array
  plugin_specs=("${(@f)specs_output}")

  # Load each plugin in order
  local spec
  for spec in "${plugin_specs[@]}"; do
    # Skip empty specs
    if [[ -z "$spec" ]]; then
      continue
    fi

    # Validate and parse the specification
    if ! _zap_parse_plugin_spec "$spec" 2>/dev/null; then
      echo "Warning: Invalid plugin specification: $spec" >&2
      continue
    fi

    # Use parsed components
    local plugin_name="$ZAP_PARSED_NAME"
    local plugin_owner="$ZAP_PARSED_OWNER"
    local plugin_repo="$ZAP_PARSED_REPO"
    local plugin_version="$ZAP_PARSED_VERSION"
    local plugin_subdir="$ZAP_PARSED_SUBDIR"

    # Use existing Zap infrastructure: clone if needed, then source
    # WHY: Avoid code duplication - reuse existing downloader and loader

    # Clone plugin if not present (uses existing _zap_clone_plugin)
    _zap_clone_plugin "$plugin_owner" "$plugin_repo" "$plugin_version" "$plugin_subdir" 2>/dev/null || {
      echo "Warning: Failed to download plugin: $plugin_name" >&2
      continue
    }

    # Source plugin using existing loader (handles file finding automatically)
    if _zap_source_plugin "$plugin_owner" "$plugin_repo" "$plugin_subdir"; then
      # Get cache directory using existing utilities
      local cache_dir="$(_zap_get_plugin_cache_dir "$plugin_owner" "$plugin_repo")"

      # Determine actual version
      local actual_version="$plugin_version"
      if [[ -z "$actual_version" && -d "$cache_dir/.git" ]]; then
        actual_version=$(cd "$cache_dir" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
      fi
      if [[ -z "$actual_version" ]]; then
        actual_version="unknown"
      fi

      # Add to state: state, specification, path, version, source
      _zap_add_plugin_to_state \
        "$plugin_name" \
        "$spec" \
        "declared" \
        "$cache_dir" \
        "$actual_version" \
        "array"
    else
      echo "Warning: Failed to load plugin: $plugin_name" >&2
      # Continue loading other plugins (FR-018: graceful degradation)
    fi
  done

  # Write state to disk
  _zap_write_state

  # Log declarative plugin loading (T033)
  if [[ -n "$ZAP_STATE_LOG" ]]; then
    {
      echo "[$(command date -Iseconds 2>/dev/null || command date)] Declarative loading completed"
      echo "  Config file: $config_file"
      echo "  Plugins loaded: ${#plugin_specs[@]}"
      echo "  Plugins: ${plugin_specs[*]}"
    } >> "$ZAP_STATE_LOG" 2>/dev/null
  fi

  return 0
}

#
# zap try - Temporarily try a plugin without adding it to configuration
#
# Usage: zap try owner/repo[@version][:subdir]
#
# Parameters:
#   $1 - plugin_spec (e.g., "zsh-users/zsh-autosuggestions")
#
# Returns: 0 on success, 1 on error
#
# WHY: User Story 2 - enable fearless experimentation. Users can try new plugins
# without modifying their .zshrc. Experimental plugins are NOT reloaded on
# shell restart, making it safe to experiment.
#
# Design decisions:
# - Experimental plugins tracked with state="experimental" and source="try_command"
# - If plugin already declared, inform user (no-op, already permanent)
# - If plugin already experimental, inform user (already loaded)
# - Downloads plugin if not present, then loads it
#
#
# _zap_declarative_dispatch - Handle declarative plugin management commands
#
# Purpose: Dispatcher for declarative commands (try, sync, status, diff, adopt)
# Parameters:
#   $1 - Subcommand (try, sync, status, diff, adopt)
#   $@ - Subcommand arguments
# Returns: Subcommand exit code
#
# WHY: Separate dispatcher for declarative commands to avoid conflicts with main zap()
#
_zap_declarative_dispatch() {
  local subcommand="$1"
  shift

  case "$subcommand" in
    try)
      # Parse arguments and flags (T048)
      local plugin_spec=""
      local verbose=false
      local -a args=("$@")

      for arg in "${args[@]}"; do
        case "$arg" in
          --verbose)
            verbose=true
            ;;
          -*)
            echo "Unknown flag: $arg" >&2
            echo "Usage: zap try [--verbose] owner/repo[@version][:subdir]" >&2
            return 1
            ;;
          *)
            plugin_spec="$arg"
            ;;
        esac
      done

      if [[ -z "$plugin_spec" ]]; then
        echo "Usage: zap try [--verbose] owner/repo[@version][:subdir]" >&2
        echo "" >&2
        echo "Examples:" >&2
        echo "  zap try zsh-users/zsh-autosuggestions" >&2
        echo "  zap try romkatv/powerlevel10k@master" >&2
        echo "  zap try ohmyzsh/ohmyzsh:plugins/git" >&2
        echo "  zap try --verbose zsh-users/zsh-autosuggestions" >&2
        return 1
      fi

      # Validate and parse specification
      $verbose && echo "[Verbose] Validating plugin specification: $plugin_spec"
      if ! _zap_parse_plugin_spec "$plugin_spec" 2>/dev/null; then
        echo "Error: Invalid plugin specification: $plugin_spec" >&2
        return 1
      fi

      local plugin_name="$ZAP_PARSED_NAME"
      local plugin_owner="$ZAP_PARSED_OWNER"
      local plugin_repo="$ZAP_PARSED_REPO"
      local plugin_version="$ZAP_PARSED_VERSION"
      local plugin_subdir="$ZAP_PARSED_SUBDIR"

      $verbose && echo "[Verbose] Parsed: owner=$plugin_owner, repo=$plugin_repo, version=${plugin_version:-latest}, subdir=${plugin_subdir:-(root)}"

      # Load current state
      $verbose && echo "[Verbose] Loading current plugin state..."
      _zap_load_state

      # Check if already declared
      if [[ -n "${_zap_plugin_state[$plugin_name]}" ]]; then
        local metadata="${_zap_plugin_state[$plugin_name]}"
        local state_field="${${(@s:|:)metadata}[1]}"

        if [[ "$state_field" == "declared" ]]; then
          echo "Plugin '$plugin_name' is already declared in your configuration." >&2
          echo "It will be loaded automatically on every shell startup." >&2
          $verbose && echo "[Verbose] State: declared, source: array"
          return 0
        elif [[ "$state_field" == "experimental" ]]; then
          echo "Plugin '$plugin_name' is already loaded experimentally in this session." >&2
          $verbose && echo "[Verbose] State: experimental, source: try_command"
          return 0
        fi
      fi

      # Use existing Zap infrastructure: clone if needed, then source
      # WHY: Avoid code duplication - reuse existing downloader and loader

      # Clone plugin if not present (uses existing _zap_clone_plugin)
      $verbose && echo "[Verbose] Checking if plugin needs to be downloaded..."
      if ! _zap_clone_plugin "$plugin_owner" "$plugin_repo" "$plugin_version" "$plugin_subdir"; then
        echo "Error: Failed to download plugin: $plugin_name" >&2
        return 1
      fi

      # Source plugin using existing loader (handles file finding automatically)
      $verbose && echo "[Verbose] Loading plugin files..."
      if _zap_source_plugin "$plugin_owner" "$plugin_repo" "$plugin_subdir"; then
        # Get cache directory using existing utilities
        local cache_dir="$(_zap_get_plugin_cache_dir "$plugin_owner" "$plugin_repo")"

        # Determine actual version
        local actual_version="$plugin_version"
        if [[ -z "$actual_version" && -d "$cache_dir/.git" ]]; then
          actual_version=$(cd "$cache_dir" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
          $verbose && echo "[Verbose] Detected git commit: $actual_version"
        fi
        if [[ -z "$actual_version" ]]; then
          actual_version="unknown"
        fi

        # Track as experimental
        $verbose && echo "[Verbose] Tracking plugin as experimental in state metadata..."
        _zap_add_plugin_to_state \
          "$plugin_name" \
          "$plugin_spec" \
          "experimental" \
          "$cache_dir" \
          "$actual_version" \
          "try_command"

        # Write state
        _zap_write_state

        echo "✓ Loaded $plugin_name experimentally"
        if $verbose; then
          echo "  Specification: $plugin_spec"
          echo "  Cache directory: $cache_dir"
          echo "  Version: $actual_version"
        fi
        echo "  This plugin will NOT be reloaded on shell restart."
        echo "  To make it permanent, run: zap adopt $plugin_name"
        echo "  To return to declared state, run: zap sync"

        return 0
      else
        echo "Error: Failed to load plugin: $plugin_name" >&2
        return 1
      fi
      ;;

    sync)
      # User Story 3: Reconcile to declared state (T059-T067)
      #
      # WHY: Return shell to exact configuration state. Removes experimental
      # plugins and ensures only declared plugins are loaded.
      #
      # Design: Idempotent operation - safe to run multiple times
      # Implementation: Full reload (exec zsh) guarantees clean state for v1

      # Parse flags (T064-T065)
      local dry_run=false
      local verbose=false
      local -a args=("$@")

      for arg in "${args[@]}"; do
        case "$arg" in
          --dry-run)
            dry_run=true
            ;;
          --verbose)
            verbose=true
            ;;
          -*)
            echo "Unknown flag: $arg" >&2
            echo "Usage: zap sync [--dry-run] [--verbose]" >&2
            return 1
            ;;
        esac
      done

      # Load current state
      _zap_load_state

      # Get list of experimental plugins
      local -a experimental_plugins
      experimental_plugins=($(_zap_list_experimental_plugins))

      if [[ ${#experimental_plugins[@]} -eq 0 ]]; then
        echo "✓ Already in sync - no experimental plugins loaded"
        if $verbose; then
          local -a declared_plugins
          declared_plugins=($(_zap_list_declared_plugins))
          echo ""
          echo "Declared plugins (${#declared_plugins[@]}):"
          for plugin_name in "${declared_plugins[@]}"; do
            echo "  ✓ $plugin_name"
          done
        fi
        return 0
      fi

      # Show preview (T061)
      echo "Synchronizing to declared state..."
      echo ""
      echo "Experimental plugins to be removed (${#experimental_plugins[@]}):"
      for plugin_name in "${experimental_plugins[@]}"; do
        local metadata="${_zap_plugin_state[$plugin_name]}"
        if $verbose; then
          # Show detailed metadata in verbose mode (T065)
          local spec="${${(@s:|:)metadata}[2]}"
          local timestamp="${${(@s:|:)metadata}[3]}"
          local version="${${(@s:|:)metadata}[5]}"
          echo "  - $plugin_name"
          echo "      spec: $spec"
          echo "      version: $version"
          echo "      loaded: $(command date -d @$timestamp 2>/dev/null || echo "$timestamp")"
        else
          echo "  - $plugin_name"
        fi
      done
      echo ""

      # Dry-run mode: show what would happen without executing (T064)
      if $dry_run; then
        echo "[DRY RUN] Would remove ${#experimental_plugins[@]} experimental plugin(s)"
        echo "[DRY RUN] Would reload shell to apply changes"
        echo ""
        echo "Run 'zap sync' without --dry-run to apply these changes"
        return 0
      fi

      # Remove experimental plugins from state
      local removed_count=0
      for plugin_name in "${experimental_plugins[@]}"; do
        _zap_remove_plugin_from_state "$plugin_name"
        ((removed_count++))
      done

      # Write updated state (T066)
      _zap_write_state

      # Log sync operation (T067)
      if [[ -n "$ZAP_STATE_LOG" ]]; then
        {
          echo "[$(command date -Iseconds 2>/dev/null || command date)] Sync operation completed"
          echo "  Experimental plugins removed: $removed_count"
          echo "  Plugins: ${experimental_plugins[*]}"
          if $verbose; then
            echo "  Verbose mode: enabled"
          fi
          if $dry_run; then
            echo "  Dry run: true"
          fi
        } >> "$ZAP_STATE_LOG" 2>/dev/null
      fi

      echo "✓ Removed $removed_count experimental plugin(s) from state"
      echo ""

      # T062-T063: Full reload reconciliation with history preservation
      # WHY: Full reload (exec zsh) is simplest and guarantees correct state.
      # All declarative plugins will be reloaded automatically on startup.
      # Experimental plugins removed from state won't be loaded.

      echo "Reloading shell to apply changes..."
      $verbose && echo "[Verbose] Preserving command history..."

      # Preserve history (T063)
      # WHY: Users expect command history to persist across sync operations
      setopt INC_APPEND_HISTORY 2>/dev/null || true
      fc -W 2>/dev/null || true

      # Reload shell (T062)
      # WHY: exec zsh replaces current shell process, applying declared config
      # from .zshrc which will load only declared plugins via _zap_load_declared_plugins()
      exec zsh
      ;;

    status)
      # User Story 5: Show current plugin state (T096-T102)
      #
      # WHY: Help users understand what's loaded and from where

      # Parse flags (T101-T102)
      local verbose=false
      local machine_readable=false
      local -a args=("$@")

      for arg in "${args[@]}"; do
        case "$arg" in
          --verbose)
            verbose=true
            ;;
          --machine-readable|--json)
            machine_readable=true
            ;;
          -*)
            echo "Unknown flag: $arg" >&2
            echo "Usage: zap status [--verbose] [--machine-readable]" >&2
            return 1
            ;;
        esac
      done

      _zap_load_state

      local -a declared_plugins experimental_plugins
      declared_plugins=($(_zap_list_declared_plugins))
      experimental_plugins=($(_zap_list_experimental_plugins))

      # Machine-readable output (T102)
      if $machine_readable; then
        echo "{"
        echo "  \"declared\": ["
        local first=true
        for plugin_name in "${declared_plugins[@]}"; do
          local metadata="${_zap_plugin_state[$plugin_name]}"
          local spec="${${(@s:|:)metadata}[2]}"
          local version="${${(@s:|:)metadata}[5]}"
          local path="${${(@s:|:)metadata}[4]}"

          if $first; then
            first=false
          else
            echo ","
          fi
          echo -n "    {\"name\": \"$plugin_name\", \"spec\": \"$spec\", \"version\": \"$version\", \"path\": \"$path\"}"
        done
        if [[ ${#declared_plugins[@]} -gt 0 ]]; then
          echo ""
        fi
        echo "  ],"
        echo "  \"experimental\": ["
        first=true
        for plugin_name in "${experimental_plugins[@]}"; do
          local metadata="${_zap_plugin_state[$plugin_name]}"
          local spec="${${(@s:|:)metadata}[2]}"
          local version="${${(@s:|:)metadata}[5]}"
          local path="${${(@s:|:)metadata}[4]}"

          if $first; then
            first=false
          else
            echo ","
          fi
          echo -n "    {\"name\": \"$plugin_name\", \"spec\": \"$spec\", \"version\": \"$version\", \"path\": \"$path\"}"
        done
        if [[ ${#experimental_plugins[@]} -gt 0 ]]; then
          echo ""
        fi
        echo "  ]"
        echo "}"
        return 0
      fi

      # Human-readable output
      echo "=== Zap Plugin Status ==="
      echo ""

      if [[ ${#declared_plugins[@]} -gt 0 ]]; then
        echo "Declared plugins (${#declared_plugins[@]}):"
        for plugin_name in "${declared_plugins[@]}"; do
          local metadata="${_zap_plugin_state[$plugin_name]}"
          local version="${${(@s:|:)metadata}[5]}"

          echo "  ✓ $plugin_name [$version]"

          # Verbose output (T101): show versions, paths, load times
          if $verbose; then
            local spec="${${(@s:|:)metadata}[2]}"
            local path="${${(@s:|:)metadata}[4]}"
            local timestamp="${${(@s:|:)metadata}[3]}"
            echo "      spec: $spec"
            echo "      path: $path"
            if [[ -n "$timestamp" && "$timestamp" != "0" ]]; then
              echo "      loaded: $(command date -d @$timestamp 2>/dev/null || echo "$timestamp")"
            fi
          fi
        done
      else
        echo "Declared plugins: (none)"
      fi

      echo ""

      if [[ ${#experimental_plugins[@]} -gt 0 ]]; then
        echo "Experimental plugins (${#experimental_plugins[@]}):"
        for plugin_name in "${experimental_plugins[@]}"; do
          local metadata="${_zap_plugin_state[$plugin_name]}"
          local version="${${(@s:|:)metadata}[5]}"

          echo "  ⚡ $plugin_name [$version]"

          # Verbose output (T101)
          if $verbose; then
            local spec="${${(@s:|:)metadata}[2]}"
            local path="${${(@s:|:)metadata}[4]}"
            local timestamp="${${(@s:|:)metadata}[3]}"
            echo "      spec: $spec"
            echo "      path: $path"
            if [[ -n "$timestamp" && "$timestamp" != "0" ]]; then
              echo "      loaded: $(command date -d @$timestamp 2>/dev/null || echo "$timestamp")"
            fi
          fi
        done
        echo ""
        echo "Run 'zap sync' to remove experimental plugins"
      else
        echo "Experimental plugins: (none)"
        echo ""
        echo "✓ In sync with declared configuration"
      fi

      return 0
      ;;

    diff)
      # User Story 5: Show drift between declared and actual state (T097, T103-T106)
      #
      # WHY: Preview what would change if you ran `zap sync`

      # Parse flags (T105)
      local verbose=false
      local -a args=("$@")

      for arg in "${args[@]}"; do
        case "$arg" in
          --verbose)
            verbose=true
            ;;
          -*)
            echo "Unknown flag: $arg" >&2
            echo "Usage: zap diff [--verbose]" >&2
            return 1
            ;;
        esac
      done

      _zap_load_state

      local -a declared_plugins experimental_plugins
      declared_plugins=($(_zap_list_declared_plugins))
      experimental_plugins=($(_zap_list_experimental_plugins))

      echo "=== Zap State Diff ==="
      echo ""

      # Exit code logic (T106): 0 = drift detected, 1 = in sync
      if [[ ${#experimental_plugins[@]} -eq 0 ]]; then
        echo "✓ No drift detected - in sync with declared configuration"
        echo ""
        echo "Declared plugins (${#declared_plugins[@]}):"
        for plugin_name in "${declared_plugins[@]}"; do
          echo "  = $plugin_name"
          if $verbose; then
            local metadata="${_zap_plugin_state[$plugin_name]}"
            local spec="${${(@s:|:)metadata}[2]}"
            local version="${${(@s:|:)metadata}[5]}"
            echo "      spec: $spec, version: $version"
          fi
        done
        return 1  # Exit code 1 = in sync
      fi

      echo "Drift detected:"
      echo ""

      if [[ ${#declared_plugins[@]} -gt 0 ]]; then
        echo "Declared plugins (will remain):"
        for plugin_name in "${declared_plugins[@]}"; do
          echo "  = $plugin_name"
          if $verbose; then
            local metadata="${_zap_plugin_state[$plugin_name]}"
            local spec="${${(@s:|:)metadata}[2]}"
            local version="${${(@s:|:)metadata}[5]}"
            echo "      spec: $spec, version: $version"
          fi
        done
        echo ""
      fi

      if [[ ${#experimental_plugins[@]} -gt 0 ]]; then
        echo "Experimental plugins (will be removed by sync):"
        for plugin_name in "${experimental_plugins[@]}"; do
          echo "  - $plugin_name"
          if $verbose; then
            local metadata="${_zap_plugin_state[$plugin_name]}"
            local spec="${${(@s:|:)metadata}[2]}"
            local version="${${(@s:|:)metadata}[5]}"
            local timestamp="${${(@s:|:)metadata}[3]}"
            echo "      spec: $spec, version: $version"
            if [[ -n "$timestamp" && "$timestamp" != "0" ]]; then
              echo "      loaded: $(command date -d @$timestamp 2>/dev/null || echo "$timestamp")"
            fi
          fi
        done
        echo ""
      fi

      echo "Run 'zap sync' to reconcile to declared state"

      return 0  # Exit code 0 = drift detected
      ;;

    adopt)
      # User Story 4: Adopt experimental plugin to declared state (T076-T088)
      #
      # WHY: Make successful experiments permanent by adding them to .zshrc
      # automatically. No manual editing required.

      # Parse flags (T086-T087)
      local plugin_spec=""
      local verbose=false
      local skip_confirm=false
      local adopt_all=false
      local config_file="${ZDOTDIR:-$HOME}/.zshrc"
      local -a args=("$@")

      for arg in "${args[@]}"; do
        case "$arg" in
          --verbose)
            verbose=true
            ;;
          --yes|-y)
            skip_confirm=true
            ;;
          --all)
            adopt_all=true
            ;;
          -*)
            echo "Unknown flag: $arg" >&2
            echo "Usage: zap adopt [--verbose] [--yes] <plugin-name>" >&2
            echo "       zap adopt --all [--yes] [--verbose]" >&2
            return 1
            ;;
          *)
            if [[ -z "$plugin_spec" ]]; then
              plugin_spec="$arg"
            fi
            ;;
        esac
      done

      if [[ -z "$plugin_spec" && "$adopt_all" == false ]]; then
        echo "Usage: zap adopt [--verbose] [--yes] <plugin-name>" >&2
        echo "       zap adopt --all [--yes] [--verbose]" >&2
        echo "" >&2
        echo "Examples:" >&2
        echo "  zap adopt zsh-users/zsh-completions" >&2
        echo "  zap adopt --verbose zsh-users/zsh-completions" >&2
        echo "  zap adopt --all  # Adopt all experimental plugins" >&2
        echo "  zap adopt --all --yes  # Skip confirmation" >&2
        return 1
      fi

      # Load current state
      $verbose && echo "[Verbose] Loading current plugin state..."
      _zap_load_state

      # Handle --all flag (T085)
      if $adopt_all; then
        local -a experimental_plugins experimental_specs
        experimental_plugins=($(_zap_list_experimental_plugins))

        if [[ ${#experimental_plugins[@]} -eq 0 ]]; then
          echo "No experimental plugins to adopt"
          return 0
        fi

        # Collect all specs BEFORE adopting (state will change during adoption)
        for plugin_name in "${experimental_plugins[@]}"; do
          local metadata="${_zap_plugin_state[$plugin_name]}"
          local original_spec="${${(@s:|:)metadata}[2]}"
          experimental_specs+=("$original_spec")
        done

        echo "Adopting ${#experimental_plugins[@]} experimental plugin(s):"
        for plugin in "${experimental_plugins[@]}"; do
          echo "  - $plugin"
        done

        # Confirmation prompt (T086 - unless --yes flag is provided)
        if ! $skip_confirm; then
          echo ""
          read "REPLY?Continue? [y/N] "
          if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            echo "Adoption cancelled"
            return 0
          fi
        fi

        # Adopt each experimental plugin using collected specs
        local adopted_count=0
        for original_spec in "${experimental_specs[@]}"; do
          if $verbose; then
            if zap adopt --yes "$original_spec"; then
              ((adopted_count++))
            fi
          else
            if zap adopt --yes "$original_spec" >/dev/null 2>&1; then
              ((adopted_count++))
            fi
          fi
        done

        echo "✓ Adopted $adopted_count plugin(s) to your configuration"
        return 0
      fi

      # Validate plugin specification
      $verbose && echo "[Verbose] Validating plugin specification: $plugin_spec"
      if ! _zap_parse_plugin_spec "$plugin_spec" 2>/dev/null; then
        echo "Error: Invalid plugin specification: $plugin_spec" >&2
        return 1
      fi

      local plugin_name="$ZAP_PARSED_NAME"
      $verbose && echo "[Verbose] Plugin name: $plugin_name"

      # Check if plugin is loaded
      if [[ -z "${_zap_plugin_state[$plugin_name]}" ]]; then
        echo "Error: Plugin '$plugin_name' is not loaded" >&2
        echo "Use 'zap try $plugin_name' first to load it experimentally" >&2
        return 1
      fi

      local metadata="${_zap_plugin_state[$plugin_name]}"
      local state_field="${${(@s:|:)metadata}[1]}"

      # Check if already declared (T079)
      if [[ "$state_field" == "declared" ]]; then
        echo "Plugin '$plugin_name' is already declared in your configuration" >&2
        $verbose && echo "[Verbose] State: declared, source: array"
        return 0
      fi

      # Check if experimental (T078)
      if [[ "$state_field" != "experimental" ]]; then
        echo "Error: Plugin '$plugin_name' is not experimental" >&2
        $verbose && echo "[Verbose] Current state: $state_field"
        return 1
      fi

      # Create backup (T080)
      local backup_file="${config_file}.backup-$(command date +%s 2>/dev/null || echo "backup")"
      $verbose && echo "[Verbose] Creating backup: $backup_file"
      if ! cp "$config_file" "$backup_file" 2>/dev/null; then
        echo "Error: Failed to create backup of $config_file" >&2
        return 1
      fi

      # Add plugin to plugins=() array using awk (T081-T082)
      $verbose && echo "[Verbose] Modifying $config_file to add plugin to plugins=() array..."
      local temp_file="${config_file}.tmp.$$"

      # AWK script to add plugin to array (T077)
      awk -v plugin="$plugin_spec" '
      BEGIN { in_array = 0; added = 0; }

      # Detect start of plugins array
      /^[[:space:]]*plugins=\(/ {
        in_array = 1
        print
        next
      }

      # If in array and hit closing paren, add plugin before it
      in_array == 1 && /^[[:space:]]*\)/ {
        print "  " plugin
        added = 1
        in_array = 0
        print
        next
      }

      # Print all other lines
      { print }

      # If no array found, add one at the end
      END {
        if (added == 0) {
          print ""
          print "# Plugins (added by zap adopt)"
          print "plugins=("
          print "  " plugin
          print ")"
        }
      }
      ' "$config_file" > "$temp_file"

      # Atomic move with permission preservation (T082-T083)
      if [[ -f "$temp_file" ]]; then
        # Preserve permissions (T083)
        if command -v chmod >/dev/null; then
          chmod --reference="$config_file" "$temp_file" 2>/dev/null || true
          $verbose && echo "[Verbose] Preserved file permissions from original"
        fi

        $verbose && echo "[Verbose] Performing atomic move (temp file → config file)..."
        if mv "$temp_file" "$config_file" 2>/dev/null; then
          # Update state metadata (experimental → declared, try_command → array) (T084)
          $verbose && echo "[Verbose] Updating state metadata (experimental → declared)..."
          _zap_update_plugin_state "$plugin_name" "declared" "array"
          _zap_write_state

          echo "✓ Adopted $plugin_name to your configuration"
          if $verbose; then
            echo "  Specification: $plugin_spec"
          fi
          echo "  Added to: $config_file"
          echo "  Backup saved: $backup_file"
          echo "  Plugin will now load automatically on shell startup"

          # Special guidance for themes (especially powerlevel10k)
          if [[ "$plugin_name" == *"powerlevel10k"* ]]; then
            echo ""
            echo "📝 Next steps for Powerlevel10k:"
            echo "   1. Add this line to your $config_file (after sourcing zap):"
            echo "      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh"
            echo ""
            echo "   2. Run: p10k configure"
            echo "      This will guide you through prompt customization"
            echo ""
            echo "   3. Restart your shell: exec zsh"
          fi

          return 0
        else
          echo "Error: Failed to update $config_file" >&2
          rm -f "$temp_file" 2>/dev/null
          return 1
        fi
      else
        echo "Error: Failed to modify configuration" >&2
        return 1
      fi
      ;;

    *)
      # Fallback to original zap command handler (if exists)
      # This will be integrated with existing zap commands
      echo "Unknown command: $subcommand" >&2
      echo "Try: zap help" >&2
      return 1
      ;;
  esac
}

# Module initialization
typeset -g ZAP_DECLARATIVE_LOADED=1
