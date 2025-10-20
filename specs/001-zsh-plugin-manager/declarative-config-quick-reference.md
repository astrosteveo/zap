# Declarative Configuration Quick Reference

**Source**: [declarative-config-research.md](./declarative-config-research.md)
**Date**: 2025-10-18

## TL;DR - Core Patterns

### 1. Desired vs. Current State
```
User Config → Reconciliation → Runtime State
(desired)         (loop)         (current)
```

All declarative systems maintain this separation and continuously reconcile.

### 2. Idempotent Reconciliation
```zsh
# Pattern: Check-then-act
if [[ ! -d "$plugin_dir" ]]; then
  git clone "$url" "$plugin_dir"  # Only if needed
fi

# Not: Always act
git clone "$url" "$plugin_dir"  # Fails if exists
```

### 3. Level-Based Reconciliation Loop
```zsh
while true; do
  desired=$(parse_config)
  current=$(query_state)
  diff=$(compare $desired $current)

  if [[ -n $diff ]]; then
    reconcile $diff
  fi

  sleep $interval
done
```

### 4. Three-Way Merge (kubectl style)
```
Compare:
  1. Last applied (what was in config)
  2. Current live (what's running now)
  3. New desired (what's in config now)

Merge:
  - New fields → add
  - Removed fields → delete (if unchanged)
  - Changed fields → use new value (unless manually modified)
```

### 5. Preview Mode
```zsh
zap plan() {
  # Calculate changes WITHOUT applying
  to_install=(${desired:|current})
  to_remove=(${current:|desired})
  to_update=(${needs_update})

  # Show human-readable diff
  print "Would install: $to_install"
  print "Would remove: $to_remove"
  print "Would update: $to_update"
}
```

## Quick Implementation Checklist for Zap

### Essential (MVP)
- [ ] Parse config file → desired state
- [ ] Query installed plugins → current state
- [ ] Calculate diff (to_install, to_remove, to_update)
- [ ] Implement `zap sync` (reconcile)
- [ ] Track metadata separately from config
- [ ] Atomic metadata writes (tmp file + mv)
- [ ] Idempotent operations (check before act)

