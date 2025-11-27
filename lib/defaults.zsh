#!/usr/bin/env zsh
#
# defaults.zsh - Default keybindings and minimal completion system
#
# WHY: Provide sensible defaults so users have a working terminal immediately
# after installation without configuration (per FR-011, FR-012, User Story 3)
#
# Based on Oh-My-Zsh key-bindings.zsh with Zap-specific enhancements

# Reference documentation:
# http://zsh.sourceforge.net/Doc/Release/Zsh-Line-Editor.html
# http://zsh.sourceforge.net/Doc/Release/Zsh-Line-Editor.html#Zle-Builtins
# http://zsh.sourceforge.net/Doc/Release/Zsh-Line-Editor.html#Standard-Widgets

#
# Terminal Application Mode
#
# WHY: Some terminals require application mode for special keys to work.
# This ensures terminfo values are valid when ZLE (Zsh Line Editor) is active.
#
if (( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )); then
  function zle-line-init() {
    echoti smkx
  }
  function zle-line-finish() {
    echoti rmkx
  }
  zle -N zle-line-init
  zle -N zle-line-finish
fi

#
# Keymap Mode Selection
#
# WHY: Default to emacs mode for consistency with most shells (bash, zsh default).
# Users who want vi mode should set `bindkey -v` BEFORE sourcing zap.
# This ensures vi mode users don't get their preference overridden.
#
bindkey -e  # Use emacs key bindings by default

# Enable Ctrl-S for forward incremental search
# WHY: By default, Ctrl-S is captured by terminal flow control (XOFF). Disabling
# flow control allows Ctrl-S to work as forward-i-search, matching user expectations.
stty -ixon 2>/dev/null

#
# Smart History Search (Fuzzy Find)
#
# WHY: Much better UX than plain history navigation. If you type "git" and press
# Up arrow, you only see commands starting with "git" instead of all history.
# This is one of Oh-My-Zsh's most popular features.
#
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

#
# Navigation Keybindings
#
# WHY: These keys work across all three keymaps (emacs, viins, vicmd) to ensure
# consistent behavior whether user is in emacs mode or vi mode. This matches
# Oh-My-Zsh's approach of explicitly binding to all three maps.
#

# [Up-Arrow] - Smart history search backward (filters by what you've typed)
if [[ -n "${terminfo[kcuu1]}" ]]; then
  bindkey -M emacs "${terminfo[kcuu1]}" up-line-or-beginning-search
  bindkey -M viins "${terminfo[kcuu1]}" up-line-or-beginning-search
  bindkey -M vicmd "${terminfo[kcuu1]}" up-line-or-beginning-search
fi
bindkey -M emacs "^[[A" up-line-or-beginning-search
bindkey -M viins "^[[A" up-line-or-beginning-search
bindkey -M vicmd "^[[A" up-line-or-beginning-search

# [Down-Arrow] - Smart history search forward
if [[ -n "${terminfo[kcud1]}" ]]; then
  bindkey -M emacs "${terminfo[kcud1]}" down-line-or-beginning-search
  bindkey -M viins "${terminfo[kcud1]}" down-line-or-beginning-search
  bindkey -M vicmd "${terminfo[kcud1]}" down-line-or-beginning-search
fi
bindkey -M emacs "^[[B" down-line-or-beginning-search
bindkey -M viins "^[[B" down-line-or-beginning-search
bindkey -M vicmd "^[[B" down-line-or-beginning-search

# [PageUp] - Move up in history
if [[ -n "${terminfo[kpp]}" ]]; then
  bindkey -M emacs "${terminfo[kpp]}" up-line-or-history
  bindkey -M viins "${terminfo[kpp]}" up-line-or-history
  bindkey -M vicmd "${terminfo[kpp]}" up-line-or-history
fi
bindkey -M emacs "^[[5~" up-line-or-history
bindkey -M viins "^[[5~" up-line-or-history
bindkey -M vicmd "^[[5~" up-line-or-history

# [PageDown] - Move down in history
if [[ -n "${terminfo[knp]}" ]]; then
  bindkey -M emacs "${terminfo[knp]}" down-line-or-history
  bindkey -M viins "${terminfo[knp]}" down-line-or-history
  bindkey -M vicmd "${terminfo[knp]}" down-line-or-history
