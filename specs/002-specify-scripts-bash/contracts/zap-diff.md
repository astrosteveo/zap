# Contract: `zap diff`

**Command**: `zap diff`
**Purpose**: Preview changes that would be applied by reconciliation
**Requirements**: FR-011
**Success Criteria**: SC-005

## Signature

```zsh
zap diff [--verbose]
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--verbose` | flag | No | false | Show detailed information about each change |

## Behavior

### Preconditions
- User has sourced `zap.zsh`
- `$ZAP_DATA_DIR` exists
- `.zshrc` contains `plugins=()` array (or no array = empty desired state)

### Algorithm

1. **Parse Declared State**
   - Extract `plugins=()` array from `.zshrc`
   - Validate each plugin specification
   - Build list of desired plugins

2. **Read Current State**
   - Load `$ZAP_DATA_DIR/state.zsh`
   - Query declared plugins (exclude experimental)
   - Build list of current plugins

3. **Calculate Drift**
   - Compute `to_install = desired - current`
   - Compute `to_remove = current - desired`
   - Include experimental plugins in `to_remove`

4. **Display Preview**
   - Show plugins to be installed (+)
   - Show plugins to be removed (-)
   - Show summary of total changes
   - Indicate this is a preview (not applying)

5. **Exit Without Modification**
   - Do NOT modify any state
   - Do NOT reload shell
   - Return status code based on drift

### Postconditions
- User understands what `zap sync` would change
- No state has been modified
- User can decide whether to run `zap sync`

## Return Codes

| Code | Meaning |
|------|---------|
| 0 | Drift detected - changes would be applied |
| 1 | No drift - state is in sync |
| 2 | Error parsing config |

## Output Format

### Standard Output (Drift Detected)
```
Plugins to be installed:
  + ohmyzsh/ohmyzsh:plugins/docker
  + romkatv/powerlevel10k@v1.19.0

Plugins to be removed:
  - old/deprecated-plugin (experimental)

Summary:
  2 plugins to install
  1 plugin to remove
  3 total changes

Run 'zap sync' to apply these changes.
```

### Standard Output (No Drift)
```
No changes needed - all plugins synced with config.
```

### Standard Output (--verbose)
```
Comparing declared state with current state...

Declared plugins (from ~/.zshrc):
  1. zsh-users/zsh-syntax-highlighting
  2. zsh-users/zsh-autosuggestions
  3. ohmyzsh/ohmyzsh:plugins/docker  # ← not loaded
  4. romkatv/powerlevel10k@v1.19.0   # ← not loaded

Current plugins (loaded):
  1. zsh-users/zsh-syntax-highlighting (declared)
  2. zsh-users/zsh-autosuggestions (declared)
  3. old/deprecated-plugin (experimental)  # ← not declared

Drift analysis:
  ✓ 2 plugins in sync
  + 2 plugins to install (declared but not loaded)
  - 1 plugin to remove (loaded but not declared)

Plugins to be installed:
  + ohmyzsh/ohmyzsh:plugins/docker
    Source: declared in ~/.zshrc line 18
    Action: Clone and load
    Est. time: 5 seconds

  + romkatv/powerlevel10k@v1.19.0
    Source: declared in ~/.zshrc line 19
    Action: Clone and load (pinned to v1.19.0)
    Est. time: 8 seconds

Plugins to be removed:
  - old/deprecated-plugin (experimental)
    Reason: Not declared in config
    Action: Unload (exec zsh)
    State: Loaded via 'zap try' 2 hours ago

Summary:
  2 plugins to install (est. 13 seconds)
  1 plugin to remove (0 seconds)
  3 total changes

Run 'zap sync' to apply these changes.
```

### Standard Error (Parse Error)
```
Error: Failed to parse plugins array in ~/.zshrc
  Reason: Invalid plugin specification: "../evil/path"
  Fix your plugins=() array and try again.
```

## Display Components

### Change Indicators
- `+` - Plugin will be installed
- `-` - Plugin will be removed
- `✓` - Plugin in sync (verbose mode only)

### Plugin Details (Verbose Mode)
- Source location (config file, line number)
- Current state (loaded/not loaded, experimental/declared)
- Action to be taken (clone, load, unload)
- Estimated time (for downloads)
- Version information (if pinned)

## Performance Requirements

- **Parse config**: < 10ms
- **Read state**: < 5ms
- **Calculate drift**: < 50ms
- **Format output**: < 135ms
- **Total**: < 200ms (budget from plan)

## Examples

### Example 1: No drift
```zsh
$ zap diff
No changes needed - all plugins synced with config.

$ echo $?
1  # Exit code 1 = no drift
```

### Example 2: Plugins to install
```zsh
# User edited .zshrc, added new plugins
$ zap diff
Plugins to be installed:
  + ohmyzsh/ohmyzsh:plugins/docker
  + romkatv/powerlevel10k@v1.19.0

Summary:
  2 plugins to install
  0 plugins to remove
  2 total changes

Run 'zap sync' to apply these changes.

$ echo $?
0  # Exit code 0 = drift detected
```

### Example 3: Experimental plugins to remove
```zsh
$ zap try jeffreytse/zsh-vi-mode
$ zap try test/another-plugin

$ zap diff
Plugins to be removed:
  - jeffreytse/zsh-vi-mode (experimental)
  - test/another-plugin (experimental)

Summary:
  0 plugins to install
  2 plugins to remove
  2 total changes

Run 'zap sync' to apply these changes.
```

