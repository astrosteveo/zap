# Data Model: Declarative Plugin Management

**Feature**: [spec.md](spec.md) | **Branch**: `002-specify-scripts-bash` | **Date**: 2025-10-18

## Overview

This data model defines the core entities, relationships, and state transitions for Zap's declarative plugin management system. The model follows the declarative configuration paradigm (Constitution Principle VIII) with clear separation between declared state, runtime state, and experimental state.

## Entity Definitions

### 1. Plugin Specification

A string representation defining a plugin to be loaded by Zap.

**Format**: `owner/repo[@version][:subdir]`

**Attributes**:
- `owner` (string, required): GitHub username or organization
- `repo` (string, required): Repository name
- `version` (string, optional): Version pin (tag, commit hash, or branch)
- `subdir` (string, optional): Subdirectory within repository to source

**Examples**:
```
zsh-users/zsh-syntax-highlighting
zsh-users/zsh-autosuggestions@v0.7.0
ohmyzsh/ohmyzsh:plugins/git
romkatv/powerlevel10k@d7a8b72:config
```

**Validation Rules** (FR-027):
- MUST match pattern: `^[a-zA-Z0-9_\-]+/[a-zA-Z0-9_\-\.]+(@[a-zA-Z0-9_\-\.]+)?(:[\w/\-]+)?$`
- MUST contain exactly one slash (separating owner/repo)
- MUST NOT contain path traversal sequences (`../`, absolute paths)
- MUST NOT contain shell metacharacters that could enable command injection
- Version part (if present) MUST NOT contain whitespace
- Subdir part (if present) MUST NOT start with `/` or contain `..`

**Parsing Strategy**:
```zsh
# Extract components
local spec="$1"
local owner="${spec%%/*}"
local rest="${spec#*/}"
local repo="${rest%%[@:]*}"
local version="${${spec#*@}%%:*}"  # Empty if no @
local subdir="${spec##*:}"         # Empty if no :

# Validate each component
[[ -z "$owner" || -z "$repo" ]] && return 1
```

---

### 2. Declared Plugin

A plugin that appears in the `plugins=()` array in the user's `.zshrc` file. This represents the **desired end state** of plugin configuration.

**Source**: `.zshrc` configuration file

**Attributes**:
- `specification` (Plugin Specification): The plugin spec string
- `array_position` (integer): Order in the plugins array (determines load order)
- `config_file` (path): Path to `.zshrc` containing the declaration

**State**: `declared`

**Persistence**: Permanent (persists across shell sessions)

**Load Behavior**:
- Automatically loaded on shell startup (FR-002)
- Load order preserved from array position (FR-013)
- Errors loading individual plugins MUST NOT block others (FR-018)

**Example in `.zshrc`**:
```zsh
plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions@v0.7.0'
  'ohmyzsh/ohmyzsh:plugins/git'
)

source "$HOME/.local/share/zap/zap.zsh"
```

**Extraction Algorithm**:
```zsh
# Text-based parsing (no code execution)
_zap_extract_plugins_array() {
  local zshrc="$1"
  local in_array=0
  local array_content=""

  while IFS= read -r line; do
    # Skip comments
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Detect array start
    if [[ "$line" =~ ^[[:space:]]*plugins[[:space:]]*=\( ]]; then
      in_array=1
      continue
    fi

    # Collect array elements
    if [[ $in_array -eq 1 ]]; then
      if [[ "$line" =~ \) ]]; then
        break
      else
        array_content+=" $line"
      fi
    fi
  done < "$zshrc"

  # Parse using Zsh (z) flag (shell-aware splitting)
  local -a elements
  elements=("${(z)array_content}")

  # Unquote and output
  for elem in "${(@)elements}"; do
    elem="${(Q)elem}"  # Remove one level of quoting
    echo "$elem"
  done
}
```

---

### 3. Experimental Plugin

A plugin loaded via the `zap try` command for temporary experimentation. This represents **ephemeral runtime state** that does not persist across shell sessions.

