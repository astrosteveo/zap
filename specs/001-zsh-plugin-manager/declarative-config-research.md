# Research: Declarative Configuration Systems

**Feature**: 001-zsh-plugin-manager
**Date**: 2025-10-18
**Research Focus**: Best practices from NixOS, Docker Compose, Kubernetes, and Terraform

## Executive Summary

This research examines declarative configuration systems used in production infrastructure tools to extract patterns applicable to Zap's plugin management. The core insight: successful declarative systems separate **desired state** (config files) from **runtime state** (actual system), use **reconciliation loops** to detect drift, and provide **preview modes** before applying changes.

## 1. Core Patterns Across All Systems

### 1.1 Desired State vs. Current State

All examined systems maintain a clear separation between:

- **Desired State**: What the user declares in configuration files
- **Current State**: What actually exists in the runtime environment
- **Last Applied State**: What the system last successfully applied (used for three-way merge)

**Key Insight**: The system's job is to continuously reconcile current state toward desired state, not to execute imperative commands.

```
User Config → Reconciliation Engine → Runtime State
     ↑                 ↓                      ↓
     |          Drift Detection          Feedback
     └────────────────┬──────────────────────┘
                      ↓
              Preview/Plan Mode
```

### 1.2 Idempotent Operations

**Definition**: Running the same operation multiple times produces the same result as running it once.

**Implementation Patterns**:

1. **Check-then-act**: Query current state before making changes
2. **Upsert operations**: Update if exists, create if not
3. **Unique identifiers**: Track resources by stable IDs
4. **Transaction logs**: Record operations to detect duplicates

**Example from Terraform**:
```
1. Read current state from state file
2. Query actual infrastructure state (refresh)
3. Compare desired vs. actual
4. Generate minimal change set
5. Apply only necessary changes
6. Update state file
```

### 1.3 Reconciliation Loop Pattern

All systems use a variant of the "reconciliation loop" (also called "control loop"):

```
loop forever:
  1. Read desired state from config
  2. Query current state from system
  3. Calculate diff (desired - current)
  4. If diff is empty: sleep
  5. Else: execute actions to reconcile
  6. Update tracking metadata
  7. Log results
  8. Sleep/wait for next trigger
```

**Kubernetes Implementation**:
```go
func (r *Reconciler) Reconcile(ctx context.Context, req Request) (Result, error) {
    // 1. Fetch desired state
    desired := &CustomResource{}
    if err := r.Get(ctx, req.NamespacedName, desired); err != nil {
        return Result{}, err
    }

    // 2. Query current state
    current := r.queryActualState(desired)

    // 3. Compare and reconcile
    if !reflect.DeepEqual(desired.Spec, current) {
        if err := r.reconcileState(desired, current); err != nil {
            return Result{Requeue: true}, err
        }
    }

    // 4. Return (requeue if needed)
    return Result{}, nil
}
```

### 1.4 Atomic Transitions

**NixOS Approach**: Every system change creates a new "generation" with atomic symlink switching.

```zsh
# Old generation
/nix/var/nix/profiles/system -> system-42-link

# Build new generation
nixos-rebuild switch
  → Builds new derivation
  → Creates system-43-link
  → Atomically updates symlink

# New generation active
/nix/var/nix/profiles/system -> system-43-link

# Rollback is just another symlink update
nixos-rebuild switch --rollback
  → /nix/var/nix/profiles/system -> system-42-link
```

**Why it matters**: Changes are all-or-nothing. No partial states. Rollback is instant.

### 1.5 Preview/Plan Mode

All mature systems provide "dry-run" or "plan" modes to show changes before applying:

| System | Command | Description |
|--------|---------|-------------|
| Terraform | `terraform plan` | Shows resources to create/update/delete |
| Kubernetes | `kubectl diff` | Three-way diff against cluster |
| Docker Compose | `docker-compose config` | Validates and shows resolved config |
| NixOS | `nixos-rebuild dry-run` | Builds but doesn't activate new generation |

**Common Pattern**:
```
1. Parse config
2. Query current state
3. Calculate diff
4. Display human-readable changes
5. Wait for confirmation (or --auto-approve flag)
6. Execute changes
```

## 2. Reconciliation Approaches

### 2.1 Imperative vs. Declarative

**Imperative** (avoid):
```bash
# User gives commands
docker run -d nginx
docker stop nginx
docker rm nginx
```