### Example 4: Mixed changes
```zsh
# User edited config and has experimental plugins
$ zap diff
Plugins to be installed:
  + new/declared-plugin

Plugins to be removed:
  - old/experimental-plugin (experimental)

Summary:
  1 plugin to install
  1 plugin to remove
  2 total changes

Run 'zap sync' to apply these changes.
```

### Example 5: Verbose mode
```zsh
$ zap diff --verbose
Comparing declared state with current state...

Declared plugins (from ~/.zshrc):
  1. zsh-users/zsh-syntax-highlighting
  2. zsh-users/zsh-autosuggestions
  3. ohmyzsh/ohmyzsh:plugins/docker  # ← not loaded

Current plugins (loaded):
  1. zsh-users/zsh-syntax-highlighting (declared)
  2. zsh-users/zsh-autosuggestions (declared)

Drift analysis:
  ✓ 2 plugins in sync
  + 1 plugin to install (declared but not loaded)
  - 0 plugins to remove

Plugins to be installed:
  + ohmyzsh/ohmyzsh:plugins/docker
    Source: declared in ~/.zshrc line 18
    Action: Clone and load
    Est. time: 5 seconds

Summary:
  1 plugin to install (est. 5 seconds)
  0 plugins to remove
  1 total change

Run 'zap sync' to apply these changes.
```

### Example 6: Empty config (remove all)
```zsh
# User set plugins=()
$ zap diff
Plugins to be removed:
  - zsh-users/zsh-syntax-highlighting
  - zsh-users/zsh-autosuggestions
  - ohmyzsh/ohmyzsh:plugins/git

Summary:
  0 plugins to install
  3 plugins to remove
  3 total changes

Run 'zap sync' to apply these changes.
```

## Comparison with `zap status`

| Feature | `zap status` | `zap diff` |
|---------|--------------|------------|
| **Purpose** | Show current state | Show what sync would change |
| **Focus** | What IS | What WILL BE |
| **Drift** | Indicates drift exists | Shows exact changes |
| **Experimental** | Lists separately | Includes in removal list |
| **Action** | Informational | Preview before action |
| **Exit Code** | Always 0 (success) | 0 if drift, 1 if synced |

## Use Cases

### Use Case 1: Before running sync
```zsh
# User wants to see what will change before syncing
$ zap diff
Plugins to be removed:
  - experimental/plugin (experimental)

# User decides to adopt it instead
$ zap adopt experimental/plugin

# Now diff shows no changes
$ zap diff
No changes needed - all plugins synced with config.
```

### Use Case 2: After editing config
```zsh
# User edited .zshrc, wants to preview
$ vim ~/.zshrc  # Add new plugins

$ zap diff
Plugins to be installed:
  + new/plugin1
  + new/plugin2

# Looks good, apply changes
$ zap sync
```

### Use Case 3: Multi-machine sync workflow
```zsh
# On machine A: push config changes
$ git add ~/.zshrc && git commit -m "Add plugins" && git push

# On machine B: pull and preview
$ git pull
$ zap diff
Plugins to be installed:
  + new/plugin-from-machine-a

# Apply changes
$ zap sync
```

### Use Case 4: CI/CD validation
```zsh
#!/bin/zsh
# Check if config is in sync (exit 1 if drift)
zap diff > /dev/null
if [[ $? -eq 0 ]]; then
  echo "ERROR: Plugin configuration drift detected"
  zap diff  # Show details
  exit 1
fi
echo "SUCCESS: All plugins synced"
```

## Test Cases

### Contract Tests
```zsh
# TC-DIFF-001: No drift returns exit 1
test_diff_no_drift() {
  echo 'plugins=("test/plugin")' > ~/.zshrc
  source zap.zsh
  zap diff > /dev/null
  [[ $? -eq 1 ]]
}

# TC-DIFF-002: Drift detected returns exit 0
test_diff_with_drift() {
  echo 'plugins=("test/plugin")' > ~/.zshrc
  # Don't load plugin
  zap diff > /dev/null
  [[ $? -eq 0 ]]
}

# TC-DIFF-003: Shows additions
test_diff_additions() {
  echo 'plugins=("new/plugin")' > ~/.zshrc
  output=$(zap diff)
  echo "$output" | grep -q "+ new/plugin"
}

# TC-DIFF-004: Shows removals
test_diff_removals() {
  zap try experimental/plugin
  output=$(zap diff)
  echo "$output" | grep -q "- experimental/plugin"
}

# TC-DIFF-005: Doesn't modify state
test_diff_no_side_effects() {
  state_before=$(zap status --machine-readable)
  zap diff > /dev/null
  state_after=$(zap status --machine-readable)
  [[ "$state_before" == "$state_after" ]]
}

# TC-DIFF-006: Performance < 200ms
test_diff_performance() {
  # Create config with 20 plugins
  echo 'plugins=(' > ~/.zshrc
  for i in {1..20}; do
    echo "  'user$i/repo$i'" >> ~/.zshrc
  done
  echo ')' >> ~/.zshrc

  start=$(date +%s%3N)
  zap diff > /dev/null
  end=$(date +%s%3N)
  duration=$((end - start))

  [[ $duration -lt 200 ]]  # Budget: < 200ms
}
```

## Dependencies

- `_zap_extract_plugins_array()` - Parse config
- `_zap_list_declared_plugins()` - Query current state
- `_zap_calculate_drift()` - Compute differences
- `_zap_format_plugin_list()` - Format output
