# Contract: `zap try`

**Command**: `zap try`
**Purpose**: Load a plugin temporarily for experimentation without modifying configuration
**Requirements**: FR-004, FR-005, FR-014
**Success Criteria**: SC-009

## Signature

```zsh
zap try <plugin-spec> [--verbose]
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `<plugin-spec>` | string | Yes | - | Plugin specification: `owner/repo[@version][:subdir]` |
| `--verbose` | flag | No | false | Show detailed loading information |

## Behavior

### Preconditions
- User has sourced `zap.zsh`
- `$ZAP_DATA_DIR` exists and is writable
- Plugin specification is valid (matches format)

### Algorithm

1. **Validate Plugin Specification** (FR-027)
   - Check format: `owner/repo[@version][:subdir]`
   - Reject path traversal (`../`, absolute paths)
   - Reject command injection attempts

2. **Check If Already Declared**
   - Parse `plugins=()` array from `.zshrc`
   - If plugin already declared, show informational message and exit
   - Rationale: Declared plugins always loaded, trying them is redundant

3. **Check If Already Loaded** (experimental)
   - Query `$ZAP_DATA_DIR/state.zsh`
   - If already loaded as experimental, show message and exit

4. **Download Plugin** (if not cached)
   - Clone repository to `$ZAP_DATA_DIR/plugins/owner--repo/`
   - Checkout specified version if `@version` provided
   - Standard Zap download logic (reuse existing downloader)

5. **Load Plugin**
   - Source plugin file(s) from install path
   - If `:subdir` specified, load from subdirectory
   - Standard Zap loading logic (reuse existing loader)

6. **Update State Metadata**
   - Add entry to `state.zsh`:
     ```zsh
     'owner/repo' 'experimental|owner/repo|<timestamp>|<path>|<version>|try_command'
     ```
   - Mark as `experimental` (FR-005)
   - Record load timestamp
   - Atomic write (temp file + mv)

7. **Show Confirmation**
   - Display success message with next steps

### Postconditions
- Plugin is loaded and functional in current shell session
- Plugin marked as `experimental` in state metadata
- Plugin will NOT be reloaded on next shell startup (FR-014)
- User can reconcile away with `zap sync` or promote with `zap adopt`

## Return Codes

| Code | Meaning | User Action |
|------|---------|-------------|
| 0 | Success - plugin loaded | None |
| 1 | Validation error - invalid plugin spec | Fix specification format |
| 2 | Already loaded - plugin is declared | No action needed (already permanent) |
| 3 | Download error - cannot clone repo | Check repo name, connectivity |
| 4 | Load error - plugin failed to source | Check plugin compatibility |

## Output Format

### Standard Output (Success)
```
Trying plugin: owner/repo
  ✓ Downloaded to ~/.local/share/zap/plugins/owner--repo
  ✓ Loaded successfully (experimental)

This plugin is temporary and will not persist across shell restarts.

Next steps:
  - Test the plugin in your current session
  - Run 'zap adopt owner/repo' to make it permanent
  - Run 'zap sync' to remove it and return to declared state
```

### Standard Output (Already Declared)
```
Plugin owner/repo is already declared in your config.
No action needed - it's already loaded permanently.

Location: ~/.zshrc plugins=() array
```

### Standard Output (Already Loaded as Experimental)
```
Plugin owner/repo is already loaded experimentally.
Run 'zap status' to see current plugin state.
```

### Standard Output (--verbose)
```
Validating plugin specification: owner/repo@v1.0.0
  ✓ Format valid
  ✓ No path traversal detected
  ✓ No command injection detected

Checking if already declared...
  ✗ Not found in plugins=() array

Checking if already loaded...
  ✗ Not currently loaded

Downloading plugin...
  Cloning https://github.com/owner/repo.git
  Checking out v1.0.0
  ✓ Downloaded to ~/.local/share/zap/plugins/owner--repo

Loading plugin...
  Sourcing: ~/.local/share/zap/plugins/owner--repo/repo.plugin.zsh
  ✓ Loaded successfully

Updating state metadata...
  ✓ Marked as experimental in ~/.local/share/zap/state.zsh

Success! Plugin loaded experimentally.
```

### Standard Error (Validation Error)
```
Error: Invalid plugin specification: "../evil/path"
  Plugin specs must match format: owner/repo[@version][:subdir]
  Examples:
    zap try zsh-users/zsh-syntax-highlighting
    zap try zsh-users/zsh-autosuggestions@v0.7.0
    zap try ohmyzsh/ohmyzsh:plugins/git
```

### Standard Error (Download Error)
```
Error: Failed to download plugin: owner/nonexistent-repo
  Reason: Repository not found (404)
  Fix: Check repository name and try again
```

### Standard Error (Load Error)
```
Error: Failed to load plugin: owner/repo
  Reason: No .plugin.zsh or .zsh file found
  Fix: Check plugin structure and compatibility
```

## Ephemeral Behavior (FR-014)

Experimental plugins MUST NOT persist across shell restarts:

```zsh
# Session 1
$ zap try test/plugin
✓ Loaded successfully (experimental)