**Declarative** (prefer):
```yaml
# User declares desired state
services:
  nginx:
    image: nginx:latest
    state: started  # or absent
```

The system determines what commands to run based on current vs. desired state.

### 2.2 Level-Based vs. Edge-Based

**Edge-Based** (event-driven):
- React to events (create, update, delete)
- Risk: May miss events during downtime
- Example: Traditional webhooks

**Level-Based** (state-driven):
- Periodically reconcile to desired state
- More robust to missed events
- Example: Kubernetes controllers

**Kubernetes uses level-based**:
```
Controller doesn't care HOW the state changed.
It only cares: "Does current state match desired state?"
If no → reconcile
If yes → done
```

### 2.3 Three-Way Merge (kubectl apply)

**Problem**: How to handle manual changes + config file changes simultaneously?

**Solution**: Track three versions:
1. **Last Applied**: What was in config file last time
2. **Current Live**: What's actually running
3. **New Desired**: What's in config file now

**Algorithm**:
```
For each field:
  if field in new but not in last-applied:
    → Add field (user added it to config)

  if field in last-applied but not in new:
    if field in current and unchanged:
      → Delete field (user removed from config)
    else:
      → Keep current value (manual change)

  if field in both:
    if current != last-applied:
      → Keep current (manual change wins)
    else:
      → Use new value (config change applies)
```

**Storage**: kubectl stores last-applied as annotation:
```yaml
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Pod",...}
```

### 2.4 Two-Way Merge (Terraform)

**Simpler approach**: Only track desired state and current state.

**Algorithm**:
```
terraform plan:
  1. Read desired state from .tf files
  2. Read current state from state file
  3. Refresh: Query actual infrastructure
  4. Diff: Compare desired vs. actual
  5. Generate execution plan

terraform apply:
  6. Execute plan
  7. Update state file with new state
```

**Trade-off**: Manual changes detected as drift, but no automatic merge. User must choose:
- Import manual changes to state
- Destroy manual changes and recreate from config

### 2.5 Drift Detection Strategies

**Continuous Monitoring** (Kubernetes):
- Controllers watch for events
- Reconcile on every change
- Pros: Instant response, self-healing
- Cons: Resource intensive

**Periodic Polling** (Terraform/Spacelift):
- Cron job runs `terraform plan`
- Detects drift every N hours
- Pros: Predictable resource usage
- Cons: Delayed detection

**On-Demand** (Manual):
- User runs `terraform plan` when concerned
- Detects drift only when invoked
- Pros: Zero overhead when not needed
- Cons: Drift may persist unnoticed

**Hybrid** (Recommended for Zap):
- Fast check on shell startup (cached metadata)
- Full reconciliation on `zap update`
- Background update checks (opt-in)

## 3. State Tracking Metadata

### 3.1 What to Track

All systems track similar metadata per managed resource:

| Metadata | Purpose | Example |
|----------|---------|---------|
| **Unique ID** | Identify resource across operations | Plugin path: `user/repo` |
| **Desired Version** | What user requested | `@v1.2.3`, `@main`, `@abc123` |
| **Current Version** | What's actually installed | Git commit SHA |
| **Last Update Check** | When we last checked remote | Unix timestamp |
| **Status** | Current state | `installed`, `pending`, `failed` |
| **Dependencies** | Load order, conflicts | Array of plugin IDs |
| **Source Location** | Where to fetch from | Git URL, tarball URL |
| **Checksum/Hash** | Verify integrity | SHA256 of plugin contents |
| **Metadata Updated** | When metadata changed | Timestamp |

### 3.2 Terraform State File Structure

```json
{
  "version": 4,
  "terraform_version": "1.5.0",
  "serial": 42,
  "lineage": "uuid-here",
  "resources": [
    {
      "type": "aws_instance",
      "name": "example",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 1,
          "attributes": {
            "id": "i-0abcd1234efgh5678",
            "ami": "ami-0c55b159cbfafe1f0",
            "instance_type": "t2.micro",
            "tags": {"Name": "example"}
          },
          "dependencies": ["aws_security_group.example"]
        }
      ]
    }
  ]
}
```

**Key Insights**:
- **Version/Serial**: Detect concurrent modifications
- **Lineage**: Prevent mixing state from different infrastructures
- **Dependencies**: Graph for correct destroy order
- **Schema Version**: Handle resource type changes over time

### 3.3 NixOS Generation Metadata

