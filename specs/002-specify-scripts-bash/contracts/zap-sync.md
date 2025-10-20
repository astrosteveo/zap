# Contract: `zap sync`

**Command**: `zap sync`
**Purpose**: Reconcile runtime plugin state to declared configuration
**Requirements**: FR-006, FR-007
**Success Criteria**: SC-003

## Signature

```zsh
zap sync [--dry-run] [--verbose]
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--dry-run` | flag | No | false | Preview changes without applying |
| `--verbose` | flag | No | false | Show detailed output including timestamps, versions |

## Behavior

### Preconditions
- User has sourced `zap.zsh`
- `$ZAP_DATA_DIR` exists and is writable
- `.zshrc` exists and contains `plugins=()` array (or no array = empty desired state)

### Algorithm

1. **Parse Declared State**
   - Extract `plugins=()` array from `.zshrc` using text-based parsing
   - Validate each plugin specification (FR-027)
   - Build list of desired plugins

2. **Query Current State**
   - Read `$ZAP_DATA_DIR/state.zsh` metadata
   - Filter for `declared` plugins only (exclude `experimental`)
   - Build list of current plugins

3. **Calculate Drift**
   - Compute `to_install = desired - current`
   - Compute `to_remove = current - desired`
   - If both empty, state is in sync (exit early)

4. **Preview Changes**
   - Display summary:
     ```
     Plugins to be installed:
       + owner1/repo1
       + owner2/repo2@v1.0

     Plugins to be removed:
       - old/plugin (experimental)

     Run 'zap sync' to apply these changes.
     ```
   - If `--dry-run`, exit here

5. **Apply Reconciliation**
   - **v1 Strategy**: `exec zsh` (full reload)
     - Shell history preserved via `INC_APPEND_HISTORY` + `fc -W`
     - Environment variables preserved
     - Working directory preserved
   - **v2 Strategy** (future): Incremental load/unload

6. **Update State Metadata**
   - Write new `state.zsh` with current plugin list
   - Mark all plugins as `source: array` (declared)
   - Atomic write (temp file + mv)

### Postconditions
- Runtime state matches declared state exactly
- No experimental plugins remain (removed during reconciliation)
- State metadata file updated
- User sees summary of changes applied

## Return Codes

| Code | Meaning | User Action |
|------|---------|-------------|
| 0 | Success - state reconciled | None |
| 1 | Parse error - invalid plugin spec in array | Fix `.zshrc` syntax |
| 2 | Permission error - cannot write state file | Check `$ZAP_DATA_DIR` permissions |
| 3 | Network error - cannot clone new plugins | Check connectivity, retry |

## Output Format

### Standard Output (Success, No Drift)
```
All plugins synced with config.
```

### Standard Output (Success, With Changes)
```
Installing plugins:
  ✓ owner1/repo1
  ✓ owner2/repo2@v1.0

Removing plugins:
  ✗ old/plugin (experimental)

Synced 2 plugins with config.
```

### Standard Output (--verbose)
```
Parsing declared state from /home/user/.zshrc...
  Found 3 plugins in array

Querying current state from /home/user/.local/share/zap/state.zsh...
  Found 2 declared plugins, 1 experimental plugin

Calculating drift...
  To install: owner1/repo1
  To remove: old/plugin

Applying reconciliation...
  Reloading shell (exec zsh)...
```

### Standard Error (Parse Error)
```
Error: Invalid plugin specification in .zshrc: "../evil/path"
  Plugin specs must match format: owner/repo[@version][:subdir]
  Fix your plugins=() array and try again.
```

### Standard Error (Permission Error)
```
Error: Cannot write to /home/user/.local/share/zap/state.zsh
  Reason: Permission denied
  Fix: chmod u+w /home/user/.local/share/zap/ && zap sync
```

## Idempotency (FR-007)

Running `zap sync` multiple times MUST produce the same result:

