# Quickstart Guide: Zsh Plugin Manager (Zap)

**Feature**: 001-zsh-plugin-manager
**Date**: 2025-10-17
**Audience**: End users (developers using Zsh)

## What is Zap?

Zap is a lightweight, easy-to-use plugin manager for Zsh. It's designed to be a modern alternative to Antigen with:
- Simple, intuitive configuration
- Automatic plugin downloads and updates
- Built-in Oh-My-Zsh and Prezto compatibility
- Fast startup times (< 1 second with 10 plugins)
- Sensible defaults (working keybindings and completions out of the box)

## Installation

### One-Command Install

```bash
curl -sL https://raw.githubusercontent.com/astrosteveo/zap/main/install.zsh | zsh
```

### Manual Install

1. Clone the repository:
   ```bash
   git clone https://github.com/astrosteveo/zap ~/.zap
   ```

2. Add to your `~/.zshrc`:
   ```zsh
   source ~/.zap/zap.zsh
   ```

3. Restart your shell:
   ```bash
   exec zsh
   ```

## Basic Usage

### Loading Your First Plugin

Add this line to your `~/.zshrc` (after sourcing zap.zsh):

```zsh
zap load zsh-users/zsh-syntax-highlighting
```

Restart your shell, and syntax highlighting is active!

### Loading Multiple Plugins

```zsh
# In ~/.zshrc
source ~/.zap/zap.zsh

# Essential plugins
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions
zap load zsh-users/zsh-completions

# Theme
zap load romkatv/powerlevel10k
```

That's it! Zap will:
1. Download each plugin on first shell startup
2. Load them in the order specified
3. Cache them for fast subsequent startups

## Advanced Features

### Version Pinning

Lock a plugin to a specific version:

```zsh
zap load zsh-users/zsh-autosuggestions@v0.7.0
```

This ensures the plugin won't change when you update.

### Oh-My-Zsh Plugins

Use any Oh-My-Zsh plugin without installing Oh-My-Zsh:

```zsh
# Load specific Oh-My-Zsh plugins
zap load ohmyzsh/ohmyzsh path:plugins/git
zap load ohmyzsh/ohmyzsh path:plugins/kubectl
zap load ohmyzsh/ohmyzsh path:plugins/docker
```

Zap automatically detects and configures the Oh-My-Zsh environment.

### Prezto Modules

Similarly, use Prezto modules:

```zsh
zap load sorin-ionescu/prezto path:modules/git
zap load sorin-ionescu/prezto path:modules/history
```

### Subdirectory Plugins

Some repositories contain multiple plugins in subdirectories:

```zsh
zap load ohmyzsh/ohmyzsh path:plugins/git
```

The `path:` annotation tells zap to load only that specific subdirectory.

## Common Tasks

### Updating Plugins

Check for updates:

```zsh
zap update
```

Output:
```
Checking for updates...
  zsh-users/zsh-syntax-highlighting  current
  zsh-users/zsh-autosuggestions      v0.7.0 → v0.7.1
  ohmyzsh/ohmyzsh                    pinned (skipped)
  romkatv/powerlevel10k              current

Updated 1 plugin. Restart your shell to apply changes.
```

Update a specific plugin:

```zsh
zap update zsh-users/zsh-autosuggestions
```

### Listing Installed Plugins

```zsh
zap list
```

Output:
```
Installed plugins:
  zsh-users/zsh-syntax-highlighting  master   ✓ loaded
  zsh-users/zsh-autosuggestions      v0.7.1   ✓ loaded
  ohmyzsh/ohmyzsh                    master   ✓ loaded (framework)
  romkatv/powerlevel10k              v1.16.1  ✓ loaded

Total: 4 plugins
```

For more details:

```zsh
zap list --verbose
```

### Cleaning Cache

Remove temporary files:

```zsh
zap clean
```

Remove everything (requires confirmation):

```zsh
zap clean --all
```

### Troubleshooting

Run diagnostics:

```zsh
zap doctor
```

This checks:
- Zsh and Git versions
- File permissions
- Plugin load errors
- Startup performance issues

## Configuration Examples

### Minimal Setup

