# Research: Zsh Plugin Manager

**Feature**: 001-zsh-plugin-manager
**Date**: 2025-10-17
**Phase**: 0 (Outline & Research)

## Purpose

Research technical decisions, best practices, and patterns for building a lightweight Zsh plugin manager compatible with Oh-My-Zsh and Prezto ecosystems.

## Key Research Areas

### 1. Plugin Specification Format

**Decision**: Simple line-based format with intuitive syntax

**Format**:
```zsh
# Basic plugin
user/repo

# Version pinning
user/repo@v1.2.3
user/repo@commit-hash
user/repo@branch-name

# Subdirectory path
user/repo path:plugins/git

# Combined
ohmyzsh/ohmyzsh@master path:plugins/kubectl

# Comments and blank lines ignored
# user/disabled-plugin
```

**Rationale**:
- Mimics Antigen's simplicity while adding clarity
- No complex DSL or learning curve
- Easy to parse with Zsh built-ins
- Human-readable and git-diff friendly
- Supports all required features (FR-002, FR-004, FR-005)

**Alternatives Considered**:
- **TOML/YAML**: Rejected - requires external parser, adds complexity
- **Zsh array syntax**: Rejected - less intuitive for non-Zsh experts, harder to edit
- **Function calls**: Rejected - more complex, requires sourcing config before parsing

### 2. Testing Strategy

**Decision**: Multi-layered testing with BATS + Zsh Test Framework

**Tools Selected**:
- **BATS (Bash Automated Testing System)**: Integration tests, cross-shell compatibility validation
- **Zsh Test Framework (ztf)** or **shunit2**: Unit tests for Zsh functions
- **Manual performance benchmarks**: Shell startup timing with `time zsh -i -c exit`

**Rationale**:
- BATS is widely adopted, has good GitHub Actions support, handles subprocess testing well
- ztf/shunit2 provides xUnit-style assertions for shell scripts
- Performance testing requires real-world shell startup measurement
- Satisfies constitution's TDD requirement and 80% coverage target

**Test Coverage Strategy**:
- Contract tests: Plugin spec parsing, framework detection
- Integration tests: Full install flow, plugin load cycles, update checking
- Unit tests: Utility functions, Git operations, path resolution

**Alternatives Considered**:
- **Pure Zsh assertions**: Rejected - reinventing the wheel, no TAP output
- **Docker-based testing only**: Rejected - too slow for TDD workflow, but will use in CI

### 3. Oh-My-Zsh / Prezto Compatibility

**Decision**: Auto-detect framework and set up environment variables/functions before loading plugins

**Implementation Strategy**:
1. Detect framework plugins by repository pattern (`ohmyzsh/ohmyzsh`, `sorin-ionescu/prezto`)
2. Clone base framework to cache if not present
3. Set framework-specific environment variables:
   - Oh-My-Zsh: `ZSH`, `ZSH_CUSTOM`, `ZSH_CACHE_DIR`
   - Prezto: `ZDOTDIR`, `PREZTO`
4. Source framework initialization files before plugin loading
5. Load framework plugins using framework-native methods

**Rationale**:
- Transparent to user (FR-017)
- Leverages existing framework initialization logic
- Avoids reimplementing framework internals
- Achieves 90%+ compatibility goal (SC-005)

**Alternatives Considered**:
- **Reimplement framework logic**: Rejected - maintenance burden, compatibility fragility
- **Require manual framework installation**: Rejected - violates transparency requirement
- **Fork and vendor frameworks**: Rejected - licensing complexity, update lag

### 4. Performance Optimization

**Decision**: Lazy loading with startup profiling and parallel git operations

**Techniques**:
1. **Lazy source where possible**: Only source files that register commands/completions
2. **Parallel cloning**: Use background jobs for initial multi-plugin installation
3. **Cache plugin load order**: Avoid re-parsing config on every shell startup
4. **Minimize subshells**: Use Zsh builtins instead of external commands where possible
5. **Defer completion loading**: Use `compinit` once after all plugins loaded

**Rationale**:
- Meets < 1 second startup target for 10 plugins (SC-002)
- Reduces redundant work (parsing, file I/O)
- Zsh supports background jobs natively
- Antigen's performance issues came from excessive sourcing

**Measurement Plan**:
- Benchmark baseline bare Zsh: `time zsh -i -c exit`
- Benchmark with 10/25 plugins, measure delta
- Profile with `zsh -xv` to identify bottlenecks
- Target: < 100ms overhead for plugin manager itself

**Alternatives Considered**:
- **Compiled plugin cache**: Rejected - complex, fragile across Zsh versions
- **Async loading**: Rejected - causes race conditions with plugin dependencies
- **Precompiled zwc files**: Considered for future optimization, not MVP

### 5. Error Handling & Recovery

**Decision**: Graceful degradation with detailed warnings

