# New User Experience: Powerlevel10k Theme

This document demonstrates the improved first-time user experience for theme plugins, specifically powerlevel10k.

## Problem Statement

**Before the improvements**, a new user trying powerlevel10k would have a confusing experience:

```bash
$ zap try romkatv/powerlevel10k
✓ Loaded successfully (experimental)

# But... nothing changes! No visible prompt. User is confused.
# No guidance on what to do next.
```

The plugin would load successfully, but:
- ❌ No visible change to the prompt
- ❌ No instructions on how to configure
- ❌ User doesn't know about `p10k configure`
- ❌ User doesn't know to add config line to .zshrc

## Solution Implemented

We added **two levels of user guidance** to improve the experience:

### 1. Post-Load Hints (`zap try`)

When a user tries powerlevel10k for the first time:

```bash
$ zap try romkatv/powerlevel10k
⬇ Downloading romkatv/powerlevel10k...
✓ Loaded romkatv/powerlevel10k experimentally

💡 Powerlevel10k Quick Start:
   Run: p10k configure
   This will guide you through prompt customization.

   After configuration, add to your .zshrc:
   [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

  This plugin will NOT be reloaded on shell restart.
  To make it permanent, run: zap adopt romkatv/powerlevel10k
  To return to declared state, run: zap sync
```

**Benefits:**
- ✅ User immediately knows what to do next
- ✅ Clear steps: configure → add to zshrc → adopt
- ✅ Educates about experimental vs declared state

### 2. Adoption Guidance (`zap adopt`)

When a user adopts powerlevel10k after trying it:

```bash
$ zap adopt romkatv/powerlevel10k
✓ Adopted romkatv/powerlevel10k to your configuration
  Added to: /home/user/.zshrc
  Backup saved: /home/user/.zshrc.backup-1729388399
  Plugin will now load automatically on shell startup

📝 Next steps for Powerlevel10k:
   1. Add this line to your /home/user/.zshrc (after sourcing zap):
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

   2. Run: p10k configure
      This will guide you through prompt customization

   3. Restart your shell: exec zsh
```

**Benefits:**
- ✅ Clear numbered steps for complete setup
- ✅ Shows exact line to add to config
- ✅ Reminds user to configure and restart
- ✅ Provides complete path to config file

## Complete New User Journey

Here's the **complete happy path** for a new user discovering powerlevel10k:

### Step 1: Discovery & Experimentation
```bash
$ zap try romkatv/powerlevel10k
⬇ Downloading romkatv/powerlevel10k...
✓ Loaded romkatv/powerlevel10k experimentally

💡 Powerlevel10k Quick Start:
   Run: p10k configure
   [... instructions ...]
```

### Step 2: Configuration
```bash
$ p10k configure
# User goes through the interactive wizard
# Creates ~/.p10k.zsh with their preferences
```

### Step 3: Adoption
```bash
$ zap adopt romkatv/powerlevel10k
✓ Adopted romkatv/powerlevel10k to your configuration

📝 Next steps for Powerlevel10k:
   1. Add this line to your ~/.zshrc (after sourcing zap):
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
   [... next steps ...]
```

### Step 4: Follow Instructions
User manually adds the config line or lets zap guide them:

```bash
# User edits ~/.zshrc to add:
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
```

### Step 5: Restart
```bash
$ exec zsh
# Beautiful powerlevel10k prompt appears!
# Configuration is permanent and loads automatically
```

## Technical Implementation

### 1. Theme Detection in Loader

**File**: `lib/loader.zsh`

Added `_zap_handle_post_load()` function that:
- Detects `.zsh-theme` files
- Identifies special cases (powerlevel10k)
- Shows contextual help after plugin loads
- Only shows hints if config doesn't exist
- Respects `ZAP_QUIET` mode

