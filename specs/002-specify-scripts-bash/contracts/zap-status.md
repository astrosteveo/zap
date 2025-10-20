# Contract: `zap status`

**Command**: `zap status`
**Purpose**: Display current plugin state vs. declared configuration
**Requirements**: FR-010, FR-012
**Success Criteria**: SC-005

## Signature

```zsh
zap status [--verbose] [--machine-readable]
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--verbose` | flag | No | false | Show detailed information (versions, paths, load times) |
| `--machine-readable` | flag | No | false | Output parseable format (JSON or key=value) |

## Behavior

### Preconditions
- User has sourced `zap.zsh`
- `$ZAP_DATA_DIR` exists

### Algorithm

1. **Parse Declared State**
   - Extract `plugins=()` array from `.zshrc`
   - Build list of declared plugins

2. **Read Current State**
   - Load `$ZAP_DATA_DIR/state.zsh`
   - Query `_zap_plugin_state` associative array
   - Separate plugins by state: `declared` vs `experimental`

3. **Calculate Drift**
   - Compare declared (from config) vs current (from state)
   - Identify plugins in config but not loaded
   - Identify plugins loaded but not in config

4. **Display Summary**
   - Show declared plugins with status indicators
   - Show experimental plugins separately
   - Show drift if detected
   - Use color/symbols for visual clarity

### Postconditions
- User understands current plugin state
- User knows if drift exists
- User knows which plugins are experimental vs declared

## Return Codes

| Code | Meaning |
|------|---------|
| 0 | Success - state displayed |
| 1 | Error reading state file |

## Output Format

### Standard Output (No Drift)
```
Declared plugins (3):
  ✓ zsh-users/zsh-syntax-highlighting
  ✓ zsh-users/zsh-autosuggestions@v0.7.0
  ✓ ohmyzsh/ohmyzsh:plugins/git

Experimental plugins (0):
  (none)

Status: All plugins synced with config
```

### Standard Output (With Experimental Plugins)
```
Declared plugins (2):
  ✓ zsh-users/zsh-syntax-highlighting
  ✓ zsh-users/zsh-autosuggestions

Experimental plugins (2):
  ⚡ jeffreytse/zsh-vi-mode (loaded 5 minutes ago)
  ⚡ romkatv/powerlevel10k@v1.19.0 (loaded 2 minutes ago)

Status: 2 experimental plugins loaded
  Run 'zap sync' to remove experimental plugins
  Run 'zap adopt <plugin>' to make them permanent
```

### Standard Output (With Drift)
```
Declared plugins (3):
  ✓ zsh-users/zsh-syntax-highlighting (loaded)
  ✗ zsh-users/zsh-autosuggestions (not loaded)
  ✓ ohmyzsh/ohmyzsh:plugins/git (loaded)

Experimental plugins (1):
  ⚡ jeffreytse/zsh-vi-mode (not declared)

Status: Configuration drift detected
  1 declared plugin not loaded
  1 experimental plugin loaded

  Run 'zap diff' to see what would change
  Run 'zap sync' to reconcile state
```

### Standard Output (--verbose)
```
Declared plugins (2):
  ✓ zsh-users/zsh-syntax-highlighting
    Version: abc123def (commit hash)
    Path: ~/.local/share/zap/plugins/zsh-users--zsh-syntax-highlighting
    Loaded: 2025-10-18 14:00:00 (15 minutes ago)
    Load time: 23ms
    Source: array

  ✓ zsh-users/zsh-autosuggestions@v0.7.0
    Version: v0.7.0
    Path: ~/.local/share/zap/plugins/zsh-users--zsh-autosuggestions
    Loaded: 2025-10-18 14:00:01 (15 minutes ago)
    Load time: 18ms
    Source: array

Experimental plugins (1):
  ⚡ jeffreytse/zsh-vi-mode
    Version: xyz789abc (commit hash)
    Path: ~/.local/share/zap/plugins/jeffreytse--zsh-vi-mode
    Loaded: 2025-10-18 14:10:00 (5 minutes ago)
    Load time: 45ms
    Source: try_command

Status: 1 experimental plugin loaded
Total plugins: 3
Total load time: 86ms
```

### Machine-Readable Output (--machine-readable)
```json
{
  "declared": [
    {
      "name": "zsh-users/zsh-syntax-highlighting",
      "state": "declared",
      "loaded": true,
      "version": "abc123def",
      "path": "/home/user/.local/share/zap/plugins/zsh-users--zsh-syntax-highlighting",
      "load_timestamp": 1729267200,
      "load_time_ms": 23,
      "source": "array"
    },
    {
      "name": "zsh-users/zsh-autosuggestions",
      "state": "declared",
      "loaded": true,
      "version": "v0.7.0",
      "path": "/home/user/.local/share/zap/plugins/zsh-users--zsh-autosuggestions",
      "load_timestamp": 1729267201,
      "load_time_ms": 18,
      "source": "array"
    }
  ],
  "experimental": [
    {
      "name": "jeffreytse/zsh-vi-mode",
      "state": "experimental",
      "loaded": true,
      "version": "xyz789abc",
      "path": "/home/user/.local/share/zap/plugins/jeffreytse--zsh-vi-mode",
      "load_timestamp": 1729267800,
      "load_time_ms": 45,
      "source": "try_command"
    }
  ],
  "drift": {
    "detected": true,
    "to_install": [],
    "to_remove": ["jeffreytse/zsh-vi-mode"]
  },
  "summary": {
    "total_plugins": 3,
    "declared_count": 2,
    "experimental_count": 1,
    "total_load_time_ms": 86,
    "in_sync": false
  }
}
```