### Important (Phase 2)
- [ ] Implement `zap plan` (preview)
- [ ] Implement `zap status` (drift detection)
- [ ] Track last_update_check per plugin
- [ ] Stagger update checks (don't check all at once)
- [ ] Graceful error handling (warn, don't fail)

### Nice-to-Have (Phase 3+)
- [ ] Rollback to previous plugin set
- [ ] Lock file for reproducible builds
- [ ] Dependency resolution
- [ ] Async update checks
- [ ] Three-way merge for manual changes

## Zsh-Specific Implementation Patterns

### Atomic Metadata Updates
```zsh
# WRONG: Direct write (can be interrupted)
print "data" > metadata.zsh

# RIGHT: Atomic write
print "data" > metadata.zsh.tmp
mv -f metadata.zsh.tmp metadata.zsh  # Atomic on POSIX
```

### Fast State Checks
```zsh
# Cheap: File modification time check
if [[ ~/.zap/plugins.zsh -nt ~/.local/share/zap/metadata.zsh ]]; then
  warn "Config changed, run: zap sync"
fi

# Expensive: Full reconciliation
zap sync  # Only when user explicitly requests
```

### Idempotent Path Management
```zsh
# WRONG: Duplicates on re-source
export PATH="$HOME/bin:$PATH"

# RIGHT: Unique array
typeset -gU path  # Mark as unique
path=($HOME/bin $path)  # Auto-deduplicates
```

### Set Operations for Diff
```zsh
desired=(plugin1 plugin2 plugin3)
current=(plugin1 plugin4)

to_install=(${desired:|current})  # plugin2 plugin3
to_remove=(${current:|desired})   # plugin4
both=(${desired:*current})        # plugin1 (intersection)
```

## Metadata Schema

```zsh
# ~/.local/share/zap/metadata.zsh
typeset -gA _ZAP_META

_ZAP_META[$plugin:desired_version]="v1.2.3"
_ZAP_META[$plugin:current_commit]="abc123"
_ZAP_META[$plugin:last_check]=1729267200
_ZAP_META[$plugin:status]="installed"
_ZAP_META[$plugin:install_time]=1729180800
```

## Command Reference

| Command | Purpose | When to Run |
|---------|---------|-------------|
| `zap sync` | Reconcile config → state | After editing config |
| `zap plan` | Preview changes | Before syncing |
| `zap status` | Check drift | Periodically |
| `zap update` | Check for updates | Weekly/on-demand |
| `zap list` | Show installed | Informational |

## Key Design Decisions

### ✅ Do
- Separate config (plugins.zsh) from state (metadata.zsh)
- Make all operations idempotent
- Provide preview mode before changes
- Use atomic file operations
- Optimize for "no changes" path
- Track metadata for drift detection

### ❌ Don't
- Mix imperative and declarative commands
- Block shell startup on network operations
- Write partial/corrupted state files
- Assume config == state (drift happens)
- Perform expensive checks on every startup
- Let errors break the shell

## Performance Guidelines

| Operation | Target | Strategy |
|-----------|--------|----------|
| Shell startup | <100ms overhead | Cache metadata, lazy reconciliation |
| Config parse | <10ms | Simple line-based format |
| Drift check | <50ms | File mtime comparison |
| Full reconciliation | <5s for 10 plugins | Parallel git operations |
| Update check | <1s per plugin | Stagger, cache results |

## Testing Checklist

```zsh
# Idempotency test
zap sync
state1=$(zap list)
zap sync
state2=$(zap list)
[[ $state1 == $state2 ]]  # Must be identical

# Drift detection test
git clone $url ~/.local/share/zap/plugins/user__plugin
zap status  # Should warn

# Reconciliation test
echo "new/plugin" >> ~/.zap/plugins.zsh
zap sync
[[ -d ~/.local/share/zap/plugins/new__plugin ]]  # Must exist

# Preview test
before=$(zap list)
zap plan
after=$(zap list)
[[ $before == $after ]]  # Must not change state
```

## Common Pitfalls

### 1. Non-Idempotent Operations
```zsh
# BAD
export PATH="$plugin_bin:$PATH"  # Adds duplicate on re-run

# GOOD
path=($plugin_bin $path)
typeset -U path
```

### 2. Non-Atomic State Updates
```zsh
# BAD
echo "new_data" > state.zsh  # Interrupted = corrupted file

# GOOD
echo "new_data" > state.zsh.tmp
mv state.zsh.tmp state.zsh  # Atomic
```

### 3. Blocking Shell Startup
```zsh
# BAD
zap sync  # Runs git operations on every shell start

# GOOD
if [[ config -nt metadata ]]; then
  warn "Run 'zap sync' to apply config changes"
fi
```

### 4. Ignoring Drift
```zsh
# BAD: Assume config == reality
plugins=$(cat plugins.zsh)
load $plugins

# GOOD: Reconcile periodically
zap status  # Shows drift
zap sync    # Fixes drift
```

## Real-World Examples

### NixOS Generation Switching
```bash
nixos-rebuild switch
# 1. Builds new generation
# 2. Atomically updates symlink
# 3. Instant rollback: --rollback flag
```

### Terraform Plan/Apply
```bash
terraform plan   # Preview
terraform apply  # Execute after review
```

### Kubernetes Reconciliation
```go
func Reconcile(req Request) (Result, error) {
  desired := getDesiredState(req)
  current := getCurrentState(req)

  if !equal(desired, current) {
    reconcile(desired, current)
  }

  return Result{}, nil
}
```

### Docker Compose Smart Reconciliation
```bash
docker-compose up -d
# Only recreates containers whose config changed
# Preserves containers with unchanged config
```

## References

- Full research: [declarative-config-research.md](./declarative-config-research.md)
- Existing Zap research: [research.md](./research.md)
- Spec: [spec.md](./spec.md)
- Implementation plan: [plan.md](./plan.md)

---

**When in doubt**: Check if operation is idempotent, preview before applying, and reconcile rather than execute.
