# Data Model: Zsh Plugin Manager

**Feature**: 001-zsh-plugin-manager
**Date**: 2025-10-17
**Phase**: 1 (Design & Contracts)

## Overview

This document defines the data structures, file formats, and state management for the Zsh Plugin Manager (zap).

## Core Entities

### 1. Plugin Specification

**Purpose**: Represents a user's declaration of a desired plugin

**Format**: Plain text line in configuration file

**Structure**:
```
<owner>/<repo>[@<version>] [path:<subdirectory>]
```

**Fields**:
- `owner` (string, required): GitHub username or organization
- `repo` (string, required): Repository name
- `version` (string, optional): Git tag, commit hash, or branch name
  - Default: `main` or `master` (detect default branch)
  - Examples: `@v1.2.3`, `@abc123def`, `@develop`
- `subdirectory` (string, optional): Path within repo to treat as plugin root
  - Specified as `path:plugins/git`
  - Default: repository root

**Examples**:
```zsh
zsh-users/zsh-syntax-highlighting
zsh-users/zsh-autosuggestions@v0.7.0
ohmyzsh/ohmyzsh path:plugins/git
romkatv/powerlevel10k@v1.16.1
```

**Validation Rules**:
- Owner/repo must not contain spaces or special chars except `-_`
- Version must be valid Git ref (checked during fetch)
- Subdirectory path must be relative (no leading `/`)
- Lines starting with `#` are comments
- Empty lines ignored

**State Transitions**:
```
[declared] → [downloading] → [cached] → [loaded]
                ↓               ↓          ↓
           [download_failed] [outdated] [load_failed]
```

### 2. Plugin Cache Entry

**Purpose**: Represents a downloaded/installed plugin on disk

**Location**: `~/.local/share/zap/plugins/<owner>__<repo>/`

**Structure**:
```
~/.local/share/zap/plugins/zsh-users__zsh-syntax-highlighting/
├── .git/                  # Git repository metadata
├── zsh-syntax-highlighting.plugin.zsh
├── zsh-syntax-highlighting.zsh
└── [other plugin files]
```

**Metadata** (stored in `~/.local/share/zap/metadata.zsh`):
```zsh
# Format: associative array
typeset -gA ZAP_PLUGIN_META

ZAP_PLUGIN_META=(
  "zsh-users/zsh-syntax-highlighting:version" "master"
  "zsh-users/zsh-syntax-highlighting:commit" "a0b12c3d4e5f"
  "zsh-users/zsh-syntax-highlighting:last_check" "2025-10-17T14:30:00Z"
  "zsh-users/zsh-syntax-highlighting:status" "loaded"
)
```

**Fields**:
- `version`: Current checkout ref (tag/branch/commit)
- `commit`: Full commit SHA for version tracking
- `last_check`: ISO 8601 timestamp of last update check
- `status`: `loaded` | `failed` | `disabled` | `outdated`

