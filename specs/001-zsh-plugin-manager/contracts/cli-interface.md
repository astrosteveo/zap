# CLI Interface Contract: Zsh Plugin Manager

**Feature**: 001-zsh-plugin-manager
**Date**: 2025-10-17
**Phase**: 1 (Design & Contracts)

## Overview

This document specifies the command-line interface for the Zsh Plugin Manager (zap). All commands follow Unix conventions and provide consistent, user-friendly output.

## Installation

### Command: `install.zsh`

**Purpose**: Install zap plugin manager

**Usage**:
```bash
curl -sL https://raw.githubusercontent.com/user/zap/main/install.zsh | zsh
```

**Behavior**:
1. Clone zap repository to `~/.zap/`
2. Add initialization line to `~/.zshrc`
3. Create `~/.local/share/zap/` data directory
4. Display quickstart instructions

**Output**:
```
✓ Cloning zap to ~/.zap
✓ Adding initialization to ~/.zshrc
✓ Creating data directory
✓ Installation complete!

Next steps:
  1. Restart your shell or run: source ~/.zshrc
  2. Add plugins to ~/.zshrc:
     zap load zsh-users/zsh-syntax-highlighting
  3. Run 'zap help' for more commands
```

**Exit Codes**:
- `0`: Success
- `1`: General error (network, permissions, etc.)
- `2`: Already installed (warn and exit)

## Core Commands

All commands are invoked as Zsh functions after sourcing `zap.zsh`.

### Command: `zap load`

**Purpose**: Load a plugin (used in .zshrc)

**Usage**:
```zsh
zap load <owner>/<repo>[@<version>] [path:<subdirectory>]
```

**Examples**:
```zsh
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions@v0.7.0
zap load ohmyzsh/ohmyzsh path:plugins/git
```

**Behavior**:
1. Parse plugin specification
2. Check if plugin cached
3. If not cached, clone repository
4. Checkout specified version (if provided)
5. Source plugin files
6. Handle errors gracefully (warn, continue)

**Output** (on first load):
```
⬇ Downloading zsh-users/zsh-syntax-highlighting...
✓ Loaded zsh-users/zsh-syntax-highlighting
```

**Output** (subsequent loads):
```
(silent - no output on success)
```

**Output** (on error):
```
⚠ Failed to load user/nonexistent: Repository not found
  Check repository name and network connection
  Shell will continue without this plugin
```

**Exit Codes**: None (function, not command)

### Command: `zap update`

**Purpose**: Update plugins to latest versions

**Usage**:
```zsh
zap update [<owner>/<repo>]
```

**Examples**:
```zsh
zap update                           # Update all plugins
zap update zsh-users/zsh-syntax-highlighting  # Update specific plugin
```

**Behavior**:
1. If no argument, check all plugins for updates
2. For each plugin:
   - Run `git fetch origin`
   - Compare local commit with remote HEAD
   - If different, pull updates
   - If version pinned, respect pin (skip update)
3. Display summary of updated plugins
4. Prompt to restart shell

**Output**:
```
Checking for updates...
  zsh-users/zsh-syntax-highlighting  current
  zsh-users/zsh-autosuggestions      v0.7.0 → v0.7.1
  ohmyzsh/ohmyzsh                    pinned (skipped)
  romkatv/powerlevel10k              current

Updated 1 plugin. Restart your shell to apply changes.
```

**Exit Codes**:
- `0`: Success (updates found or not)
- `1`: Error during update (network, git failure)

### Command: `zap list`

**Purpose**: List installed plugins and their status

**Usage**:
```zsh
zap list [--verbose]
```

**Behavior**:
1. Read metadata.zsh
2. Display plugin name, version, status
3. With `--verbose`, show commit SHA, last check time

**Output**:
```
Installed plugins:
  zsh-users/zsh-syntax-highlighting  master   ✓ loaded
  zsh-users/zsh-autosuggestions      v0.7.0   ✓ loaded
  ohmyzsh/ohmyzsh                    master   ✓ loaded (framework)
  romkatv/powerlevel10k              v1.16.1  ✓ loaded

Total: 4 plugins
```

**Output** (verbose):
```
Installed plugins:
  zsh-users/zsh-syntax-highlighting
    Version:  master
    Commit:   a0b12c3d4e5f6789...
    Status:   ✓ loaded
    Checked:  2025-10-17 14:30 (2 hours ago)
  ...
```

**Exit Codes**:
- `0`: Success

### Command: `zap clean`

**Purpose**: Clean plugin cache and temporary files

**Usage**:
```zsh
zap clean [--all]
```

**Behavior**:
1. Without `--all`: Remove load order cache, error log
2. With `--all`: Also remove downloaded plugins (requires confirmation)
3. Preserve metadata.zsh (unless `--all`)

**Output**:
```
Cleaning cache...
  ✓ Removed load order cache
  ✓ Removed error log
Done.
```

**Output** (with --all):
```
This will remove all downloaded plugins. Continue? [y/N] y
Cleaning all data...
  ✓ Removed load order cache
  ✓ Removed error log
  ✓ Removed plugin cache (4 plugins)
  ✓ Removed metadata
Done. Plugins will be re-downloaded on next shell startup.
```

**Exit Codes**:
- `0`: Success
- `1`: User cancelled
- `2`: Error during cleanup

### Command: `zap doctor`

**Purpose**: Diagnose plugin manager issues

**Usage**:
```zsh
zap doctor
```

**Behavior**:
1. Check Zsh version (>= 5.0)
2. Check Git availability and version
3. Verify cache directory permissions
4. Check for plugin load errors
5. Validate configuration syntax
6. Report findings with actionable suggestions