**Source**: `zap try owner/repo` command

**Attributes**:
- `specification` (Plugin Specification): The plugin spec string
- `load_timestamp` (epoch time): When the plugin was loaded
- `session_id` (string): Shell session identifier (e.g., `$$` PID)

**State**: `experimental`

**Persistence**: Ephemeral (FR-014 - does NOT persist across shell restarts)

**Load Behavior**:
- Loaded immediately upon `zap try` execution
- Marked distinctly in state tracking
- NOT reloaded on shell startup
- Removed by `zap sync` reconciliation (FR-006)
- Can be promoted to declared state via `zap adopt` (FR-008)

**Example Usage**:
```zsh
# Try a new plugin without modifying config
$ zap try jeffreytse/zsh-vi-mode

# Check status
$ zap status
Declared plugins (2):
  ✓ zsh-users/zsh-syntax-highlighting
  ✓ zsh-users/zsh-autosuggestions@v0.7.0

Experimental plugins (1):
  ⚡ jeffreytse/zsh-vi-mode (loaded at 2025-10-18 14:32:15)

# Return to declared state
$ zap sync
Removing experimental plugins: jeffreytse/zsh-vi-mode
All plugins synced with config.
```

---

### 4. Plugin State Metadata

Tracked information about each loaded plugin, stored in `$ZAP_DATA_DIR/state.zsh`.

**Attributes**:
- `name` (string): Plugin identifier (owner/repo)
- `state` (enum): `declared` | `experimental`
- `specification` (Plugin Specification): Full spec including version/subdir
- `load_timestamp` (epoch time): When plugin was loaded
- `install_path` (path): Where plugin is installed on disk
- `version_actual` (string): Actual version loaded (commit hash)
- `source` (enum): `array` | `try_command` | `legacy_load`

**File Format** (`$ZAP_DATA_DIR/state.zsh`):
```zsh
# Zap Plugin State Metadata
# Auto-generated - do not edit manually
# Session: 12345 (PID)
# Last updated: 2025-10-18 14:32:15

typeset -A _zap_plugin_state

_zap_plugin_state=(
  'zsh-users/zsh-syntax-highlighting' 'declared|zsh-users/zsh-syntax-highlighting|1729267935|/home/user/.local/share/zap/plugins/zsh-users--zsh-syntax-highlighting|abc123def|array'
  'zsh-users/zsh-autosuggestions' 'declared|zsh-users/zsh-autosuggestions@v0.7.0|1729267936|/home/user/.local/share/zap/plugins/zsh-users--zsh-autosuggestions|v0.7.0|array'
  'jeffreytse/zsh-vi-mode' 'experimental|jeffreytse/zsh-vi-mode|1729267998|/home/user/.local/share/zap/plugins/jeffreytse--zsh-vi-mode|xyz789abc|try_command'
)
```

**Field Separator**: `|` (pipe character)

**Parsing**:
```zsh
_zap_parse_state_entry() {
  local entry="$1"
  local -a fields
  fields=("${(@s:|:)entry}")

  echo "State: ${fields[1]}"
  echo "Spec: ${fields[2]}"
  echo "Timestamp: ${fields[3]}"
  echo "Path: ${fields[4]}"
  echo "Version: ${fields[5]}"
  echo "Source: ${fields[6]}"
}
```

**Update Strategy**:
- Atomic writes (temp file + `mv`)
- Updated on: plugin load, plugin unload, reconciliation
- Read on: `zap status`, `zap diff`, `zap sync`

---

### 5. State Drift

The calculated difference between **declared configuration** (plugins array) and **current runtime state** (loaded plugins).

**Attributes**:
- `to_install` (array of Plugin Specifications): Plugins in config but not loaded
- `to_remove` (array of Plugin Specifications): Plugins loaded but not in config
- `in_sync` (boolean): True if no drift detected

