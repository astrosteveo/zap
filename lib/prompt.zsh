#!/usr/bin/env zsh
#
# prompt.zsh - Simple, fast, built-in prompt
#
# WHY: Provide a clean, informative prompt out of the box with zero dependencies.
# Users who want a fancier prompt can easily opt into Starship or other prompts.
#
# Design goals:
# - Fast (pure Zsh, no external commands)
# - Informative (shows directory, git branch, exit status)
# - Clean (minimal clutter)
# - No dependencies (works everywhere)
#
# Configuration (via zstyle):
#   zstyle ':zap:prompt' show-user 'always|auto|never'  # Show user@host (default: auto)
#   zstyle ':zap:prompt' symbol '❯'                     # Prompt symbol (default: ❯)
#
# Examples:
#   # Always show user@host
#   zstyle ':zap:prompt' show-user 'always'
#
#   # Never show user@host
#   zstyle ':zap:prompt' show-user 'never'
#
#   # Custom prompt symbol
#   zstyle ':zap:prompt' symbol '➜'

#
# Initialize version control info system
#
# WHY: Zsh's built-in vcs_info provides git/svn/hg info efficiently without
#      spawning external processes on every prompt render.
#
autoload -Uz vcs_info

# Configure vcs_info
# WHY: We only care about git (most common), and only need branch name
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' check-for-changes false  # Disable for speed
zstyle ':vcs_info:git:*' formats ' %b'        # Format: " branch-name"
zstyle ':vcs_info:git:*' actionformats ' %b|%a'  # Format during rebase/merge

#
# _zap_prompt_precmd - Update prompt before each command
#
# WHY: This hook runs before each prompt display, updating vcs_info
#      and capturing exit status of the last command.
#
_zap_prompt_precmd() {
  # Capture exit status immediately
  # WHY: Must be first line in precmd to get accurate exit code
  local last_exit=$?

  # Update version control info
  vcs_info

  # Color the prompt based on exit status
  # WHY: Visual feedback - red prompt means last command failed
  if [[ $last_exit -eq 0 ]]; then
    _ZAP_PROMPT_COLOR="%F{green}"  # Green for success
  else
    _ZAP_PROMPT_COLOR="%F{red}"    # Red for failure
  fi
}

#
# Build the prompt
#
# WHY: Separate the prompt construction so it's easy to customize
#

# Read configuration from zstyles
local show_user_config
zstyle -s ':zap:prompt' show-user 'show_user_config' || show_user_config='auto'

local prompt_symbol
zstyle -s ':zap:prompt' symbol 'prompt_symbol' || prompt_symbol='❯'

# Determine if we should show username@hostname
# WHY: Show user@host based on configuration:
#      - 'always': Always show
#      - 'never': Never show
#      - 'auto' (default): Show if SSH or root
case "$show_user_config" in
  always)
    _ZAP_PROMPT_USER="%n@%m "  # Always show user@hostname
    ;;
  never)
    _ZAP_PROMPT_USER=""        # Never show
    ;;
  auto|*)
    # Auto-detect: show if SSH or root
    if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" || "$EUID" -eq 0 ]]; then
      _ZAP_PROMPT_USER="%n@%m "  # user@hostname
    else
      _ZAP_PROMPT_USER=""        # Skip on local machine
    fi
    ;;
esac

# Set the prompt
# WHY: Single-line prompt with:
#      - Optional user@host (configurable)
#      - Current directory (with ~ expansion)
#      - Git branch (if in git repo)
#      - Prompt symbol (configurable, changes color based on exit status)
#
# Format: user@host ~/path/to/dir branch ❯
#
setopt PROMPT_SUBST  # Enable parameter expansion in prompt

PROMPT='${_ZAP_PROMPT_COLOR}${_ZAP_PROMPT_USER}%F{cyan}%~%f%F{yellow}${vcs_info_msg_0_}%f
${_ZAP_PROMPT_COLOR}'"${prompt_symbol}"'%f '

# Right prompt (optional, disabled by default)
# WHY: Some users like seeing timestamp or other info on the right
# Uncomment to enable:
# RPROMPT='%F{8}%*%f'  # Shows current time

#
# Register the precmd hook
#
# WHY: Update prompt info before each prompt display
#
autoload -Uz add-zsh-hook
add-zsh-hook precmd _zap_prompt_precmd
