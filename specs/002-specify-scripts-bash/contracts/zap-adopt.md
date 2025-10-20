# Contract: `zap adopt`

**Command**: `zap adopt`
**Purpose**: Promote experimental plugin to declared configuration
**Requirements**: FR-008, FR-009
**Success Criteria**: SC-004

## Signature

```zsh
zap adopt <plugin-name> [--verbose]
zap adopt --all [--yes]
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `<plugin-name>` | string | Yes* | - | Plugin to adopt (owner/repo format) |
| `--all` | flag | No | false | Adopt all experimental plugins |
| `--yes` | flag | No | false | Skip confirmation prompt (with --all) |
| `--verbose` | flag | No | false | Show detailed modification steps |

\* Required unless `--all` is specified

## Behavior

### Preconditions
- User has sourced `zap.zsh`
- `.zshrc` exists and is writable
- Plugin is currently loaded as experimental

### Algorithm

1. **Validate Input**
   - If `--all`: Get list of all experimental plugins from state
   - If specific plugin: Validate plugin name format
   - If no experimental plugins exist, show message and exit

2. **Check Plugin State**
   - Query `$ZAP_DATA_DIR/state.zsh`
   - Verify plugin is loaded with `state: experimental`
   - If not loaded, show error and exit (must use `zap try` first)
   - If already declared, show informational message and exit

3. **Confirm Action** (if `--all` without `--yes`)
   - Show list of plugins to be adopted
   - Prompt: "Adopt all N experimental plugins? (y/N)"
   - If declined, exit

4. **Create Backup**
   - Copy `.zshrc` to `.zshrc.backup-<timestamp>`
   - Ensure backup succeeds before modification

5. **Modify Configuration File** (FR-009)
   - Parse `.zshrc` to find `plugins=()` array
   - If array exists:
     - Insert plugin before closing `)`
     - Preserve existing formatting (indentation, quotes)
   - If array doesn't exist:
     - Create array at end of file (before `source zap.zsh` if present)
   - Use AWK-based insertion (text manipulation, no code execution)
   - Atomic write (temp file + mv)
   - Preserve file permissions

6. **Update State Metadata**
   - Change plugin state from `experimental` to `declared`
   - Update source from `try_command` to `array`
   - Atomic write to `state.zsh`

7. **Show Confirmation**
   - Display success message
   - Show updated plugins array
   - Provide next steps

### Postconditions
- Plugin appears in `plugins=()` array in `.zshrc`
- Plugin state changed from `experimental` to `declared` in metadata
- Plugin will be loaded automatically on next shell startup
- Backup of original `.zshrc` exists

## Return Codes

| Code | Meaning | User Action |
|------|---------|-------------|
| 0 | Success - plugin adopted | None |
| 1 | Validation error - invalid plugin name | Fix plugin name format |
| 2 | State error - plugin not loaded | Run `zap try` first |
| 3 | State error - already declared | No action needed |
| 4 | Permission error - cannot write .zshrc | Check file permissions |
| 5 | User cancelled - declined confirmation | None |

## Output Format

### Standard Output (Success)
```
Adopting plugin: owner/repo
  ✓ Created backup: ~/.zshrc.backup-2025-10-18-143215
  ✓ Updated plugins array in ~/.zshrc
  ✓ Updated state metadata

Plugin owner/repo is now declared in your config.

Updated plugins array:
  plugins=(
    'existing/plugin'
    'owner/repo'  # ← newly adopted
  )

Next steps:
  - Plugin will be loaded automatically on next shell startup
  - Run 'zap sync' to apply changes immediately
  - Run 'zap status' to verify declared state
```

### Standard Output (--all with confirmation)
```
Found 3 experimental plugins to adopt:
  - jeffreytse/zsh-vi-mode
  - romkatv/powerlevel10k@v1.19.0
  - user/custom-plugin

Adopt all 3 plugins? (y/N): y

Adopting plugins...
  ✓ Created backup: ~/.zshrc.backup-2025-10-18-143215
  ✓ Added jeffreytse/zsh-vi-mode to plugins array
  ✓ Added romkatv/powerlevel10k@v1.19.0 to plugins array
  ✓ Added user/custom-plugin to plugins array
  ✓ Updated state metadata