fi
bindkey -M emacs "^[[6~" down-line-or-history
bindkey -M viins "^[[6~" down-line-or-history
bindkey -M vicmd "^[[6~" down-line-or-history

# [Home] - Go to beginning of line
if [[ -n "${terminfo[khome]}" ]]; then
  bindkey -M emacs "${terminfo[khome]}" beginning-of-line
  bindkey -M viins "${terminfo[khome]}" beginning-of-line
  bindkey -M vicmd "${terminfo[khome]}" beginning-of-line
fi
bindkey -M emacs "^[[H" beginning-of-line
bindkey -M viins "^[[H" beginning-of-line
bindkey -M vicmd "^[[H" beginning-of-line
bindkey -M emacs "^[[1~" beginning-of-line
bindkey -M viins "^[[1~" beginning-of-line
bindkey -M vicmd "^[[1~" beginning-of-line

# [End] - Go to end of line
if [[ -n "${terminfo[kend]}" ]]; then
  bindkey -M emacs "${terminfo[kend]}" end-of-line
  bindkey -M viins "${terminfo[kend]}" end-of-line
  bindkey -M vicmd "${terminfo[kend]}" end-of-line
fi
bindkey -M emacs "^[[F" end-of-line
bindkey -M viins "^[[F" end-of-line
bindkey -M vicmd "^[[F" end-of-line
bindkey -M emacs "^[[4~" end-of-line
bindkey -M viins "^[[4~" end-of-line
bindkey -M vicmd "^[[4~" end-of-line

#
# Editing Keybindings
#

# [Backspace] - Delete backward
bindkey -M emacs '^?' backward-delete-char
bindkey -M viins '^?' backward-delete-char
bindkey -M vicmd '^?' backward-delete-char

# [Delete] - Delete forward
if [[ -n "${terminfo[kdch1]}" ]]; then
  bindkey -M emacs "${terminfo[kdch1]}" delete-char
  bindkey -M viins "${terminfo[kdch1]}" delete-char
  bindkey -M vicmd "${terminfo[kdch1]}" delete-char
else
  bindkey -M emacs "^[[3~" delete-char
  bindkey -M viins "^[[3~" delete-char
  bindkey -M vicmd "^[[3~" delete-char
fi

# [Ctrl-Delete] - Delete whole forward word
# WHY: Matches GUI application behavior for power users
bindkey -M emacs '^[[3;5~' kill-word
bindkey -M viins '^[[3;5~' kill-word
bindkey -M vicmd '^[[3;5~' kill-word

# [Ctrl-RightArrow] - Move forward one word
# WHY: Common in GUI applications; complements Alt-F
bindkey -M emacs '^[[1;5C' forward-word
bindkey -M viins '^[[1;5C' forward-word
bindkey -M vicmd '^[[1;5C' forward-word

# [Ctrl-LeftArrow] - Move backward one word
# WHY: Common in GUI applications; complements Alt-B
bindkey -M emacs '^[[1;5D' backward-word
bindkey -M viins '^[[1;5D' backward-word
bindkey -M vicmd '^[[1;5D' backward-word

# [Ctrl-r] - Search backward incrementally in history
# WHY: This is muscle memory for most terminal users
bindkey '^r' history-incremental-search-backward

# [Space] - Don't do history expansion
# WHY: Prevents surprises when typing commands with "!" in them
bindkey ' ' magic-space

#
# Advanced Editing Features
#

# [Ctrl-x Ctrl-e] - Edit command line in $EDITOR
# WHY: Essential for editing complex commands (multi-line, long pipelines)
autoload -U edit-command-line
zle -N edit-command-line
bindkey '\C-x\C-e' edit-command-line

# [Alt-m] - Copy previous shell word
# WHY: Useful for repeating arguments from previous command
bindkey "^[m" copy-prev-shell-word

# [Alt-w] - Kill from cursor to mark
# WHY: Part of standard emacs editing keybindings
bindkey '\ew' kill-region

#
# Completion Keybindings
#

# [Shift-Tab] - Move through completion menu backwards
# WHY: Complements Tab for bidirectional menu navigation
if [[ -n "${terminfo[kcbt]}" ]]; then
  bindkey -M emacs "${terminfo[kcbt]}" reverse-menu-complete
  bindkey -M viins "${terminfo[kcbt]}" reverse-menu-complete
  bindkey -M vicmd "${terminfo[kcbt]}" reverse-menu-complete