```
/nix/var/nix/profiles/
├── system -> system-43-link
├── system-41-link -> /nix/store/abc123-nixos-system-41
├── system-42-link -> /nix/store/def456-nixos-system-42
└── system-43-link -> /nix/store/ghi789-nixos-system-43

Each generation stores:
- Full system closure (all dependencies)
- Configuration.nix that produced it
- Timestamp of creation
- Bootloader entries
```

**Rollback**: Just symlink to previous generation. All dependencies immutable in Nix store.

### 3.4 Docker Compose State

Docker Compose doesn't maintain explicit state files. Instead:

1. **Labels**: Attach metadata to containers
   ```yaml
   labels:
     com.docker.compose.project: "myapp"
     com.docker.compose.service: "web"
     com.docker.compose.version: "1.29.2"
     com.docker.compose.config-hash: "abc123"
   ```

2. **Reconciliation**: Query Docker API for containers with matching labels
3. **Diff**: Compare container config vs. desired config
4. **Action**: Recreate if config changed, no-op if same

**Trade-off**: No persistent state means can't detect out-of-band changes to non-Docker-managed containers.

### 3.5 Recommended Metadata for Zap

```zsh
# ~/.local/share/zap/metadata.zsh
# Auto-generated - do not edit manually

typeset -gA ZAP_PLUGIN_METADATA

# Plugin: ohmyzsh/ohmyzsh
ZAP_PLUGIN_METADATA[ohmyzsh/ohmyzsh]=(
  desired_version "master"
  current_commit "a1b2c3d4e5f6"
  last_update_check 1729267200
  status "installed"
  install_time 1729180800
  source_url "https://github.com/ohmyzsh/ohmyzsh"
  subdir "plugins/git"
)

# Plugin: zsh-users/zsh-syntax-highlighting
ZAP_PLUGIN_METADATA[zsh-users/zsh-syntax-highlighting]=(
  desired_version "v0.8.0"
  current_commit "abcdef123456"
  last_update_check 1729267200
  status "installed"
  install_time 1729180800
  source_url "https://github.com/zsh-users/zsh-syntax-highlighting"
  subdir ""
)
```

**Benefits**:
- Fast load (no git operations needed on startup)
- Enables drift detection
- Supports `zap list --verbose`
- Enables smart update checks (skip if checked recently)

## 4. File Format Choices

### 4.1 Comparison Matrix

| Format | Pros | Cons | Best For |
|--------|------|------|----------|
| **YAML** | Human-readable, widely known, supports complex structures | Indentation-sensitive, ambiguous parsing, security issues (arbitrary code execution) | Configuration with nested data |
| **TOML** | Simple, unambiguous, no indentation issues, explicit typing | Less widespread, limited nesting support | Flat/moderate configuration |
| **JSON** | Ubiquitous, strict parsing, machine-friendly | Not human-friendly (no comments, trailing commas), verbose | API responses, machine-generated config |
| **Nix Expressions** | Functional, composable, Turing-complete | Steep learning curve, niche ecosystem | Complex systems requiring logic in config |
| **Custom DSL** | Tailored to use case, minimal syntax | Requires custom parser, documentation burden | Simple, domain-specific needs |

### 4.2 Why Each System Chose Their Format

**Kubernetes → YAML**:
- Need: Nested resources, lists, metadata
- Users: Wide range (devs, ops, admins)
- Decision: YAML is "good enough" and familiar
- Regrets: Indentation errors, security issues with Helm templates

**Terraform → HCL (HashiCorp Configuration Language)**:
- Need: Declarative with some logic (variables, conditionals)
- Users: Infrastructure engineers
- Decision: Custom DSL balances readability + power
- Win: `terraform fmt` auto-formats, better error messages than YAML

**Docker Compose → YAML**:
- Need: Service definitions with ports, volumes, networks
- Users: Developers familiar with docker-compose v1 (also YAML)
- Decision: Continuity + widespread YAML knowledge
- Trade-off: Anchors/references for DRY configs are confusing

**NixOS → Nix Language**:
- Need: Entire OS configuration with packages, services, users
- Users: Advanced Linux users willing to learn
- Decision: Full programming language for composability
- Win: Can abstract common patterns, share modules
- Cost: Extremely steep learning curve

**Ansible → YAML**:
- Need: Playbooks with tasks, handlers, variables
- Users: Ops teams, not necessarily programmers
- Decision: YAML for accessibility
- Regret: Complex Jinja2 templating needed for logic → readability suffers

