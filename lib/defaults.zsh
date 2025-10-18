#!/usr/bin/env zsh
#
# defaults.zsh - Default keybindings and minimal completion system
#
# WHY: Provide sensible defaults so users have a working terminal immediately
# after installation without configuration (per FR-011, FR-012, User Story 3)

#
# Default Keybindings (FR-011)
#
# WHY: Standard terminal keys should work out of the box. Many terminal emulators
# don't bind these by default, causing frustration (User Story 3 acceptance criteria)
#

# Make sure the terminal is in application mode when zle is active
# WHY: Some terminals require application mode for special keys to work
if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
  autoload -Uz add-zle-hook-widget
  function zle_application_mode_start { echoti smkx }
  function zle_application_mode_stop { echoti rmkx }
  add-zle-hook-widget -Uz zle-line-init zle_application_mode_start
  add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
fi

# Delete key - delete character under cursor
# WHY: Delete key not working is a common complaint
[[ -n "${terminfo[kdch1]}" ]] && bindkey "${terminfo[kdch1]}" delete-char
bindkey "^[[3~" delete-char  # Fallback for terminals without terminfo

# Home key - move to beginning of line
# WHY: Critical for command editing efficiency
[[ -n "${terminfo[khome]}" ]] && bindkey "${terminfo[khome]}" beginning-of-line
bindkey "^[[H" beginning-of-line  # Fallback
bindkey "^[[1~" beginning-of-line # Alternative fallback

# End key - move to end of line
[[ -n "${terminfo[kend]}" ]] && bindkey "${terminfo[kend]}" end-of-line
bindkey "^[[F" end-of-line  # Fallback
bindkey "^[[4~" end-of-line # Alternative fallback

# Page Up - search backward in history
# WHY: Common pattern for history navigation
[[ -n "${terminfo[kpp]}" ]] && bindkey "${terminfo[kpp]}" up-line-or-history
bindkey "^[[5~" up-line-or-history  # Fallback

# Page Down - search forward in history
[[ -n "${terminfo[knp]}" ]] && bindkey "${terminfo[knp]}" down-line-or-history
bindkey "^[[6~" down-line-or-history  # Fallback

# Up arrow - previous command in history
[[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" up-line-or-history
bindkey "^[[A" up-line-or-history

# Down arrow - next command in history
[[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" down-line-or-history
bindkey "^[[B" down-line-or-history

#
# Minimal Completion System (FR-022)
#
# WHY: Tab completion is essential for usability. Provide basic completion without
# requiring user configuration (User Story 3 acceptance scenario 3)
#

# Enable completion system
autoload -Uz compinit

# Initialize completion (will be called once in zap.zsh after all plugins loaded)
# WHY: Running compinit multiple times slows startup. Defer to main entry point

# Basic completion options
setopt COMPLETE_IN_WORD     # Complete from both ends of word
setopt ALWAYS_TO_END        # Move cursor to end of word after completion
setopt AUTO_MENU            # Show completion menu on successive tab
setopt AUTO_LIST            # Automatically list choices on ambiguous completion
setopt AUTO_PARAM_SLASH     # Add trailing slash for directory completions

# Case-insensitive completion
# WHY: More forgiving for users, matches modern UX expectations
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Use menu selection for completions
# WHY: Visual menu is more intuitive than cycling through options
zstyle ':completion:*' menu select

# Group completions by type
# WHY: Organized display helps users find what they need
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%B%d%b'

# Enable completion caching for faster performance
# WHY: Speeds up completion for commands with many options
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZAP_DATA_DIR/.zcompcache"

# Color file completions
# WHY: Visual distinction helps identify file types
zstyle ':completion:*' list-colors ''

# History-based completion
# WHY: Leverage shell history for smarter suggestions (FR-022 requirement)
setopt HIST_IGNORE_ALL_DUPS  # Don't record duplicate commands
setopt HIST_FIND_NO_DUPS     # Don't display duplicates when searching
setopt HIST_IGNORE_SPACE     # Don't record commands starting with space

# Set history file and size
HISTFILE="$ZAP_DATA_DIR/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

#
# Additional Quality-of-Life Settings
#
# WHY: These settings improve shell usability without changing behavior significantly
#

# Don't beep on errors
setopt NO_BEEP

# Allow comments in interactive shell
setopt INTERACTIVE_COMMENTS

# cd without typing cd
setopt AUTO_CD

# Correct minor typos in commands
setopt CORRECT