**Output**:
```
Running diagnostics...

✓ Zsh version: 5.8 (OK)
✓ Git version: 2.39.0 (OK)
✓ Cache directory: ~/.local/share/zap (OK, writable)
⚠ Plugin errors found: 1

Issues:
  1. Plugin 'user/typo' failed to load
     Error: Repository not found
     Fix: Check plugin name in ~/.zshrc

  2. Slow startup detected (2.3s with 10 plugins)
     Suggestion: Consider lazy loading or reducing plugins

Run 'zap help' for more information.
```

**Exit Codes**:
- `0`: No issues found
- `1`: Issues found (non-fatal)
- `2`: Critical issues (zsh/git missing)

### Command: `zap help`

**Purpose**: Display help information

**Usage**:
```zsh
zap help [<command>]
```

**Behavior**:
1. Without argument, show general help
2. With command name, show detailed help for that command

**Output** (general):
```
Zap - Lightweight Zsh Plugin Manager

Usage:
  zap load <owner>/<repo>[@<version>] [path:<subdir>]
  zap update [<plugin>]
  zap list [--verbose]
  zap clean [--all]
  zap doctor
  zap help [<command>]

Examples:
  zap load zsh-users/zsh-syntax-highlighting
  zap load ohmyzsh/ohmyzsh@master path:plugins/git
  zap update
  zap list

For more help: zap help <command>
Documentation: https://github.com/user/zap
```

**Exit Codes**:
- `0`: Success

## Function API (Internal)

These functions are used internally by zap commands. Not intended for direct user invocation.

### Function: `_zap_parse_spec`

**Signature**:
```zsh
_zap_parse_spec <spec_string>
```

**Returns** (via stdout):
```
owner repo version subdirectory
```

**Example**:
```zsh
_zap_parse_spec "ohmyzsh/ohmyzsh@master path:plugins/git"
# Output: ohmyzsh ohmyzsh master plugins/git
```

### Function: `_zap_clone_plugin`

**Signature**:
```zsh
_zap_clone_plugin <owner> <repo> <version>
```

**Returns**: Exit code 0 on success, 1 on failure

### Function: `_zap_source_plugin`

**Signature**:
```zsh
_zap_source_plugin <cache_path> <subdirectory>
```

**Returns**: Exit code 0 on success, 1 on failure

## Error Messages

All error messages follow this format:
```
⚠ <What failed>: <Why it failed>
  <Actionable resolution step>
  <Optional: Additional context>
```

**Examples**:
```
⚠ Failed to clone plugin 'user/repo': Repository not found
  Check repository name and network connection

⚠ Invalid version pin 'v99.99.99': Tag does not exist
  Falling back to latest version

⚠ Disk space low: 50MB remaining
  Plugin downloads may fail. Free up space and retry
```

## Output Formatting

**Colors**:
- Green `✓`: Success
- Yellow `⚠`: Warning
- Red `✗`: Error
- Blue `⬇`: Download in progress
- Gray: Informational text

**Symbols**:
- `✓`: Success/OK
- `⚠`: Warning
- `✗`: Error/Failed
- `⬇`: Downloading
- `→`: Version change (old → new)

**Progress Indicators**:
- Downloads: `⬇ Downloading user/repo...` (no spinner, simple message)
- Updates: `Checking for updates...` followed by line-per-plugin summary

## Environment Variables

**User-Configurable**:
- `ZAP_DIR`: Installation directory (default: `~/.zap`)
- `ZAP_DATA_DIR`: Cache/data directory (default: `~/.local/share/zap`)
- `ZAP_QUIET`: Suppress non-error output (`export ZAP_QUIET=1`)

**Internal** (set by zap):
- `ZAP_PLUGIN_DIR`: `$ZAP_DATA_DIR/plugins`
- `ZAP_VERSION`: zap version string (e.g., `1.0.0`)

## Configuration File Format

Users can choose between inline or file-based configuration.

**Inline** (in ~/.zshrc):
```zsh
source ~/.zap/zap.zsh

zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions@v0.7.0
zap load ohmyzsh/ohmyzsh path:plugins/git
```

**File-based** (in ~/.zap/plugins.zsh):
```zsh
# ~/.zshrc
source ~/.zap/zap.zsh
zap init ~/.zap/plugins.zsh

# ~/.zap/plugins.zsh
zsh-users/zsh-syntax-highlighting
zsh-users/zsh-autosuggestions@v0.7.0
ohmyzsh/ohmyzsh path:plugins/git
```

Both formats achieve the same result. File-based is cleaner for many plugins.

## Performance Contracts

**Startup Time**:
- Initialization: < 50ms overhead
- Load 10 plugins: < 1 second total
- Load 25 plugins: < 2 seconds total

**Update Checking**:
- 10 plugins: < 5 seconds
- Network timeout: 10 seconds per plugin

**Memory Usage**:
- Zap overhead: < 10MB RSS
- Per plugin: ~1MB (varies by plugin size)

## Compatibility

**Zsh Versions**:
- Minimum: 5.0
- Tested: 5.0, 5.8, 5.9
- Target: Latest stable

**Platforms**:
- Linux (all distributions)
- macOS (10.15+)
- BSD (FreeBSD, OpenBSD)

**Git Versions**:
- Minimum: 2.0
- Tested: 2.0, 2.30, 2.39
- Features used: clone, fetch, checkout, log

## Future API Extensions

**Planned** (not in MVP):
- `zap search <query>`: Search for plugins
- `zap info <plugin>`: Show plugin details
- `zap disable <plugin>`: Temporarily disable plugin
- `zap enable <plugin>`: Re-enable disabled plugin
- `zap benchmark`: Measure startup performance

These commands are reserved for future versions and should not be implemented in MVP.