fi

#
# IMPORTANT NOTES (per Constitution Principle III: Respect Standard Behaviors)
#
# The following keybindings are NEVER overridden:
# - Ctrl-D: EOF (exit shell when line is empty)
# - Ctrl-C: SIGINT (interrupt current command)
# - Ctrl-Z: SIGTSTP (suspend current process)
# - Ctrl-L: Clear screen (standard across all terminals)
#
# These are handled by the terminal and shell core, not by ZLE keybindings.
# Attempting to rebind them breaks user expectations and creates frustration.
#

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

# History configuration (based on Oh-My-Zsh history.zsh)
# WHY: Robust history settings improve command recall and productivity

# Set history file and size
# WHY: Default location if not set; increase size to 50k (Oh-My-Zsh standard)
# Configuration via zstyle:
#   zstyle ':zap:history' file '/path/to/history'
#   zstyle ':zap:history' size '100000'
#   zstyle ':zap:history' share 'yes|no'  (default: no)

# Read history file from zstyle or use default
local history_file
zstyle -s ':zap:history' file 'history_file' || history_file="$ZAP_DATA_DIR/.zsh_history"
[ -z "$HISTFILE" ] && HISTFILE="$history_file"

# Read history size from zstyle or use default
local history_size
zstyle -s ':zap:history' size 'history_size' || history_size=50000
[ "$HISTSIZE" -lt "$history_size" ] && HISTSIZE="$history_size"
[ "$SAVEHIST" -lt 10000 ] && SAVEHIST=10000

# History behavior options
setopt EXTENDED_HISTORY       # Record timestamp of command in HISTFILE
setopt HIST_EXPIRE_DUPS_FIRST # Delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt HIST_IGNORE_DUPS       # Don't record duplicate consecutive commands
setopt HIST_IGNORE_SPACE      # Don't record commands starting with space
setopt HIST_VERIFY            # Show command with history expansion (!!) before running it
setopt HIST_FIND_NO_DUPS      # Don't display duplicates when searching

# Share history across sessions (configurable via zstyle)
# WHY: Some users love it (instant history sync), others hate it (per-session isolation).
# Default to 'no' for predictable behavior.
local share_history
zstyle -s ':zap:history' share 'share_history' || share_history='no'

if [[ "$share_history" == 'yes' ]]; then
  setopt SHARE_HISTORY        # Share command history data across all sessions
fi

#
# Additional Quality-of-Life Settings (based on Oh-My-Zsh misc.zsh and directories.zsh)
#
# WHY: These settings improve shell usability without changing behavior significantly
#

# Basic shell behavior
setopt NO_BEEP                # Don't beep on errors
setopt INTERACTIVE_COMMENTS   # Allow comments in interactive shell
setopt AUTO_CD                # cd without typing cd
setopt CORRECT                # Correct minor typos in commands

# Directory navigation (from Oh-My-Zsh directories.zsh)
setopt AUTO_PUSHD             # Automatically push directories onto stack
setopt PUSHD_IGNORE_DUPS      # Don't duplicate directories in stack
setopt PUSHDMINUS             # Swap meaning of cd +1 and cd -1

# Directory aliases for quick navigation
# WHY: Typing ../../.. is tedious; these are muscle memory for many users
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'
alias -- -='cd -'             # Quick switch to previous directory

# Advanced features (from Oh-My-Zsh misc.zsh)
setopt MULTIOS                # Enable redirect to multiple streams: echo >file1 >file2
setopt LONG_LIST_JOBS         # Show long list format job notifications

# Bracketed paste mode - SECURITY FEATURE
# WHY: Prevents accidental execution when pasting commands (e.g., curl|sh exploits).
# Text pasted with bracketed paste is treated as literal, not as keystrokes.
autoload -Uz is-at-least
if [[ $DISABLE_MAGIC_FUNCTIONS != true ]]; then
  for d in $fpath; do
    if [[ -e "$d/url-quote-magic" ]]; then
      if is-at-least 5.1; then
        autoload -Uz bracketed-paste-magic
        zle -N bracketed-paste bracketed-paste-magic
      fi
      autoload -Uz url-quote-magic
      zle -N self-insert url-quote-magic
      break
    fi
  done
fi
