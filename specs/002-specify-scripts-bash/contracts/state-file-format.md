# Contract: State File Format

**File**: `$ZAP_DATA_DIR/state.zsh` (typically `~/.local/share/zap/state.zsh`)
**Purpose**: Track loaded plugins and their metadata
**Requirements**: FR-012
**Format**: Zsh sourceable script

## File Structure

### Format

```zsh
# Zap Plugin State Metadata
# Auto-generated - do not edit manually
# Session: <PID>
# Last updated: <ISO-8601 timestamp>

typeset -A _zap_plugin_state

_zap_plugin_state=(
  '<plugin-name>' '<pipe-delimited-metadata>'
  ...
)
```

### Metadata Fields

Each plugin entry is a pipe-delimited string with 6 fields:

```
<state>|<specification>|<timestamp>|<path>|<version>|<source>
```

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `state` | enum | `declared` or `experimental` | `declared` |
| `specification` | string | Full plugin spec (owner/repo[@version][:subdir]) | `owner/repo@v1.0` |
| `timestamp` | integer | Unix epoch time when loaded | `1729267935` |
| `path` | string | Absolute path to plugin directory | `/home/user/.local/share/zap/plugins/owner--repo` |
| `version` | string | Actual version loaded (commit hash or tag) | `abc123def` |
| `source` | enum | `array`, `try_command`, or `legacy_load` | `array` |

## Example File

```zsh
# Zap Plugin State Metadata
# Auto-generated - do not edit manually
# Session: 12345
# Last updated: 2025-10-18T14:32:15-07:00

typeset -A _zap_plugin_state

_zap_plugin_state=(
  'zsh-users/zsh-syntax-highlighting' 'declared|zsh-users/zsh-syntax-highlighting|1729267935|/home/user/.local/share/zap/plugins/zsh-users--zsh-syntax-highlighting|abc123def|array'
  'zsh-users/zsh-autosuggestions' 'declared|zsh-users/zsh-autosuggestions@v0.7.0|1729267936|/home/user/.local/share/zap/plugins/zsh-users--zsh-autosuggestions|v0.7.0|array'
  'ohmyzsh/ohmyzsh' 'declared|ohmyzsh/ohmyzsh:plugins/git|1729267937|/home/user/.local/share/zap/plugins/ohmyzsh--ohmyzsh|master|array'
  'jeffreytse/zsh-vi-mode' 'experimental|jeffreytse/zsh-vi-mode|1729267998|/home/user/.local/share/zap/plugins/jeffreytse--zsh-vi-mode|xyz789abc|try_command'
)
```

## Field Specifications

### State Field

**Valid Values**:
- `declared` - Plugin from `plugins=()` array
- `experimental` - Plugin loaded via `zap try`

