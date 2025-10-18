# Zap - Lightweight Zsh Plugin Manager

A modern, minimal Zsh plugin manager designed for speed and simplicity.

## Features

- **Simple Configuration**: Intuitive syntax for plugin specifications
- **Fast Startup**: Sub-second shell initialization with 10+ plugins
- **Version Pinning**: Lock plugins to specific versions, tags, or commits
- **Framework Compatible**: Works seamlessly with Oh-My-Zsh and Prezto plugins
- **Sensible Defaults**: Working keybindings and completions out of the box
- **Graceful Degradation**: Plugin failures never block shell startup

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/astrosteveo/zap ~/.zap

# Add to your ~/.zshrc
echo 'source ~/.zap/zap.zsh' >> ~/.zshrc

# Restart your shell
exec zsh
```

### Basic Usage

Add plugins to your `~/.zshrc`:

```zsh
source ~/.zap/zap.zsh

# Essential plugins
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions@v0.7.0

# Oh-My-Zsh plugins
zap load ohmyzsh/ohmyzsh path:plugins/git
zap load ohmyzsh/ohmyzsh path:plugins/docker
```

### Power User Example

```zsh
source ~/.zap/zap.zsh

# Performance plugins
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions@v0.7.0
zap load zsh-users/zsh-completions

# Oh-My-Zsh plugins (selective loading)
zap load ohmyzsh/ohmyzsh path:plugins/git
zap load ohmyzsh/ohmyzsh path:plugins/docker
zap load ohmyzsh/ohmyzsh path:plugins/kubectl
zap load ohmyzsh/ohmyzsh path:plugins/terraform

# Theme (pinned for stability)
zap load romkatv/powerlevel10k@v1.16.1
```

## Commands

- `zap load <owner>/<repo>[@version] [path:subdir]` - Load a plugin
- `zap update [<plugin>]` - Update plugins to latest versions
- `zap list [--verbose]` - List installed plugins
- `zap clean [--all] [--yes]` - Clean plugin cache
- `zap doctor` - Diagnose issues
- `zap uninstall [--keep-cache] [--yes]` - Uninstall zap
- `zap help [command]` - Show help information

## Documentation

- **[Quickstart Guide](specs/001-zsh-plugin-manager/quickstart.md)** - Comprehensive usage guide with examples
- **[Troubleshooting](#troubleshooting)** - Common issues and solutions
- **[Migration Guides](#migration-guides)** - Switching from other plugin managers

## Troubleshooting

### Slow shell startup

Run `zap doctor` to diagnose performance issues. Common causes:
- Too many plugins (reduce to essentials)
- Heavy themes (try lighter alternatives)
- Network-dependent plugins (ensure they're cached)

### Plugin not loading

1. Check plugin specification syntax: `owner/repo[@version] [path:subdir]`
2. Run `zap doctor` to see detailed error messages
3. Check `~/.local/share/zap/errors.log` for error details

### Error: "Zsh version too old"

Zap requires Zsh 5.0 or later. Update Zsh:
- **Ubuntu/Debian**: `sudo apt install zsh`
- **macOS**: `brew install zsh`
- **Fedora**: `sudo dnf install zsh`

### Conflicts with other plugin managers

If you see warnings about Antigen/zinit/zplug:
1. Remove other plugin manager initialization from `~/.zshrc`
2. Clean their cache directories
3. Restart your shell

For more help, run: `zap doctor`

## Migration Guides

### From Antigen

Replace:
```zsh
antigen bundle zsh-users/zsh-syntax-highlighting
antigen apply
```

With:
```zsh
zap load zsh-users/zsh-syntax-highlighting
```

### From Oh-My-Zsh

Instead of:
```zsh
plugins=(git docker kubectl)
source $ZSH/oh-my-zsh.sh
```

Use:
```zsh
source ~/.zap/zap.zsh
zap load ohmyzsh/ohmyzsh path:plugins/git
zap load ohmyzsh/ohmyzsh path:plugins/docker
zap load ohmyzsh/ohmyzsh path:plugins/kubectl
```

### From Prezto

Replace:
```zsh
zstyle ':prezto:load' pmodule 'git' 'history'
```

With:
```zsh
zap load sorin-ionescu/prezto path:modules/git
zap load sorin-ionescu/prezto path:modules/history
```

## Requirements

- **Zsh**: 5.0 or later (tested on 5.0, 5.8, 5.9)
- **Git**: 2.0 or later
- **Platform**: Linux, macOS, BSD
- **Disk space**: ~100MB free for plugin cache

## Performance

Zap is designed for speed:
- **Startup time**: < 1 second with 10 plugins
- **Memory overhead**: < 10MB compared to bare Zsh
- **Update check**: < 5 seconds for 10 plugins

## License

MIT License - see LICENSE file for details

## Contributing

Contributions welcome! Please see CONTRIBUTING.md for guidelines.
