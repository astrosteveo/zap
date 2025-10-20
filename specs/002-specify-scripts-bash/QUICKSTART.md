# Declarative Plugin Management - Quickstart Guide

This guide shows you how to use Zap's declarative plugin management system to declare your desired plugin state, experiment fearlessly, and reconcile back to your configuration.

## 🎯 Core Concepts

**Declarative Configuration**: Declare what plugins you want in a `plugins=()` array, and Zap automatically loads them.

**Experimental Plugins**: Try plugins temporarily with `zap try` without modifying your config.

**Reconciliation**: Return to your declared state with `zap sync`, removing all experimental plugins.

---

## 📦 User Story 1: Declare Desired Plugin State

### Goal
Stop writing repetitive `zap load` commands. Declare your plugins once in an array, and Zap loads them automatically on every shell startup.

### Setup

Add a `plugins=()` array to your `.zshrc` (before sourcing zap.zsh):

```zsh
# Declare your desired plugins
plugins=(
  zsh-users/zsh-autosuggestions
  zsh-users/zsh-syntax-highlighting
  romkatv/powerlevel10k
)

# Source Zap (this auto-loads all declared plugins)
source ~/.zap/zap.zsh
```

### What Happens

1. Zap reads your `plugins=()` array
2. Each plugin is validated and loaded in order
3. Plugins are tracked as "declared" in state metadata
4. On next shell startup, the same plugins auto-load

### Advanced Syntax

```zsh
plugins=(
  # Basic plugin
  zsh-users/zsh-autosuggestions

  # Pin to specific version
  romkatv/powerlevel10k@v1.19.0

  # Use subdirectory
  ohmyzsh/ohmyzsh:plugins/git

  # Combine version + subdir
  ohmyzsh/ohmyzsh@master:plugins/docker
)
```

### Key Benefits

- ✅ **Version-controlled dotfiles**: Your `.zshrc` is the single source of truth
- ✅ **Predictable startup**: Same plugins load every time
- ✅ **Load order preservation**: Plugins load in array order (important for dependencies)
- ✅ **Graceful error handling**: Bad plugins logged but don't block shell startup

---

## 🧪 User Story 2: Experiment with Temporary Plugins

### Goal
Try new plugins without modifying your `.zshrc`. Experimental plugins are NOT reloaded on shell restart, enabling fearless experimentation.

### Usage

```bash
# Try a plugin experimentally
zap try zsh-users/zsh-completions

# Output:
# Downloading zsh-users/zsh-completions...
# ✓ Loaded zsh-users/zsh-completions experimentally
#   This plugin will NOT be reloaded on shell restart.
#   To make it permanent, add it to your plugins=() array.
#   To return to declared state, run: zap sync
```

### What Happens

1. Plugin is downloaded (if not already cached)
2. Plugin is loaded into current shell session
3. Plugin is tracked as "experimental" in state metadata
4. **On shell restart**: Experimental plugin is NOT reloaded

### Check Current State

```bash
zap status

# Output:
# === Zap Plugin Status ===
#
# Declared plugins (3):
#   ✓ zsh-users/zsh-autosuggestions [abc123]
#   ✓ zsh-users/zsh-syntax-highlighting [def456]
#   ✓ romkatv/powerlevel10k [ghi789]
#
# Experimental plugins (1):
#   ⚡ zsh-users/zsh-completions [jkl012]
#
# Run 'zap sync' to remove experimental plugins
```

### Safety Features

- **No accidental permanence**: Experiments never auto-load
- **Clear feedback**: Always tells you when plugin is experimental
- **Easy cleanup**: `zap sync` removes all experiments
- **Already-declared protection**: Won't load experimental if already declared

---

## 🔄 User Story 3: Reconcile to Declared State

### Goal
Return your shell to the exact state defined in your `.zshrc`, removing all experimental plugins.

### Usage

```bash
# After trying some plugins experimentally...
zap try zsh-users/zsh-completions
zap try zdharma/fast-syntax-highlighting

# Check what's different
zap status

# Return to declared state
zap sync

# Output:
# Synchronizing to declared state...
# ✓ Removed 2 experimental plugin(s)
#   Your shell is now in sync with your declared configuration.
#   Note: You may need to restart your shell for full cleanup.
```

### What Happens

1. Zap identifies experimental plugins (state="experimental")
2. Removes them from state metadata
3. Reports how many were removed
4. Your shell now matches your `.zshrc` exactly

### Idempotent Operation

Running `zap sync` multiple times is safe:

```bash
zap sync  # Removes 2 experimental plugins
zap sync  # Output: ✓ Already in sync - no experimental plugins loaded
zap sync  # Output: ✓ Already in sync - no experimental plugins loaded
```

### When to Use

- **After experimentation**: Tried several plugins, want to clean up
- **Before committing dotfiles**: Ensure `.zshrc` reflects actual state
- **Troubleshooting**: Reset to known-good configuration
- **Daily workflow**: Start fresh each morning