**Rules**:
- MUST be one of the two valid values
- Determines persistence behavior (declared persists, experimental doesn't)
- Used by reconciliation to distinguish permanent vs temporary

### Specification Field

**Format**: `owner/repo[@version][:subdir]`

**Examples**:
- `zsh-users/zsh-syntax-highlighting`
- `zsh-users/zsh-autosuggestions@v0.7.0`
- `ohmyzsh/ohmyzsh:plugins/git`
- `romkatv/powerlevel10k@v1.19.0:config`

**Rules**:
- MUST match plugin specification format from data model
- Used to identify plugin uniquely
- Used for version pinning during updates

### Timestamp Field

**Format**: Unix epoch time (seconds since 1970-01-01 00:00:00 UTC)

**Example**: `1729267935` → 2025-10-18 14:32:15 PDT

**Rules**:
- MUST be valid integer
- MUST be parseable by `date -d @<timestamp>` (GNU) or `date -r <timestamp>` (BSD)
- Used for load time tracking and status display

### Path Field

**Format**: Absolute path to plugin directory

**Example**: `/home/user/.local/share/zap/plugins/owner--repo`

**Rules**:
- MUST be absolute path (starts with `/`)
- MUST use double-dash separator for owner/repo (`owner--repo`)
- MUST exist on filesystem
- Used for plugin loading and cleanup

### Version Field

**Format**: Git commit hash, tag, or branch name

**Examples**:
- `abc123def456789` (commit hash)
- `v0.7.0` (tag)
- `master` (branch)

**Rules**:
- MUST match actual checked-out version
- Updated on plugin install/update
- Used for version drift detection

### Source Field

**Valid Values**:
- `array` - Loaded from `plugins=()` array (declarative)
- `try_command` - Loaded via `zap try` (experimental)
- `legacy_load` - Loaded via old `zap load` command (deprecated)

**Rules**:
- MUST be one of the three valid values
- Determines reconciliation behavior
- `legacy_load` treated as experimental for sync purposes

## Parsing Algorithm

```zsh
_zap_parse_state_entry() {
  local entry="$1"
  local -a fields

  # Split on pipe character
  fields=("${(@s:|:)entry}")

  # Extract fields
  local state="${fields[1]}"
  local specification="${fields[2]}"
  local timestamp="${fields[3]}"
  local path="${fields[4]}"
  local version="${fields[5]}"
  local source="${fields[6]}"

  # Validate field count
  if [[ ${#fields[@]} -ne 6 ]]; then
    echo "Error: Invalid state entry (expected 6 fields, got ${#fields[@]})" >&2
    return 1
  fi

  # Validate state
  if [[ "$state" != "declared" && "$state" != "experimental" ]]; then
    echo "Error: Invalid state value: $state" >&2
    return 1
  fi

  # Validate source
  if [[ "$source" != "array" && "$source" != "try_command" && "$source" != "legacy_load" ]]; then
    echo "Error: Invalid source value: $source" >&2
    return 1
  fi

  # Return structured data (example using associative array)
  typeset -A plugin_data
  plugin_data=(
    state "$state"
    specification "$specification"
    timestamp "$timestamp"
    path "$path"
    version "$version"
    source "$source"
  )

  # Output in desired format (modify as needed)
  echo "State: $state"
  echo "Spec: $specification"
  echo "Timestamp: $timestamp"
  echo "Path: $path"
  echo "Version: $version"
  echo "Source: $source"
}
```

## Write Algorithm (Atomic)

```zsh
_zap_write_state() {
  local state_file="${ZAP_DATA_DIR}/state.zsh"
  local tmp_file="${state_file}.tmp.$$"
  local session_pid="$$"
  local timestamp=$(date -Iseconds)

  # Build header
  cat > "$tmp_file" <<EOF
# Zap Plugin State Metadata
# Auto-generated - do not edit manually
# Session: $session_pid
# Last updated: $timestamp

typeset -A _zap_plugin_state

_zap_plugin_state=(
EOF

  # Write plugin entries
  for plugin_name plugin_metadata in "${(@kv)_zap_plugin_state}"; do
    echo "  '$plugin_name' '$plugin_metadata'" >> "$tmp_file"
  done

  # Close array
  echo ")" >> "$tmp_file"

  # Atomic move
  mv "$tmp_file" "$state_file"
}
```

## Loading Algorithm

```zsh
_zap_load_state() {
  local state_file="${ZAP_DATA_DIR}/state.zsh"

  # Check if file exists
  if [[ ! -f "$state_file" ]]; then
    # Initialize empty state
    typeset -gA _zap_plugin_state
    _zap_plugin_state=()
    return 0
  fi

  # Source file to populate associative array
  source "$state_file"

  # Validate it's an associative array
  if [[ ${(t)_zap_plugin_state} != "association" ]]; then
    echo "Warning: State file corrupted, reinitializing" >&2
    typeset -gA _zap_plugin_state
    _zap_plugin_state=()
    return 1
  fi

  return 0
}
```

## Querying State

### Get All Declared Plugins

```zsh
_zap_list_declared_plugins() {
  local -a declared_plugins

  for plugin_name plugin_metadata in "${(@kv)_zap_plugin_state}"; do
    local state="${${(@s:|:)plugin_metadata}[1]}"
    if [[ "$state" == "declared" ]]; then
      declared_plugins+=("$plugin_name")
    fi
  done

  echo "${(F)declared_plugins}"  # Join with newlines
}
```

### Get All Experimental Plugins

```zsh
_zap_list_experimental_plugins() {
  local -a experimental_plugins

  for plugin_name plugin_metadata in "${(@kv)_zap_plugin_state}"; do
    local state="${${(@s:|:)plugin_metadata}[1]}"
    if [[ "$state" == "experimental" ]]; then
      experimental_plugins+=("$plugin_name")
    fi
  done

  echo "${(F)experimental_plugins}"  # Join with newlines
}
```

### Check If Plugin Is Loaded

```zsh
_zap_is_plugin_loaded() {
  local plugin_name="$1"
  [[ -n "${_zap_plugin_state[$plugin_name]}" ]]
}
```

### Get Plugin Metadata

```zsh
_zap_get_plugin_info() {
  local plugin_name="$1"
  local entry="${_zap_plugin_state[$plugin_name]}"

  if [[ -z "$entry" ]]; then
    echo "Error: Plugin not found: $plugin_name" >&2
    return 1
  fi

  _zap_parse_state_entry "$entry"
}
```

## Updating State

### Add Plugin

```zsh
_zap_add_plugin_to_state() {
  local plugin_name="$1"
  local specification="$2"
  local state="$3"  # declared or experimental
  local path="$4"
  local version="$5"
  local source="$6"  # array, try_command, legacy_load

  local timestamp=$(date +%s)

  # Build metadata string
  local metadata="${state}|${specification}|${timestamp}|${path}|${version}|${source}"

  # Add to associative array
  _zap_plugin_state[$plugin_name]="$metadata"

  # Write to file
  _zap_write_state
}
```

### Remove Plugin

```zsh
_zap_remove_plugin_from_state() {
  local plugin_name="$1"

  # Remove from associative array
  unset "_zap_plugin_state[$plugin_name]"

  # Write to file
  _zap_write_state
}
```

### Update Plugin State

```zsh
_zap_update_plugin_state() {
  local plugin_name="$1"
  local new_state="$2"  # declared or experimental
  local new_source="$3"  # array, try_command, legacy_load

  local entry="${_zap_plugin_state[$plugin_name]}"
  if [[ -z "$entry" ]]; then
    echo "Error: Plugin not found: $plugin_name" >&2
    return 1
  fi

  # Parse existing entry
  local -a fields
  fields=("${(@s:|:)entry}")

  # Update state and source
  fields[1]="$new_state"
  fields[6]="$new_source"

  # Rebuild metadata string
  local new_metadata="${(j:|:)fields}"

  # Update associative array
  _zap_plugin_state[$plugin_name]="$new_metadata"

  # Write to file
  _zap_write_state
}
```

## File Lifecycle

### Initialization (First Run)

1. User sources `zap.zsh`
2. Zap checks if `$ZAP_DATA_DIR/state.zsh` exists
3. If not, creates empty state file
4. Loads plugins from `plugins=()` array
5. Writes state file with all loaded plugins

### Normal Startup

1. User sources `zap.zsh`
2. Zap loads existing `state.zsh`
3. Loads plugins from `plugins=()` array
4. Updates state with any new plugins
5. Does NOT remove experimental plugins (ephemeral by design)

### After `zap try`

1. User runs `zap try owner/repo`
2. Plugin loads successfully
3. Entry added to state with `state: experimental`
4. State file updated atomically

### After `zap adopt`

1. User runs `zap adopt owner/repo`
2. State updated: `experimental` → `declared`, `try_command` → `array`
3. `.zshrc` updated with plugin in array
4. State file updated atomically

### After `zap sync`

1. User runs `zap sync`
2. Shell reloads (`exec zsh`)
3. New state file created from `plugins=()` array
4. All experimental plugins removed (not in array)
5. Only declared plugins remain

## Error Handling

### Corrupted State File

```zsh
_zap_load_state() {
  local state_file="${ZAP_DATA_DIR}/state.zsh"

  if [[ -f "$state_file" ]]; then
    # Attempt to source
    if ! source "$state_file" 2>/dev/null; then
      echo "Warning: State file corrupted, reinitializing" >&2
      # Create backup
      mv "$state_file" "$state_file.corrupted.$(date +%s)"
      # Reinitialize
      typeset -gA _zap_plugin_state
      _zap_plugin_state=()
      return 1
    fi
  else
    # No state file, initialize empty
    typeset -gA _zap_plugin_state
    _zap_plugin_state=()
  fi

  return 0
}
```

### Missing Fields

```zsh
# Defensive parsing - handle missing fields
_zap_parse_state_entry_safe() {
  local entry="$1"
  local -a fields
  fields=("${(@s:|:)entry}")

  # Provide defaults for missing fields
  local state="${fields[1]:-unknown}"
  local specification="${fields[2]:-unknown/unknown}"
  local timestamp="${fields[3]:-0}"
  local path="${fields[4]:-}"
  local version="${fields[5]:-unknown}"
  local source="${fields[6]:-legacy_load}"

  # Warn about malformed entry
  if [[ ${#fields[@]} -ne 6 ]]; then
    echo "Warning: Malformed state entry for $specification" >&2
  fi

  # Continue with available data
  ...
}
```

## Performance Considerations

### File Size

- Each entry: ~150-200 bytes
- 100 plugins: ~15-20 KB
- Well under 1MB budget

### Read Performance

- Sourcing Zsh file: ~5ms for 100 plugins
- Associative array lookup: O(1)
- Total query time: < 10ms

### Write Performance

- Formatting: ~5ms
- Writing temp file: ~5ms
- Atomic move: ~1ms
- Total write time: < 20ms

## Security Considerations

- **No Code Execution**: File is sourced but contains only data declarations
- **Atomic Writes**: Temp file + mv prevents corruption
- **File Permissions**: Created with user permissions (600 recommended)
- **Path Validation**: Paths validated before writing
- **No User Input**: All data comes from Zap internals, not user

## Test Cases

```zsh
# TC-STATE-001: File creation
test_state_file_created() {
  rm -f "$ZAP_DATA_DIR/state.zsh"
  source zap.zsh
  [[ -f "$ZAP_DATA_DIR/state.zsh" ]]
}

# TC-STATE-002: Plugin added to state
test_state_plugin_added() {
  echo 'plugins=("test/plugin")' > ~/.zshrc
  source zap.zsh
  grep -q "test/plugin" "$ZAP_DATA_DIR/state.zsh"
}

# TC-STATE-003: Experimental marked correctly
test_state_experimental_marked() {
  zap try test/plugin
  entry=$(grep "test/plugin" "$ZAP_DATA_DIR/state.zsh")
  echo "$entry" | grep -q "experimental|"
}

# TC-STATE-004: Atomic writes (no corruption)
test_state_atomic_write() {
  # Simulate concurrent writes
  for i in {1..10}; do
    zap try "test/plugin$i" &
  done
  wait

  # State file should still be valid
  source "$ZAP_DATA_DIR/state.zsh"
  [[ ${(t)_zap_plugin_state} == "association" ]]
}

# TC-STATE-005: Corrupted file recovery
test_state_corrupted_recovery() {
  echo "garbage data" > "$ZAP_DATA_DIR/state.zsh"
  source zap.zsh
  # Should reinitialize
  [[ -f "$ZAP_DATA_DIR/state.zsh.corrupted."* ]]
  [[ -f "$ZAP_DATA_DIR/state.zsh" ]]
}
```

## Dependencies

- Zsh associative arrays (`typeset -A`)
- Standard file operations (`cat`, `mv`, `source`)
- Date utilities (`date`)