**Strategy**:
- Never block shell startup (FR-015, FR-018)
- Log failures to `~/.local/share/zap/errors.log`
- Display summary of failures on shell start (colorized, dismissible)
- Provide `zap doctor` command to diagnose issues

**Error Categories**:
1. **Network failures**: Skip plugin, warn, suggest retry
2. **Invalid version pins**: Fall back to latest, warn (FR-019)
3. **Missing subdirectories**: Skip plugin, provide path correction hint
4. **Git errors**: Show git output, suggest manual intervention
5. **Disk space**: Fail fast with clear error before partial download

**Rationale**:
- Aligns with constitution's UX principle (actionable error messages)
- Prevents frustration from broken terminal
- Enables debugging without breaking workflow

**Alternatives Considered**:
- **Silent failures**: Rejected - users don't know what broke
- **Strict mode (fail on any error)**: Rejected - violates graceful degradation requirement
- **Automatic retry logic**: Deferred - adds complexity, may mask persistent issues

### 6. Cache Management

**Decision**: XDG Base Directory structure with plugin metadata

**Cache Structure**:
```
~/.local/share/zap/
├── plugins/
│   ├── user__repo/          # Double underscore separator
│   │   ├── .git/
│   │   └── [plugin files]
│   └── ohmyzsh__ohmyzsh/
│       ├── .git/
│       └── plugins/
│           └── git/
├── metadata.zsh             # Plugin versions, last update check
├── load-order.cache         # Cached parsed config
└── errors.log               # Error log
```

**Rationale**:
- XDG compliance (clarification answer)
- Double underscore avoids filesystem path issues
- Metadata enables fast update checking without git operations
- Separate errors.log for debugging

**Alternatives Considered**:
- **Flat structure**: Rejected - namespace collisions possible
- **Hash-based paths**: Rejected - harder to manually inspect/debug
- **SQLite metadata**: Rejected - external dependency, overkill for simple key-value data

### 7. Version Pinning Implementation

**Decision**: Git checkout with detached HEAD for commits/tags, track branches

**Implementation**:
```zsh
# After clone/pull
case $version_spec in
  v*|[0-9]*) git checkout --quiet "tags/$version_spec" 2>/dev/null || \
             git checkout --quiet "$version_spec" ;;  # Commit hash fallback
  *)         git checkout --quiet "$version_spec" ;;  # Branch
esac
```

**Rationale**:
- Handles tags, commits, branches uniformly
- Quiet mode reduces noise
- Fallback from tag to commit supports both patterns
- Non-existent refs trigger warning, fall back to latest (FR-019)

**Alternatives Considered**:
- **Lock file with exact commits**: Rejected - requires additional tooling, not lightweight
- **Shallow clones with specific refs**: Considered for bandwidth optimization, adds complexity

## Dependencies Matrix

| Dependency | Required | Purpose | Fallback |
|------------|----------|---------|----------|
| Git | Yes | Clone plugins | None - fail with error |
| curl/wget | Optional | Download tarballs (future) | Use git clone |
| zsh 5.0+ | Yes | Shell environment | None - platform requirement |
| BATS | Dev only | Integration testing | shunit2 |
| compinit | Yes | Completion system | Warn if missing |

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Plugin repo breaks compatibility | High | Medium | Version pinning, graceful degradation |
| Network unavailable on first load | High | Low | Clear error, allow manual installation |
| Git version incompatibility | Medium | Low | Document minimum Git version (2.0+) |
| Name conflicts with existing tools | Low | Medium | Use `zap` namespace consistently |
| Large plugin slows startup | Medium | Medium | Lazy loading, warn on >5s startup |

## Performance Baselines

**Target Metrics** (from spec):
- 10 plugins: < 1 second startup
- 25 plugins: < 2 seconds startup
- Update check (10 plugins): < 5 seconds
- Memory overhead: < 10MB

**Profiling Plan**:
1. Measure baseline Zsh startup: `hyperfine 'zsh -i -c exit'`
2. Add plugin manager overhead measurement
3. Add 10 test plugins, measure
4. Add 15 more plugins, measure
5. Identify and optimize slowest operations

## Best Practices Summary

1. **Use Zsh builtins over external commands** (faster, fewer forks)
2. **Parse config once, cache results** (avoid repeated I/O)
3. **Background long operations** (git clone during install)
4. **Provide escape hatches** (disable plugins, manual mode)
5. **Follow XDG standards** (predictable, standard locations)
6. **Optimize the common case** (fast load, slower install)
7. **Test on multiple platforms** (Linux, macOS, BSD)
8. **Document the Why** (comments explain rationale per constitution)

## Next Steps

Phase 1 will use these research findings to:
1. Define data model for plugin specifications, metadata, cache structure
2. Specify CLI interface contracts (`zap update`, `zap clean`, etc.)
3. Create quickstart guide based on researched installation flow
