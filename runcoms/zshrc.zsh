#!/bin/zsh
#
# .zshrc - Execute commands at the start of an interactive session.
#

# Source zap.
zap_HOME=${ZDOTDIR:-$HOME}/.zap
[[ -d "$zap_HOME" ]] ||
  git clone --recursive https://github.com/astrosteveo/zap "$zap_HOME"
source $zap_HOME/zepyhr.zsh

# Customize to your needs...