---

## 📊 Complete Workflow Example

```bash
# 1. Start with declared plugins in .zshrc
cat ~/.zshrc
# plugins=(
#   zsh-users/zsh-autosuggestions
#   zsh-users/zsh-syntax-highlighting
# )
# source ~/.zap/zap.zsh

# 2. Try a new plugin experimentally
zap try romkatv/powerlevel10k
# ✓ Loaded romkatv/powerlevel10k experimentally

# 3. Try another plugin
zap try zsh-users/zsh-completions
# ✓ Loaded zsh-users/zsh-completions experimentally

# 4. Check status
zap status
# Declared plugins (2):
#   ✓ zsh-users/zsh-autosuggestions
#   ✓ zsh-users/zsh-syntax-highlighting
# Experimental plugins (2):
#   ⚡ romkatv/powerlevel10k
#   ⚡ zsh-users/zsh-completions

# 5. Like powerlevel10k? Add it to .zshrc manually
vim ~/.zshrc
# plugins=(
#   zsh-users/zsh-autosuggestions
#   zsh-users/zsh-syntax-highlighting
#   romkatv/powerlevel10k  # ← ADDED
# )

# 6. Sync to remove leftover experiments
zap sync
# ✓ Removed 2 experimental plugin(s)

# 7. Restart shell - only declared plugins load
exec zsh

# 8. Verify
zap status
# Declared plugins (3):
#   ✓ zsh-users/zsh-autosuggestions
#   ✓ zsh-users/zsh-syntax-highlighting
#   ✓ romkatv/powerlevel10k
# Experimental plugins: (none)
# ✓ In sync with declared configuration
```

---

## 🔐 Security Features

All plugin specifications are validated to prevent:

- **Path traversal**: `../../../etc/passwd` rejected
- **Command injection**: `owner/repo; rm -rf /` rejected
- **Shell metacharacters**: `;`, `` ` ``, `$()`, `|`, `&`, etc. rejected
- **Absolute paths**: `/etc/passwd` rejected
- **Length limits**: Max 256 characters (DoS prevention)

Example:

```bash
zap try "../evil/plugin"
# Error: Path traversal detected in plugin specification

zap try "owner/repo; whoami"
# Error: Invalid characters detected in plugin specification
```

---

## 🎨 Design Philosophy

### Declarative over Imperative

**Before (Imperative)**:
```zsh
zap load zsh-users/zsh-autosuggestions
zap load zsh-users/zsh-syntax-highlighting
zap load romkatv/powerlevel10k
```

**After (Declarative)**:
```zsh
plugins=(
  zsh-users/zsh-autosuggestions
  zsh-users/zsh-syntax-highlighting
  romkatv/powerlevel10k
)
```

### Fearless Experimentation

- **Traditional risk**: Modifying `.zshrc` is scary - what if it breaks?
- **Zap solution**: Try anything with `zap try`, sync back with `zap sync`
- **Confidence**: Experiments never persist, so you can't break your config

### Single Source of Truth

- **State file**: `$ZAP_DATA_DIR/state.zsh` tracks what's actually loaded
- **Configuration**: `.zshrc` plugins array declares what should be loaded
- **Reconciliation**: `zap sync` ensures they match

---

## 📝 State File Format

Zap tracks plugin metadata in `$ZAP_DATA_DIR/state.zsh`:

```zsh
typeset -A _zap_plugin_state

_zap_plugin_state=(
  'zsh-users/zsh-autosuggestions' 'declared|zsh-users/zsh-autosuggestions|1729267935|/path|abc123|array'
  'romkatv/powerlevel10k' 'experimental|romkatv/powerlevel10k|1729267936|/path|def456|try_command'
)
```

### Metadata Fields (pipe-delimited)

1. **State**: `declared` or `experimental`
2. **Specification**: Original plugin spec (e.g., `owner/repo@version`)
3. **Timestamp**: Unix epoch when loaded
4. **Path**: Absolute path to plugin directory
5. **Version**: Actual version (commit hash or tag)
6. **Source**: `array`, `try_command`, or `legacy_load`

### State Transitions

```
Unloaded ──[plugins=()]──> Declared (persists across restarts)
Unloaded ──[zap try]─────> Experimental (ephemeral)
Experimental ──[zap sync]─> Unloaded
```

---

## 🚀 Next Steps

1. **Convert existing setup**: Move your `zap load` commands to a `plugins=()` array
2. **Experiment safely**: Use `zap try` to test new plugins
3. **Stay in sync**: Run `zap sync` to clean up experiments
4. **Version control**: Commit your `.zshrc` with confidence

For more details, see:
- `specs/002-specify-scripts-bash/spec.md` - Full feature specification
- `specs/002-specify-scripts-bash/contracts/` - API contracts
- `tests/contract/declarative/` - Contract tests showing expected behavior
