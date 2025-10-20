# Quickstart: Declarative Plugin Management

**Feature**: Declarative Plugin Management | **Date**: 2025-10-18

## Overview

Zap's declarative plugin management lets you configure all your plugins in a single `plugins=()` array, inspired by NixOS, Docker Compose, and Kubernetes. Instead of running repetitive `zap load` commands, you declare your desired plugin state and Zap handles the rest.

**Key Benefits**:
- ✅ Single source of truth for plugin configuration
- ✅ Version-controlled dotfiles that work across machines
- ✅ Fearless experimentation with easy rollback
- ✅ Clear separation between permanent and temporary plugins
- ✅ Automatic reconciliation to declared state

## Quick Start (30 seconds)

### 1. Declare Your Plugins

Edit your `.zshrc` and add a `plugins=()` array:

```zsh
# ~/.zshrc

# Declare your desired plugins
plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions'
  'ohmyzsh/ohmyzsh:plugins/git'
)

# Source Zap (must come after plugins array)
source ~/.local/share/zap/zap.zsh
```

### 2. Reload Your Shell

```zsh
exec zsh
```

**That's it!** All your plugins are now loaded automatically. No `zap load` commands needed.

---

## Core Concepts

### Declarative vs. Imperative

**Old Way (Imperative)** - Repeat commands every session:
```zsh
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions
zap load ohmyzsh/ohmyzsh:plugins/git
```

**New Way (Declarative)** - Declare once, automatic forever:
```zsh
plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions'
  'ohmyzsh/ohmyzsh:plugins/git'
)
```

### Plugin States

Zap tracks plugins in two states:

1. **Declared** - Plugins in your `plugins=()` array
   - Permanent (persist across shell sessions)
   - Loaded automatically on startup
   - Source of truth for configuration

2. **Experimental** - Plugins loaded via `zap try`
   - Temporary (do NOT persist across shell sessions)
   - For testing before committing to config
   - Easily removed via `zap sync`

---

## Common Workflows

### Workflow 1: Add a New Plugin Permanently

```zsh
# Edit your .zshrc
vim ~/.zshrc

# Add plugin to array:
# plugins=(
#   'existing/plugin'
#   'new/plugin'  ← add this
# )

# Reload shell
exec zsh

# Or run sync immediately without restart
zap sync
```

### Workflow 2: Try Before You Commit

```zsh
# Try a plugin temporarily (doesn't modify config)
zap try jeffreytse/zsh-vi-mode

# Test it out...
# Use the plugin, see if you like it

# Option A: Make it permanent
zap adopt jeffreytse/zsh-vi-mode
# (This automatically adds it to your plugins array)

# Option B: Remove it and go back to declared state
zap sync
# (Removes all experimental plugins)
```

### Workflow 3: Multi-Machine Sync

```zsh
# On your work laptop
vim ~/.zshrc  # Add new plugin
git add ~/.zshrc
git commit -m "Add docker plugin"
git push

# On your home desktop
git pull
zap sync  # Apply the changes

# Both machines now have identical plugin configuration
```

### Workflow 4: Clean Up Experiments

```zsh
# You tried 5 different plugins temporarily
zap try plugin1/test
zap try plugin2/test
zap try plugin3/test
zap try plugin4/test
zap try plugin5/test

# Check what's loaded
zap status
# Shows: 5 experimental plugins

# Remove all experiments, return to declared state
zap sync

# Check again
zap status
# Shows: 0 experimental plugins, back to config
```

---

## Plugin Specification Format

### Basic Format

```
owner/repo[@version][:subdir]
```

### Examples

**Simple plugin**:
```zsh
plugins=(
  'zsh-users/zsh-syntax-highlighting'
)
```

**Version-pinned plugin**:
```zsh
plugins=(
  'zsh-users/zsh-autosuggestions@v0.7.0'
)
```

**Subdirectory plugin** (for Oh-My-Zsh):
```zsh
plugins=(
  'ohmyzsh/ohmyzsh:plugins/git'
  'ohmyzsh/ohmyzsh:plugins/docker'
)
```

**Combination**:
```zsh
plugins=(
  'romkatv/powerlevel10k@v1.19.0'
  'ohmyzsh/ohmyzsh:plugins/kubectl'
)
```

---

## Commands Reference

### `zap status`

