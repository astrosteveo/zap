#!/usr/bin/env zsh
#
# framework.zsh - Oh-My-Zsh and Prezto compatibility layer
#
# WHY: Enable transparent use of existing framework plugins without requiring
# full framework installation (per FR-009, FR-010, FR-017, FR-025)

# Source utilities
source "${0:A:h}/utils.zsh"
source "${0:A:h}/parser.zsh"

#
# _zap_detect_framework - Detect if plugin requires framework support
#
# Purpose: Identify Oh-My-Zsh or Prezto plugins by repository pattern
# Parameters:
#   $1 - Owner
#   $2 - Repo
# Returns: 0 if framework detected, 1 otherwise
# Output: Framework name ("oh-my-zsh" or "prezto") on stdout
#
# WHY: Repository-based detection is reliable and doesn't require parsing
# plugin files (FR-025)
#
_zap_detect_framework() {
  local owner="$1"
  local repo="$2"

  # Oh-My-Zsh detection (FR-025)
  if [[ "$owner" == "ohmyzsh" && "$repo" == "ohmyzsh" ]]; then
    echo "oh-my-zsh"
    return 0
  fi

  # Prezto detection (FR-025)
  if [[ "$owner" == "sorin-ionescu" && "$repo" == "prezto" ]]; then
    echo "prezto"
    return 0
  fi

  return 1
}

#
# _zap_setup_oh_my_zsh - Configure Oh-My-Zsh environment
#
# Purpose: Set up required environment variables for Oh-My-Zsh plugins
# Parameters: None
# Returns: 0 always
# Side Effects: Exports ZSH, ZSH_CACHE_DIR, ZSH_CUSTOM
#
# WHY: Oh-My-Zsh plugins expect specific environment variables to be set
# (data-model.md §4, research.md §3)
#
_zap_setup_oh_my_zsh() {
  local omz_cache_dir="$(_zap_get_plugin_cache_dir "ohmyzsh" "ohmyzsh")"

  # Export Oh-My-Zsh environment variables
  export ZSH="$omz_cache_dir"
  export ZSH_CACHE_DIR="$ZAP_DATA_DIR/oh-my-zsh-cache"
  export ZSH_CUSTOM="$ZAP_DATA_DIR/oh-my-zsh-custom"

  # Create cache directories
  # WHY: Completions directory is needed for dynamic completion generation (e.g., kubectl)
  mkdir -p "$ZSH_CACHE_DIR/completions" "$ZSH_CUSTOM" 2>/dev/null

  # Add completions directory to fpath
  # WHY: Oh-My-Zsh plugins generate completions into ZSH_CACHE_DIR/completions
  if [[ -d "$ZSH_CACHE_DIR/completions" ]] && (( ! ${fpath[(I)$ZSH_CACHE_DIR/completions]} )); then
    fpath=("$ZSH_CACHE_DIR/completions" $fpath)
  fi

  return 0
}

#
# _zap_setup_prezto - Configure Prezto environment
#
# Purpose: Set up required environment variables for Prezto modules
# Parameters: None
# Returns: 0 always
# Side Effects: Exports ZDOTDIR, PREZTO, modifies fpath
#
# WHY: Prezto modules expect specific environment and fpath configuration
# (data-model.md §4, research.md §3)
#
_zap_setup_prezto() {
  local prezto_cache_dir="$(_zap_get_plugin_cache_dir "sorin-ionescu" "prezto")"

  # Export Prezto environment variables
  export ZDOTDIR="${ZDOTDIR:-$HOME}"
  export PREZTO="$prezto_cache_dir"

  # Add Prezto module functions to fpath
  fpath=("$prezto_cache_dir/modules/"*/functions(N) $fpath)

  return 0
}

#
# _zap_ensure_framework - Ensure framework base is installed
#
# Purpose: Download framework base repository if needed
# Parameters:
#   $1 - Framework name ("oh-my-zsh" or "prezto")
#   $2 - Subdirectory (optional: use sparse checkout for just this path)
# Returns: 0 if framework available, 1 on error
#
# WHY: Framework plugins require base framework libraries (FR-017)
# Framework is downloaded automatically without user intervention
# Sparse checkout used when subdirectory specified to save bandwidth/disk
#
_zap_ensure_framework() {
  local framework="$1"
  local subdir="${2:-}"

  case "$framework" in
    oh-my-zsh)
      local owner="ohmyzsh"
      local repo="ohmyzsh"
      local cache_dir="$(_zap_get_plugin_cache_dir "$owner" "$repo")"

      # Download Oh-My-Zsh base (FR-017: automatic detection and installation)
      # WHY: Always call _zap_clone_plugin even if cache exists, because it handles
      # adding new subdirectories to existing sparse checkouts
      local framework_exists=0
      if [[ -d "$cache_dir/.git" ]]; then
        framework_exists=1
      fi

      # Use sparse checkout if subdirectory specified to avoid downloading 300+ plugins
      # WHY: _zap_clone_plugin will print appropriate download messages
      if _zap_clone_plugin "$owner" "$repo" "" "$subdir"; then
        # Only print framework setup message on first download
        if [[ $framework_exists -eq 0 ]]; then
          _zap_print_success "Oh-My-Zsh framework initialized"
        fi
        _zap_setup_oh_my_zsh
        return 0
      else
        _zap_print_error "Failed to download Oh-My-Zsh framework" "Network or repository error" \
          "Framework plugins may not work correctly"
        return 1
      fi
      ;;

    prezto)
      local owner="sorin-ionescu"
      local repo="prezto"
      local cache_dir="$(_zap_get_plugin_cache_dir "$owner" "$repo")"

      # Download Prezto base (FR-017: automatic detection and installation)
      # WHY: Always call _zap_clone_plugin even if cache exists, because it handles
      # adding new subdirectories to existing sparse checkouts
      local framework_exists=0
      if [[ -d "$cache_dir/.git" ]]; then
        framework_exists=1
      fi

      # Use sparse checkout if subdirectory specified
      # WHY: _zap_clone_plugin will print appropriate download messages
      if _zap_clone_plugin "$owner" "$repo" "" "$subdir"; then
        # Only print framework setup message on first download
        if [[ $framework_exists -eq 0 ]]; then
          _zap_print_success "Prezto framework initialized"
        fi
        _zap_setup_prezto
        return 0
      else
        _zap_print_error "Failed to download Prezto framework" "Network or repository error" \
          "Framework modules may not work correctly"
        return 1
      fi
      ;;

    *)
      return 1
      ;;
  esac
}

#
# _zap_load_framework_plugin - Load framework plugin with proper setup
#
# Purpose: Load Oh-My-Zsh or Prezto plugin with framework environment
# Parameters:
#   $1 - Owner
#   $2 - Repo
#   $3 - Subdirectory (for framework plugins, typically plugins/* or modules/*)
# Returns: 0 on success, 1 on failure
#
# WHY: Framework plugins need framework environment set up before loading
# (FR-009, FR-010, User Story 4)
#
_zap_load_framework_plugin() {
  local owner="$1"
  local repo="$2"
  local subdir="$3"
  local framework

  # Detect which framework
  if ! framework=$(_zap_detect_framework "$owner" "$repo"); then
    # Not a framework plugin
    return 1
  fi

  # Ensure framework base is installed and configured
  # Pass subdirectory to enable sparse checkout optimization
  if ! _zap_ensure_framework "$framework" "$subdir"; then
    _zap_log_error "ERROR" "$owner/$repo" "Framework setup failed" \
      "Could not install $framework base"
    return 1
  fi

  # Framework is now set up, plugin can be loaded normally
  return 0
}