```zsh
# ~/.zshrc
source ~/.zap/zap.zsh

zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions
```

### Power User Setup

```zsh
# ~/.zshrc
source ~/.zap/zap.zsh

# Performance: syntax highlighting and autosuggestions
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions@v0.7.0
zap load zsh-users/zsh-completions

# Oh-My-Zsh plugins
zap load ohmyzsh/ohmyzsh path:plugins/git
zap load ohmyzsh/ohmyzsh path:plugins/docker
zap load ohmyzsh/ohmyzsh path:plugins/kubectl
zap load ohmyzsh/ohmyzsh path:plugins/terraform

# Theme (pinned version for stability)
zap load romkatv/powerlevel10k@v1.16.1

# Additional utilities
zap load zsh-users/zsh-history-substring-search
```

### File-Based Configuration

For cleaner separation, use a separate config file:

```zsh
# ~/.zshrc
source ~/.zap/zap.zsh
zap init ~/.zap/plugins.zsh
```

```zsh
# ~/.zap/plugins.zsh
zsh-users/zsh-syntax-highlighting
zsh-users/zsh-autosuggestions@v0.7.0
ohmyzsh/ohmyzsh path:plugins/git
romkatv/powerlevel10k@v1.16.1
```

Both approaches work identically.

### Advanced Configuration with zstyle

Zap uses Zsh's `zstyle` system for configuration, providing a clean and powerful way to customize behavior.

**Creating a configuration file:**

The installer can optionally create `~/.zaprc` with example configurations:

```bash
cp ~/.zap/config/zaprc.template ~/.zaprc
```

Then edit `~/.zaprc` to customize. All settings are commented by default.

**Common configurations:**

```zsh
# ~/.zaprc

# Node.js version manager (auto-detected, lazy-loaded by default)
zstyle ':zap:nvm' enable 'yes'        # Force enable
zstyle ':zap:nvm' lazy-load 'no'      # Immediate load (slower startup)

# Disable built-in prompt (use Starship instead)
zstyle ':zap:prompt' enable 'no'

# Customize history size
zstyle ':zap:history' size '100000'

# Disable auto-pushd
zstyle ':zap:directories' auto-pushd 'no'

# Use vi mode for keybindings
zstyle ':zap:keybindings' mode 'vi'
```

**Version managers supported:**
- **nvm** (Node.js) - Auto-detected if `~/.nvm` exists
- **rbenv** (Ruby) - Auto-detected if `~/.rbenv` exists
- **pyenv** (Python) - Auto-detected if `~/.pyenv` exists

All version managers use lazy-loading by default for fast startup.

**Viewing active configuration:**

```zsh
# Show all zap zstyles
zstyle -L ':zap:*'
```

**Configuration precedence:**
1. `~/.zaprc` (if it exists) - user customization
2. Built-in defaults - sensible out-of-the-box behavior

For a complete list of configuration options, see `~/.zap/config/zaprc.template`.

## Default Features

Zap provides sensible defaults out of the box, even with zero plugins:

### Keybindings

Zap provides working keybindings out of the box (based on Oh-My-Zsh):

**Smart History Search** (the killer feature!):
- Start typing a command, then press **Up/Down arrows**
- Only shows commands that start with what you've typed
- Example: Type `git` then Up arrow → only see git commands

**Navigation:**
- **Home / End**: Beginning/end of line
- **Ctrl-Left / Ctrl-Right**: Move by word
- **Page Up / Page Down**: Full history navigation
- **Ctrl-R**: Reverse incremental search

**Editing:**
- **Delete / Backspace**: Delete character
- **Ctrl-Delete**: Kill word forward
- **Ctrl-U / Ctrl-K**: Kill line backward/forward
- **Ctrl-W**: Kill word backward
- **Ctrl-X Ctrl-E**: Edit command in $EDITOR

**Completion:**
- **Tab**: Complete and cycle
- **Shift-Tab**: Reverse cycle

**Mode Support:**
- **Emacs mode** (default): Ctrl-A, Ctrl-E, Ctrl-R, Ctrl-U, Ctrl-K, etc.
- **Vi mode**: Fully supported! Add `bindkey -v` before sourcing zap
  ```zsh
  # In ~/.zshrc
  bindkey -v              # Enable vi mode
  source ~/.zap/zap.zsh   # Then source zap
  ```