**Validation Rules**:
- Directory name uses double underscore (`__`) separator
- Must contain `.git` directory (validate it's a git repo)
- Commit SHA must be 40-character hex string

### 3. Load Order Cache

**Purpose**: Avoid reparsing configuration on every shell startup

**Location**: `~/.local/share/zap/load-order.cache`

**Format**: Zsh array serialization

**Structure**:
```zsh
# Generated cache - DO NOT EDIT MANUALLY
# Config hash: a1b2c3d4e5f6
# Generated: 2025-10-17T14:30:00Z

typeset -ga ZAP_LOAD_ORDER
ZAP_LOAD_ORDER=(
  "zsh-users/zsh-syntax-highlighting:::"
  "zsh-users/zsh-autosuggestions:v0.7.0::"
  "ohmyzsh/ohmyzsh:master:plugins/git:"
)
```

**Format**: `<owner>/<repo>:<version>:<subdirectory>:<flags>`

**Fields**:
- `owner/repo`: Plugin identifier
- `version`: Pinned version or empty for latest
- `subdirectory`: Subdirectory path or empty for root
- `flags`: Reserved for future use (lazy load, etc.)

**Invalidation Rules**:
- Regenerate if config file modified (check mtime)
- Regenerate if cache format version changes
- Regenerate if config hash mismatch

### 4. Framework Detection

**Purpose**: Identify and configure Oh-My-Zsh or Prezto plugins

**Detection Logic**:
```zsh
# Oh-My-Zsh
if [[ "$repo" == "ohmyzsh" && "$owner" == "ohmyzsh" ]]; then
  framework="oh-my-zsh"
  base_path="$ZAP_PLUGIN_DIR/ohmyzsh__ohmyzsh"
fi

# Prezto
if [[ "$repo" == "prezto" && "$owner" == "sorin-ionescu" ]]; then
  framework="prezto"
  base_path="$ZAP_PLUGIN_DIR/sorin-ionescu__prezto"
fi
```

**Environment Setup**:

**Oh-My-Zsh**:
```zsh
export ZSH="$ZAP_PLUGIN_DIR/ohmyzsh__ohmyzsh"
export ZSH_CACHE_DIR="$ZAP_DATA_DIR/oh-my-zsh-cache"
export ZSH_CUSTOM="$ZAP_DATA_DIR/oh-my-zsh-custom"
```

**Prezto**:
```zsh
export ZDOTDIR="${ZDOTDIR:-$HOME}"
export PREZTO="$ZAP_PLUGIN_DIR/sorin-ionescu__prezto"
fpath=("$PREZTO/modules/*/functions" $fpath)
```

### 5. Error Log Entry

**Purpose**: Record plugin loading failures for debugging

**Location**: `~/.local/share/zap/errors.log`

**Format**: Timestamped log entries

**Structure**:
```
[2025-10-17T14:30:15Z] ERROR: Failed to clone plugin 'user/nonexistent'
  Reason: Repository not found (HTTP 404)
  Action: Check repository name and network connection

[2025-10-17T14:30:20Z] WARN: Invalid version pin 'user/repo@v99.99.99'
  Reason: Tag 'v99.99.99' does not exist
  Action: Falling back to latest version (main)
```

**Fields**:
- Timestamp: ISO 8601 format
- Level: `ERROR` | `WARN` | `INFO`
- Plugin: Fully qualified name (`owner/repo`)
- Reason: Technical explanation
- Action: User-facing resolution steps

**Retention**: Keep last 100 entries, rotate when exceeded

## File System Layout

```
~/.local/share/zap/                    # XDG_DATA_HOME/zap
├── plugins/                           # Cloned plugin repositories
│   ├── zsh-users__zsh-syntax-highlighting/
│   ├── zsh-users__zsh-autosuggestions/
│   ├── ohmyzsh__ohmyzsh/
│   └── romkatv__powerlevel10k/
├── metadata.zsh                       # Plugin metadata (versions, timestamps)
├── load-order.cache                   # Cached parsed configuration
├── errors.log                         # Error log (last 100 entries)
└── oh-my-zsh-cache/                   # Oh-My-Zsh cache directory
    └── [omz cache files]
```

## Configuration File

**Location**: Embedded in `~/.zshrc` or separate `~/.zap/plugins.zsh`

**Format**:
```zsh
# Zap plugin configuration
# Format: owner/repo[@version] [path:subdirectory]

# Syntax highlighting
zsh-users/zsh-syntax-highlighting

# Autosuggestions with version pin
zsh-users/zsh-autosuggestions@v0.7.0

# Oh-My-Zsh plugin (framework auto-detected)
ohmyzsh/ohmyzsh path:plugins/git
ohmyzsh/ohmyzsh path:plugins/kubectl

# Theme with version pin
romkatv/powerlevel10k@v1.16.1

# Disabled plugin (commented out)
# user/disabled-plugin
```

**Loading**: Configuration sourced via zap function calls in `.zshrc`:
```zsh
# In ~/.zshrc
source ~/zap/zap.zsh  # Initialize zap

# Declare plugins
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions@v0.7.0
zap load ohmyzsh/ohmyzsh path:plugins/git
```

OR configuration file approach:
```zsh
# In ~/.zshrc
source ~/zap/zap.zsh
zap init ~/.zap/plugins.zsh  # Load config from file
```

## Data Relationships

```
┌─────────────────────┐
│  Plugin Spec        │
│  (User Config)      │
└──────────┬──────────┘
           │ declares
           ↓
┌─────────────────────┐      ┌──────────────────┐
│  Cache Entry        │←────→│  Metadata        │
│  (Filesystem)       │syncs │  (metadata.zsh)  │
└──────────┬──────────┘      └──────────────────┘
           │ generates
           ↓
┌─────────────────────┐
│  Load Order Cache   │
│  (load-order.cache) │
└─────────────────────┘
           │ referenced by
           ↓
┌─────────────────────┐
│  Runtime State      │
│  (Shell Session)    │
└─────────────────────┘
```

## State Management

### Plugin Lifecycle

1. **Declaration**: User adds plugin spec to config
2. **Parsing**: zap parses config, validates syntax
3. **Download**: If not cached, git clone repository
4. **Checkout**: If version specified, checkout ref
5. **Cache**: Store metadata (version, commit, timestamp)
6. **Load**: Source plugin files into shell
7. **Monitor**: Track load status, log errors

### Cache Invalidation

**Triggers**:
- Config file modified (mtime changed)
- Manual cache clear (`zap clean`)
- Cache format version mismatch
- Corrupted cache file (parse error)

**Actions**:
- Delete `load-order.cache`
- Regenerate from config on next shell startup
- Preserve `plugins/` directory (don't re-download)

### Update Checking

**Process**:
1. For each cached plugin:
   - Run `git fetch origin --dry-run` (check for updates)
   - Compare local commit SHA with remote HEAD
   - Mark as `outdated` if mismatch
2. Display summary of outdated plugins
3. User decides whether to update (`zap update` command)

**Frequency**: Manual only (no automatic background checks)

## Performance Considerations

**Optimization Strategies**:
1. **Parse config once**: Cache load order, check mtime before reparse
2. **Lazy metadata**: Only load metadata.zsh when needed (update checking)
3. **Batch git operations**: Clone multiple plugins in parallel during install
4. **Minimize disk I/O**: Use in-memory arrays during load, write only on change
5. **Avoid subshells**: Use Zsh builtins for string operations

**Memory Footprint**:
- metadata.zsh: ~1KB per plugin (50 plugins = 50KB)
- load-order.cache: ~100 bytes per plugin (50 plugins = 5KB)
- Runtime arrays: ~10KB total
- Target: < 100KB memory overhead

## Security Considerations

**Threat Model**:
- **Malicious plugins**: Users responsible for vetting (out of scope)
- **Supply chain attacks**: Version pinning mitigates
- **Path traversal**: Validate subdirectory paths (no `..`)
- **Command injection**: Sanitize user input (repo names, versions)

**Mitigations**:
- Validate all input against regex patterns
- Use `--` separator in git commands to prevent flag injection
- Never eval user-provided strings
- Warn on HTTP clones (prefer HTTPS/SSH)

## Future Extensions

**Potential Additions** (not in MVP):
- Plugin dependency declarations (`.zap-deps` file)
- Lazy loading based on command triggers
- Binary release downloads (GitHub releases)
- Plugin search/discovery command
- Automatic update scheduling
- Parallel plugin loading (requires careful ordering)
