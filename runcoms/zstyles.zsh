#!/bin/zsh
#
# .zstyles - Set zstyle options for zap and other plugins/features.
#

#
# General
#

# Set case-sensitivity for completion, history lookup, etc.
# zstyle ':zap:*:*' case-sensitive 'yes'

# Set the zap plugins to load (browse plugins).
# The order matters.
zstyle ':zap:load' plugins \
  'environment' \
  'editor' \
  'history' \
  'directory' \
  'color' \
  'utility' \
  'completion' \
  'prompt'

#
# Completions
#

# Set the entries to ignore in static '/etc/hosts' for host completion.
# zstyle ':zap:plugin:completion:*:hosts' etc-host-ignores \
#   '0.0.0.0' '127.0.0.1'

# Set the preferred completion style.
# zstyle ':zap:plugin:completion' compstyle 'zap'

#
# Editor
#

# Set the key mapping style to 'emacs' or 'vi'.
zstyle ':zap:plugin:editor' key-bindings 'emacs'

# Auto convert .... to ../..
# zstyle ':zap:plugin:editor' dot-expansion 'yes'

# Use ^z to return background processes to foreground.
# zstyle ':zap:plugin:editor' symmetric-ctrl-z 'yes'

# Expand aliases to their actual command like Fish abbreviations.
# zstyle ':zap:plugin:editor' glob-alias 'yes'

# Set the default (magic) command when hitting enter on an empty prompt.
# zstyle ':zap:plugin:editor' magic-enter 'yes'
# zstyle ':zap:plugin:editor:magic-enter' command 'ls -lh .'
# zstyle ':zap:plugin:editor:magic-enter' git-command 'git status -u .'

#
# History
#

# Set the file to save the history in when an interactive shell exits.
# zstyle ':zap:plugin:history' histfile "${ZDOTDIR:-$HOME}/.zsh_history"

# Set the maximum number of events stored in the internal history list.
# zstyle ':zap:plugin:history' histsize 10000

# Set the maximum number of history events to save in the history file.
# zstyle ':zap:plugin:history' savehist 10000

#
# Prompt
#

# Set the prompt theme to load.
# starship themes: zap, hydro, prezto
zstyle ':zap:plugin:prompt' theme starship zap
