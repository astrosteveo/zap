#!/usr/bin/env zsh
#
# nvm.zsh - Node Version Manager lazy-loading support
#
# WHY: nvm is essential for Node.js development but slow to load (~200-500ms).
# Lazy-loading gives users nvm functionality without startup cost (Principle IV).
# Auto-detection means zero configuration required (Principle III).
#
# Configuration (via zstyle):
#   zstyle ':zap:nvm' enable 'yes|no|auto'  # Enable nvm (default: auto-detect)
#   zstyle ':zap:nvm' dir '/path/to/nvm'    # Custom nvm directory (default: $NVM_DIR or ~/.nvm)
#   zstyle ':zap:nvm' lazy-load 'yes|no'    # Lazy-load (default: yes)
#
# Examples:
#   # Force enable (even if ~/.nvm doesn't exist)
#   zstyle ':zap:nvm' enable 'yes'
#
#   # Disable nvm support entirely
#   zstyle ':zap:nvm' enable 'no'
#
#   # Custom nvm directory
#   zstyle ':zap:nvm' dir '/opt/nvm'
#
#   # Disable lazy-loading (immediate load, slower startup)
#   zstyle ':zap:nvm' lazy-load 'no'

# Check if explicitly disabled
local enable_nvm
zstyle -s ':zap:nvm' enable 'enable_nvm' || enable_nvm='auto'

if [[ "$enable_nvm" == 'no' ]]; then
  return 0
fi

# Determine nvm directory
local nvm_dir
zstyle -s ':zap:nvm' dir 'nvm_dir' || nvm_dir="${NVM_DIR:-$HOME/.nvm}"
export NVM_DIR="$nvm_dir"

# Auto-detection: only enable if nvm is installed
if [[ "$enable_nvm" == 'auto' ]]; then
  [[ ! -d "$NVM_DIR" ]] && return 0
fi

# If explicitly enabled but nvm.sh doesn't exist, warn user
if [[ "$enable_nvm" == 'yes' && ! -s "$NVM_DIR/nvm.sh" ]]; then
  print "[zap] Warning: nvm enabled but $NVM_DIR/nvm.sh not found" >&2
  return 1
fi

# Check if lazy-loading is disabled
local lazy_load
zstyle -s ':zap:nvm' lazy-load 'lazy_load' || lazy_load='yes'

if [[ "$lazy_load" == 'no' ]]; then
  # Immediate load (slower startup)
  # WHY: Some users need nvm available immediately (e.g., prompt integrations)
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  return 0
fi

# Lazy-load nvm on first use (default behavior)
# WHY: Defer expensive nvm.sh sourcing (~200-500ms) until actually needed
_zap_nvm_lazy_load() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}

# Create placeholder functions that trigger real nvm load
# WHY: First invocation loads nvm, then calls the real function
nvm() {
  _zap_nvm_lazy_load
  nvm "$@"
}

node() {
  _zap_nvm_lazy_load
  node "$@"
}

npm() {
  _zap_nvm_lazy_load
  npm "$@"
}

npx() {
  _zap_nvm_lazy_load
  npx "$@"
}