### 4.3 Recommendation for Zap

**Decision: Simple line-based format** (already chosen in research.md)

**Why not YAML/TOML?**
1. **Parsing complexity**: Requires external parser (against "lightweight" goal)
2. **Overkill**: Plugin specs are simple key-value, not nested structures
3. **Performance**: Parsing YAML on every shell startup adds overhead
4. **Error-prone**: YAML indentation issues frustrate users

**Why not Zsh arrays/hashes?**
1. **Readability**: Less obvious to non-Zsh users
2. **Editability**: Harder to manually edit than plain text
3. **Tooling**: Can't use standard text tools (grep, sed) easily

**Why custom line-based format wins**:
1. **Parse speed**: Native Zsh `read` is fast
2. **Human-friendly**: Looks like `.gitignore` or `requirements.txt`
3. **Git-friendly**: Line-based → clean diffs
4. **Familiar**: Similar to Antigen, Antibody, other Zsh managers
5. **Extensible**: Can add `key:value` syntax later if needed

## 5. User Workflow Patterns

### 5.1 Declarative Workflow (Recommended)

**Terraform Model**:
```bash
# 1. Edit config
vim main.tf

# 2. Preview changes
terraform plan

# 3. Review plan
# (Shows what will be created/updated/destroyed)

# 4. Apply changes
terraform apply

# 5. Verify
terraform show
```

**Kubernetes Model**:
```bash
# 1. Edit manifest
vim deployment.yaml

# 2. Preview diff
kubectl diff -f deployment.yaml

# 3. Apply
kubectl apply -f deployment.yaml

# 4. Watch rollout
kubectl rollout status deployment/myapp
```

### 5.2 Imperative Workflow (Discouraged)

**Docker without Compose**:
```bash
docker run -d --name web nginx
docker stop web
docker rm web
docker run -d --name web -p 80:80 nginx
# Risk: Drift from manual commands, no reproducibility
```

### 5.3 Hybrid Workflow (Pragmatic)

**Docker Compose Supports Both**:
```bash
# Declarative
docker-compose up -d

# But also imperative
docker-compose exec web bash
docker-compose restart web
```

**Key**: Imperative commands for **temporary** changes, declarative for **persistent** state.

### 5.4 Recommended Workflow for Zap

**Declarative (Primary)**:
```bash
# 1. User edits ~/.zap/plugins.zsh
echo "zsh-users/zsh-autosuggestions" >> ~/.zap/plugins.zsh

# 2. Reconciliation happens on next shell start
zsh

# Alternative: Explicit apply
zap sync  # Future command
```

**Imperative (Secondary - for experimentation)**:
```bash
# Temporary load (not persisted to config)
zap try user/repo

# If satisfied, add to config
zap install user/repo  # Appends to ~/.zap/plugins.zsh
```

**Drift Handling**:
```bash
# Detect drift (config vs. installed)
zap status

# Show what would change
zap plan  # Future command

# Reconcile (install missing, remove unlisted)
zap sync --prune
```

## 6. Zsh-Specific Considerations

### 6.1 Shell Startup Constraints

**Challenge**: Unlike infrastructure tools, Zap runs during shell initialization.

**Implications**:
- **Speed critical**: Every millisecond matters (user feels >100ms delay)
- **No blocking operations**: Can't wait for network on every startup
- **Graceful degradation**: Failed plugins shouldn't break shell

**Solutions**:
1. **Lazy reconciliation**: Only check state if config changed
2. **Background updates**: Async update checks with notifications
3. **Cached metadata**: Fast reads, infrequent writes

### 6.2 State Persistence Location

**Options**:
1. **In-memory only**: Lost on shell exit (❌ not durable)
2. **Embedded in config**: Metadata in comments (⚠️ manual editing breaks it)
3. **Separate state file**: `~/.local/share/zap/metadata.zsh` (✅ recommended)

**XDG Base Directory Spec**:
```
XDG_CONFIG_HOME (~/.config)     → User config (plugins.zsh)
XDG_DATA_HOME (~/.local/share)  → Program state (metadata.zsh, plugins/)
XDG_CACHE_HOME (~/.cache)       → Disposable cache (load-order.cache)
```

### 6.3 Idempotency in Shell Context