$ zap status
Experimental plugins (1):
  ⚡ test/plugin

# Session 2 (new shell)
$ zap status
Experimental plugins (0):
  (none)

# Plugin is NOT automatically reloaded
```

## Performance Requirements

- **Validation**: < 5ms
- **Already-loaded check**: < 10ms
- **Download** (if needed): < 30 seconds for typical plugin
- **Load**: < 50ms
- **State update**: < 10ms
- **Total** (cached): < 100ms
- **Total** (download): < 30 seconds

## Security Considerations

- **Input Validation**: Strict regex on plugin spec (FR-027)
- **Path Traversal Prevention**: Reject `../` and absolute paths
- **Command Injection Prevention**: No `eval` on user input
- **Network Security**: Use HTTPS for git clone
- **Filesystem Isolation**: Plugins installed in `$ZAP_DATA_DIR` only

## Examples

### Example 1: Try new plugin
```zsh
$ zap try jeffreytse/zsh-vi-mode
Trying plugin: jeffreytse/zsh-vi-mode
  ✓ Downloaded to ~/.local/share/zap/plugins/jeffreytse--zsh-vi-mode
  ✓ Loaded successfully (experimental)

This plugin is temporary and will not persist across shell restarts.

Next steps:
  - Test the plugin in your current session
  - Run 'zap adopt jeffreytse/zsh-vi-mode' to make it permanent
  - Run 'zap sync' to remove it and return to declared state
```

### Example 2: Try with version pin
```zsh
$ zap try romkatv/powerlevel10k@v1.19.0
Trying plugin: romkatv/powerlevel10k@v1.19.0
  ✓ Downloaded to ~/.local/share/zap/plugins/romkatv--powerlevel10k
  ✓ Checked out v1.19.0
  ✓ Loaded successfully (experimental)
```

### Example 3: Try subdirectory plugin
```zsh
$ zap try ohmyzsh/ohmyzsh:plugins/docker
Trying plugin: ohmyzsh/ohmyzsh:plugins/docker
  ✓ Downloaded to ~/.local/share/zap/plugins/ohmyzsh--ohmyzsh
  ✓ Loaded from subdirectory: plugins/docker
  ✓ Loaded successfully (experimental)
```

### Example 4: Try already-declared plugin (no-op)
```zsh
# .zshrc contains:
plugins=(
  'zsh-users/zsh-syntax-highlighting'
)

$ zap try zsh-users/zsh-syntax-highlighting
Plugin zsh-users/zsh-syntax-highlighting is already declared in your config.
No action needed - it's already loaded permanently.

Location: ~/.zshrc plugins=() array
```

### Example 5: Invalid specification
```zsh
$ zap try ../evil/path
Error: Invalid plugin specification: "../evil/path"
  Plugin specs must match format: owner/repo[@version][:subdir]
```

## Test Cases

### Contract Tests
```zsh
# TC-TRY-001: Valid plugin loads successfully
test_try_valid_plugin() {
  zap try zsh-users/zsh-syntax-highlighting
  [[ $? -eq 0 ]]
  zap status | grep -q "zsh-users/zsh-syntax-highlighting"
  zap status | grep -q "experimental"
}

# TC-TRY-002: Experimental doesn't persist
test_try_ephemeral() {
  zap try test/plugin
  zap status | grep -q "test/plugin"

  # Restart shell (new session)
  zsh -i -c "zap status" | ! grep -q "test/plugin"
}

# TC-TRY-003: Already-declared is no-op
test_try_already_declared() {
  echo 'plugins=("test/plugin")' > ~/.zshrc
  source zap.zsh

  output=$(zap try test/plugin)
  echo "$output" | grep -q "already declared"
  [[ $? -eq 2 ]]  # Return code 2
}

# TC-TRY-004: Invalid spec rejected
test_try_invalid_spec() {
  zap try "../evil/path"
  [[ $? -eq 1 ]]  # Validation error
}

# TC-TRY-005: Nonexistent repo fails gracefully
test_try_nonexistent() {
  zap try user/nonexistent-repo-12345
  [[ $? -eq 3 ]]  # Download error
}
```

### Security Tests
```zsh
# TC-TRY-SEC-001: Path traversal rejected
test_try_path_traversal() {
  zap try "owner/repo:../../etc"
  [[ $? -eq 1 ]]
}

# TC-TRY-SEC-002: Command injection rejected
test_try_command_injection() {
  zap try "owner/repo; rm -rf /"
  [[ $? -eq 1 ]]
}

# TC-TRY-SEC-003: Absolute path rejected
test_try_absolute_path() {
  zap try "/etc/passwd"
  [[ $? -eq 1 ]]
}
```

## Dependencies

- `_zap_validate_plugin_spec()` - Validate specification
- `_zap_extract_plugins_array()` - Check if declared
- `_zap_download_plugin()` - Clone repository
- `_zap_load_plugin()` - Source plugin files
- `_zap_write_state()` - Update metadata
- `_zap_list_loaded_plugins()` - Check if already loaded