**Purpose**: Show current plugin state

**Usage**:
```zsh
zap status [--verbose]
```

**Example Output**:
```
Declared plugins (2):
  ✓ zsh-users/zsh-syntax-highlighting
  ✓ zsh-users/zsh-autosuggestions

Experimental plugins (1):
  ⚡ jeffreytse/zsh-vi-mode (loaded 5 minutes ago)

Status: 1 experimental plugin loaded
  Run 'zap sync' to remove experimental plugins
  Run 'zap adopt jeffreytse/zsh-vi-mode' to make it permanent
```

---

### `zap try`

**Purpose**: Load a plugin temporarily without modifying config

**Usage**:
```zsh
zap try <owner>/<repo>[@version][:subdir]
```

**Examples**:
```zsh
# Try basic plugin
zap try jeffreytse/zsh-vi-mode

# Try specific version
zap try romkatv/powerlevel10k@v1.19.0

# Try Oh-My-Zsh plugin
zap try ohmyzsh/ohmyzsh:plugins/docker
```

**Key Points**:
- Plugin loads immediately in current session
- Does NOT persist across shell restarts
- Use `zap adopt` to make permanent
- Use `zap sync` to remove

---

### `zap adopt`

**Purpose**: Promote experimental plugin to declared configuration

**Usage**:
```zsh
zap adopt <plugin-name>
zap adopt --all [--yes]
```

**Examples**:
```zsh
# Adopt single plugin
zap try jeffreytse/zsh-vi-mode
# (test it out...)
zap adopt jeffreytse/zsh-vi-mode
# Now it's in your .zshrc permanently

# Adopt all experimental plugins at once
zap adopt --all

# Adopt all without confirmation prompt
zap adopt --all --yes
```

**What It Does**:
1. Creates backup of `.zshrc`
2. Adds plugin to `plugins=()` array
3. Updates state metadata
4. Plugin now loads automatically on next shell startup

---

### `zap sync`

**Purpose**: Reconcile runtime state to declared configuration

**Usage**:
```zsh
zap sync [--dry-run]
```

**What It Does**:
- Reads your `plugins=()` array (declared state)
- Compares with currently loaded plugins (runtime state)
- Removes experimental plugins
- Adds missing declared plugins
- Reloads shell to apply changes

**Examples**:
```zsh
# Preview changes without applying
zap diff
# Output:
# Plugins to be removed:
#   - experimental/plugin

# Apply the changes
zap sync
# Output:
# Removing plugins:
#   ✗ experimental/plugin
# Synced 2 plugins with config.

# Run again (idempotent)
zap sync
# Output:
# All plugins synced with config.
```

**Key Points**:
- Idempotent (safe to run multiple times)
- Always returns to declared state
- Removes ALL experimental plugins
- Does NOT modify your `.zshrc`

---

### `zap diff`

**Purpose**: Preview what `zap sync` would change

**Usage**:
```zsh
zap diff [--verbose]
```

**Example Output**:
```
Plugins to be installed:
  + ohmyzsh/ohmyzsh:plugins/docker

Plugins to be removed:
  - jeffreytse/zsh-vi-mode (experimental)

Summary:
  1 plugin to install
  1 plugin to remove
  2 total changes

Run 'zap sync' to apply these changes.
```

**Key Points**:
- Does NOT modify any state
- Shows exactly what sync would do
- Exit code 0 = drift detected, 1 = in sync
- Useful before running sync

---

## Real-World Examples

### Example 1: Minimal Setup

```zsh
# ~/.zshrc
plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions'
)

source ~/.local/share/zap/zap.zsh
```

### Example 2: Power User Setup

```zsh
# ~/.zshrc
plugins=(
  # Core plugins
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions@v0.7.0'
  'zsh-users/zsh-completions'

  # Oh-My-Zsh plugins
  'ohmyzsh/ohmyzsh:plugins/git'
  'ohmyzsh/ohmyzsh:plugins/docker'
  'ohmyzsh/ohmyzsh:plugins/kubectl'

  # Theme
  'romkatv/powerlevel10k@v1.19.0'
)

source ~/.local/share/zap/zap.zsh
```

### Example 3: Conditional Loading (Machine-Specific)