All 3 experimental plugins are now declared.
Run 'zap sync' to apply changes immediately.
```

### Standard Output (--all --yes, no confirmation)
```
Adopting 3 experimental plugins...
  ✓ Created backup: ~/.zshrc.backup-2025-10-18-143215
  ✓ Updated plugins array in ~/.zshrc
  ✓ Updated state metadata

All 3 plugins adopted successfully.
```

### Standard Output (--verbose)
```
Validating plugin name: owner/repo
  ✓ Format valid

Checking plugin state...
  ✓ Plugin loaded as experimental
  ✓ Not already declared

Creating backup...
  Copying ~/.zshrc → ~/.zshrc.backup-2025-10-18-143215
  ✓ Backup created

Parsing .zshrc...
  Found plugins=() array at line 15
  Current entries: 2

Modifying plugins array...
  Inserting 'owner/repo' before closing )
  Using AWK-based insertion (safe text manipulation)
  Writing to temporary file: ~/.zshrc.tmp.12345
  Atomic move: ~/.zshrc.tmp.12345 → ~/.zshrc
  ✓ Config file updated

Updating state metadata...
  Changing state: experimental → declared
  Changing source: try_command → array
  ✓ Metadata updated

Success! Plugin adopted.
```

### Standard Error (Plugin Not Loaded)
```
Error: Plugin owner/repo is not currently loaded.
  You must load the plugin experimentally first:
    zap try owner/repo

  Then adopt it:
    zap adopt owner/repo
```

### Standard Error (Already Declared)
```
Plugin owner/repo is already declared in your config.
No action needed - it's already permanent.

Location: ~/.zshrc line 16
  plugins=(
    ...
    'owner/repo'  # ← already here
  )
```

### Standard Error (Permission Denied)
```
Error: Cannot modify ~/.zshrc
  Reason: Permission denied
  Fix: chmod u+w ~/.zshrc && zap adopt owner/repo
```

### Standard Error (No Experimental Plugins)
```
No experimental plugins to adopt.
  Run 'zap try owner/repo' to load a plugin experimentally first.
```

## Configuration File Modification

### AWK-Based Insertion Algorithm

```zsh
_zap_adopt_plugin() {
  local plugin="$1"
  local zshrc="$HOME/.zshrc"
  local tmp="$zshrc.tmp.$$"

  # Create backup
  cp "$zshrc" "$zshrc.backup-$(date +%Y-%m-%d-%H%M%S)"

  # Use AWK to insert plugin before closing )
  awk -v plugin="$plugin" '
    # Detect array opening
    /^[[:space:]]*plugins[[:space:]]*=\(/ {
      in_array = 1
      print
      next
    }

    # Detect array closing
    in_array && /\)/ {
      # Insert plugin with proper indentation
      indent = match($0, /[^[:space:]]/)
      if (indent > 0) {
        printf "%*s'\''%s'\''\n", indent - 1, "", plugin
      } else {
        printf "  '\''%s'\''\n", plugin
      }
      in_array = 0
    }

    # Print all other lines
    { print }
  ' "$zshrc" > "$tmp"

  # Atomic move
  mv "$tmp" "$zshrc"
}
```

### Example Transformations

**Before**:
```zsh
plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions'
)
```

**After** (`zap adopt jeffreytse/zsh-vi-mode`):
```zsh
plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions'
  'jeffreytse/zsh-vi-mode'
)
```

**Edge Case: Empty Array**

**Before**:
```zsh
plugins=()
```

**After**:
```zsh
plugins=(
  'owner/repo'
)
```

**Edge Case: No Array**

**Before**:
```zsh
# Some existing config
export PATH="/usr/local/bin:$PATH"

source ~/.local/share/zap/zap.zsh
```

**After**:
```zsh
# Some existing config
export PATH="/usr/local/bin:$PATH"

plugins=(
  'owner/repo'
)

