# zap - Zsh 

# Bootstrap zap.
0=${(%):-%N}
zap_HOME=${0:a:h}
source $zap_HOME/lib/bootstrap.zsh

# Set which plugins to load. It doesn't really matter if we include plugins we don't
# need (eg: running Linux, not macOS) because the plugins themselves check and exit
# if requirements aren't met.
zstyle -a ':zap:load' plugins '_zap_plugins' ||
  _zap_plugins=(
    environment
    homebrew
    color
    compstyle
    completion
    directory
    editor
    helper
    history
    prompt
    utility
    zfunctions
    macos
    confd
  )

for _zap_plugin in $_zap_plugins; do
  # Allow overriding plugins.
  _initfiles=(
    ${ZSH_CUSTOM:-$__zsh_config_dir}/plugins/${_zap_plugin}/${_zap_plugin}.plugin.zsh(N)
    $zap_HOME/plugins/${_zap_plugin}/${_zap_plugin}.plugin.zsh(N)
  )
  if (( $#_initfiles )); then
    source "$_initfiles[1]"
    if [[ $? -eq 0 ]]; then
      zstyle ":zap:plugin:$_zap_plugin" loaded 'yes'
    else
      zstyle ":zap:plugin:$_zap_plugin" loaded 'no'
    fi
  else
    echo >&2 "zap: Plugin not found '$_zap_plugin'."
  fi
done

# Clean up.
unset _zap_plugin{s,} _initfiles