## Display Components

### Status Indicators
- `✓` - Plugin loaded and in sync
- `✗` - Plugin declared but not loaded (drift)
- `⚡` - Experimental plugin (ephemeral)

### Time Formatting
- < 1 minute: "loaded X seconds ago"
- < 1 hour: "loaded X minutes ago"
- < 24 hours: "loaded X hours ago"
- ≥ 24 hours: "loaded YYYY-MM-DD HH:MM:SS"

### Color Scheme (if terminal supports)
- Green: Declared plugins in sync
- Yellow: Experimental plugins
- Red: Drift detected
- Gray: Metadata (paths, timestamps)

## Performance Requirements

- **Parse config**: < 10ms
- **Read state**: < 5ms
- **Calculate drift**: < 20ms
- **Format output**: < 15ms
- **Total**: < 100ms for 20 plugins (SC-005)

## Examples

### Example 1: Clean state (no experimental, no drift)
```zsh
$ zap status
Declared plugins (3):
  ✓ zsh-users/zsh-syntax-highlighting
  ✓ zsh-users/zsh-autosuggestions
  ✓ ohmyzsh/ohmyzsh:plugins/git

Experimental plugins (0):
  (none)

Status: All plugins synced with config
```

### Example 2: With experimental plugins
```zsh
$ zap try jeffreytse/zsh-vi-mode
$ zap status
Declared plugins (2):
  ✓ zsh-users/zsh-syntax-highlighting
  ✓ zsh-users/zsh-autosuggestions

Experimental plugins (1):
  ⚡ jeffreytse/zsh-vi-mode (loaded 10 seconds ago)

Status: 1 experimental plugin loaded
  Run 'zap sync' to remove experimental plugins
  Run 'zap adopt jeffreytse/zsh-vi-mode' to make it permanent
```

### Example 3: With drift (config changed)
```zsh
# User manually edited .zshrc, added new plugin
$ zap status
Declared plugins (4):
  ✓ zsh-users/zsh-syntax-highlighting (loaded)
  ✓ zsh-users/zsh-autosuggestions (loaded)
  ✗ ohmyzsh/ohmyzsh:plugins/docker (not loaded)
  ✓ ohmyzsh/ohmyzsh:plugins/git (loaded)

Experimental plugins (0):
  (none)

Status: Configuration drift detected
  1 declared plugin not loaded

  Run 'zap diff' to see what would change
  Run 'zap sync' to reconcile state
```

### Example 4: Verbose output
```zsh
$ zap status --verbose
Declared plugins (2):
  ✓ zsh-users/zsh-syntax-highlighting
    Version: abc123def (commit hash)
    Path: ~/.local/share/zap/plugins/zsh-users--zsh-syntax-highlighting
    Loaded: 2025-10-18 14:00:00 (15 minutes ago)
    Load time: 23ms
    Source: array

  ✓ zsh-users/zsh-autosuggestions@v0.7.0
    Version: v0.7.0
    Path: ~/.local/share/zap/plugins/zsh-users--zsh-autosuggestions
    Loaded: 2025-10-18 14:00:01 (15 minutes ago)
    Load time: 18ms
    Source: array

Total plugins: 2
Total load time: 41ms
Status: All plugins synced with config
```

### Example 5: Machine-readable output
```zsh
$ zap status --machine-readable | jq '.summary'
{
  "total_plugins": 2,
  "declared_count": 2,
  "experimental_count": 0,
  "total_load_time_ms": 41,
  "in_sync": true
}
```

## Test Cases

### Contract Tests
```zsh
# TC-STATUS-001: Shows declared plugins
test_status_declared() {
  echo 'plugins=("test/plugin1" "test/plugin2")' > ~/.zshrc
  source zap.zsh
  output=$(zap status)
  echo "$output" | grep -q "test/plugin1"
  echo "$output" | grep -q "test/plugin2"
}

# TC-STATUS-002: Shows experimental plugins
test_status_experimental() {
  zap try test/plugin
  output=$(zap status)
  echo "$output" | grep -q "test/plugin"
  echo "$output" | grep -q "experimental"
}

# TC-STATUS-003: Detects drift
test_status_drift() {
  echo 'plugins=("test/plugin")' > ~/.zshrc
  # Don't load plugin
  output=$(zap status)
  echo "$output" | grep -q "drift"
  echo "$output" | grep -q "not loaded"
}

# TC-STATUS-004: In sync message
test_status_in_sync() {
  echo 'plugins=("test/plugin")' > ~/.zshrc
  source zap.zsh
  output=$(zap status)
  echo "$output" | grep -q "All plugins synced"
}

# TC-STATUS-005: Performance < 100ms
test_status_performance() {
  # Create config with 20 plugins
  echo 'plugins=(' > ~/.zshrc
  for i in {1..20}; do
    echo "  'user$i/repo$i'" >> ~/.zshrc
  done
  echo ')' >> ~/.zshrc
  source zap.zsh

  start=$(date +%s%3N)
  zap status > /dev/null
  end=$(date +%s%3N)
  duration=$((end - start))

  [[ $duration -lt 100 ]]  # SC-005: < 100ms
}

# TC-STATUS-006: Machine-readable format
test_status_machine_readable() {
  zap status --machine-readable | jq . > /dev/null
  [[ $? -eq 0 ]]  # Valid JSON
}
```

## Dependencies

- `_zap_extract_plugins_array()` - Parse config
- `_zap_load_state()` - Read metadata
- `_zap_calculate_drift()` - Compute differences
- `_zap_format_timestamp()` - Time ago formatting
- `jq` (optional) - JSON formatting for --machine-readable