```zsh
_zap_handle_post_load() {
  local plugin_id="$1"
  local plugin_file="$2"

  # Detect theme files
  if [[ "$plugin_file" == *.zsh-theme ]]; then
    # Special handling for powerlevel10k
    if [[ "$plugin_id" == *"powerlevel10k"* ]]; then
      # Show configuration hint if needed
      if [[ ! -f ~/.p10k.zsh ]] && [[ -z "${ZAP_QUIET:-}" ]]; then
        echo "💡 Powerlevel10k Quick Start:"
        # ... helpful instructions ...
      fi
    fi
  fi
}
```

### 2. Adoption Guidance

**File**: `lib/declarative.zsh`

Enhanced the success message after `zap adopt`:
- Detects powerlevel10k by name
- Shows numbered next steps
- Provides exact config line to add
- Reminds about configuration wizard

### 3. Theme File Support

**File**: `lib/loader.zsh`

Extended plugin file detection to support `.zsh-theme` files:

```zsh
# Priority order:
#   1. <name>.plugin.zsh
#   2. <name>.zsh
#   3. <name>.zsh-theme  ← ADDED
#   4. init.zsh
#   5. <repo>.plugin.zsh
#   6. <repo>.zsh
#   7. <repo>.zsh-theme  ← ADDED
```

## Extensibility

This pattern can be extended to other plugins that need special handling:

### Example: Starship Prompt
```zsh
if [[ "$plugin_id" == *"starship"* ]]; then
  echo ""
  echo "💡 Starship Quick Start:"
  echo "   Add to your .zshrc: eval \"\$(starship init zsh)\""
  echo "   Configure: starship config"
fi
```

### Example: NVM (Node Version Manager)
```zsh
if [[ "$plugin_id" == *"nvm"* ]]; then
  echo ""
  echo "💡 NVM Quick Start:"
  echo "   Source NVM: [ -s \"$NVM_DIR/nvm.sh\" ] && . \"$NVM_DIR/nvm.sh\""
  echo "   Install Node: nvm install --lts"
fi
```

## User Feedback

Expected improvements in user experience:
- ❌ **Before**: "I tried powerlevel10k but nothing happened. Is it broken?"
- ✅ **After**: "Cool! I just ran `p10k configure` and now I have a beautiful prompt!"

## Edge Cases Handled

1. **User already configured**: If `~/.p10k.zsh` exists, don't show hints
2. **Quiet mode**: Respect `ZAP_QUIET=1` environment variable
3. **Multiple tries**: Only show hints on first load (check for config file)
4. **Other themes**: Generic theme detection works for all `.zsh-theme` files
5. **Mixed workflows**: Works with both `zap try` and direct `zap adopt`

## Testing

To test the new user experience:

```bash
# 1. Remove any existing p10k config
rm ~/.p10k.zsh

# 2. Try powerlevel10k
zap try romkatv/powerlevel10k
# Should see helpful Quick Start message

# 3. Configure it
p10k configure
# Interactive wizard

# 4. Adopt it
zap adopt romkatv/powerlevel10k
# Should see next steps guidance

# 5. Follow instructions and restart
exec zsh
```

## Future Enhancements

Potential improvements for Phase 10 (Polish):

1. **Auto-config insertion**: Offer to automatically add config line to .zshrc during adoption
2. **Plugin registry**: Maintain a registry of plugins with special requirements
3. **Smart defaults**: Detect common tools (nvm, fzf, starship) and provide setup hints
4. **Configuration templates**: Ship with example configs for popular plugins
5. **Help command**: `zap help powerlevel10k` shows plugin-specific guidance

## Related Files

- `lib/loader.zsh` - Theme detection and post-load hints
- `lib/declarative.zsh` - Adoption guidance
- `specs/002-specify-scripts-bash/tasks.md` - Task tracking

## Conclusion

This improvement transforms the new user experience from **confusing and broken** to **guided and successful**. Users now receive clear, actionable instructions at every step of the journey, resulting in a much more polished and professional plugin manager experience.