**Challenge**: Sourcing a plugin twice can cause issues:
- Aliases re-defined (harmless)
- Functions re-defined (harmless)
- PATH modified twice → duplicates (⚠️ subtle bug)
- Hooks registered twice → double execution (❌ broken behavior)

**Solutions**:
1. **Guard variables**: `[[ -n $PLUGIN_LOADED ]] && return`
2. **Idempotent operations**: Use `typeset -gU path` (unique array)
3. **Track loaded plugins**: Skip if already sourced

```zsh
# Anti-pattern
export PATH="$HOME/bin:$PATH"  # Duplicates on re-source

# Idempotent pattern
path=("$HOME/bin" $path)       # Zsh array auto-deduplicates if typeset -U
typeset -U path                # Mark path as unique
```

### 6.4 Conflict Detection

**Unlike infrastructure**: Can't isolate plugins from each other. All run in same shell process.

**Potential conflicts**:
1. **Alias conflicts**: Two plugins define same alias
2. **Function conflicts**: Two plugins define same function
3. **Keybinding conflicts**: Two plugins bind same key
4. **PATH conflicts**: Two plugins add conflicting binaries

**Detection strategy**:
```zsh
# Before loading plugin
_zap_snapshot_state() {
  local -a existing_aliases=(${(k)aliases})
  local -a existing_functions=(${(k)functions})
  # Store in associative array keyed by plugin name
}

# After loading plugin
_zap_detect_conflicts() {
  local -a new_aliases=(${(k)aliases})
  local -a conflicting=(${existing_aliases:*new_aliases})  # Intersection
  if (( ${#conflicting} > 0 )); then
    _zap_warn "Plugin $1 overwrote aliases: ${conflicting[*]}"
  fi
}
```

**Resolution**: Warn user, let last-loaded plugin win (same as manual sourcing).

### 6.5 Dependency Ordering

**Challenge**: Plugin A requires Plugin B to be loaded first.

**Solutions**:

1. **Manual ordering** (simple):
   ```zsh
   # User lists in dependency order
   zsh-users/zsh-syntax-highlighting  # Must be last
   ```

2. **Topological sort** (complex):
   ```zsh
   # Plugins declare dependencies
   # user/plugin-a depends:user/plugin-b
   # Zap sorts into correct load order
   ```

**Recommendation**: Start with manual ordering. Add automatic sorting if users request it.

### 6.6 Framework Compatibility

**Oh-My-Zsh expects**:
- `$ZSH` = framework directory
- `$ZSH_CUSTOM` = user customizations
- Specific initialization order

**Prezto expects**:
- `$ZDOTDIR` = config directory
- Specific module loading mechanism

**Zap's approach**:
1. Detect framework plugins by repo pattern
2. Set environment variables before loading
3. Use framework's native plugin loader for framework plugins
4. Use Zap's loader for standalone plugins

```zsh
# Pseudocode
_zap_load_plugin() {
  local plugin=$1

  case $plugin in
    ohmyzsh/ohmyzsh*)
      _zap_init_omz
      source "$ZSH/oh-my-zsh.sh"
      ;;
    sorin-ionescu/prezto*)
      _zap_init_prezto
      source "${ZDOTDIR:-$HOME}/.zpreztorc"
      ;;
    *)
      _zap_source_plugin "$plugin"
      ;;
  esac
}
```

## 7. Recommendations for Zap Implementation

### 7.1 Reconciliation Strategy

**Adopt level-based reconciliation**:

```zsh
_zap_reconcile() {
  # 1. Parse desired state (user config)
  local -a desired_plugins
  _zap_parse_config desired_plugins

  # 2. Query current state (installed plugins)
  local -a installed_plugins
  _zap_query_installed installed_plugins

  # 3. Calculate diff
  local -a to_install=(${desired_plugins:|installed_plugins})  # Set difference
  local -a to_remove=(${installed_plugins:|desired_plugins})
  local -a to_update=(${desired_plugins:*installed_plugins})   # Intersection

  # 4. Reconcile
  for plugin in $to_install; do
    _zap_install_plugin "$plugin"
  done

  for plugin in $to_update; do
    _zap_check_updates "$plugin"
  done

  if [[ $ZAP_PRUNE == 1 ]]; then
    for plugin in $to_remove; do
      _zap_remove_plugin "$plugin"
    done
  fi
}
```

### 7.2 State File Format

**Use Zsh-native format** for fast parsing:

```zsh
# ~/.local/share/zap/metadata.zsh
# Generated by zap - do not edit manually
# Version: 1
# Last sync: 2025-10-18T14:23:45Z

typeset -gA _ZAP_META

_ZAP_META[ohmyzsh/ohmyzsh:desired_version]="master"
_ZAP_META[ohmyzsh/ohmyzsh:current_commit]="a1b2c3d4"
_ZAP_META[ohmyzsh/ohmyzsh:last_check]=1729267200
_ZAP_META[ohmyzsh/ohmyzsh:status]="installed"

_ZAP_META[zsh-users/zsh-autosuggestions:desired_version]="v0.7.0"
_ZAP_META[zsh-users/zsh-autosuggestions:current_commit]="e5f123ab"
_ZAP_META[zsh-users/zsh-autosuggestions:last_check]=1729267200
_ZAP_META[zsh-users/zsh-autosuggestions:status]="installed"
```

**Why**:
- Native Zsh: `source metadata.zsh` loads instantly
- Structured: Key format `plugin:field` enables queries
- Atomic writes: Write to temp file, then `mv` (atomic on POSIX)

### 7.3 Preview Mode Implementation

```zsh
zap plan() {
  local -a desired installed to_install to_remove to_update

  _zap_parse_config desired
  _zap_query_installed installed

  to_install=(${desired:|installed})
  to_remove=(${installed:|desired})

  # Check versions for installed plugins
  for plugin in ${desired:*installed}; do
    local desired_ver current_ver
    desired_ver=$(_zap_get_desired_version "$plugin")
    current_ver=$(_zap_get_current_commit "$plugin")

    if [[ $desired_ver != $current_ver ]]; then
      to_update+=("$plugin")
    fi
  done

  # Display plan
  if (( ${#to_install} > 0 )); then
    print -P "%F{green}Plugins to install:%f"
    printf '  + %s\n' "${to_install[@]}"
  fi

  if (( ${#to_update} > 0 )); then
    print -P "%F{yellow}Plugins to update:%f"
    printf '  ~ %s\n' "${to_update[@]}"
  fi

  if (( ${#to_remove} > 0 )); then
    print -P "%F{red}Plugins to remove (use --prune):%f"
    printf '  - %s\n' "${to_remove[@]}"
  fi

  if (( ${#to_install} + ${#to_update} + ${#to_remove} == 0 )); then
    print -P "%F{green}✓ No changes needed%f"
  fi
}
```

### 7.4 Drift Detection

**Cheap check** (runs on shell startup):
```zsh
# Check if config file modified since last sync
if [[ ~/.zap/plugins.zsh -nt ~/.local/share/zap/metadata.zsh ]]; then
  _zap_warn "Config changed since last sync. Run 'zap sync' to reconcile."
fi
```

**Full check** (runs on `zap status`):
```zsh
zap status() {
  local -a desired installed
  _zap_parse_config desired
  _zap_query_installed installed

  local -a drift=(${installed:|desired})

  if (( ${#drift} > 0 )); then
    print -P "%F{yellow}⚠ Drift detected:%f"
    print "Plugins installed but not in config:"
    printf '  %s\n' "${drift[@]}"
    print "\nRun 'zap sync --prune' to remove them."
  else
    print -P "%F{green}✓ All plugins match config%f"
  fi
}
```

### 7.5 Atomic Operations

**Ensure metadata updates are atomic**:

```zsh
_zap_update_metadata() {
  local plugin=$1
  local field=$2
  local value=$3

  local tmpfile="${XDG_DATA_HOME:-$HOME/.local/share}/zap/metadata.zsh.tmp"
  local metafile="${XDG_DATA_HOME:-$HOME/.local/share}/zap/metadata.zsh"

  # Read current metadata
  [[ -f $metafile ]] && source "$metafile"

  # Update field
  _ZAP_META["${plugin}:${field}"]="$value"

  # Write to temp file
  {
    print "# Generated by zap - do not edit"
    print "# Last updated: $(date -Iseconds)"
    print "typeset -gA _ZAP_META"

    for key in ${(k)_ZAP_META}; do
      printf '_ZAP_META[%s]=%s\n' "${(q)key}" "${(q)_ZAP_META[$key]}"
    done
  } > "$tmpfile"

  # Atomic move
  mv -f "$tmpfile" "$metafile"
}
```