**Calculation Algorithm**:
```zsh
_zap_calculate_drift() {
  # 1. Parse desired state from config
  local -a desired
  desired=($(zap_extract_plugins_array ~/.zshrc))

  # 2. Query current loaded plugins (declared only, exclude experimental)
  local -a current
  current=($(zap_list_declared_plugins))

  # 3. Compute set differences using Zsh operators
  local -a to_install to_remove
  to_install=(${desired:|current})   # Elements in desired but not current
  to_remove=(${current:|desired})    # Elements in current but not desired

  # 4. Determine sync status
  local in_sync=false
  [[ ${#to_install[@]} -eq 0 && ${#to_remove[@]} -eq 0 ]] && in_sync=true

  # 5. Return results
  echo "TO_INSTALL:${(j:,:)to_install}"
  echo "TO_REMOVE:${(j:,:)to_remove}"
  echo "IN_SYNC:$in_sync"
}
```

**Display Behavior**:
```zsh
# zap diff output
$ zap diff
Plugins to be installed:
  + ohmyzsh/ohmyzsh:plugins/docker
  + romkatv/powerlevel10k

Plugins to be removed:
  - old/deprecated-plugin (experimental)

Run 'zap sync' to apply these changes.
```

**Reconciliation** (FR-006, FR-007):
- Idempotent: Running `zap sync` multiple times produces same result
- Safe: Preview changes with `zap diff` before applying
- Complete: Handles both additions and removals
- Conservative: Never modifies config file (only runtime state)

---

## Entity Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                      User's .zshrc                          │
│  ┌────────────────────────────────────────────────────┐     │
│  │ plugins=(                                          │     │
│  │   'owner1/repo1'         ◄── Declared Plugin 1    │     │
│  │   'owner2/repo2@v1.0'    ◄── Declared Plugin 2    │     │
│  │ )                                                  │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
                       │
                       │ Parsed by
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Plugin State Metadata                          │
│         ($ZAP_DATA_DIR/state.zsh)                           │
│  ┌────────────────────────────────────────────────────┐     │
│  │ _zap_plugin_state=(                                │     │
│  │   'owner1/repo1' → [declared|...]                 │     │
│  │   'owner2/repo2' → [declared|...]                 │     │
│  │   'owner3/repo3' → [experimental|...]  ◄── Experimental│
│  │ )                                                  │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
                       │
                       │ Compared to compute
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                   State Drift                               │
│  ┌────────────────────────────────────────────────────┐     │
│  │ to_install = [plugins in config but not loaded]   │     │
│  │ to_remove  = [plugins loaded but not in config]   │     │
│  │ in_sync    = true | false                         │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
                       │
                       │ Resolved by
                       ▼
                 zap sync command
```

---

## State Transitions

### Plugin Lifecycle

```
┌──────────────┐
│  Undeclared  │ (not in config, not loaded)
└──────┬───────┘
       │
       ├─────────────────── zap try owner/repo ──────────────────┐
       │                                                          │
       │                                                          ▼
       │                                              ┌───────────────────┐
       │                                              │   Experimental    │
       │                                              │  (loaded, temp)   │
       │                                              └─────┬─────────────┘
       │                                                    │
       │                                                    │ zap adopt
       │                                                    │
       │                                                    ▼
       │                                              ┌───────────────────┐
       │                                              │   Declared +      │
       │                                              │   Experimental    │
       │                                              └─────┬─────────────┘
       │                                                    │
       │                                                    │ zap sync
       │                                                    │ (removes
       │                                                    │  experimental
       │                                                    │  marker)
       │                                                    ▼
       │                                              ┌───────────────────┐
       ├─── Add to plugins=() array ─────────────────►│    Declared       │
       │    + shell restart                           │  (loaded, perm)   │
       │                                              └─────┬─────────────┘
       │                                                    │
       │                                                    │ Remove from
       │                                                    │ plugins=()
       │                                                    │ + zap sync
       │                                                    ▼
       └────────────────────────────────────────────► ┌──────────────┐
                                                       │  Undeclared  │
                                                       └──────────────┘