```zsh
# ~/.zshrc
plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions'
)

# Add work-specific plugins on work laptop
if [[ "$HOST" == "work-laptop" ]]; then
  plugins+=(
    'ohmyzsh/ohmyzsh:plugins/aws'
    'ohmyzsh/ohmyzsh:plugins/terraform'
  )
fi

# Add gaming plugins on home desktop
if [[ "$HOST" == "home-desktop" ]]; then
  plugins+=(
    'user/gaming-shortcuts'
  )
fi

source ~/.local/share/zap/zap.zsh
```

### Example 4: Experimenting with New Plugins

```zsh
# Current config (in .zshrc):
# plugins=('zsh-users/zsh-syntax-highlighting')

# Try a new plugin
$ zap try jeffreytse/zsh-vi-mode
✓ Loaded successfully (experimental)

# Use it for a few days...
# Vi mode is awesome! Let's keep it.

# Make it permanent
$ zap adopt jeffreytse/zsh-vi-mode
✓ Added to plugins array in ~/.zshrc

# New config (in .zshrc):
# plugins=(
#   'zsh-users/zsh-syntax-highlighting'
#   'jeffreytse/zsh-vi-mode'
# )
```

---

## Troubleshooting

### "Plugin not loading automatically"

**Check**:
1. Is plugin in `plugins=()` array?
   ```zsh
   grep "plugins=" ~/.zshrc
   ```

2. Is `source zap.zsh` AFTER plugins array?
   ```zsh
   # ✅ Correct order:
   plugins=(...)
   source zap.zsh

   # ❌ Wrong order:
   source zap.zsh
   plugins=(...)  # Too late!
   ```

3. Check state:
   ```zsh
   zap status
   ```

**Fix**:
```zsh
# Ensure correct order in .zshrc, then:
zap sync
```

---

### "Experimental plugin persists after restart"

**This is actually correct behavior!** Experimental plugins should NOT persist.

If a plugin persists, check:
```zsh
zap status
```

If it shows as "declared", the plugin is in your `plugins=()` array. Check:
```zsh
grep "plugin-name" ~/.zshrc
```

---

### "zap sync removes plugins I want"

**Cause**: Plugins not declared in `plugins=()` array

**Fix**: Add them to your config:
```zsh
# 1. See what would be removed
zap diff

# 2. Adopt experimental plugins you want to keep
zap adopt plugin-name

# Or manually add to .zshrc:
# plugins=(
#   'existing/plugin'
#   'plugin-name'  ← add this
# )

# 3. Now sync won't remove it
zap sync
```

---

### "Config drift detected"

**This is informational**, not an error. It means:
- You have experimental plugins loaded, OR
- You edited config but haven't synced yet

**Check what would change**:
```zsh
zap diff
```

**Apply changes**:
```zsh
zap sync
```

---

### "Can't adopt plugin - permission denied"

**Cause**: `.zshrc` is read-only

**Fix**:
```zsh
chmod u+w ~/.zshrc
zap adopt plugin-name
```

---

## Migration from Imperative Style

### Before (Old Imperative Style)

```zsh
# ~/.zshrc

zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions
zap load ohmyzsh/ohmyzsh:plugins/git
```

### After (New Declarative Style)

```zsh
# ~/.zshrc

plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions'
  'ohmyzsh/ohmyzsh:plugins/git'
)

source ~/.local/share/zap/zap.zsh
```

### Migration Steps

1. **Identify your current plugins**:
   ```zsh
   zap list
   ```

2. **Create plugins array** in `.zshrc`:
   ```zsh
   plugins=(
     # Copy plugin names from zap list output
   )
   ```

3. **Remove old `zap load` commands** from `.zshrc`

4. **Reload shell**:
   ```zsh
   exec zsh
   ```

5. **Verify**:
   ```zsh
   zap status
   # All plugins should show as "declared"
   ```

---

## Best Practices

### ✅ Do

- **Use version pinning for stability**:
  ```zsh
  plugins=(
    'zsh-users/zsh-autosuggestions@v0.7.0'
  )
  ```

- **Use `zap try` before committing**:
  ```zsh
  zap try new/plugin  # Test first
  zap adopt new/plugin  # Then commit
  ```

- **Keep config in version control**:
  ```zsh
  git add ~/.zshrc
  git commit -m "Add docker plugin"
  ```

