# Zap

> Minimal Zsh plugin manager with sensible defaults

Inspired by [zsh_unplugged](https://github.com/mattmc3/zsh_unplugged) - because a plugin manager doesn't need to be 5000 lines.

## Install

```bash
git clone https://github.com/astrosteveo/zap.git ~/.zap
```

## Usage

```zsh
# ~/.zshrc
plugins=(
  'zsh-users/zsh-autosuggestions'
  'zsh-users/zsh-syntax-highlighting'
  'ohmyzsh/ohmyzsh:plugins/git'
)

source ~/.zap/zap.zsh
```

That's it. Declare plugins, source zap, done.

## Plugin Formats

```zsh
'owner/repo'              # latest
'owner/repo@v1.0.0'       # pinned version
'owner/repo@branch'       # specific branch
'owner/repo:plugins/git'  # subdirectory (oh-my-zsh style)
```

## Commands

```bash
zap update [plugin]    # update plugins
zap list               # show installed plugins
zap clean              # remove unused plugins
zap doctor             # diagnostics
zap upgrade            # update zap itself
```

## What You Get

Zap provides sensible zsh defaults out of the box:

- **Smart history search** - Type `git` then press Up, only see git commands
- **~/.local/bin in PATH** - Where it should be
- **ls with colors** - Auto-detects eza, falls back to colored ls
- **Keybindings** - Home/End, Ctrl+arrows, Ctrl+R all work
- **Completions** - Case-insensitive, menu selection
- **Terminal titles** - Auto-updating window/tab titles
- **Directory navigation** - `...` for `../..`, `-` for `cd -`
- **Simple prompt** - Git-aware, disable with `zstyle ':zap:prompt' enable 'no'`

## Customization

Put your stuff in `~/.zshrc.local` (auto-sourced after plugins):

```zsh
# ~/.zshrc.local
alias k='kubectl'
eval "$(starship init zsh)"
```

## Using Starship/Powerlevel10k

Disable the built-in prompt:

```zsh
# Before sourcing zap
zstyle ':zap:prompt' enable 'no'

source ~/.zap/zap.zsh

# After sourcing zap
eval "$(starship init zsh)"
```

## License

MIT