source ~/.local/share/zap/zap.zsh
```

## Performance Requirements

- **Validation**: < 5ms
- **State check**: < 10ms
- **Backup creation**: < 50ms
- **File parsing**: < 20ms
- **File modification**: < 50ms
- **State update**: < 10ms
- **Total**: < 500ms (SC-004: 95% success rate)

## Security Considerations

- **Backup Before Modify**: Always create backup (prevents data loss)
- **Atomic Operations**: Use temp file + mv (prevents partial writes)
- **Input Validation**: Validate plugin name format
- **Permission Preservation**: Maintain original file permissions
- **Text-Based Modification**: Use AWK (no code execution)
- **No Sourcing**: Never source .zshrc during modification

## Examples

### Example 1: Adopt single plugin
```zsh
# Try a plugin experimentally
$ zap try jeffreytse/zsh-vi-mode
✓ Loaded successfully (experimental)

# Test it out...
# (use the plugin for a while)

# Adopt it permanently
$ zap adopt jeffreytse/zsh-vi-mode
Adopting plugin: jeffreytse/zsh-vi-mode
  ✓ Created backup: ~/.zshrc.backup-2025-10-18-143215
  ✓ Updated plugins array in ~/.zshrc
  ✓ Updated state metadata

Plugin jeffreytse/zsh-vi-mode is now declared in your config.
```

### Example 2: Adopt all experimental plugins
```zsh
$ zap status
Experimental plugins (3):
  ⚡ jeffreytse/zsh-vi-mode
  ⚡ romkatv/powerlevel10k
  ⚡ user/custom-plugin

$ zap adopt --all
Found 3 experimental plugins to adopt:
  - jeffreytse/zsh-vi-mode
  - romkatv/powerlevel10k
  - user/custom-plugin

Adopt all 3 plugins? (y/N): y

Adopting plugins...
  ✓ All 3 plugins adopted successfully.
```

### Example 3: Adopt all with auto-confirmation
```zsh
$ zap adopt --all --yes
Adopting 2 experimental plugins...
  ✓ All 2 plugins adopted successfully.
```

### Example 4: Try to adopt non-loaded plugin
```zsh
$ zap adopt owner/never-tried
Error: Plugin owner/never-tried is not currently loaded.
  You must load the plugin experimentally first:
    zap try owner/never-tried

  Then adopt it:
    zap adopt owner/never-tried
```

### Example 5: Try to adopt already-declared plugin
```zsh
$ zap adopt zsh-users/zsh-syntax-highlighting
Plugin zsh-users/zsh-syntax-highlighting is already declared in your config.
No action needed - it's already permanent.
```

## Test Cases

### Contract Tests
```zsh
# TC-ADOPT-001: Successful adoption
test_adopt_success() {
  zap try test/plugin
  zap adopt test/plugin
  [[ $? -eq 0 ]]
  grep -q "test/plugin" ~/.zshrc
  zap status | grep -q "test/plugin" | grep -q "declared"
}

# TC-ADOPT-002: Backup created
test_adopt_creates_backup() {
  zap try test/plugin
  zap adopt test/plugin
  [[ -f ~/.zshrc.backup-* ]]
}

# TC-ADOPT-003: Not loaded error
test_adopt_not_loaded() {
  zap adopt never/loaded
  [[ $? -eq 2 ]]
}

# TC-ADOPT-004: Already declared error
test_adopt_already_declared() {
  echo 'plugins=("test/plugin")' > ~/.zshrc
  source zap.zsh
  zap adopt test/plugin
  [[ $? -eq 3 ]]
}

# TC-ADOPT-005: Adopt all
test_adopt_all() {
  zap try plugin1/test
  zap try plugin2/test
  echo "y" | zap adopt --all
  grep -q "plugin1/test" ~/.zshrc
  grep -q "plugin2/test" ~/.zshrc
}

# TC-ADOPT-006: File permissions preserved
test_adopt_preserves_permissions() {
  chmod 600 ~/.zshrc
  orig_perms=$(stat -c %a ~/.zshrc)
  zap try test/plugin
  zap adopt test/plugin
  new_perms=$(stat -c %a ~/.zshrc)
  [[ "$orig_perms" == "$new_perms" ]]
}
```

## Dependencies

- `_zap_list_loaded_plugins()` - Query current state
- `_zap_validate_plugin_spec()` - Validate plugin name
- `_zap_parse_plugins_array()` - Find existing array
- `_zap_write_state()` - Update metadata
- `awk` - Config file modification
- `cp` - Backup creation
- `mv` - Atomic file operations