- **Run `zap sync` after pulling dotfile changes**:
  ```zsh
  git pull
  zap sync
  ```

- **Use `zap diff` before syncing**:
  ```zsh
  zap diff  # Preview
  zap sync  # Apply
  ```

### ❌ Don't

- **Don't mix imperative and declarative**:
  ```zsh
  # ❌ BAD - confusing state
  plugins=('plugin1')
  zap load plugin2  # Use array instead!
  ```

- **Don't manually edit state files**:
  ```zsh
  # ❌ NEVER DO THIS
  vim ~/.local/share/zap/state.zsh
  ```

- **Don't forget to sync after config changes**:
  ```zsh
  vim ~/.zshrc  # Added new plugin
  # ❌ Forgot to run: zap sync
  # ✅ Remember to: zap sync
  ```

- **Don't use `zap load` anymore** (deprecated):
  ```zsh
  # ❌ Old way
  zap load plugin

  # ✅ New way - add to array
  plugins+=('plugin')
  zap sync
  ```

---

## Advanced Usage

### Conditional Plugin Loading

```zsh
# Base plugins for all machines
plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions'
)

# Machine-specific plugins
case "$HOST" in
  work-laptop)
    plugins+=(
      'ohmyzsh/ohmyzsh:plugins/aws'
      'ohmyzsh/ohmyzsh:plugins/terraform'
    )
    ;;
  home-server)
    plugins+=(
      'ohmyzsh/ohmyzsh:plugins/docker'
      'ohmyzsh/ohmyzsh:plugins/systemd'
    )
    ;;
esac

source ~/.local/share/zap/zap.zsh
```

### Environment-Based Plugin Loading

```zsh
plugins=(
  'zsh-users/zsh-syntax-highlighting'
)

# Add dev tools only in development environment
if [[ "$ENVIRONMENT" == "development" ]]; then
  plugins+=(
    'debug/tools'
    'profiling/suite'
  )
fi

source ~/.local/share/zap/zap.zsh
```

### Bulk Plugin Management

```zsh
# Try multiple plugins at once
for plugin in plugin1/test plugin2/test plugin3/test; do
  zap try "$plugin"
done

# Check which ones you like
zap status

# Adopt all experimental plugins
zap adopt --all --yes

# Or selectively adopt
zap adopt plugin1/test
zap adopt plugin3/test
zap sync  # Remove plugin2/test
```

---

## FAQ

**Q: Can I still use `zap load`?**

A: Yes, for now. It works but is deprecated and treated as experimental for reconciliation purposes. We recommend migrating to the declarative `plugins=()` array.

---

**Q: What happens to experimental plugins when I restart my shell?**

A: They are NOT reloaded. Experimental plugins are ephemeral by design. Use `zap adopt` to make them permanent.

---

**Q: Can I have plugins in both the array and loaded via `zap try`?**

A: Yes. If you `zap try` a plugin that's already in your array, Zap will inform you it's already declared and do nothing.

---

**Q: What if I delete a plugin from the array?**

A: Run `zap sync` to reconcile. The plugin will be unloaded and your shell will return to the state defined in your config.

---

**Q: Does `zap sync` download plugins?**

A: Yes, if you've added new plugins to your array that aren't cached yet, `zap sync` will download and load them.

---

**Q: How do I remove ALL plugins?**

A: Set `plugins=()` (empty array) in your `.zshrc`, then run `zap sync`. All plugins will be unloaded.

---

**Q: Can I have multiple machines with different plugin configs?**

A: Yes! Use conditional logic in your `.zshrc` based on hostname or environment variables.

---

**Q: What's the performance impact of declarative loading?**

A: Negligible. Declarative loading is within 5% of imperative loading performance. For 10 plugins, startup time is < 1 second.

---

## Next Steps

- **Read the full specification**: [spec.md](spec.md)
- **Explore the data model**: [data-model.md](data-model.md)
- **Review command contracts**: [contracts/](contracts/)
- **Run `zap status`**: See your current plugin state
- **Try a plugin**: `zap try <owner>/<repo>`
- **Migrate to declarative**: Convert your `zap load` commands to `plugins=()` array

---

**Questions or Issues?**

- Check `zap doctor` for diagnostics
- Run `zap help <command>` for command-specific help
- Review troubleshooting section above
- See [spec.md](spec.md) for complete requirements
