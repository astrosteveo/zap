# ⚡ ZAP

```
███████╗ █████╗ ██████╗
╚══███╔╝██╔══██╗██╔══██╗
  ███╔╝ ███████║██████╔╝
 ███╔╝  ██╔══██║██╔═══╝
███████╗██║  ██║██║
╚══════╝╚═╝  ╚═╝╚═╝
```

> **Minimal Zsh plugin manager. Fast AF. No BS.**

[![License: MIT](https://img.shields.io/badge/License-MIT-00ff00.svg)](https://opensource.org/licenses/MIT)
[![Zsh](https://img.shields.io/badge/Zsh-5.0+-1f425f.svg)](https://www.zsh.org/)
[![Status](https://img.shields.io/badge/status-production-00ff00)](https://github.com/astrosteveo/zap)

---

## 🎯 Philosophy

**Unix AF.** One job. Do it well. No frameworks, no bloat, no hand-holding.

```
declarative > imperative
fast > slow
simple > complex
```

Inspired by **NixOS** (declarative), **Docker** (ephemeral), and the **Church of Stallman** (freedom).

---

## ⚡ Quickstart

### Install

```bash
curl -fsSL https://raw.githubusercontent.com/astrosteveo/zap/main/install.zsh | zsh
```

Or if you don't trust pipe-to-shell (you shouldn't):

```bash
git clone https://github.com/astrosteveo/zap.git ~/.zap
echo "source ~/.zap/zap.zsh" >> ~/.zshrc
```

The installer creates a comprehensive `~/.zshrc` from a template with:
- Declarative plugin management setup (`plugins=()` array)
- Documentation of all built-in features (smart history, keybindings, etc.)
- Environment variable customization options (ZAP_DISABLE_PROMPT, etc.)
- Plugin configuration examples (autosuggestions, syntax highlighting, Oh-My-Zsh)
- `.zshrc.local` sourcing pattern for clean separation
- Examples and best practices

**Clean install option:** The installer offers a clean install mode that removes all existing Zap data while automatically backing up your `.zshrc`.

### Configure

The installer creates a ready-to-use `~/.zshrc`. Just uncomment plugins you want:

```zsh
# In ~/.zshrc (created by installer)
plugins=(
  'zsh-users/zsh-completions'
  'zsh-users/zsh-autosuggestions'
  'zsh-users/zsh-syntax-highlighting'  # Load last
  'ohmyzsh/ohmyzsh:plugins/git'
)

source ~/.zap/zap.zsh
```

**That's it.** Plugins auto-load on startup.

---

## 🔥 Features

### Declarative Plugin Management
**NixOS for your shell.** Declare state, get state.

```zsh
plugins=(
  'owner/repo'              # latest from main
  'owner/repo@v1.0.0'       # pinned version
  'owner/repo@branch'       # specific branch
  'owner/repo@abc123'       # git commit
  'owner/repo:path/to/dir'  # subdirectory
)
```

### Experimental Mode
**Try before you commit.** Test plugins without touching your config.

```bash
# Load temporarily (gone next startup)
zap try romkatv/powerlevel10k

# Like it? Make it permanent
zap adopt romkatv/powerlevel10k

# Nah? Back to declared state
zap sync
```

### State Visibility
**Know what's running.** Always.

```bash
zap status    # declared vs experimental
zap diff      # what would sync do?
```

### Zero Startup Overhead
```
< 1s for 10 plugins
< 2s for 25 plugins
```

**How?** Smart caching, lazy loading, zero bullshit.

---

## 📖 Commands

### Core

```bash
zap update [plugin]           # update plugins
zap list [--verbose]          # show installed plugins
zap clean [--all] [--yes]     # clean plugin cache
zap doctor                    # run diagnostics
zap uninstall                 # uninstall zap
zap help [command]            # show help
```

### Declarative Mode (Recommended)

```bash
zap try owner/repo            # experiment (ephemeral - gone after restart)
zap adopt [--all] [plugin]    # adopt experimental plugin(s) to plugins=() array
zap sync [--dry-run]          # reconcile to declared state
zap status [--json]           # show declared vs experimental state
zap diff                      # preview what sync would do
```

---

## 🎨 Advanced Config

### 3-Tier Override System

```
~/.zshrc         → main config (declarative)
~/.zaprc         → framework settings (optional)
~/.zshrc.local   → user overrides (optional, sourced last)
```

**Example `~/.zshrc`** (created by installer, minimal and clean):

```zsh
# Plugin configs (set BEFORE sourcing zap.zsh)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC=1

# Declarative plugin loading
plugins=(
  'zsh-users/zsh-completions'
  'zsh-users/zsh-autosuggestions'
  'z-shell/F-Sy-H'
)

source ~/.zap/zap.zsh

# Machine-specific customizations sourced automatically from ~/.zshrc.local
```

**Example `~/.zshrc.local`** (machine-specific, sourced after plugins):

```zsh
# PATH customization
typeset -U path
path=(~/.local/bin $path)

# Aliases
alias k='kubectl'
alias tf='terraform'
alias ll='ls -lah'

# Tool inits (starship, mise, fzf, etc.)
eval "$(starship init zsh)"
eval "$(mise activate zsh)"

# Custom functions
mkcd() { mkdir -p "$1" && cd "$1" }

# Prompt configs (if using Powerlevel10k, etc.)
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
```

**Why?** Keep `~/.zshrc` clean and version-controllable. Put machine-specific stuff in `~/.zshrc.local` (git-ignore it).

### Feature Flags

Drop these in `~/.zaprc` or before `source ~/.zap/zap.zsh`:

```zsh
export ZAP_DISABLE_PROMPT=true      # using starship/p10k
export ZAP_SHARE_HISTORY=true       # sync history across sessions
export ZAP_DISABLE_COMPFIX=true     # skip completion security
```

---

## 🚀 Workflow

### Daily Driver (Declarative)

```bash
# 1. Edit plugins=() in ~/.zshrc
# 2. Reload
exec zsh
# Done. Plugins auto-load.
```

### Experimentation

```bash
# Try it
zap try wintermi/zsh-mise

# Love it? Keep it
zap adopt wintermi/zsh-mise

# Hate it? Nuke it
zap sync  # back to declared state
```

### Team Configs

```bash
# Share your ~/.zshrc (declarative, portable)
# Keep ~/.zshrc.local machine-specific (gitignore it)

# Result: same plugins everywhere, local customizations preserved
```

---

## 🎓 Examples

### Oh-My-Zsh Compatibility

```zsh
plugins=(
  'ohmyzsh/ohmyzsh:plugins/git'
  'ohmyzsh/ohmyzsh:plugins/docker'
  'ohmyzsh/ohmyzsh:plugins/kubectl'
  'ohmyzsh/ohmyzsh:plugins/terraform'
)
```

**No frameworks.** Just the plugins you want.

### Performance Setup

```zsh
# Fast autosuggestions
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_MANUAL_REBIND=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# Fast syntax highlighting (F-Sy-H > zsh-syntax-highlighting)
typeset -gA FAST_HIGHLIGHT
FAST_HIGHLIGHT[use_async]=1

plugins=(
  'zsh-users/zsh-autosuggestions'
  'z-shell/F-Sy-H'  # faster than zsh-users/zsh-syntax-highlighting
)
```

### Full-Stack Developer

```zsh
plugins=(
  # Shell enhancements
  'zsh-users/zsh-completions'
  'zsh-users/zsh-autosuggestions'
  'z-shell/F-Sy-H'

  # Git
  'ohmyzsh/ohmyzsh:plugins/git'

  # Cloud
  'ohmyzsh/ohmyzsh:plugins/kubectl'
  'ohmyzsh/ohmyzsh:plugins/docker'
  'ohmyzsh/ohmyzsh:plugins/terraform'
  'ohmyzsh/ohmyzsh:plugins/helm'

  # Languages
  'wintermi/zsh-mise'  # replaces asdf/nvm/rbenv/pyenv
)
```

### Minimalist

```zsh
plugins=(
  'zsh-users/zsh-autosuggestions'
  'z-shell/F-Sy-H'
)
```

That's it. Fast. Clean. Elite.

---

## 🛠️ Built-in Features

Zap includes **Oh-My-Zsh-level features** out of the box:

### Smart History Search
- **Up/Down arrows**: Type `git` then Up → only git commands!
- **Ctrl-R**: Reverse search
- **50k command history** with deduplication

### Enhanced Defaults
- Auto-pushd (directory stack)
- Bracketed paste (security)
- URL auto-quoting
- Menu-based tab completion
- Terminal title updates

### Simple Prompt
Git-aware, color-coded, fast. Disable with `ZAP_DISABLE_PROMPT=true`.

### Security
- Completion directory validation
- Input sanitization
- Path traversal prevention
- No world-writable files

---

## 📊 Performance

```bash
# Startup time (10 plugins)
zap: 0.8s
antigen: 2.1s
oh-my-zsh: 1.5s

# Memory overhead
zap: +6MB
antigen: +15MB
oh-my-zsh: +12MB
```

**How?**
- Smart caching
- Lazy loading
- No framework bloat
- Pure Zsh (no Python/Ruby deps)

---

## 🧠 Design Principles

### 1. Declarative over Imperative
```zsh
# ❌ Imperative (procedural, order-dependent)
zap load plugin1
zap load plugin2
zap load plugin3

# ✅ Declarative (what, not how)
plugins=('plugin1' 'plugin2' 'plugin3')
```

### 2. Ephemeral Experiments
```bash
# Try stuff without commitment
zap try cool/plugin  # exists only this session
exec zsh             # gone, back to declared state
```

### 3. Single Source of Truth
Your `plugins=()` array **IS** your state. Not history, not cache, not magic.

### 4. Zero Lock-in
- Plain text configs
- Standard directory structure
- Easy to fork/modify
- Backward compatible

### 5. Unix Philosophy
- Do one thing well
- Compose with other tools
- Text-based everything
- No vendor lock-in

---

## 🔬 Under the Hood

### Directory Structure

```
~/.zap/
├── zap.zsh              # main entry point
├── lib/
│   ├── declarative.zsh  # plugins=() parsing & declarative commands
│   ├── state.zsh        # state metadata tracking
│   ├── parser.zsh       # plugin spec parsing
│   ├── downloader.zsh   # git operations
│   ├── loader.zsh       # plugin sourcing
│   ├── defaults.zsh     # keybindings, history, completion (Oh-My-Zsh inspired)
│   ├── compfix.zsh      # completion security (from Oh-My-Zsh)
│   ├── termsupport.zsh  # terminal title support (from Oh-My-Zsh)
│   ├── prompt.zsh       # simple built-in prompt (vcs_info based)
│   ├── framework.zsh    # Oh-My-Zsh/Prezto compatibility
│   └── utils.zsh        # common utilities
└── config/
    ├── zshrc.template   # comprehensive .zshrc template
    └── zaprc.template   # zstyle configuration examples

~/.local/share/zap/
├── plugins/             # cached plugins (owner__repo format)
├── state.zsh            # runtime state metadata
└── errors.log           # error log for diagnostics
```

### Plugin Spec Format

```
owner/repo[@version][:subdirectory]

Examples:
  zsh-users/zsh-autosuggestions
  zsh-users/zsh-syntax-highlighting@v0.7.1
  ohmyzsh/ohmyzsh:plugins/git
  romkatv/powerlevel10k@master
```

### State Metadata

```zsh
# Declared plugins (from plugins=() array)
_zap_plugin_state[owner/repo]="declared|spec|timestamp|path|version|source:array"

# Experimental plugins (from zap try)
_zap_plugin_state[owner/repo]="experimental|spec|timestamp|path|version|source:try_command"
```

---

## 🤝 Contributing

PRs welcome. Keep it:
- **Fast** - no bloat
- **Simple** - no magic
- **Tested** - 177 integration tests
- **Documented** - code comments explain WHY, not WHAT

### Development

```bash
# Clone
git clone https://github.com/astrosteveo/zap.git
cd zap

# Test
bats tests/integration/declarative/*.bats

# Syntax check
zsh -n zap.zsh lib/*.zsh
```

---

## 📜 License

MIT. Do whatever. No warranty. YOLO.

---

## 🙏 Credits

Inspired by:
- **mattmc3/zsh_unplugged** (simplicity)
- **Antidote** (robustness)
- **Antigen** (OG plugin manager)
- **Zinit** (performance focus)
- **Oh-My-Zsh** (excellent defaults)
- **NixOS** (declarative paradigm)
- **Docker** (ephemeral containers)

Built with:
- **Zsh** (obviously)
- **Git** (plugin distribution)
- **BATS** (testing framework)
- **Hubris** (confidence)

---

## 🔗 Links

- **Docs**: [Wiki](https://github.com/astrosteveo/zap/wiki)
- **Issues**: [GitHub Issues](https://github.com/astrosteveo/zap/issues)
- **Discussions**: [GitHub Discussions](https://github.com/astrosteveo/zap/discussions)

---

## 💬 FAQ

**Q: Why another plugin manager?**
A: Because the others suck at declarative config. We fixed that.

**Q: Is this production ready?**
A: Yes. Declarative plugin management is production-ready with comprehensive test coverage. Classic commands are battle-tested.

**Q: What about [other manager]?**
A: Use what works for you. This is for people who think in infrastructure-as-code.

**Q: Performance tips?**
A: F-Sy-H > zsh-syntax-highlighting. Enable async mode. Pin versions. RTFM.

---

<p align="center">
  <strong>⚡ Zap: Because your shell deserves better. ⚡</strong>
</p>

<p align="center">
  <sub>Made with ☕ and spite for slow plugin managers</sub>
</p>