All navigation keys work in both modes.

### Tab Completion

Basic tab completion works immediately:
- Command completion
- File/directory completion
- Option completion for common commands
- Case-insensitive matching

### Prompt

Zap includes a simple, fast built-in prompt:

```
user@host ~/projects/zap main ❯
```

Features:
- Shows username@hostname (only on remote/SSH or when root)
- Current directory with ~ expansion
- Git branch (if in git repo)
- Color-coded prompt (green = success, red = last command failed)
- Zero dependencies, pure Zsh

**Want a fancier prompt?** Use Starship!

[Starship](https://starship.rs/) is a fast, beautiful, cross-shell prompt written in Rust.

Install Starship:
```bash
curl -sS https://starship.rs/install.sh | sh
```

Enable in your `~/.zshrc` (**before** sourcing zap):
```zsh
# Disable zap's built-in prompt
export ZAP_DISABLE_PROMPT=true

# Enable Starship
eval "$(starship init zsh)"

# Then source zap
source ~/.zap/zap.zsh

# Load plugins...
zap load zsh-users/zsh-syntax-highlighting
```

**Why Starship?**
- Shows git status, language versions (Node, Python, Rust, etc.)
- Customizable modules
- Fast (Rust compiled binary)
- Works across shells (zsh, bash, fish, powershell)
- Beautiful defaults

**Or use any custom prompt!** Just set `ZAP_DISABLE_PROMPT=true` and configure your own.

## Performance Tips

1. **Pin versions for stability**: Use `@version` to avoid unexpected changes
2. **Load order matters**: Faster plugins first (syntax highlighting before themes)
3. **Monitor startup time**: Run `time zsh -i -c exit` to measure
4. **Use zap doctor**: Identifies slow plugins and suggests optimizations

## Migrating from Other Plugin Managers

### From Antigen

Replace:
```zsh
antigen bundle zsh-users/zsh-syntax-highlighting
```

With:
```zsh
zap load zsh-users/zsh-syntax-highlighting
```

Zap uses the same repository format, so most migrations are search-and-replace.

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

Zap automatically handles Oh-My-Zsh setup.

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

## FAQ

### Where are plugins stored?

Plugins are downloaded to `~/.local/share/zap/plugins/` following the XDG Base Directory specification.

### How do I disable a plugin temporarily?

Comment it out in your `~/.zshrc`:

```zsh
# zap load zsh-users/zsh-autosuggestions
```

Restart your shell. The plugin remains cached but won't load.

### How do I remove a plugin completely?

1. Remove the `zap load` line from `~/.zshrc`
2. Run `zap clean --all` to remove the cache
3. Restart your shell

### Why is my shell startup slow?

Run `zap doctor` to diagnose. Common causes:
- Too many plugins (reduce to essentials)
- Heavy themes (try lighter alternatives)
- Network-dependent plugins (ensure they're cached)

### Can I use private Git repositories?

Yes, if you have SSH keys configured:

```zsh
zap load mycompany/private-plugin
```

Zap uses standard Git clone, which respects your SSH configuration.

### What if a plugin breaks my shell?

1. Open a new terminal (starts fresh shell)
2. Edit `~/.zshrc` and comment out the problematic plugin
3. Restart shell or run `source ~/.zshrc`
4. Run `zap doctor` to see error details

Zap never blocks shell startup, so a broken plugin won't lock you out.

## Getting Help

- **Documentation**: Visit https://github.com/astrosteveo/zap
- **Issues**: Report bugs at https://github.com/astrosteveo/zap/issues
- **Diagnostics**: Run `zap doctor` for automated troubleshooting
- **Help**: Run `zap help` for command reference

## Next Steps

1. **Explore plugins**: Browse popular Zsh plugins on GitHub
2. **Customize**: Add your favorite plugins to `~/.zshrc`
3. **Share**: Tell others about Zap if you find it useful
4. **Contribute**: Submit improvements or report issues

Happy Zsh-ing! 🚀