```

### Reconciliation Flow

```
User runs: zap sync
       │
       ▼
┌────────────────────────────────────────┐
│ 1. Parse declared state from .zshrc   │
│    plugins=() array                    │
└────────┬───────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────┐
│ 2. Read current state from metadata   │
│    $ZAP_DATA_DIR/state.zsh             │
└────────┬───────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────┐
│ 3. Calculate drift                     │
│    to_install = desired - current      │
│    to_remove = current - desired       │
└────────┬───────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────┐
│ 4. Preview changes                     │
│    Show +/- summary to user            │
└────────┬───────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────┐
│ 5. Apply reconciliation                │
│    For v1: exec zsh (full reload)      │
│    For v2: incremental load/unload     │
└────────┬───────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────┐
│ 6. Update state metadata               │
│    Write new state.zsh                 │
└────────┬───────────────────────────────┘
         │
         ▼
     Success
```

---

## Storage Locations

### User Configuration
- **File**: `~/.zshrc`
- **Content**: `plugins=()` array with Plugin Specifications
- **Ownership**: User (manually edited or via `zap adopt`)
- **Format**: Zsh array syntax

### State Metadata
- **File**: `$ZAP_DATA_DIR/state.zsh` (typically `~/.local/share/zap/state.zsh`)
- **Content**: Associative array mapping plugin name → state metadata
- **Ownership**: Zap (auto-generated, atomic updates)
- **Format**: Zsh associative array (sourceable)

### Plugin Installation
- **Directory**: `$ZAP_DATA_DIR/plugins/` (typically `~/.local/share/zap/plugins/`)
- **Structure**: `owner--repo/` (double dash separator)
- **Ownership**: Zap (managed via git clone/pull)
- **Persistence**: Permanent (cleaned via `zap clean`)

---

## Validation Rules

### Plugin Specification Validation
- ✅ Valid: `zsh-users/zsh-syntax-highlighting`
- ✅ Valid: `ohmyzsh/ohmyzsh@master:plugins/git`
- ✅ Valid: `romkatv/powerlevel10k@v1.19.0`
- ❌ Invalid: `../evil/path` (path traversal)
- ❌ Invalid: `/absolute/path` (absolute path)
- ❌ Invalid: `no-slash-separator` (missing owner/repo)
- ❌ Invalid: `owner/repo; rm -rf /` (command injection)

### Array Parsing Validation
- ✅ Valid: `plugins=('foo' 'bar')`
- ✅ Valid: `plugins=( 'foo' 'bar' )` (extra whitespace)
- ✅ Valid multiline:
  ```zsh
  plugins=(
    'foo'
    'bar'
  )
  ```
- ❌ Invalid: `plugins=($EVIL_VAR)` (variable expansion - security risk)
- ❌ Invalid: `plugins=($(command))` (command substitution - security risk)

### State Metadata Validation
- Each entry MUST have exactly 6 pipe-delimited fields
- Timestamp MUST be valid epoch time
- State MUST be one of: `declared`, `experimental`
- Source MUST be one of: `array`, `try_command`, `legacy_load`
- Install path MUST exist on disk

---

## Performance Considerations

### Startup Time
- Parsing plugins array: < 10ms for 20 plugins
- Loading state metadata: < 5ms (sourceable Zsh file)
- Total declarative overhead: < 20ms (SC-002: within 5% of imperative)

### Reconciliation Time
- Drift calculation: < 50ms for 20 plugins
- Preview generation: < 50ms
- Full reload (exec zsh): ~200-500ms (acceptable for v1)
- Total `zap sync`: < 2 seconds (SC-003)

### State Queries
- `zap status`: < 100ms (SC-005)
- `zap diff`: < 200ms

### Memory Overhead
- State metadata: ~1KB per plugin
- Total for 100 plugins: ~100KB (well under 1MB budget)

---

## Security Model

### Threat Model
- **Attacker Goal**: Inject malicious code via plugins array
- **Attack Vectors**:
  1. Command injection in plugin spec (`owner/repo; evil-command`)
  2. Path traversal in subdir (`owner/repo:../../evil`)
  3. Code execution during parsing (`plugins=($(malicious))`)

### Mitigations
- **Input Validation**: Strict regex on all plugin specs (FR-027)
- **Text-Based Parsing**: Never source .zshrc during array extraction
- **No Code Execution**: Use `(z)` and `(Q)` flags, not eval
- **Atomic Operations**: Temp file + mv for config modifications
- **Principle of Least Privilege**: Zap runs with user permissions (no sudo)

### Trust Boundaries
- **Trusted**: User's .zshrc (user controls file, can run arbitrary code anyway)
- **Untrusted**: Plugin specifications (validated before use)
- **Untrusted**: Network data (git clone, downloads)

---

## Backward Compatibility

### Migration Path (FR-020)
Support both declarative and imperative modes simultaneously:

```zsh
# Old imperative style (still works)
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions

# New declarative style
plugins=(
  'zsh-users/zsh-syntax-highlighting'
  'zsh-users/zsh-autosuggestions'
)
```

State tracking distinguishes source:
- `source: array` → Declared
- `source: legacy_load` → Imperative (treated as experimental for reconciliation)

### Deprecation Strategy
- v1.x: Both modes supported, deprecation warning on `zap load`
- v2.x: Declarative-only, `zap load` removed

---

## Edge Cases

### Missing Config Array
**Scenario**: User has no `plugins=()` array in .zshrc

**Behavior**:
- `zap sync`: No-op (nothing declared, nothing to sync)
- `zap status`: Shows experimental plugins only
- `zap adopt`: Creates plugins array at end of .zshrc

### Empty Config Array
**Scenario**: `plugins=()`

**Behavior**:
- All plugins are removed on `zap sync`
- Shell remains functional (no plugins loaded)

### Config Modified While Shell Running
**Scenario**: User edits .zshrc in another window, adds plugin

**Behavior**:
- No immediate effect (runtime state unchanged)
- `zap sync` picks up new config and installs plugin
- `zap status` shows drift

### Git Merge Conflict in Array
**Scenario**: Multi-machine sync creates conflict in `plugins=()`

**Behavior**:
- Standard git conflict resolution
- User manually resolves array
- Run `zap sync` after resolution

### Plugin Load Failure
**Scenario**: Plugin repo doesn't exist (404)

**Behavior** (FR-018):
- Log error to `$ZAP_ERROR_LOG`
- Show warning at shell startup
- Continue loading other plugins
- `zap status` marks plugin as failed

### Read-Only .zshrc
**Scenario**: User runs `zap adopt` but .zshrc is immutable

**Behavior**:
- Detect write failure
- Show clear error: "Cannot modify .zshrc: Permission denied"
- Suggest manual addition or fix permissions

---

## Testing Strategy

### Contract Tests
- Plugin specification parsing (valid/invalid formats)
- State metadata serialization/deserialization
- Config array extraction (various formats)
- Validation rules (security checks)

### Integration Tests
- Full workflow: declare → load → sync → adopt
- Multi-machine sync (git clone → sync)
- Edge cases (empty array, missing config, conflicts)
- Error handling (network failures, missing repos)

### Property-Based Tests
- Idempotency: `sync(); sync(); sync()` → same result
- Reversibility: Add plugin → remove plugin → state unchanged
- Atomicity: Interrupted sync → no partial state

---

## Future Extensions

### Planned for v2
- **Incremental Reconciliation**: Unload plugins without full reload
- **Performance Tracking**: `zap status --perf` shows load time per plugin
- **Conditional Loading**: `[[ $HOST == ... ]] && plugins+=('...')`
- **Plugin Groups**: `groups=(dev-tools testing)` with named collections

### Not Planned
- Remote config fetching (violates single source of truth)
- Automatic sync on config change (event-driven adds complexity)
- Plugin dependencies (scope creep, use frameworks for this)