**Why atomic**:
- If process killed mid-write, metadata remains valid (old version)
- No corrupted state files
- Safe for concurrent shells reading metadata

### 7.6 Update Check Optimization

**Problem**: Checking 25 plugins for updates takes time (git network operations).

**Solution**: Stagger checks, cache results.

```zsh
_zap_should_check_update() {
  local plugin=$1
  local last_check=${_ZAP_META[${plugin}:last_check]:-0}
  local now=$(date +%s)
  local interval=${ZAP_UPDATE_INTERVAL:-86400}  # 24 hours default

  (( now - last_check > interval ))
}

zap update() {
  local plugin

  for plugin in $(_zap_list_installed); do
    if _zap_should_check_update "$plugin"; then
      _zap_check_remote_updates "$plugin"
      _zap_update_metadata "$plugin" "last_check" "$(date +%s)"
    fi
  done
}
```

**Async update checks** (future enhancement):
```zsh
# Background process checks updates, writes to separate file
# Shell reads update notifications on next startup
zap update --async &!  # Disown process
```

### 7.7 Testing Strategy for Declarative Features

**Test scenarios**:

1. **Idempotency**:
   ```zsh
   # Test: Running sync twice should be no-op
   zap sync
   first_state=$(zap list)

   zap sync
   second_state=$(zap list)

   [[ $first_state == $second_state ]]  # Should be identical
   ```

2. **Drift detection**:
   ```zsh
   # Test: Manual plugin install detected
   git clone https://github.com/user/plugin ~/.local/share/zap/plugins/user__plugin

   zap status  # Should warn about drift
   ```

3. **Reconciliation**:
   ```zsh
   # Test: Adding plugin to config installs it
   echo "user/new-plugin" >> ~/.zap/plugins.zsh

   zap sync

   [[ -d ~/.local/share/zap/plugins/user__new-plugin ]]  # Should exist
   ```

4. **Preview mode**:
   ```zsh
   # Test: Plan doesn't change state
   before=$(zap list)

   zap plan

   after=$(zap list)
   [[ $before == $after ]]  # No changes
   ```

## 8. Implementation Roadmap

### Phase 1: Foundation (Current)
- [x] Line-based config parser
- [x] Plugin installation/loading
- [x] Basic metadata tracking

### Phase 2: Declarative Core (Recommended Next)
- [ ] Implement `zap sync` command (reconciliation loop)
- [ ] Implement `zap plan` command (preview mode)
- [ ] Implement `zap status` command (drift detection)
- [ ] Metadata file with atomic writes
- [ ] Track desired vs. current state

### Phase 3: Advanced Features (Future)
- [ ] Three-way merge for manual changes
- [ ] Dependency resolution and topological sort
- [ ] Async update checks
- [ ] Lock file for reproducible builds
- [ ] Rollback to previous plugin set

### Phase 4: Polish (Future)
- [ ] `zap doctor` diagnostics
- [ ] Conflict detection and warnings
- [ ] Performance profiling tools
- [ ] Migration from other plugin managers

## 9. Key Takeaways

1. **Separation of concerns**: Config (desired) vs. state (actual) vs. metadata (tracking)

2. **Idempotency is mandatory**: Users should be able to run `zap sync` anytime without fear

3. **Preview before apply**: Let users see changes before committing (`zap plan`)

4. **Level-based reconciliation**: Continuously align actual state to desired state

5. **Atomic operations**: Metadata updates must be all-or-nothing

6. **Fast common case**: Optimize for "no changes needed" path

7. **Graceful degradation**: Failures shouldn't break the shell

8. **Simple formats win**: Line-based config beats YAML for Zsh use case

9. **Track metadata separately**: Don't pollute config with implementation details

10. **Learn from production systems**: NixOS, Terraform, Kubernetes have solved these problems at scale

## 10. References

- [NixOS Manual: Configuration](https://nixos.org/manual/nixos/stable/)
- [Terraform State Management](https://www.terraform.io/language/state)
- [Kubernetes Declarative Management](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/)
- [Docker Compose Specification](https://docs.docker.com/compose/compose-file/)
- [kubectl apply Three-Way Merge](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/#how-apply-calculates-differences-and-merges-changes)
- [Idempotency in Distributed Systems](https://www.infoq.com/articles/idempotent-operations/)
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)

---

**Next Steps**: Use these patterns to design `zap sync`, `zap plan`, and `zap status` commands per spec requirements.