```zsh
# First run
$ zap sync
Synced 5 plugins with config.

# Second run (no changes)
$ zap sync
All plugins synced with config.

# Third run (still no changes)
$ zap sync
All plugins synced with config.
```

**Verification Test**:
```zsh
zap sync
state1=$(zap status --machine-readable)
zap sync
state2=$(zap status --machine-readable)
zap sync
state3=$(zap status --machine-readable)

[[ "$state1" == "$state2" && "$state2" == "$state3" ]]
# Exit code 0 = idempotent ✓
```

## Performance Requirements

- **Total execution time**: < 2 seconds for 20 plugins (SC-003)
- **Drift calculation**: < 50ms
- **Preview generation**: < 50ms
- **Reload time**: ~200-500ms (exec zsh)

## Security Considerations

- **Input Validation**: All plugin specs from array MUST be validated (FR-027)
- **No Code Execution**: Array parsing MUST NOT source `.zshrc`
- **Atomic Operations**: State file writes MUST be atomic (temp + mv)
- **Principle of Least Privilege**: Runs with user permissions only

## Examples

### Example 1: First-time sync
```zsh
# .zshrc contains:
plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions'
)

$ zap sync
Installing plugins:
  ✓ zsh-users/zsh-syntax-highlighting
  ✓ zsh-users/zsh-autosuggestions

Synced 2 plugins with config.
```

### Example 2: Remove experimental plugin
```zsh
# User tried a plugin temporarily
$ zap try jeffreytse/zsh-vi-mode

# Now reconcile back to declared state
$ zap sync
Removing plugins:
  ✗ jeffreytse/zsh-vi-mode (experimental)

Synced 2 plugins with config.
```

### Example 3: Dry-run preview
```zsh
# User edited .zshrc, added new plugin
$ zap sync --dry-run
Plugins to be installed:
  + ohmyzsh/ohmyzsh:plugins/git

No plugins to remove.

Run 'zap sync' to apply these changes.
```

### Example 4: Empty array (remove all)
```zsh
# .zshrc contains: plugins=()

$ zap sync
Removing plugins:
  ✗ zsh-users/zsh-syntax-highlighting
  ✗ zsh-users/zsh-autosuggestions

Synced 0 plugins with config.
```

## Test Cases

### Contract Tests
```zsh
# TC-SYNC-001: Idempotency
test_sync_idempotent() {
  zap sync
  state1=$(zap status)
  zap sync
  state2=$(zap status)
  [[ "$state1" == "$state2" ]]
}

# TC-SYNC-002: Experimental removal
test_sync_removes_experimental() {
  zap try test/plugin
  zap status | grep -q "experimental"
  zap sync
  ! zap status | grep -q "experimental"
}

# TC-SYNC-003: Parse error handling
test_sync_invalid_spec() {
  echo 'plugins=("../evil/path")' >> ~/.zshrc
  zap sync
  [[ $? -eq 1 ]]  # Parse error code
}

# TC-SYNC-004: Dry-run doesn't modify state
test_sync_dry_run() {
  state_before=$(zap status)
  zap sync --dry-run
  state_after=$(zap status)
  [[ "$state_before" == "$state_after" ]]
}
```

### Performance Tests
```zsh
# TC-SYNC-PERF-001: 20 plugins < 2 seconds
test_sync_performance() {
  # Create config with 20 plugins
  echo 'plugins=(' > ~/.zshrc
  for i in {1..20}; do
    echo "  'user$i/repo$i'" >> ~/.zshrc
  done
  echo ')' >> ~/.zshrc

  start_time=$(date +%s)
  zap sync
  end_time=$(date +%s)
  duration=$((end_time - start_time))

  [[ $duration -lt 2 ]]  # SC-003: < 2 seconds
}
```

## Dependencies

- `_zap_extract_plugins_array()` - Parse .zshrc array
- `_zap_validate_plugin_spec()` - Validate specifications
- `_zap_list_declared_plugins()` - Query current state
- `_zap_calculate_drift()` - Compute set differences
- `_zap_write_state()` - Update metadata file
